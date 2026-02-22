import SwiftUI

struct TodoRow: View {
    @Binding var todo: TodoItem
    let listName: String
    let lists: [TodoList]
    let isPinned: Bool
    let onToggleDone: () -> Void
    let onTapDetail: () -> Void

    // 读取用户自定义的优先级颜色（默认：高=红，中=橙，低=绿）
    @AppStorage("priorityColorHigh")  private var priorityHighColorRaw: String  = PriorityColorOption.red.rawValue
    @AppStorage("priorityColorMedium") private var priorityMediumColorRaw: String = PriorityColorOption.orange.rawValue
    @AppStorage("priorityColorLow")   private var priorityLowColorRaw: String   = PriorityColorOption.green.rawValue

    private var isOverdue: Bool {
        guard let due = todo.dueDate, !todo.isDone else { return false }
        let today = Calendar.current.startOfDay(for: Date())
        let dueDay = Calendar.current.startOfDay(for: due)
        return dueDay < today
    }

    /// 优先级圆点颜色（使用设置里的配置）
    private var priorityDotColor: Color {
        let raw: String
        switch todo.priority {
        case .high:   raw = priorityHighColorRaw
        case .medium: raw = priorityMediumColorRaw
        case .low:    raw = priorityLowColorRaw
        }
        return PriorityColorOption(rawValue: raw)?.color ?? .orange
    }

    /// 截止日期文案（不加“清单 / 优先级”字眼）
    private var dueDateText: String? {
        guard let due = todo.dueDate else { return nil }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none

        let dateString = formatter.string(from: due)
        if isOverdue {
            return "已超期 · \(dateString)"
        } else if Calendar.current.isDateInToday(due) {
            return "今天 · \(dateString)"
        } else {
            return "截止 \(dateString)"
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            // 左侧完成圆圈
            Image(systemName: todo.isDone ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(isOverdue ? .red : (todo.isDone ? .green : .gray))
                .imageScale(.large)
                .onTapGesture {
                    onToggleDone()
                }

            // 中间：标题 + 一行详情
            VStack(alignment: .leading, spacing: 4) {
                // 标题
                Text(todo.title)
                    .foregroundStyle(isOverdue ? .red : .primary)
                    .font(.body)
                    .lineLimit(1)

                // 详情行：优先级圆点 + 清单名 + 截止日期（全部同一行）
                HStack(spacing: 6) {
                    Circle()
                        .fill(priorityDotColor)
                        .frame(width: 8, height: 8)

                    Text(listName)
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    if let text = dueDateText {
                        Text("· \(text)")
                            .font(.caption2)
                            .foregroundStyle(isOverdue ? .red.opacity(0.85) : .secondary)
                    }

                    Spacer(minLength: 0)
                }
                .lineLimit(1)
                .truncationMode(.tail)
            }

            Spacer()

            // 右侧：关注标记（可选）
            if isPinned {
                Image(systemName: "pin.fill")
                    .foregroundStyle(.secondary)
                    .imageScale(.small)
            }

            // 右侧自定义箭头（唯一的箭头）
            Image(systemName: "chevron.right")
                .foregroundStyle(.tertiary)
                .imageScale(.small)
        }
        .contentShape(Rectangle())
        .onTapGesture { onTapDetail() }
    }
}

#Preview {
    let list = TodoList(name: "工作")
    let item = TodoItem(
        title: "预览事项：写 iOS todos App",
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
                isPinned: false,
                onToggleDone: {},
                onTapDetail: {}
            )
        }
        .listStyle(.insetGrouped)
    }
}
