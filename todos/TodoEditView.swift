import SwiftUI

struct TodoEditView: View {
    @Binding var todo: TodoItem
    let lists: [TodoList]
    
    // 是否有截止日期（控制 UI）
    @State private var hasDueDate: Bool = false
    // 是否开启提醒
    @State private var hasReminder: Bool = false
    
    // 用于选择清单
    @State private var selectedListId: UUID = UUID()
    
    init(todo: Binding<TodoItem>, lists: [TodoList]) {
        self._todo = todo
        self.lists = lists
        
        _hasDueDate = State(initialValue: todo.wrappedValue.dueDate != nil)
        _hasReminder = State(initialValue: todo.wrappedValue.reminderTime != nil)
        _selectedListId = State(initialValue: todo.wrappedValue.listId)
    }
    
    var body: some View {
        Form {
            // 标题
            Section("标题") {
                TextField("请输入待办事项", text: $todo.title)
            }
            
            // 清单
            Section("清单") {
                Picker("所属清单", selection: $selectedListId) {
                    ForEach(lists) { list in
                        Text(list.name).tag(list.id)
                    }
                }
                .onChange(of: selectedListId) { newValue in
                    todo.listId = newValue
                }
            }
            
            // 优先级
            Section("优先级") {
                Picker("优先级", selection: $todo.priority) {
                    ForEach(TodoItem.Priority.allCases) { level in
                        Text(level.displayName).tag(level)
                    }
                }
                .pickerStyle(.segmented)
            }
            
            // ✅ 日期 & 提醒（放在一个 Section，提醒就在截止日期下面）
            Section("日期与提醒") {
                // 截止日期开关
                Toggle("设置截止日期", isOn: $hasDueDate)
                    .onChange(of: hasDueDate) { newValue in
                        if newValue {
                            // 开启截止日期：如果原来没有，就给一个默认今天
                            if todo.dueDate == nil {
                                todo.dueDate = Date()
                            }
                            // 如果已经有提醒，则把提醒的日期部分对齐到当前截止日
                            if let due = todo.dueDate,
                               let currentReminder = todo.reminderTime {
                                todo.reminderTime = normalizeReminderTime(
                                    from: currentReminder,
                                    toDueDate: due
                                )
                            }
                        } else {
                            // 关闭截止日期：清空截止日期 & 提醒
                            todo.dueDate = nil
                            todo.reminderTime = nil
                            hasReminder = false
                        }
                    }
                
                // 截止日期选择
                if hasDueDate {
                    DatePicker(
                        "截止日期",
                        selection: Binding(
                            get: { todo.dueDate ?? Date() },
                            set: { newDate in
                                todo.dueDate = newDate
                                // 如果已经设置了提醒时间，调整其日期部分到新的截止日
                                if let currentReminder = todo.reminderTime {
                                    todo.reminderTime = normalizeReminderTime(
                                        from: currentReminder,
                                        toDueDate: newDate
                                    )
                                }
                            }
                        ),
                        displayedComponents: .date
                    )
                }
                
                // 提醒：紧跟在截止日期下面
                if todo.dueDate == nil {
                    // 没有截止日时，提醒不可用
                    Text("请先设置截止日期才能开启提醒。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else {
                    Toggle("开启提醒", isOn: $hasReminder)
                        .onChange(of: hasReminder) { newValue in
                            if newValue {
                                // 开启提醒：如果之前没有设置，给一个默认时间（截止日当天 09:00）
                                if todo.reminderTime == nil, let due = todo.dueDate {
                                    todo.reminderTime = defaultReminderDate(for: due)
                                }
                            } else {
                                // 关闭提醒：清空 reminderTime
                                todo.reminderTime = nil
                            }
                        }
                    
                    if hasReminder, let due = todo.dueDate {
                        // 只调时间（小时+分钟），日期固定在截止日当天
                        DatePicker(
                            "提醒时间",
                            selection: Binding(
                                get: {
                                    todo.reminderTime ?? defaultReminderDate(for: due)
                                },
                                set: { newDate in
                                    todo.reminderTime = normalizeReminderTime(
                                        from: newDate,
                                        toDueDate: due
                                    )
                                }
                            ),
                            displayedComponents: .hourAndMinute
                        )
                    }
                }
            }
            
            // 重复
            Section {
                Picker("重复", selection: $todo.repeatRule) {
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
        .navigationTitle("编辑事项")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    // MARK: - Helper：默认提醒时间 = 截止日当天 09:00
    
    private func defaultReminderDate(for dueDate: Date) -> Date {
        let cal = Calendar.current
        var comps = cal.dateComponents([.year, .month, .day], from: dueDate)
        comps.hour = 9
        comps.minute = 0
        return cal.date(from: comps) ?? dueDate
    }
    
    /// 将源时间的“时分”投射到指定的截止日（保持日期 = dueDate，时间 = source 的时分）
    private func normalizeReminderTime(from source: Date, toDueDate dueDate: Date) -> Date {
        let cal = Calendar.current
        let time = cal.dateComponents([.hour, .minute], from: source)
        var comps = cal.dateComponents([.year, .month, .day], from: dueDate)
        comps.hour = time.hour
        comps.minute = time.minute
        return cal.date(from: comps) ?? dueDate
    }
}
