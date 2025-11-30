import SwiftUI

struct DayOverviewView: View {
    @Binding var data: AppData
    @State private var currentDate: Date

    private let calendar = Calendar.current

    init(date: Date, data: Binding<AppData>) {
        self._data = data
        self._currentDate = State(initialValue: Calendar.current.startOfDay(for: date))
    }

    // MARK: - 数据切片

    private var dayTodos: [TodoItem] {
        let day = currentDate
        return data.todos.filter { item in
            guard item.deletedAt == nil,
                  let due = item.dueDate else { return false }
            return calendar.isDate(due, inSameDayAs: day)
        }
    }

    private var overdueTodos: [TodoItem] {
        dayTodos.filter { !$0.isDone && isOverdue($0) }
    }

    private var undoneTodos: [TodoItem] {
        dayTodos.filter { !$0.isDone && !isOverdue($0) }
    }

    private var doneTodos: [TodoItem] {
        dayTodos.filter { $0.isDone }
    }

    private func isOverdue(_ item: TodoItem) -> Bool {
        guard let due = item.dueDate else { return false }
        let day = calendar.startOfDay(for: due)
        let today = calendar.startOfDay(for: Date())
        return day < today
    }

    private var titleText: String {
        if calendar.isDateInToday(currentDate) {
            return "今天"
        } else {
            let f = DateFormatter()
            f.dateStyle = .medium
            f.timeStyle = .none
            return f.string(from: currentDate)
        }
    }

    private var summaryText: String {
        let total = dayTodos.count
        let done = doneTodos.count
        let overdue = overdueTodos.count
        return "共 \(total) 个任务 · 已完成 \(done) · 逾期 \(overdue)"
    }

    private func nameForList(id: UUID) -> String {
        data.lists.first(where: { $0.id == id })?.name ?? "未知清单"
    }

    private func goTo(offset: Int) {
        if let next = calendar.date(byAdding: .day, value: offset, to: currentDate) {
            currentDate = calendar.startOfDay(for: next)
        }
    }

    private func goToToday() {
        currentDate = calendar.startOfDay(for: Date())
    }

    // MARK: - View

    var body: some View {
        List {
            // 顶部头部卡片（类似屏幕使用时间的日期切换）
            Section {
                HStack(spacing: 12) {
                    // 前一天
                    Button {
                        goTo(offset: -1)
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .semibold))
                            .frame(width: 28, height: 28)
                            .background(.thinMaterial)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)

                    // 中间：日期 + 摘要
                    VStack(alignment: .leading, spacing: 4) {
                        Text(titleText)
                            .font(.headline)

                        Text(summaryText)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    // 右侧：今天徽标 / 按钮 + 后一天
                    HStack(spacing: 8) {
                        // 当前是今天：右侧显示一个静态“今天”徽标（不可点，表示当前就在今天）
                        if calendar.isDateInToday(currentDate) {
                            Text("今天")
                                .font(.footnote)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(
                                    Capsule()
                                        .fill(Color.accentColor.opacity(0.18))
                                )
                        } else {
                            // 不是今天：显示“今天”按钮，点击跳回今天
                            Button {
                                goToToday()
                            } label: {
                                Text("今天")
                                    .font(.footnote)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(
                                        Capsule()
                                            .fill(Color.accentColor.opacity(0.12))
                                    )
                            }
                            .buttonStyle(.plain)
                        }

                        // 后一天
                        Button {
                            goTo(offset: 1)
                        } label: {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 16, weight: .semibold))
                                .frame(width: 28, height: 28)
                                .background(.thinMaterial)
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 4)
            }

            if !overdueTodos.isEmpty {
                Section("逾期") {
                    ForEach(overdueTodos) { item in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.title)
                                .font(.body)
                            HStack(spacing: 6) {
                                Text(nameForList(id: item.listId))
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                Text("已逾期")
                                    .font(.caption2)
                                    .foregroundStyle(.red)
                            }
                        }
                    }
                }
            }

            if !undoneTodos.isEmpty {
                Section("待完成") {
                    ForEach(undoneTodos) { item in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.title)
                                .font(.body)
                            HStack(spacing: 6) {
                                Text(nameForList(id: item.listId))
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                if let due = item.dueDate {
                                    Text(due, style: .time)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }

            if !doneTodos.isEmpty {
                Section("已完成") {
                    ForEach(doneTodos) { item in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.title)
                                .font(.body)
                            HStack(spacing: 6) {
                                Text(nameForList(id: item.listId))
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                Text("已完成")
                                    .font(.caption2)
                                    .foregroundStyle(.green)
                            }
                        }
                    }
                }
            }

            if dayTodos.isEmpty {
                Section {
                    Text("这一天没有任务")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationBarTitleDisplayMode(.inline)
        .gesture(
            // 保留左右滑切换天
            DragGesture(minimumDistance: 20)
                .onEnded { value in
                    if value.translation.width < -40 {
                        goTo(offset: 1)   // 左滑 → 下一天
                    } else if value.translation.width > 40 {
                        goTo(offset: -1)  // 右滑 → 前一天
                    }
                }
        )
    }
}

#Preview {
    NavigationStack {
        DayOverviewView(date: Date(), data: .constant(AppData.initial()))
    }
}
