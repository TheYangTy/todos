import SwiftUI

struct OverviewView: View {
    @Binding var data: AppData

    // MARK: - 日历状态
    @State private var calendarMonth: Date = Calendar.current.startOfMonth(for: Date())
    @State private var calendarSelectedDate: Date = Calendar.current.startOfDay(for: Date())
    @State private var isShowingDayView = false

    // MARK: - 基础统计

    private var activeTodos: [TodoItem] {
        data.todos.filter { $0.deletedAt == nil }
    }

    private var today: Date {
        Calendar.current.startOfDay(for: Date())
    }

    private var todayTodos: [TodoItem] {
        activeTodos.filter {
            if let due = $0.dueDate {
                return Calendar.current.isDate(due, inSameDayAs: today)
            } else {
                return false
            }
        }
    }

    private var todayDoneCount: Int {
        todayTodos.filter { $0.isDone }.count
    }

    private var todayUndoneCount: Int {
        todayTodos.filter { !$0.isDone }.count
    }

    private var overdueTodos: [TodoItem] {
        activeTodos.filter {
            guard let due = $0.dueDate, !$0.isDone else { return false }
            let day = Calendar.current.startOfDay(for: due)
            return day < today
        }
    }

    private var upcoming7DaysTodos: [TodoItem] {
        let cal = Calendar.current
        guard let end = cal.date(byAdding: .day, value: 7, to: today) else {
            return []
        }
        return activeTodos.filter {
            guard let due = $0.dueDate else { return false }
            let day = cal.startOfDay(for: due)
            return day > today && day <= end
        }
    }

    private var completionRate: Double {
        let todos = activeTodos
        guard !todos.isEmpty else { return 0 }
        let done = todos.filter { $0.isDone }.count
        return Double(done) / Double(todos.count)
    }

    // MARK: - 按清单统计

    private struct ListStat: Identifiable {
        let id: UUID
        let name: String
        let undone: Int
        let done: Int
    }

    private var listStats: [ListStat] {
        data.lists.map { list in
            let related = activeTodos.filter { $0.listId == list.id }
            let undone = related.filter { !$0.isDone }.count
            let done   = related.filter { $0.isDone }.count
            return ListStat(id: list.id, name: list.name, undone: undone, done: done)
        }
        .filter { $0.undone + $0.done > 0 }
    }

    // MARK: - 按优先级统计（未完成）

    private var highCount: Int {
        activeTodos.filter { !$0.isDone && $0.priority == .high }.count
    }
    private var mediumCount: Int {
        activeTodos.filter { !$0.isDone && $0.priority == .medium }.count
    }
    private var lowCount: Int {
        activeTodos.filter { !$0.isDone && $0.priority == .low }.count
    }

    // MARK: - 日期文本

    private var todayString: String {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f.string(from: Date())
    }

    var body: some View {
        List {
            // 顶部「今天概览」卡片
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text(todayString)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Text("今天概览")
                        .font(.title2)
                        .bold()

                    HStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("待办")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("\(todayUndoneCount)")
                                .font(.title3)
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            Text("已完成")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("\(todayDoneCount)")
                                .font(.title3)
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            Text("逾期")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("\(overdueTodos.count)")
                                .font(.title3)
                                .foregroundColor(overdueTodos.isEmpty ? .primary : .red)
                        }
                    }
                    .padding(.top, 4)

                    // 总体完成率
                    VStack(alignment: .leading, spacing: 4) {
                        Text("总体完成率")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        ProgressView(value: completionRate) {
                            EmptyView()
                        } currentValueLabel: {
                            Text("\(Int(completionRate * 100))%")
                                .font(.footnote)
                                .monospacedDigit()
                        }
                    }
                    .padding(.top, 4)
                }
                .padding(.vertical, 4)
            }

            // 日历预览（整月）
            Section("日历") {
                OverviewCalendarView(
                    month: $calendarMonth,
                    selectedDate: $calendarSelectedDate,
                    todos: activeTodos,
                    onSelectDate: { date in
                        calendarSelectedDate = date
                        isShowingDayView = true
                    }
                )
                .padding(.vertical, 4)
            }

            // 时间维度（可点进去看列表）
            Section("时间维度") {
                NavigationLink {
                    OverviewSimpleList(
                        title: "今天待办",
                        todos: todayTodos.filter { !$0.isDone },
                        lists: data.lists
                    )
                } label: {
                    HStack {
                        Label("今天待办", systemImage: "sun.max")
                        Spacer()
                        Text("\(todayUndoneCount)")
                            .foregroundStyle(.secondary)
                    }
                }

                NavigationLink {
                    OverviewSimpleList(
                        title: "今天已完成",
                        todos: todayTodos.filter { $0.isDone },
                        lists: data.lists
                    )
                } label: {
                    HStack {
                        Label("今天已完成", systemImage: "checkmark.circle")
                        Spacer()
                        Text("\(todayDoneCount)")
                            .foregroundStyle(.secondary)
                    }
                }

                NavigationLink {
                    OverviewSimpleList(
                        title: "已逾期",
                        todos: overdueTodos,
                        lists: data.lists
                    )
                } label: {
                    HStack {
                        Label("已逾期", systemImage: "exclamationmark.triangle")
                        Spacer()
                        Text("\(overdueTodos.count)")
                            .foregroundColor(overdueTodos.isEmpty ? .secondary : .red)
                    }
                }

                NavigationLink {
                    OverviewSimpleList(
                        title: "未来 7 天到期",
                        todos: upcoming7DaysTodos,
                        lists: data.lists
                    )
                } label: {
                    HStack {
                        Label("未来 7 天到期", systemImage: "calendar.badge.clock")
                        Spacer()
                        Text("\(upcoming7DaysTodos.count)")
                            .foregroundStyle(.secondary)
                    }
                }
            }

            // 按清单
            if !listStats.isEmpty {
                Section("按清单") {
                    ForEach(listStats) { stat in
                        HStack {
                            Text(stat.name)
                            Spacer()
                            Text("未完成 \(stat.undone) · 已完成 \(stat.done)")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            // 按优先级
            Section("按优先级（未完成）") {
                HStack {
                    Label("高", systemImage: "circle.fill")
                        .foregroundColor(.red)
                    Spacer()
                    Text("\(highCount)")
                        .foregroundStyle(.secondary)
                }
                HStack {
                    Label("中", systemImage: "circle.fill")
                        .foregroundColor(.orange)
                    Spacer()
                    Text("\(mediumCount)")
                        .foregroundStyle(.secondary)
                }
                HStack {
                    Label("低", systemImage: "circle.fill")
                        .foregroundColor(.green)
                    Spacer()
                    Text("\(lowCount)")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("总览")
        .navigationBarTitleDisplayMode(.inline)
        .background(
            NavigationLink(
                destination: DayOverviewView(date: calendarSelectedDate, data: $data),
                isActive: $isShowingDayView
            ) {
                EmptyView()
            }
            .hidden()
        )
    }
}

// MARK: - 日历 View

private struct OverviewCalendarView: View {
    @Binding var month: Date
    @Binding var selectedDate: Date

    let todos: [TodoItem]
    let onSelectDate: (Date) -> Void

    private let calendar = Calendar.current

    private var monthTitle: String {
        let f = DateFormatter()
        f.dateFormat = "yyyy年M月"
        return f.string(from: month)
    }

    /// 当前月的所有格子（包含前导空白）
    private var daysInMonth: [Date?] {
        let startOfMonth = calendar.startOfMonth(for: month)
        guard let range = calendar.range(of: .day, in: .month, for: startOfMonth) else {
            return []
        }

        let firstWeekday = calendar.component(.weekday, from: startOfMonth) // 1=周日
        // 让周一作为一周的第一天
        let leadingEmpty = (firstWeekday + 5) % 7

        var result: [Date?] = Array(repeating: nil, count: leadingEmpty)
        for day in range {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: startOfMonth) {
                result.append(date)
            }
        }
        return result
    }

    /// 统计某天的任务数量（未完成/已完成/逾期）
    private func summary(for date: Date) -> (undone: Int, done: Int, overdue: Int) {
        let dayTodos = todos.filter { item in
            guard let due = item.dueDate else { return false }
            return calendar.isDate(due, inSameDayAs: date)
        }
        let undone = dayTodos.filter { !$0.isDone }.count
        let done   = dayTodos.filter { $0.isDone }.count

        let todayStart = calendar.startOfDay(for: Date())
        let dayStart = calendar.startOfDay(for: date)
        let overdue = (dayStart < todayStart) ? undone : 0

        return (undone, done, overdue)
    }

    /// 小圆点颜色规则：逾期>未完成>已完成
    private func dotColor(for summary: (undone: Int, done: Int, overdue: Int)) -> Color? {
        if summary.overdue > 0 {
            return .red
        } else if summary.undone > 0 {
            return .blue
        } else if summary.done > 0 {
            return .green
        } else {
            return nil
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 顶部月份 + 切换按钮
            HStack {
                Button {
                    if let prev = calendar.date(byAdding: .month, value: -1, to: month) {
                        month = prev
                    }
                } label: {
                    Image(systemName: "chevron.left")
                }
                .buttonStyle(.plain)

                Spacer()

                Text(monthTitle)
                    .font(.headline)

                Spacer()

                Button {
                    if let next = calendar.date(byAdding: .month, value: 1, to: month) {
                        month = next
                    }
                } label: {
                    Image(systemName: "chevron.right")
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 4)

            // 星期标题行（周一 - 周日）
            HStack {
                ForEach(["一","二","三","四","五","六","日"], id: \.self) { w in
                    Text(w)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }

            // 日期网格
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 6) {
                ForEach(Array(daysInMonth.enumerated()), id: \.offset) { _, value in
                    if let date = value {
                        let day = calendar.component(.day, from: date)
                        let isSelected = calendar.isDate(selectedDate, inSameDayAs: date)
                        let isToday = calendar.isDateInToday(date)
                        let summary = summary(for: date)
                        let dot = dotColor(for: summary)

                        Button {
                            selectedDate = calendar.startOfDay(for: date)
                            onSelectDate(selectedDate)
                        } label: {
                            VStack(spacing: 2) {
                                Text("\(day)")
                                    .font(.system(size: 14, weight: isSelected ? .semibold : .regular))
                                    .foregroundStyle(isSelected ? .white : .primary)

                                if let dotColor = dot {
                                    Circle()
                                        .fill(dotColor)
                                        .frame(width: 4, height: 4)
                                } else {
                                    Circle()
                                        .fill(Color.clear)
                                        .frame(width: 4, height: 4)
                                }
                            }
                            .frame(maxWidth: .infinity, minHeight: 28)
                            .padding(4)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(
                                        isSelected
                                        ? Color.accentColor
                                        : (isToday ? Color.accentColor.opacity(0.12) : Color.clear)
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                    } else {
                        // 空白占位
                        Color.clear
                            .frame(minHeight: 28)
                    }
                }
            }
        }
    }
}

// MARK: - 时间维度用的简单列表

struct OverviewSimpleList: View {
    let title: String
    let todos: [TodoItem]
    let lists: [TodoList]

    private func nameForList(id: UUID) -> String {
        lists.first(where: { $0.id == id })?.name ?? "未知清单"
    }

    var body: some View {
        List {
            if todos.isEmpty {
                Text("暂无任务")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(todos) { todo in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(todo.title)
                            .font(.body)
                            .lineLimit(1)

                        HStack(spacing: 6) {
                            Text(nameForList(id: todo.listId))
                                .font(.caption2)
                                .foregroundStyle(.secondary)

                            if let due = todo.dueDate {
                                Text(due, style: .date)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }

                            if todo.isDone {
                                Text("已完成")
                                    .font(.caption2)
                                    .foregroundStyle(.green)
                            }
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Date helper

private extension Calendar {
    func startOfMonth(for date: Date) -> Date {
        let comps = dateComponents([.year, .month], from: date)
        return self.date(from: comps) ?? date
    }
}

#Preview {
    NavigationStack {
        OverviewView(data: .constant(AppData.initial()))
    }
}
