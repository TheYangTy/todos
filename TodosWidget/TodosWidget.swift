import WidgetKit
import SwiftUI

struct TodosEntry: TimelineEntry {
    let date: Date
    let todosToday: [TodoItem]
}

struct TodosProvider: TimelineProvider {
    func placeholder(in context: Context) -> TodosEntry {
        TodosEntry(date: Date(), todosToday: [])
    }
    
    func getSnapshot(in context: Context, completion: @escaping (TodosEntry) -> Void) {
        let entry = TodosEntry(date: Date(), todosToday: loadTodayTodos())
        completion(entry)
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<TodosEntry>) -> Void) {
        let entry = TodosEntry(date: Date(), todosToday: loadTodayTodos())
        let next = Calendar.current.date(byAdding: .minute, value: 30, to: Date()) ?? Date().addingTimeInterval(1800)
        let timeline = Timeline(entries: [entry], policy: .after(next))
        completion(timeline)
    }
    
    // 从 App Group 里的 AppData 读“今天的待办”
    private func loadTodayTodos() -> [TodoItem] {
        guard let data = AppData.loadFromLocal() else { return [] }
        let today = Date()
        return data.todos.filter { item in
            guard item.deletedAt == nil,
                  !item.isDone,
                  let due = item.dueDate else { return false }
            return Calendar.current.isDate(due, inSameDayAs: today)
        }
        .sorted { $0.priority.rawValue < $1.priority.rawValue }
    }
}

struct TodosWidgetEntryView: View {
    var entry: TodosProvider.Entry
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("今天待办")
                .font(.headline)
            
            if entry.todosToday.isEmpty {
                Text("今天没有待办事项")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(entry.todosToday.prefix(3)) { todo in
                    HStack(alignment: .top, spacing: 6) {
                        Image(systemName: "circle")
                            .imageScale(.small)
                            .foregroundStyle(.secondary)
                        Text(todo.title)
                            .font(.subheadline)
                            .lineLimit(1)
                    }
                }
                
                if entry.todosToday.count > 3 {
                    Text("还有 \(entry.todosToday.count - 3) 条…")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        // ✅ 关键：为 widget 提供容器背景
        .containerBackground(.background, for: .widget)
    }
}

struct TodosWidget: Widget {
    let kind: String = "TodosWidget"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TodosProvider()) { entry in
            TodosWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("今天待办")
        .description("查看今天的待办事项。")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
