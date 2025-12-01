import WidgetKit
import SwiftUI

// MARK: - 今天待办小组件

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

// MARK: - 总览小组件

struct OverviewDaySummary: Hashable {
    let date: Date
    let undoneCount: Int
}

struct TodosOverviewEntry: TimelineEntry {
    let date: Date
    let todayTotal: Int
    let todayDone: Int
    let overdueCount: Int
    let upcoming7DaysCount: Int
    let daySummaries: [OverviewDaySummary]
}

struct TodosOverviewProvider: TimelineProvider {
    func placeholder(in context: Context) -> TodosOverviewEntry {
        makeEmptyEntry()
    }

    func getSnapshot(in context: Context, completion: @escaping (TodosOverviewEntry) -> Void) {
        completion(makeEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TodosOverviewEntry>) -> Void) {
        let entry = makeEntry()
        let next = Calendar.current.date(byAdding: .minute, value: 30, to: Date()) ?? Date().addingTimeInterval(1800)
        let timeline = Timeline(entries: [entry], policy: .after(next))
        completion(timeline)
    }

    private func makeEmptyEntry() -> TodosOverviewEntry {
        let today = Calendar.current.startOfDay(for: Date())
        let summaries = (0..<7).compactMap { offset -> OverviewDaySummary? in
            guard let day = Calendar.current.date(byAdding: .day, value: offset, to: today) else {
                return nil
            }
            return OverviewDaySummary(date: day, undoneCount: 0)
        }
        return TodosOverviewEntry(
            date: Date(),
            todayTotal: 0,
            todayDone: 0,
            overdueCount: 0,
            upcoming7DaysCount: 0,
            daySummaries: summaries
        )
    }

    private func makeEntry() -> TodosOverviewEntry {
        guard let data = AppData.loadFromLocal() else {
            return makeEmptyEntry()
        }

        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let active = data.todos.filter { $0.deletedAt == nil }

        let todayTodos = active.filter { item in
            guard let due = item.dueDate else { return false }
            return cal.isDate(due, inSameDayAs: today)
        }
        let todayTotal = todayTodos.count
        let todayDone = todayTodos.filter { $0.isDone }.count

        let overdueCount = active.filter { item in
            guard let due = item.dueDate else { return false }
            return !item.isDone && due < today
        }.count

        let end = cal.date(byAdding: .day, value: 7, to: today) ?? today
        let upcoming7DaysCount = active.filter { item in
            guard let due = item.dueDate else { return false }
            return !item.isDone && due >= today && due < end
        }.count

        var daySummaries: [OverviewDaySummary] = []
        for offset in 0..<7 {
            guard let day = cal.date(byAdding: .day, value: offset, to: today) else { continue }
            let undone = active.filter { item in
                guard let due = item.dueDate else { return false }
                return !item.isDone && cal.isDate(due, inSameDayAs: day)
            }.count
            daySummaries.append(OverviewDaySummary(date: day, undoneCount: undone))
        }

        return TodosOverviewEntry(
            date: Date(),
            todayTotal: todayTotal,
            todayDone: todayDone,
            overdueCount: overdueCount,
            upcoming7DaysCount: upcoming7DaysCount,
            daySummaries: daySummaries
        )
    }
}

struct TodosOverviewWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    let entry: TodosOverviewEntry

    private var completionRate: Double {
        guard entry.todayTotal > 0 else { return 0 }
        return Double(entry.todayDone) / Double(entry.todayTotal)
    }

    var body: some View {
        Group {
            switch family {
            case .systemLarge:
                largeBody
            default:
                mediumBody
            }
        }
        .containerBackground(.background, for: .widget)
    }

    // 中等尺寸：你现在看到的样子
    private var mediumBody: some View {
        VStack(alignment: .leading, spacing: 8) {
            header

            HStack(spacing: 12) {
                todayBlock
                statsBlock
            }

            calendarStrip

            Spacer()
        }
    }

    // 大尺寸：上半部分复用 medium，下半部分多一个「未来 3 天预览」
    private var largeBody: some View {
        VStack(alignment: .leading, spacing: 8) {
            header

            HStack(spacing: 12) {
                todayBlock
                statsBlock
            }

            calendarStrip

            Divider()
                .padding(.vertical, 4)

            VStack(alignment: .leading, spacing: 4) {
                Text("未来 3 天预览")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                ForEach(entry.daySummaries.prefix(3), id: \.self) { summary in
                    HStack {
                        Text(dateLabel(for: summary.date))
                        Spacer()
                        Text(summary.undoneCount > 0 ? "\(summary.undoneCount) 个待办" : "暂无待办")
                    }
                    .font(.caption2)
                }
            }

            Spacer()
        }
    }

    private var header: some View {
        HStack {
            Text("总览看板")
                .font(.headline)
            Spacer()
            Text(Date(), style: .date)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private var todayBlock: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("今天")
                .font(.caption)
                .foregroundStyle(.secondary)

            if entry.todayTotal > 0 {
                Text("\(entry.todayDone)/\(entry.todayTotal) 已完成")
                    .font(.subheadline)
                ProgressView(value: completionRate)
                    .progressViewStyle(.linear)
            } else {
                Text("今天没有待办事项")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var statsBlock: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("统计")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("逾期 \(entry.overdueCount)")
                .font(.caption2)
            Text("未来 7 天 \(entry.upcoming7DaysCount)")
                .font(.caption2)
        }
    }

    private var calendarStrip: some View {
        HStack(spacing: 4) {
            ForEach(entry.daySummaries, id: \.self) { summary in
                dayCell(for: summary)
            }
        }
    }

    @ViewBuilder
    private func dayCell(for summary: OverviewDaySummary) -> some View {
        let isToday = Calendar.current.isDateInToday(summary.date)

        let content = VStack(spacing: 2) {
            Text(shortWeekday(for: summary.date))
                .font(.caption2)
            Text(dayString(for: summary.date))
                .font(.caption2)

            Circle()
                .frame(width: 4, height: 4)
                .opacity(summary.undoneCount > 0 ? 1 : 0.2)
        }
        .frame(maxWidth: .infinity)
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isToday ? Color.secondary.opacity(0.15) : Color.clear)
        )

        // ✅ 点击某一天，跳转 deep link：todos://day?date=yyyy-MM-dd
        if let url = deepLinkURL(for: summary.date) {
            Link(destination: url) {
                content
            }
        } else {
            content
        }
    }

    private func shortWeekday(for date: Date) -> String {
        let symbolIndex = Calendar.current.component(.weekday, from: date) - 1
        let symbols = Calendar.current.shortWeekdaySymbols
        guard symbols.indices.contains(symbolIndex) else { return "" }
        return symbols[symbolIndex]
    }

    private func dayString(for date: Date) -> String {
        let day = Calendar.current.component(.day, from: date)
        return String(day)
    }

    private func dateLabel(for date: Date) -> String {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.dateFormat = "M月d日"
        return f.string(from: date)
    }

    private func deepLinkURL(for date: Date) -> URL? {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.dateFormat = "yyyy-MM-dd"
        let str = f.string(from: date)
        return URL(string: "todos://day?date=\(str)")
    }
}

struct TodosOverviewWidget: Widget {
    let kind: String = "TodosOverviewWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TodosOverviewProvider()) { entry in
            TodosOverviewWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("待办总览")
        .description("今天、逾期和未来 7 天的待办概况，带有一个可点击的日历预览。")
        .supportedFamilies([.systemMedium, .systemLarge])
    }
}
