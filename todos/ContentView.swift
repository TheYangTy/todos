import SwiftUI
import UIKit
import WidgetKit

struct ContentView: View {
    @State private var data: AppData

    @State private var isPresentingAddSheet = false
    @State private var isShowingFilterSheet = false

    @State private var newTitle: String = ""
    @State private var newDueDate: Date = Date()
    @State private var newHasDueDate: Bool = false
    @State private var newPriority: TodoItem.Priority = .medium
    @State private var newRepeatRule: TodoItem.RepeatRule = .none
    @State private var newHasReminder: Bool = false
    @State private var newReminderTime: Date = Date()
    @State private var newListId: UUID?

    @State private var searchText: String = ""
    @State private var selectedFilter: ListFilter = .all
    @State private var dateFilter: DateFilter = .all

    // 自定义日期范围（列表筛选用）
    @State private var customStartDate: Date = Date()
    @State private var customEndDate: Date = Date()

    // 详情页导航用：选中的 Todo
    @State private var selectedTodoID: UUID?
    @State private var isShowingDetail: Bool = false
    
    

    @AppStorage("sortOption") private var sortOptionRaw: String = SortOption.priority.rawValue
    @AppStorage("showCompleted") private var showCompleted: Bool = true

    /// ✅ 已完成默认倒序；点击“已完成”标题切换倒序/顺序
    @AppStorage("completedSortDescending") private var completedSortDescending: Bool = true

    @AppStorage("defaultPriority") private var defaultPriorityRaw: String = TodoItem.Priority.medium.rawValue
    @AppStorage("enableNotifications") private var enableNotifications: Bool = false
    @AppStorage("enableICloudSync") private var enableICloudSync: Bool = false

    // 角标相关设置
    @AppStorage("badgeMode") private var badgeModeRaw: String = BadgeMode.today.rawValue
    @AppStorage("badgeRangeStart") private var badgeRangeStartTime: Double = Date().timeIntervalSince1970
    @AppStorage("badgeRangeEnd") private var badgeRangeEndTime: Double = Date().timeIntervalSince1970

    // ✅ 智能建议：记住你最近一次新建时的选择
    @AppStorage("smart_lastListId") private var smartLastListIdRaw: String = ""
    @AppStorage("smart_lastPriority") private var smartLastPriorityRaw: String = ""
    @AppStorage("smart_lastRepeatRule") private var smartLastRepeatRuleRaw: String = ""
    /// 仅记录“常用提醒时分”（minutesSinceMidnight），不强制开启提醒
    @AppStorage("smart_lastReminderMinutes") private var smartLastReminderMinutes: Int = 9 * 60

    // ✅ 关注 / Pin（不改 TodoItem 结构：用 UUID->时间戳 存 AppStorage）
    @AppStorage("pinnedTodoMap") private var pinnedTodoMapRaw: String = ""

    // ✅ 已完成时间（不改 TodoItem 结构：用 UUID->完成时间戳 存 AppStorage）
    @AppStorage("completedTodoMap") private var completedTodoMapRaw: String = ""

    @EnvironmentObject var quickActions: QuickActionCenter

    // MARK: - 内部枚举

    enum SortOption: String, CaseIterable, Identifiable {
        case priority
        case dueDate
        case title

        var id: Self { self }

        var displayName: String {
            switch self {
            case .priority: return "优先级"
            case .dueDate:  return "截止日期"
            case .title:    return "标题"
            }
        }
    }

    enum ListFilter: Hashable {
        case all
        case list(UUID)
    }

    enum DateFilter: String, CaseIterable, Identifiable {
        case all
        case today
        case range

        var id: Self { self }

        var displayName: String {
            switch self {
            case .all:   return "全部日期"
            case .today: return "今天"
            case .range: return "自定义"
            }
        }
    }

    private var sortOption: SortOption {
        SortOption(rawValue: sortOptionRaw) ?? .priority
    }

    private var defaultPriority: TodoItem.Priority {
        TodoItem.Priority(rawValue: defaultPriorityRaw) ?? .medium
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

    private var smartLastListId: UUID? {
        UUID(uuidString: smartLastListIdRaw)
    }

    private var smartLastPriority: TodoItem.Priority? {
        guard !smartLastPriorityRaw.isEmpty else { return nil }
        return TodoItem.Priority(rawValue: smartLastPriorityRaw)
    }

    private var smartLastRepeatRule: TodoItem.RepeatRule? {
        guard !smartLastRepeatRuleRaw.isEmpty else { return nil }
        return TodoItem.RepeatRule(rawValue: smartLastRepeatRuleRaw)
    }

    // MARK: - 初始化

    init() {
        if let local = AppData.loadFromLocal() {
            _data = State(initialValue: local)
        } else {
            _data = State(initialValue: AppData.initial())
        }
    }

    // MARK: - View

    var body: some View {
        NavigationStack {
            List {
                // 总览入口（优雅的列表行）
                Section {
                    NavigationLink {
                        OverviewView(data: $data)
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("总览看板")
                                    .font(.body)

                                let stats = todayStats
                                Text("今天 \(stats.total) 个 · 已完成 \(stats.done) 个 · 逾期 \(overdueCount) 个")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                        }
                    }
                }

                // 清单选择
                Section("清单") {
                    Picker("清单", selection: $selectedFilter) {
                        Text("全部").tag(ListFilter.all)
                        ForEach(data.lists) { list in
                            Text(list.name).tag(ListFilter.list(list.id))
                        }
                    }
                    .pickerStyle(.segmented)
                }

                // 新增待办
                Section {
                    Button {
                        prepareForNewTodo()
                        isPresentingAddSheet = true
                    } label: {
                        Label("新增待办事项", systemImage: "plus.circle")
                    }
                }

                // ✅ 关注（Pin）—— 放在“新增”下面，待完成上面
                if !pinnedIndices.isEmpty {
                    Section {
                        ForEach(pinnedIndices, id: \.self) { idx in
                            let listName = nameForList(id: data.todos[idx].listId)

                            TodoRow(
                                todo: $data.todos[idx],
                                listName: listName,
                                lists: data.lists,
                                onToggleDone: { toggleDone(at: idx) },
                                onTapDetail: {
                                    selectedTodoID = data.todos[idx].id
                                    isShowingDetail = true
                                }
                            )
                            .contextMenu {
                                Button {
                                    togglePinned(for: data.todos[idx].id)
                                } label: {
                                    Label("取消关注", systemImage: "pin.slash")
                                }
                            }
                            .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                Button {
                                    markDone(at: idx, done: true)
                                } label: {
                                    Label("完成", systemImage: "checkmark.circle")
                                }
                                .tint(.blue)
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    moveToTrash(at: idx)
                                } label: {
                                    Label("删除", systemImage: "trash")
                                }
                            }
                        }
                    } header: {
                        HStack {
                            Text("关注")
                            Spacer()
                            Text("\(pinnedIndices.count) 项")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                // 待完成（带数量）
                if !incompleteIndices.isEmpty {
                    Section {
                        ForEach(incompleteIndices, id: \.self) { idx in
                            let listName = nameForList(id: data.todos[idx].listId)

                            TodoRow(
                                todo: $data.todos[idx],
                                listName: listName,
                                lists: data.lists,
                                onToggleDone: { toggleDone(at: idx) },
                                onTapDetail: {
                                    selectedTodoID = data.todos[idx].id
                                    isShowingDetail = true
                                }
                            )
                            .contextMenu {
                                Button {
                                    togglePinned(for: data.todos[idx].id)
                                } label: {
                                    if isPinned(data.todos[idx].id) {
                                        Label("取消关注", systemImage: "pin.slash")
                                    } else {
                                        Label("关注", systemImage: "pin")
                                    }
                                }
                            }
                            .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                Button {
                                    markDone(at: idx, done: true)
                                } label: {
                                    Label("完成", systemImage: "checkmark.circle")
                                }
                                .tint(.blue)
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    moveToTrash(at: idx)
                                } label: {
                                    Label("删除", systemImage: "trash")
                                }
                            }
                        }
                    } header: {
                        HStack {
                            Text("待完成")
                            Spacer()
                            Text("\(incompleteIndices.count) 项")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                // 已完成（带数量）
                if showCompleted, !completedIndices.isEmpty {
                    Section {
                        ForEach(completedIndices, id: \.self) { idx in
                            let listName = nameForList(id: data.todos[idx].listId)

                            TodoRow(
                                todo: $data.todos[idx],
                                listName: listName,
                                lists: data.lists,
                                onToggleDone: { toggleDone(at: idx) },
                                onTapDetail: {
                                    selectedTodoID = data.todos[idx].id
                                    isShowingDetail = true
                                }
                            )
                            .contextMenu {
                                Button {
                                    togglePinned(for: data.todos[idx].id)
                                } label: {
                                    if isPinned(data.todos[idx].id) {
                                        Label("取消关注", systemImage: "pin.slash")
                                    } else {
                                        Label("关注", systemImage: "pin")
                                    }
                                }
                            }
                            .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                Button {
                                    markDone(at: idx, done: false)
                                } label: {
                                    Label("未完成", systemImage: "arrow.uturn.left.circle")
                                }
                                .tint(.blue)
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    moveToTrash(at: idx)
                                } label: {
                                    Label("删除", systemImage: "trash")
                                }
                            }
                        }
                    } header: {
                        HStack(spacing: 6) {
                            Text("已完成")
                            Image(systemName: completedSortDescending ? "chevron.down" : "chevron.up")
                                .font(.caption2)
                                .foregroundStyle(.secondary)

                            Spacer()

                            Text("\(completedIndices.count) 项")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            completedSortDescending.toggle()
                        }
                    }
                }

                // 更多
                Section("更多") {
                    NavigationLink {
                        TrashView(todos: $data.todos, lists: data.lists)
                    } label: {
                        Label("回收站", systemImage: "trash")
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("todos")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    EditButton()
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        isShowingFilterSheet = true
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                    }
                    .accessibilityLabel("筛选与排序")
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink {
                        SettingsView(
                            data: $data,
                                onListDeleted: { deletedListId in
                                if let firstId = data.lists.first?.id {
                                    for idx in data.todos.indices {
                                        if data.todos[idx].listId == deletedListId {
                                            data.todos[idx].listId = firstId
                                        }
                                    }
                                }
                            }
                        )
                    } label: {
                        Image(systemName: "gearshape")
                    }
                }
            }
            .sheet(isPresented: $isPresentingAddSheet) { addTodoSheet }
            .sheet(isPresented: $isShowingFilterSheet) { filterSheet }
            .navigationDestination(isPresented: $isShowingDetail) {
                if let id = selectedTodoID,
                   let binding = bindingForTodo(id: id) {
                    TodoEditView(todo: binding, lists: data.lists)
                } else {
                    Text("找不到该待办事项")
                }
            }
            .searchable(text: $searchText)
            .onChange(of: data) { _ in
                purgeOldTrashIfNeeded()

                AppData.saveToLocal(data)
                if enableICloudSync {
                    AppData.saveToICloud(data)
                }

                let active = data.todos.filter { $0.deletedAt == nil }
                NotificationManager.shared.syncNotifications(for: active, enabled: enableNotifications)

                UIApplication.shared.applicationIconBadgeNumber = computeBadgeCount()

                let kinds = [
                    "TodosWidget",
                    "TodosOverviewWidget",
                    "TodaySummaryLockWidget",
                    "ProgressRingLockWidget",
                    "MiniListLockWidget"
                ]
                for kind in kinds {
                    WidgetCenter.shared.reloadTimelines(ofKind: kind)
                }
            }
            .onAppear {
                purgeOldTrashIfNeeded()
                cleanupPinnedIfNeeded()

                NotificationCenter.default.addObserver(
                    forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
                    object: NSUbiquitousKeyValueStore.default,
                    queue: .main
                ) { _ in
                    guard enableICloudSync,
                          let fromCloud = AppData.loadFromICloud() else { return }
                    data = fromCloud
                }

                NSUbiquitousKeyValueStore.default.synchronize()

                handleQuickActionIfNeeded()
            }
            .onChange(of: quickActions.lastAction) { _ in
                handleQuickActionIfNeeded()
            }
        }
    }

    // MARK: - 新增 Sheet

    private var addTodoSheet: some View {
        NavigationStack {
            Form {
                Section("标题") {
                    TextField("请输入待办事项", text: $newTitle)
                }

                Section("清单") {
                    Picker("所属清单", selection: Binding(
                        get: { newListId ?? data.lists.first?.id ?? UUID() },
                        set: { newListId = $0 }
                    )) {
                        ForEach(data.lists) { list in
                            Text(list.name).tag(list.id)
                        }
                    }
                }

                Section("截止日期") {
                    Toggle("设置截止日期", isOn: $newHasDueDate)
                        .onChange(of: newHasDueDate) { hasDate in
                            if hasDate {
                                let cal = Calendar.current
                                var comps = cal.dateComponents([.year, .month, .day], from: newDueDate)
                                comps.hour = 9
                                comps.minute = 0
                                newReminderTime = cal.date(from: comps) ?? newDueDate
                            } else {
                                newHasReminder = false
                            }
                        }

                    if newHasDueDate {
                        DatePicker("日期", selection: $newDueDate, displayedComponents: .date)
                    }
                }

                Section("提醒") {
                    if !newHasDueDate {
                        Toggle("开启提醒", isOn: .constant(false))
                            .disabled(true)
                        Text("请先设置截止日期，才能选择提醒时间")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    } else {
                        Toggle("开启提醒", isOn: $newHasReminder)

                        if newHasReminder {
                            DatePicker("提醒时间", selection: $newReminderTime, displayedComponents: .hourAndMinute)
                        }
                    }
                }

                Section("优先级") {
                    Picker("优先级", selection: $newPriority) {
                        ForEach(TodoItem.Priority.allCases) { level in
                            Text(level.displayName).tag(level)
                        }
                    }
                }

                Section {
                    Picker("重复", selection: $newRepeatRule) {
                        ForEach(TodoItem.RepeatRule.allCases) { rule in
                            Text(rule.displayName).tag(rule)
                        }
                    }
                } header: {
                    Text("重复")
                } footer: {
                    Text("重复任务完成后自动创建下一次任务。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("新增事项")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { isPresentingAddSheet = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { addTodo() }
                        .disabled(newTitle.trimmingCharacters(in: .whitespaces).isEmpty || data.lists.isEmpty)
                }
            }
        }
    }

    // MARK: - 筛选 & 排序 Sheet

    private var filterSheet: some View {
        NavigationStack {
            Form {
                Section("排序方式") {
                    Picker("排序方式", selection: $sortOptionRaw) {
                        ForEach(SortOption.allCases) { option in
                            Text(option.displayName).tag(option.rawValue)
                        }
                    }
                }

                Section("日期范围") {
                    Picker("日期范围", selection: $dateFilter) {
                        ForEach(DateFilter.allCases) { filter in
                            Text(filter.displayName).tag(filter)
                        }
                    }

                    if dateFilter == .range {
                        DatePicker("开始日期", selection: $customStartDate, displayedComponents: .date)
                        DatePicker("结束日期", selection: $customEndDate, in: customStartDate..., displayedComponents: .date)
                    }
                }
            }
            .navigationTitle("筛选与排序")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { isShowingFilterSheet = false }
                }
            }
        }
    }

    // MARK: - 轻微震动反馈（Haptics）

    private func softImpact() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    private func mediumImpact() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    // MARK: - 过滤 & 排序逻辑

    private func matchesSearch(_ todo: TodoItem) -> Bool {
        let text = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return true }
        let lower = text.lowercased()
        return todo.title.lowercased().contains(lower)
    }

    private func matchesListFilter(_ todo: TodoItem) -> Bool {
        switch selectedFilter {
        case .all:
            return true
        case .list(let id):
            return todo.listId == id
        }
    }

    private func matchesDateFilter(_ todo: TodoItem) -> Bool {
        switch dateFilter {
        case .all:
            return true
        case .today:
            guard let due = todo.dueDate else { return false }
            return Calendar.current.isDateInToday(due)
        case .range:
            guard let due = todo.dueDate else { return false }
            let cal = Calendar.current
            let day = cal.startOfDay(for: due)
            let startDay = cal.startOfDay(for: customStartDate)
            let endDay = cal.startOfDay(for: customEndDate)
            return day >= startDay && day <= endDay
        }
    }

    private func orderedIndices(completed: Bool) -> [Int] {
        let base: [Int] = data.todos.indices.filter { idx in
            let t = data.todos[idx]
            return t.deletedAt == nil &&
                   t.isDone == completed &&
                   matchesSearch(t) &&
                   matchesListFilter(t) &&
                   matchesDateFilter(t)
        }

        let completedMap = loadCompletedMap()

        return base.sorted { (lhs: Int, rhs: Int) in
            let a = data.todos[lhs]
            let b = data.todos[rhs]

            if completed {
                let ta = completionDate(for: a.id, map: completedMap) ?? a.dueDate ?? Date.distantPast
                let tb = completionDate(for: b.id, map: completedMap) ?? b.dueDate ?? Date.distantPast
                if ta != tb {
                    return completedSortDescending ? (ta > tb) : (ta < tb)
                }
                return a.title.localizedCaseInsensitiveCompare(b.title) == .orderedAscending
            }

            switch sortOption {
            case .priority:
                let order: [TodoItem.Priority: Int] = [.high: 0, .medium: 1, .low: 2]
                let pa = order[a.priority] ?? 1
                let pb = order[b.priority] ?? 1
                if pa != pb { return pa < pb }

                switch (a.dueDate, b.dueDate) {
                case let (da?, db?):
                    if da != db { return da < db }
                case (nil, .some):
                    return false
                case (.some, nil):
                    return true
                default: break
                }
                return a.title < b.title

            case .dueDate:
                switch (a.dueDate, b.dueDate) {
                case let (da?, db?):
                    if da != db { return da < db }
                case (nil, .some):
                    return false
                case (.some, nil):
                    return true
                default: break
                }
                let order: [TodoItem.Priority: Int] = [.high: 0, .medium: 1, .low: 2]
                let pa = order[a.priority] ?? 1
                let pb = order[b.priority] ?? 1
                if pa != pb { return pa < pb }
                return a.title < b.title

            case .title:
                return a.title.localizedCaseInsensitiveCompare(b.title) == .orderedAscending
            }
        }
    }

    // ✅ 关注：普通列表里不重复
    private var pinnedIDSet: Set<String> {
        Set(loadPinnedMap().keys)
    }

    private var incompleteIndices: [Int] {
        orderedIndices(completed: false).filter { !pinnedIDSet.contains(data.todos[$0].id.uuidString) }
    }

    private var completedIndices: [Int] {
        orderedIndices(completed: true)
    }

    // ✅ 关注列表：仅未完成、未删除；按 pinned 时间倒序
    private var pinnedIndices: [Int] {
        let map = loadPinnedMap()

        let base = data.todos.indices.filter { idx in
            let t = data.todos[idx]
            guard t.deletedAt == nil, !t.isDone else { return false }
            guard map[t.id.uuidString] != nil else { return false }
            return matchesSearch(t) && matchesListFilter(t) && matchesDateFilter(t)
        }

        return base.sorted { lhs, rhs in
            let a = data.todos[lhs]
            let b = data.todos[rhs]
            let ta = map[a.id.uuidString] ?? 0
            let tb = map[b.id.uuidString] ?? 0
            if ta != tb { return ta > tb }

            switch sortOption {
            case .priority:
                let order: [TodoItem.Priority: Int] = [.high: 0, .medium: 1, .low: 2]
                let pa = order[a.priority] ?? 1
                let pb = order[b.priority] ?? 1
                if pa != pb { return pa < pb }
                return a.title < b.title
            case .dueDate:
                switch (a.dueDate, b.dueDate) {
                case let (da?, db?):
                    if da != db { return da < db }
                case (nil, .some):
                    return false
                case (.some, nil):
                    return true
                default: break
                }
                return a.title < b.title
            case .title:
                return a.title.localizedCaseInsensitiveCompare(b.title) == .orderedAscending
            }
        }
    }

    private var todayStats: (total: Int, done: Int) {
        let allToday = data.todos.filter { todo in
            guard let due = todo.dueDate, todo.deletedAt == nil else { return false }
            return Calendar.current.isDateInToday(due)
        }
        let done = allToday.filter { $0.isDone }.count
        return (total: allToday.count, done: done)
    }

    private var overdueCount: Int {
        let today = Calendar.current.startOfDay(for: Date())
        return data.todos.filter { todo in
            guard let due = todo.dueDate,
                  todo.deletedAt == nil,
                  !todo.isDone else { return false }
            let day = Calendar.current.startOfDay(for: due)
            return day < today
        }.count
    }

    // MARK: - 角标统计

    private func computeBadgeCount() -> Int {
        let active = data.todos.filter { $0.deletedAt == nil && !$0.isDone }

        switch badgeMode {
        case .all:
            return active.count
        case .today:
            return active.filter { todo in
                guard let due = todo.dueDate else { return false }
                return Calendar.current.isDateInToday(due)
            }.count
        case .range:
            let cal = Calendar.current
            let startDay = cal.startOfDay(for: badgeRangeStartDate)
            let endDay = cal.startOfDay(for: badgeRangeEndDate)

            return active.filter { todo in
                guard let due = todo.dueDate else { return false }
                let day = cal.startOfDay(for: due)
                return day >= startDay && day <= endDay
            }.count
        }
    }

    // MARK: - Binding 辅助

    private func bindingForTodo(id: UUID) -> Binding<TodoItem>? {
        guard let index = data.todos.firstIndex(where: { $0.id == id }) else { return nil }
        return $data.todos[index]
    }

    // MARK: - 操作逻辑

    private func nameForList(id: UUID) -> String {
        data.lists.first(where: { $0.id == id })?.name ?? "未知清单"
    }

    // ✅ 智能建议：新建时预填（不强制开启提醒）
    private func prepareForNewTodo() {
        newTitle = ""
        newHasDueDate = false
        newDueDate = Date()

        // 1) 优先级：最近一次 > 设置默认
        newPriority = smartLastPriority ?? defaultPriority

        // 2) 重复：最近一次（没有就 none）
        newRepeatRule = smartLastRepeatRule ?? .none

        // 3) 清单：如果当前筛选是某个清单，就用它；否则用“最近一次”或第一个
        newListId = {
            switch selectedFilter {
            case .all:
                if let last = smartLastListId,
                   data.lists.contains(where: { $0.id == last }) {
                    return last
                }
                return data.lists.first?.id
            case .list(let id):
                return id
            }
        }()

        // 4) 提醒：默认关闭，但把常用时间预填进去（体验更快）
        newHasReminder = false
        let minutes = max(0, smartLastReminderMinutes)
        let h = minutes / 60
        let m = minutes % 60
        var comps = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        comps.hour = h
        comps.minute = m
        newReminderTime = Calendar.current.date(from: comps) ?? Date()
    }

    private func addTodo() {
        guard let listId = newListId ?? data.lists.first?.id else { return }
        let trimmed = newTitle.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        let due: Date? = newHasDueDate ? newDueDate : nil

        var item = TodoItem(
            title: trimmed,
            isDone: false,
            dueDate: due,
            priority: newPriority,
            listId: listId,
            deletedAt: nil,
            repeatRule: newRepeatRule
        )

        // ✅ 根据开关设置提醒时间（把选择的时分投射到截止日当天）
        if newHasDueDate, let due = due, newHasReminder {
            let cal = Calendar.current
            let time = cal.dateComponents([.hour, .minute], from: newReminderTime)
            var comps = cal.dateComponents([.year, .month, .day], from: due)
            comps.hour = time.hour
            comps.minute = time.minute
            item.reminderTime = cal.date(from: comps)

            // 记录常用提醒时间（不影响你下次是否开启提醒）
            let mins = (time.hour ?? 9) * 60 + (time.minute ?? 0)
            smartLastReminderMinutes = mins
        } else {
            item.reminderTime = nil
        }

        // 🔑 重复且有截止日期：记录基准日期
        if newRepeatRule != .none, let due = due {
            item.repeatBaseDate = due
        }

        // ✅ 记录“最近一次新建选择”用于智能建议
        smartLastListIdRaw = listId.uuidString
        smartLastPriorityRaw = newPriority.rawValue
        smartLastRepeatRuleRaw = newRepeatRule.rawValue

        data.todos.append(item)
        isPresentingAddSheet = false
    }

    private func toggleDone(at index: Int) {
        let newValue = !data.todos[index].isDone
        markDone(at: index, done: newValue)
    }

    private func markDone(at index: Int, done: Bool) {
        softImpact()
        let item = data.todos[index]
        data.todos[index].isDone = done
        if done {
            recordCompletion(for: item.id)
        } else {
            removeCompletion(for: item.id)
        }

        // ✅ 完成后自动取消关注（更符合“关注=待做重点”）
        if done { unpinIfNeeded(for: item.id) }

        // 只有“完成”并且有重复规则、且有截止日期时，才生成下一条
        guard done,
              item.repeatRule != .none,
              let due = item.dueDate else { return }

        let baseDate = item.repeatBaseDate ?? due

        if let days = Calendar.current.dateComponents([.day], from: due, to: Date()).day,
           days > 7 { return }

        guard let nextDue = nextDueDate(from: due, base: baseDate, rule: item.repeatRule) else { return }

        var nextReminder: Date? = nil
        if let currentReminder = item.reminderTime {
            let cal = Calendar.current
            let time = cal.dateComponents([.hour, .minute], from: currentReminder)
            var comps = cal.dateComponents([.year, .month, .day], from: nextDue)
            comps.hour = time.hour
            comps.minute = time.minute
            nextReminder = cal.date(from: comps)
        }

        let newItem = TodoItem(
            title: item.title,
            isDone: false,
            dueDate: nextDue,
            priority: item.priority,
            listId: item.listId,
            deletedAt: nil,
            repeatRule: item.repeatRule,
            reminderTime: nextReminder,
            location: item.location,
            repeatBaseDate: baseDate
        )

        data.todos.append(newItem)
    }

    private func nextDueDate(from current: Date, base: Date, rule: TodoItem.RepeatRule) -> Date? {
        let cal = Calendar.current

        switch rule {
        case .none:
            return nil
        case .daily:
            return cal.date(byAdding: .day, value: 1, to: current)
        case .weekly:
            return cal.date(byAdding: .day, value: 7, to: current)
        case .monthly:
            let baseDay = cal.component(.day, from: base)
            guard let nextMonthDate = cal.date(byAdding: .month, value: 1, to: current) else { return nil }
            var comps = cal.dateComponents([.year, .month], from: nextMonthDate)
            if let range = cal.range(of: .day, in: .month, for: nextMonthDate) {
                comps.day = min(baseDay, range.count)
            } else {
                comps.day = baseDay
            }
            return cal.date(from: comps)
        }
    }

    private func moveToTrash(at index: Int) {
        mediumImpact()
        let id = data.todos[index].id
        data.todos[index].deletedAt = Date()
        unpinIfNeeded(for: id)
    }

    private func purgeOldTrashIfNeeded() {
        let now = Date()
        let cal = Calendar.current

        data.todos.removeAll { item in
            if let deletedAt = item.deletedAt {
                if let days = cal.dateComponents([.day], from: deletedAt, to: now).day,
                   days >= 14 {
                    return true
                }
            }
            return false
        }

        cleanupPinnedIfNeeded()
        cleanupCompletedIfNeeded()
    }

    private func handleQuickActionIfNeeded() {
        guard let action = quickActions.lastAction else { return }
        switch action {
        case .quickAdd:
            prepareForNewTodo()
            isPresentingAddSheet = true
        }
        quickActions.lastAction = nil
    }

    // MARK: - 关注 / Pin 存储（UUIDString -> pinnedAtSeconds）

    private func loadPinnedMap() -> [String: Double] {
        guard !pinnedTodoMapRaw.isEmpty,
              let data = pinnedTodoMapRaw.data(using: .utf8) else { return [:] }
        return (try? JSONDecoder().decode([String: Double].self, from: data)) ?? [:]
    }

    private func savePinnedMap(_ map: [String: Double]) {
        if let data = try? JSONEncoder().encode(map),
           let str = String(data: data, encoding: .utf8) {
            pinnedTodoMapRaw = str
        } else {
            pinnedTodoMapRaw = ""
        }
    }

    private func isPinned(_ id: UUID) -> Bool {
        loadPinnedMap()[id.uuidString] != nil
    }

    private func togglePinned(for id: UUID) {
        softImpact()
        var map = loadPinnedMap()
        let key = id.uuidString
        if map[key] != nil {
            map.removeValue(forKey: key)
        } else {
            map[key] = Date().timeIntervalSince1970
        }
        savePinnedMap(map)
    }

    private func unpinIfNeeded(for id: UUID) {
        var map = loadPinnedMap()
        let key = id.uuidString
        guard map[key] != nil else { return }
        map.removeValue(forKey: key)
        savePinnedMap(map)
    }

    private func cleanupPinnedIfNeeded() {
        var map = loadPinnedMap()
        guard !map.isEmpty else { return }
        let valid = Set(data.todos.filter { $0.deletedAt == nil && !$0.isDone }.map { $0.id.uuidString })
        map = map.filter { valid.contains($0.key) }
        savePinnedMap(map)
    }


    // MARK: - 已完成时间存储（UUIDString -> completedAtSeconds）

    private func loadCompletedMap() -> [String: Double] {
        guard !completedTodoMapRaw.isEmpty,
              let data = completedTodoMapRaw.data(using: .utf8) else { return [:] }
        return (try? JSONDecoder().decode([String: Double].self, from: data)) ?? [:]
    }

    private func saveCompletedMap(_ map: [String: Double]) {
        if let data = try? JSONEncoder().encode(map),
           let str = String(data: data, encoding: .utf8) {
            completedTodoMapRaw = str
        } else {
            completedTodoMapRaw = ""
        }
    }

    private func completionDate(for id: UUID, map: [String: Double]) -> Date? {
        guard let ts = map[id.uuidString] else { return nil }
        return Date(timeIntervalSince1970: ts)
    }

    private func recordCompletion(for id: UUID) {
        var map = loadCompletedMap()
        map[id.uuidString] = Date().timeIntervalSince1970
        saveCompletedMap(map)
    }

    private func removeCompletion(for id: UUID) {
        var map = loadCompletedMap()
        if map.removeValue(forKey: id.uuidString) != nil {
            saveCompletedMap(map)
        }
    }

    private func cleanupCompletedIfNeeded() {
        var map = loadCompletedMap()
        guard !map.isEmpty else { return }
        // 只保留：存在于 todos 且未被删除 的条目（已完成/未完成都可能要保留；但删除后就清掉）
        let valid = Set(data.todos.filter { $0.deletedAt == nil }.map { $0.id.uuidString })
        map = map.filter { valid.contains($0.key) }
        saveCompletedMap(map)
    }
}
