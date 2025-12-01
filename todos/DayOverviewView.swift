import SwiftUI
import UIKit

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
    
    private func overdueDescription(for item: TodoItem) -> String {
        guard let due = item.dueDate else {
            return "已逾期"
        }
        let startDue = calendar.startOfDay(for: due)
        let startToday = calendar.startOfDay(for: Date())
        let days = calendar.dateComponents([.day], from: startDue, to: startToday).day ?? 0
        
        if days <= 0 {
            return "已逾期"
        } else if days == 1 {
            return "已逾期 1 天"
        } else {
            return "已逾期 \(days) 天"
        }
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

    /// 根据 item 找到在 data.todos 中的下标，用于做绑定 & 修改
    private func index(for item: TodoItem) -> Int? {
        data.todos.firstIndex { $0.id == item.id }
    }

    private func goTo(offset: Int) {
        if let next = calendar.date(byAdding: .day, value: offset, to: currentDate) {
            currentDate = calendar.startOfDay(for: next)
        }
    }

    private func goToToday() {
        currentDate = calendar.startOfDay(for: Date())
    }
    
    private func playTickHaptic() {
        if #available(iOS 17.0, *) {
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
        } else {
            let generator = UISelectionFeedbackGenerator()
            generator.selectionChanged()
        }
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

            // 逾期
            if !overdueTodos.isEmpty {
                Section("逾期") {
                    ForEach(overdueTodos) { item in
                        if let index = index(for: item) {
                            NavigationLink {
                                TodoEditView(todo: $data.todos[index], lists: data.lists)
                            } label: {
                                rowContent(for: index, showOverdueTag: true)
                            }
                            // 右滑：完成
                            .swipeActions(edge: .trailing) {
                                Button {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        data.todos[index].isDone.toggle()
                                        playTickHaptic()
                                    }
                                } label: {
                                    Label("完成", systemImage: "checkmark")
                                }
                                .tint(.green)
                            }
                        }
                    }
                }
            }

            // 待完成
            if !undoneTodos.isEmpty {
                Section("待完成") {
                    ForEach(undoneTodos) { item in
                        if let index = index(for: item) {
                            NavigationLink {
                                TodoEditView(todo: $data.todos[index], lists: data.lists)
                            } label: {
                                rowContent(for: index, showOverdueTag: false)
                            }
                            .swipeActions(edge: .trailing) {
                                Button {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        data.todos[index].isDone.toggle()
                                        playTickHaptic()
                                    }
                                } label: {
                                    Label("完成", systemImage: "checkmark")
                                }
                                .tint(.green)
                            }
                        }
                    }
                }
            }

            // 已完成
            if !doneTodos.isEmpty {
                Section("已完成") {
                    ForEach(doneTodos) { item in
                        if let index = index(for: item) {
                            NavigationLink {
                                TodoEditView(todo: $data.todos[index], lists: data.lists)
                            } label: {
                                rowContent(for: index, showDoneTag: true)
                            }
                            .swipeActions(edge: .trailing) {
                                Button {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        data.todos[index].isDone.toggle()
                                        playTickHaptic()
                                    }
                                } label: {
                                    Label("标记未完成", systemImage: "arrow.uturn.backward")
                                }
                                .tint(.orange)
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
        .navigationTitle(titleText)
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

    // MARK: - 单行内容封装，避免三处重复

    @ViewBuilder
    private func rowContent(for index: Int,
                            showOverdueTag: Bool = false,
                            showDoneTag: Bool = false) -> some View {
        HStack(alignment: .top, spacing: 8) {
            // 勾选按钮 + 动画
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    data.todos[index].isDone.toggle()
                    playTickHaptic()
                }
            } label: {
                Image(systemName: data.todos[index].isDone ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(data.todos[index].isDone ? .green : .secondary)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 4) {
                Text(data.todos[index].title)
                    .font(.body)
                HStack(spacing: 6) {
                    Text(nameForList(id: data.todos[index].listId))
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    if showOverdueTag {
                        Text(overdueDescription(for: data.todos[index]))
                            .font(.caption2)
                            .foregroundStyle(.red)
                    }

                    if showDoneTag {
                        Text("已完成")
                            .font(.caption2)
                            .foregroundStyle(.green)
                    }

                    // ✅ 只在有提醒时间时显示“几点”
                    if let reminder = data.todos[index].reminderTime {
                        Text(reminder, style: .time)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        DayOverviewView(date: Date(), data: .constant(AppData.initial()))
    }
}
