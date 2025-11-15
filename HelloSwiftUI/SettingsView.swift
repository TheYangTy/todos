import SwiftUI

struct SettingsView: View {
    @AppStorage("showCompleted") private var showCompleted: Bool = true
    @AppStorage("defaultPriority") private var defaultPriorityRaw: String = TodoItem.Priority.medium.rawValue
    @AppStorage("enableNotifications") private var enableNotifications: Bool = false
    @AppStorage("enableICloudSync") private var enableICloudSync: Bool = false
    @AppStorage("appTheme") private var appThemeRaw: String = AppTheme.system.rawValue
    
    let openManageLists: () -> Void
    
    private var defaultPriority: TodoItem.Priority {
        TodoItem.Priority(rawValue: defaultPriorityRaw) ?? .medium
    }
    
    private var appTheme: AppTheme {
        AppTheme(rawValue: appThemeRaw) ?? .system
    }
    
    var body: some View {
        Form {
            Section("显示") {
                Toggle("显示已完成的任务", isOn: $showCompleted)
                
                Picker("新建任务默认优先级", selection: $defaultPriorityRaw) {
                    ForEach(TodoItem.Priority.allCases) { p in
                        Text(p.displayName).tag(p.rawValue)
                    }
                }
                
                // ✅ 应用主题选择：自动 / 浅色 / 深色
                Picker("应用主题", selection: $appThemeRaw) {
                    ForEach(AppTheme.allCases) { theme in
                        Text(theme.displayName).tag(theme.rawValue)
                    }
                }
            }
            
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
            
            Section("iCloud") {
                Toggle("使用 iCloud 同步数据", isOn: $enableICloudSync)
            }
            
            Section("数据与清单") {
                Button {
                    openManageLists()
                } label: {
                    HStack {
                        Image(systemName: "list.bullet")
                        Text("管理清单")
                    }
                }
            }
            
            Section("关于") {
                Text("todos · 个人待办应用")
                Text("使用 SwiftUI + WidgetKit + App Groups").font(.footnote)
            }
        }
        .navigationTitle("设置")
        .navigationBarTitleDisplayMode(.inline)
    }
}
