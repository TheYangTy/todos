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
    @State private var newHasReminder: Bool = false          // 新增
    @State private var newReminderTime: Date = Date()        // 新增
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
    @AppStorage("defaultPriority") private var defaultPriorityRaw: String = TodoItem.Priority.medium.rawValue
    @AppStorage("enableNotifications") private var enableNotifications: Bool = false
    @AppStorage("enableICloudSync") private var enableICloudSync: Bool = false

    // 角标相关设置
    @AppStorage("badgeMode") private var badgeModeRaw: String = BadgeMode.today.rawValue
    @AppStorage("badgeRangeStart") private var badgeRangeStartTime: Double = Date().timeIntervalSince1970
    @AppStorage("badgeRangeEnd") private var badgeRangeEndTime: Double = Date().timeIntervalSince1970

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

                

                // 待完成（带数量）
                if !incompleteIndices.isEmpty {
                    Section {
                        ForEach(incompleteIndices, id: \.self) { idx in
                            let listName = nameForList(id: data.todos[idx].listId)

                            TodoRow(
                                todo: $data.todos[idx],
                                listName: listName,
                                lists: data.lists,
                                onToggleDone: {
                                    toggleDone(at: idx)
                                },
                                onTapDetail: {
                                    selectedTodoID = data.todos[idx].id
                                    isShowingDetail = true
                                }
                            )
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
                                onToggleDone: {
                                    toggleDone(at: idx)
                                },
                                onTapDetail: {
                                    selectedTodoID = data.todos[idx].id
                                    isShowingDetail = true
                                }
                            )
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
                        HStack {
                            Text("已完成")
                            Spacer()
                            Text("\(completedIndices.count) 项")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
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

                // 筛选按钮
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        isShowingFilterSheet = true
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                    }
                    .accessibilityLabel("筛选与排序")
                }

                // 设置入口
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink {
                        SettingsView(
                            lists: $data.lists,
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
//            .toolbarTitleMenu {     // ✅ 新增这段
//                Button {
//                    isShowingOverview = true
//                } label: {
//                    Label("总览看板", systemImage: "chart.bar.doc.horizontal")
//                }
//            }
            .sheet(isPresented: $isPresentingAddSheet) {
                addTodoSheet
            }
            .sheet(isPresented: $isShowingFilterSheet) {
                filterSheet
            }
            // 详情页导航：通过选中的 ID 找 Binding
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

                // 本地 & iCloud 存储
                AppData.saveToLocal(data)
                if enableICloudSync {
                    AppData.saveToICloud(data)
                }

                // 通知
                let active = data.todos.filter { $0.deletedAt == nil }
                NotificationManager.shared.syncNotifications(for: active,
                                                             enabled: enableNotifications)

                // 角标（根据设置计算）
                UIApplication.shared.applicationIconBadgeNumber = computeBadgeCount()

                // Widget 刷新 —— 刷新所有桌面和锁屏小组件
                let kinds = [
                    "TodosWidget",              // 首页小组件
                    "TodosOverviewWidget",      // 如果你有这个 kind（没有也没关系，多写一个不会崩）
                    "TodaySummaryLockWidget",   // 锁屏顶部一句话
                    "ProgressRingLockWidget",   // 锁屏圆环
                    "MiniListLockWidget"        // 锁屏列表
                ]

                for kind in kinds {
                    WidgetCenter.shared.reloadTimelines(ofKind: kind)
                }
            }
            .onAppear {
                purgeOldTrashIfNeeded()

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
                                // 默认给截止日当天 09:00 一个提醒时间
                                let cal = Calendar.current
                                var comps = cal.dateComponents([.year, .month, .day], from: newDueDate)
                                comps.hour = 9
                                comps.minute = 0
                                newReminderTime = cal.date(from: comps) ?? newDueDate
                            } else {
                                // 去掉截止日期时，同步关闭提醒
                                newHasReminder = false
                            }
                        }

                    if newHasDueDate {
                        DatePicker("日期",
                                   selection: $newDueDate,
                                   displayedComponents: .date)
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
                            DatePicker(
                                "提醒时间",
                                selection: $newReminderTime,
                                displayedComponents: .hourAndMinute
                            )
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
                    Text("""
                    重复任务完成后自动创建下一次任务。
                    """)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("新增事项")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        isPresentingAddSheet = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") {
                        addTodo()
                    }
                    .disabled(newTitle.trimmingCharacters(in: .whitespaces).isEmpty
                              || data.lists.isEmpty)
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
                        DatePicker("开始日期",
                                   selection: $customStartDate,
                                   displayedComponents: .date)

                        DatePicker("结束日期",
                                   selection: $customEndDate,
                                   in: customStartDate...,
                                   displayedComponents: .date)
                    }
                }
            }
            .navigationTitle("筛选与排序")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") {
                        isShowingFilterSheet = false
                    }
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
        let base = data.todos.indices.filter {
            data.todos[$0].deletedAt == nil &&
            data.todos[$0].isDone == completed &&
            matchesSearch(data.todos[$0]) &&
            matchesListFilter(data.todos[$0]) &&
            matchesDateFilter(data.todos[$0])
        }

        return base.sorted { lhs, rhs in
            let a = data.todos[lhs]
            let b = data.todos[rhs]

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

    private var incompleteIndices: [Int] {
        orderedIndices(completed: false)
    }

    private var completedIndices: [Int] {
        orderedIndices(completed: true)
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
        // 未删除且未完成的任务
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
        guard let index = data.todos.firstIndex(where: { $0.id == id }) else {
            return nil
        }
        return $data.todos[index]
    }

    // MARK: - 操作逻辑

    private func nameForList(id: UUID) -> String {
        data.lists.first(where: { $0.id == id })?.name ?? "未知清单"
    }

    private func prepareForNewTodo() {
        newTitle = ""
        newHasDueDate = false
        newDueDate = Date()
        newPriority = defaultPriority
        newRepeatRule = .none
        newHasReminder = false
        newReminderTime = Date()
        newListId = {
            switch selectedFilter {
            case .all:
                return data.lists.first?.id
            case .list(let id):
                return id
            }
        }()
    }

    private func addTodo() {
        guard let listId = newListId ?? data.lists.first?.id else { return }
        let trimmed = newTitle.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        let due: Date? = newHasDueDate ? newDueDate : nil

        // 先构造一个 item
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
        } else {
            item.reminderTime = nil
        }

        // 🔑 如果设置了重复规则且有截止日期，那么把这一刻的 dueDate 作为「基准日期」
        if newRepeatRule != .none, let due = due {
            item.repeatBaseDate = due
        }

        // （如果你在新增页里加了地点逻辑，可以在这里再给 item.location 赋值）

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

        // 只有“标记为完成”并且有重复规则、且有截止日期时，才生成下一条
        guard done,
              item.repeatRule != .none,
              let due = item.dueDate else { return }

        // 🔑 老数据可能没有 repeatBaseDate，这里兜底用当前这条任务的截止日作为基准
        let baseDate = item.repeatBaseDate ?? due

        // 避免过期很久的任务生成一堆未来任务
        if let days = Calendar.current.dateComponents([.day], from: due, to: Date()).day,
           days > 7 {
            return
        }

        // 计算下一次的截止日期（支持“每月固定某一天”）
        guard let nextDue = nextDueDate(from: due, base: baseDate, rule: item.repeatRule) else {
            return
        }

        // ✅ 计算下一次的提醒时间（如果当前任务有提醒）
        var nextReminder: Date? = nil
        if let currentReminder = item.reminderTime {
            let cal = Calendar.current
            let time = cal.dateComponents([.hour, .minute], from: currentReminder)
            var comps = cal.dateComponents([.year, .month, .day], from: nextDue)
            comps.hour = time.hour
            comps.minute = time.minute
            nextReminder = cal.date(from: comps)
        }

        // 生成下一条任务，沿用同一个 repeatBaseDate
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

    /// 根据当前这次的截止日 + 基准日期，算下一次的截止日
    private func nextDueDate(from current: Date,
                             base: Date,
                             rule: TodoItem.RepeatRule) -> Date? {
        let cal = Calendar.current

        switch rule {
        case .none:
            return nil

        case .daily:
            // 每天：在当前截止日基础上 +1 天
            return cal.date(byAdding: .day, value: 1, to: current)

        case .weekly:
            // 每周：在当前截止日基础上 +7 天
            return cal.date(byAdding: .day, value: 7, to: current)

        case .monthly:
            // 每月固定某一天：
            //   比如 base = 1 月 7 日，无论用户何时完成，
            //   下一次都应该是下一个月的 7 号。
            let baseDay = cal.component(.day, from: base)

            // 先算出“下一个月”的年月
            guard let nextMonthDate = cal.date(byAdding: .month, value: 1, to: current) else {
                return nil
            }

            var comps = cal.dateComponents([.year, .month], from: nextMonthDate)

            // 处理不同月份的天数差异（例如 31 号 → 2 月只有 28/29）
            if let range = cal.range(of: .day, in: .month, for: nextMonthDate) {
                let maxDay = range.count
                comps.day = min(baseDay, maxDay)
            } else {
                comps.day = baseDay
            }

            return cal.date(from: comps)
        }
    }

    private func moveToTrash(at index: Int) {
        // ✅ 删除用稍微重一点的震动
        mediumImpact()
        data.todos[index].deletedAt = Date()
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
}


