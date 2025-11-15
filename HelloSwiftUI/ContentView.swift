import SwiftUI
import UIKit
import WidgetKit

struct ContentView: View {
    @State private var data: AppData
    
    @State private var isPresentingAddSheet = false
    @State private var isShowingManageLists = false
    @State private var isShowingFilterSheet = false
    
    @State private var newTitle: String = ""
    @State private var newDueDate: Date = Date()
    @State private var newHasDueDate: Bool = false
    @State private var newPriority: TodoItem.Priority = .medium
    @State private var newRepeatRule: TodoItem.RepeatRule = .none
    @State private var newListId: UUID?
    
    @State private var searchText: String = ""
    @State private var selectedFilter: ListFilter = .all
    @State private var dateFilter: DateFilter = .all
    
    // 自定义日期范围
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
                // 1️⃣ 清单放在最上方
                Section("清单") {
                    Picker("清单", selection: $selectedFilter) {
                        Text("全部").tag(ListFilter.all)
                        ForEach(data.lists) { list in
                            Text(list.name).tag(ListFilter.list(list.id))
                        }
                    }
                    .pickerStyle(.segmented)
                }
                
                // 2️⃣ 新增待办事项放第二个
                Section {
                    Button {
                        prepareForNewTodo()
                        isPresentingAddSheet = true
                    } label: {
                        Label("新增待办事项", systemImage: "plus.circle")
                    }
                }
                
                // 3️⃣ 仅在“今天”筛选时显示统计信息
                if dateFilter == .today {
                    Section {
                        let stats = todayStats
                        Text("今天共有 \(stats.total) 个任务 · 已完成 \(stats.done) 个")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                
                // 4️⃣ 待完成（带数量）
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
                
                // 5️⃣ 已完成（带数量）
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
                
                // 6️⃣ 更多（只保留回收站，放在最底部）
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
                // 筛选按钮（排序 + 日期）放在右上角
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
                        SettingsView(openManageLists: {
                            isShowingManageLists = true
                        })
                    } label: {
                        Image(systemName: "gearshape")
                    }
                }
            }
            .sheet(isPresented: $isPresentingAddSheet) {
                addTodoSheet
            }
            // 筛选与排序的 Sheet
            .sheet(isPresented: $isShowingFilterSheet) {
                filterSheet
            }
            // 从设置页跳转到管理清单
            .navigationDestination(isPresented: $isShowingManageLists) {
                ManageListsView(lists: $data.lists) { deletedListId in
                    if let firstId = data.lists.first?.id {
                        for idx in data.todos.indices {
                            if data.todos[idx].listId == deletedListId {
                                data.todos[idx].listId = firstId
                            }
                        }
                    }
                }
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
                
                // 保存
                AppData.saveToLocal(data)
                if enableICloudSync {
                    AppData.saveToICloud(data)
                }
                
                // 通知
                let active = data.todos.filter { $0.deletedAt == nil }
                NotificationManager.shared.syncNotifications(for: active,
                                                             enabled: enableNotifications)
                
                // 角标
                let badgeCount = data.todos.filter { $0.deletedAt == nil && !$0.isDone }.count
                UIApplication.shared.applicationIconBadgeNumber = badgeCount
                
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
    
    // MARK: - 过滤 & 排序
    
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
    }
    
    private func addTodo() {
        guard let listId = newListId ?? data.lists.first?.id else { return }
        let trimmed = newTitle.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        
        let due: Date? = newHasDueDate ? newDueDate : nil
        
        let item = TodoItem(
            title: trimmed,
            isDone: false,
            dueDate: due,
            priority: newPriority,
            listId: listId,
            deletedAt: nil,
            repeatRule: newRepeatRule
        )
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
        
        let newItem = TodoItem(
            title: item.title,
            isDone: false,
            dueDate: nextDue,
            priority: item.priority,
            listId: item.listId,
            deletedAt: nil,
            repeatRule: item.repeatRule
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
