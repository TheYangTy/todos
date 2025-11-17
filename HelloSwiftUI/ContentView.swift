import SwiftUI
import UIKit
import WidgetKit
import MapKit

struct ContentView: View {
    @State private var data: AppData

    @State private var isPresentingAddSheet = false
    @State private var isShowingFilterSheet = false

    @State private var newTitle: String = ""
    @State private var newDueDate: Date = Date()
    @State private var newHasDueDate: Bool = false
    @State private var newPriority: TodoItem.Priority = .medium
    @State private var newRepeatRule: TodoItem.RepeatRule = .none
    @State private var newListId: UUID?
    // 新增任务时的地点相关状态
    @State private var newHasLocation: Bool = false
    @State private var newLocationName: String = ""
    @State private var newLocationRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 22.5431, longitude: 114.0579),
        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
    )
    @State private var isPresentingNewLocationPicker: Bool = false

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

                // 今天统计
                if dateFilter == .today {
                    Section {
                        let stats = todayStats
                        Text("今天共有 \(stats.total) 个任务 · 已完成 \(stats.done) 个")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
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
                // 设置入口（这里不再负责“管理清单”的跳转）
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink {
                        SettingsView(
                            lists: $data.lists,
                            onListDeleted: { deletedListId in
                                // 如果清单被删，将属于该清单的任务归到第一个清单
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

                // Widget 刷新
                WidgetCenter.shared.reloadTimelines(ofKind: "TodosWidget")
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

                    if newHasDueDate {
                        DatePicker("日期",
                                   selection: $newDueDate,
                                   displayedComponents: .date)
                    }
                }

                Section("优先级") {
                    Picker("优先级", selection: $newPriority) {
                        ForEach(TodoItem.Priority.allCases) { level in
                            Text(level.displayName).tag(level)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("重复") {
                    Picker("重复", selection: $newRepeatRule) {
                        ForEach(TodoItem.RepeatRule.allCases) { rule in
                            Text(rule.displayName).tag(rule)
                        }
                    }
                }

                // 地点（与编辑页风格保持一致）
                Section("地点") {
                    Toggle("添加地点", isOn: $newHasLocation)
                        .onChange(of: newHasLocation) { newValue in
                            if !newValue {
                                // 关闭地点时，清空名称
                                newLocationName = ""
                            }
                        }

                    if newHasLocation {
                        VStack(alignment: .leading, spacing: 4) {
                            // 地图缩略图（只读），点击后进入全屏地图选择
                            ZStack {
                                Map(coordinateRegion: $newLocationRegion, interactionModes: [])
                                    .frame(height: 120)
                                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                    // 缩略图只作为预览，不处理手势
                                    .allowsHitTesting(false)

                                // 缩略图中央的图钉（不拦截手势）
                                Image(systemName: "mappin.circle.fill")
                                    .font(.system(size: 20))
                                    .foregroundStyle(.red, .white)
                                    .allowsHitTesting(false)

                                // 透明覆盖层，专门用来接收点击，弹出全屏地图
                                Rectangle()
                                    .fill(Color.clear)
                                    .frame(height: 120)
                                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        isPresentingNewLocationPicker = true
                                    }
                            }

                            // 选定地点的名称（有名字时才显示）
                            if !newLocationName.isEmpty {
                                Text(newLocationName)
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                                    .truncationMode(.tail)
                            }
                        }
                    }
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
            // 选择地点的全屏地图（复用编辑页的 LocationPickerView）
            .sheet(isPresented: $isPresentingNewLocationPicker) {
                LocationPickerView(region: $newLocationRegion,
                                   locationName: $newLocationName)
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
        newListId = {
            switch selectedFilter {
            case .all:
                return data.lists.first?.id
            case .list(let id):
                return id
            }
        }()
        // 重置地点状态
        newHasLocation = false
        newLocationName = ""
        // 保留上一次的 region 中心也可以，如果希望重置到默认，可在此重设 newLocationRegion
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

        // 如果用户为新任务选择了地点，则写入 TodoItem.location
        if newHasLocation {
            let coord = newLocationRegion.center
            item.location = TodoItem.TodoLocation(
                name: newLocationName,
                latitude: coord.latitude,
                longitude: coord.longitude
            )
        }

        data.todos.append(item)
        isPresentingAddSheet = false
    }

    private func toggleDone(at index: Int) {
        let newValue = !data.todos[index].isDone
        markDone(at: index, done: newValue)
    }

    private func markDone(at index: Int, done: Bool) {
        let item = data.todos[index]
        data.todos[index].isDone = done

        guard done,
              item.repeatRule != .none,
              let due = item.dueDate else { return }

        // 避免过期很久的任务生成一堆未来任务
        if let days = Calendar.current.dateComponents([.day], from: due, to: Date()).day,
           days > 7 {
            return
        }

        guard let nextDue = nextDueDate(from: due, rule: item.repeatRule) else { return }

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

        let newItem = TodoItem(
            title: item.title,
            isDone: false,
            dueDate: nextDue,
            priority: item.priority,
            listId: item.listId,
            deletedAt: nil,
            repeatRule: item.repeatRule,
            reminderTime: nextReminder
        )
        data.todos.append(newItem)
    }

    private func nextDueDate(from date: Date, rule: TodoItem.RepeatRule) -> Date? {
        let cal = Calendar.current
        switch rule {
        case .none:
            return nil
        case .daily:
            return cal.date(byAdding: .day, value: 1, to: date)
        case .weekly:
            return cal.date(byAdding: .day, value: 7, to: date)
        case .monthly:
            return cal.date(byAdding: .month, value: 1, to: date)
        }
    }

    private func moveToTrash(at index: Int) {
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
