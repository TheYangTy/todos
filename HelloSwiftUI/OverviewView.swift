import SwiftUI

struct OverviewView: View {
    @Binding var data: AppData

    // MARK: - 方便统计的中间数据

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

    // 按清单统计
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
        .filter { $0.undone + $0.done > 0 } // 没任务的清单可以过滤掉
    }

    // 按优先级统计
    private var highCount: Int {
        activeTodos.filter { !$0.isDone && $0.priority == .high }.count
    }
    private var mediumCount: Int {
        activeTodos.filter { !$0.isDone && $0.priority == .medium }.count
    }
    private var lowCount: Int {
        activeTodos.filter { !$0.isDone && $0.priority == .low }.count
    }

    // 日期文字
    private var todayString: String {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f.string(from: Date())
    }

    var body: some View {
        List {
            // 顶部概览卡片
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

                    // 完成率
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

            // 今天 & 未来 7 天
            Section("时间维度") {
                // 今天待办（未完成）
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

                // 今天已完成
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

                // 已逾期（未完成）
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

                // 未来 7 天到期（未完成）
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
                        .foregroundStyle(.red)
                    Spacer()
                    Text("\(highCount)")
                        .foregroundStyle(.secondary)
                }
                HStack {
                    Label("中", systemImage: "circle.fill")
                        .foregroundStyle(.orange)
                    Spacer()
                    Text("\(mediumCount)")
                        .foregroundStyle(.secondary)
                }
                HStack {
                    Label("低", systemImage: "circle.fill")
                        .foregroundStyle(.green)
                    Spacer()
                    Text("\(lowCount)")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("总览")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        OverviewView(data: .constant(AppData.initial()))
    }
}

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
                        // 标题
                        Text(todo.title)
                            .font(.body)
                            .lineLimit(1)

                        // 清单名 + 截止日期（如果有）
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
