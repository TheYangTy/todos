import SwiftUI

struct TodoRow: View {
    @Binding var todo: TodoItem
    let listName: String
    let lists: [TodoList]
    let onToggleDone: () -> Void
    let onTapDetail: () -> Void
    
    private var isOverdue: Bool {
        guard let due = todo.dueDate, !todo.isDone else { return false }
        let today = Calendar.current.startOfDay(for: Date())
        let dueDay = Calendar.current.startOfDay(for: due)
        return dueDay < today
    }
    
    private var subtitle: String {
        var parts: [String] = []
        parts.append("清单：\(listName)")
        
        if let due = todo.dueDate {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .none
            
            let prefix = isOverdue ? "已超期：" : "截止 "
            parts.append(prefix + formatter.string(from: due))
        }
        
        parts.append("优先级：\(todo.priority.displayName)")
        return parts.joined(separator: " · ")
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // 左侧完成圆点
            Image(systemName: todo.isDone ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(isOverdue ? .red : (todo.isDone ? .green : .gray))
                .imageScale(.large)
                .onTapGesture {
                    onToggleDone()
                }
            
            // 中间标题 + 副标题
            VStack(alignment: .leading, spacing: 4) {
                Text(todo.title)
                    .foregroundStyle(isOverdue ? .red : .primary)
                    .font(.body)
                    .lineLimit(1)
                
                Text(subtitle)
                    .font(.footnote)
                    .foregroundStyle(isOverdue ? .red.opacity(0.8) : .secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            // 右侧自定义箭头（唯一的箭头）
            Image(systemName: "chevron.right")
                .foregroundStyle(.tertiary)
                .imageScale(.small)
        }
        .contentShape(Rectangle())                // 整行可点击
        .onTapGesture {
            onTapDetail()
        }
    }
}

#Preview {
    let list = TodoList(name: "收件箱")
    let item = TodoItem(
        title: "预览事项",
        isDone: false,
        dueDate: Calendar.current.date(byAdding: .day, value: 1, to: Date()),
        priority: .high,
        listId: list.id
    )
    
    return NavigationStack {
        List {
            TodoRow(
                todo: .constant(item),
                listName: list.name,
                lists: [list],
                onToggleDone: {},
                onTapDetail: {}
            )
        }
        .listStyle(.insetGrouped)
    }
}
