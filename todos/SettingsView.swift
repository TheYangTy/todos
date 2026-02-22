import SwiftUI

// 角标统计模式
enum BadgeMode: String, CaseIterable, Identifiable {
    case today      // 今天的未完成
    case range      // 自定义日期范围内的未完成
    case all        // 全部未完成

    var id: Self { self }

    var displayName: String {
        switch self {
        case .today: return "今天未完成"
        case .range: return "时间范围未完成"
        case .all:   return "全部未完成"
        }
    }
}

struct SettingsView: View {
    // ✅ 从 ContentView 传入整份数据（用于手动 iCloud 备份/恢复）
    @Binding var data: AppData

    // 清单被删除时回调，让外层（ContentView）去更新 todos 的 listId
    let onListDeleted: (UUID) -> Void

    @AppStorage("showCompleted") private var showCompleted: Bool = true
    @AppStorage("defaultPriority") private var defaultPriorityRaw: String = TodoItem.Priority.medium.rawValue
    @AppStorage("enableNotifications") private var enableNotifications: Bool = false
    @AppStorage("enableICloudSync") private var enableICloudSync: Bool = false
    @AppStorage("appTheme") private var appThemeRaw: String = AppTheme.system.rawValue

    // 角标配置
    @AppStorage("badgeMode") private var badgeModeRaw: String = BadgeMode.today.rawValue
    @AppStorage("badgeRangeStart") private var badgeRangeStartTime: Double = Date().timeIntervalSince1970
    @AppStorage("badgeRangeEnd") private var badgeRangeEndTime: Double = Date().timeIntervalSince1970

    // 优先级颜色配置（默认：高=红，中=橙，低=绿）
    @AppStorage("priorityColorHigh")  private var priorityHighColorRaw: String  = PriorityColorOption.red.rawValue
    @AppStorage("priorityColorMedium") private var priorityMediumColorRaw: String = PriorityColorOption.orange.rawValue
    @AppStorage("priorityColorLow")   private var priorityLowColorRaw: String   = PriorityColorOption.green.rawValue

    // ✅ 记录上次手动上传时间（便于用户确认“确实有备份”）
    @AppStorage("icloudLastBackupTime") private var icloudLastBackupTime: Double = 0

    // 弹窗
    @State private var showRestoreConfirm = false
    @State private var toastMessage: String? = nil

    private var defaultPriority: TodoItem.Priority {
        TodoItem.Priority(rawValue: defaultPriorityRaw) ?? .medium
    }

    private var appTheme: AppTheme {
        AppTheme(rawValue: appThemeRaw) ?? .system
    }

    private var badgeMode: BadgeMode {
        BadgeMode(rawValue: badgeModeRaw) ?? .today
    }

    private var badgeRangeStartDate: Date {
        Date(timeIntervalSince1970: badgeRangeStartTime)
    }

    private var badgeRangeEndDate: Date {
        Date(timeIntervalSince1970: badgeRangeEndTime)
    }

    private var iCloudHasBackup: Bool {
        NSUbiquitousKeyValueStore.default.data(forKey: AppData.storageKey) != nil
    }

    private var iCloudLastBackupText: String {
        guard icloudLastBackupTime > 0 else { return "未上传" }
        let date = Date(timeIntervalSince1970: icloudLastBackupTime)
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f.string(from: date)
    }

    // ✅ 把 lists 暴露为 Binding，方便复用你现有的 ManageListsView
    private var listsBinding: Binding<[TodoList]> {
        Binding(
            get: { data.lists },
            set: { data.lists = $0 }
        )
    }

    var body: some View {
        Form {
            // 显示相关
            Section("显示") {
                Toggle("显示已完成的任务", isOn: $showCompleted)

                Picker("新建任务默认优先级", selection: $defaultPriorityRaw) {
                    ForEach(TodoItem.Priority.allCases) { p in
                        Text(p.displayName).tag(p.rawValue)
                    }
                }

                Picker("应用主题", selection: $appThemeRaw) {
                    ForEach(AppTheme.allCases) { theme in
                        Text(theme.displayName).tag(theme.rawValue)
                    }
                }
            }

            // 数据与清单
            Section("数据与清单") {
                NavigationLink {
                    ManageListsView(lists: listsBinding) { deletedId in
                        onListDeleted(deletedId)
                    }
                } label: {
                    HStack {
                        Image(systemName: "list.bullet")
                        Text("管理清单")
                    }
                }
            }

            // 通知
            Section("通知") {
                Toggle("启用本地通知", isOn: $enableNotifications)
                    .onChange(of: enableNotifications) { newValue in
                        if newValue {
                            NotificationManager.shared.requestAuthorization { granted in
                                if !granted {
                                    enableNotifications = false
                                }
                            }
                        }
                    }
            }

            // 优先级颜色
            Section("优先级") {
                Picker("高优先级", selection: $priorityHighColorRaw) {
                    ForEach(PriorityColorOption.allCases) { option in
                        HStack {
                            Circle()
                                .fill(option.color)
                                .frame(width: 10, height: 10)
                            Text(option.displayName)
                        }
                        .tag(option.rawValue)
                    }
                }

                Picker("中优先级", selection: $priorityMediumColorRaw) {
                    ForEach(PriorityColorOption.allCases) { option in
                        HStack {
                            Circle()
                                .fill(option.color)
                                .frame(width: 10, height: 10)
                            Text(option.displayName)
                        }
                        .tag(option.rawValue)
                    }
                }

                Picker("低优先级", selection: $priorityLowColorRaw) {
                    ForEach(PriorityColorOption.allCases) { option in
                        HStack {
                            Circle()
                                .fill(option.color)
                                .frame(width: 10, height: 10)
                            Text(option.displayName)
                        }
                        .tag(option.rawValue)
                    }
                }

                Text("用于首页任务预览中的优先级圆点颜色，也可在小组件中复用。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            // 角标
            Section("角标") {
                Picker("角标统计范围", selection: $badgeModeRaw) {
                    ForEach(BadgeMode.allCases) { mode in
                        Text(mode.displayName).tag(mode.rawValue)
                    }
                }

                if badgeMode == .range {
                    DatePicker(
                        "开始日期",
                        selection: Binding(
                            get: { badgeRangeStartDate },
                            set: { badgeRangeStartTime = $0.timeIntervalSince1970 }
                        ),
                        displayedComponents: .date
                    )

                    DatePicker(
                        "结束日期",
                        selection: Binding(
                            get: { badgeRangeEndDate },
                            set: { badgeRangeEndTime = $0.timeIntervalSince1970 }
                        ),
                        in: badgeRangeStartDate...,
                        displayedComponents: .date
                    )
                }

                Text("角标只统计未删除且未完成的任务数量；\"今天\"和\"时间范围\"只包含设置了截止日期的任务。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
            }

            // iCloud
            Section("iCloud") {
                Toggle("使用 iCloud 同步数据", isOn: $enableICloudSync)

                HStack {
                    Text("iCloud 备份")
                    Spacer()
                    Text(iCloudHasBackup ? "已存在" : "暂无")
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Text("上次手动上传")
                    Spacer()
                    Text(iCloudLastBackupText)
                        .foregroundStyle(.secondary)
                }

                Button {
                    AppData.saveToICloud(data)
                    icloudLastBackupTime = Date().timeIntervalSince1970
                    toastMessage = "已上传到 iCloud"
                } label: {
                    Label("上传到 iCloud", systemImage: "icloud.and.arrow.up")
                }

                Button {
                    showRestoreConfirm = true
                } label: {
                    Label("从 iCloud 恢复", systemImage: "icloud.and.arrow.down")
                }
                .disabled(!iCloudHasBackup)
                .confirmationDialog(
                    "从 iCloud 恢复将覆盖本地数据，是否继续？",
                    isPresented: $showRestoreConfirm,
                    titleVisibility: .visible
                ) {
                    Button("恢复", role: .destructive) {
                        if let cloud = AppData.loadFromICloud() {
                            data = cloud
                            toastMessage = "已从 iCloud 恢复"
                        } else {
                            toastMessage = "iCloud 暂无可恢复数据"
                        }
                    }
                    Button("取消", role: .cancel) {}
                }

                Text("提示：iCloud 同步是\"最终一致\"，不会保证立刻生效。开发阶段建议手动上传一次再验证。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
            }

            // 关于
            Section("关于") {
                Text("todos · 个人待办应用")
                Text("@marcus")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("设置")
        .navigationBarTitleDisplayMode(.inline)
        .overlay(alignment: .bottom) {
            if let msg = toastMessage {
                Text(msg)
                    .font(.footnote)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
                    .padding(.bottom, 12)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                            withAnimation { toastMessage = nil }
                        }
                    }
            }
        }
    }
}
