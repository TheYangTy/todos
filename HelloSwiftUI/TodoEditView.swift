import SwiftUI

struct TodoEditView: View {
    @Binding var todo: TodoItem
    let lists: [TodoList]
    
    @State private var hasDueDate: Bool
    @State private var tempDate: Date
    
    init(todo: Binding<TodoItem>, lists: [TodoList]) {
        _todo = todo
        self.lists = lists
        
        let initialDate = todo.wrappedValue.dueDate ?? Date()
        _tempDate = State(initialValue: initialDate)
        _hasDueDate = State(initialValue: todo.wrappedValue.dueDate != nil)
    }
    
    var body: some View {
        Form {
            Section("标题") {
                TextField("请输入待办事项", text: $todo.title)
                    .textInputAutocapitalization(.sentences)
            }
            
            Section("状态") {
                Toggle("标记为已完成", isOn: $todo.isDone)
            }
            
            Section("清单") {
                Picker("所属清单", selection: $todo.listId) {
                    ForEach(lists) { list in
                        Text(list.name).tag(list.id)
                    }
                }
            }
            
            Section("截止日期") {
                Toggle("设置截止日期", isOn: $hasDueDate)
                
                if hasDueDate {
                    DatePicker("日期",
                               selection: $tempDate,
                               displayedComponents: .date)
                }
            }
            
            Section("优先级") {
                Picker("优先级", selection: $todo.priority) {
                    ForEach(TodoItem.Priority.allCases) { level in
                        Text(level.displayName).tag(level)
                    }
                }
                .pickerStyle(.segmented)
            }
            
            Section("重复") {
                Picker("重复", selection: $todo.repeatRule) {
                    ForEach(TodoItem.RepeatRule.allCases) { rule in
                        Text(rule.displayName).tag(rule)
                    }
                }
            }
        }
        .navigationTitle("编辑事项")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: hasDueDate) { newValue in
            todo.dueDate = newValue ? tempDate : nil
        }
        .onChange(of: tempDate) { newValue in
            if hasDueDate {
                todo.dueDate = newValue
            }
        }
    }
}
