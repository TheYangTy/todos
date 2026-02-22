//
//  LockScreenWidgets.swift
//  todos
//
//  Created by marcus on 2/12/2025.
//

import WidgetKit
import SwiftUI

// MARK: - 通用 Entry

struct LockScreenEntry: TimelineEntry {
    let date: Date
    let appData: AppData
}

// MARK: - Provider（共用）

struct LockScreenProvider: TimelineProvider {
    func placeholder(in context: Context) -> LockScreenEntry {
        LockScreenEntry(date: Date(), appData: .initial())
    }

    func getSnapshot(in context: Context, completion: @escaping (LockScreenEntry) -> Void) {
        let data = AppData.loadFromLocal() ?? AppData.initial()
        completion(LockScreenEntry(date: Date(), appData: data))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<LockScreenEntry>) -> Void) {
        let data = AppData.loadFromLocal() ?? AppData.initial()
        let entry = LockScreenEntry(date: Date(), appData: data)

        // 简单一点：15 分钟刷新一次
        let next = Calendar.current.date(byAdding: .minute, value: 15, to: Date())
            ?? Date().addingTimeInterval(900)

        let timeline = Timeline(entries: [entry], policy: .after(next))
        completion(timeline)
    }
}

// MARK: - AppData 辅助统计（给锁屏用）

extension AppData {
    /// 计算某一天的统计数据（今天用得最多）
    func stats(for date: Date, calendar: Calendar = .current) -> (total: Int,
                                                                  done: Int,
                                                                  overdue: Int,
                                                                  todos: [TodoItem]) {
        let day = calendar.startOfDay(for: date)
        let todosOfDay = todos.filter { item in
            guard item.deletedAt == nil,
                  let due = item.dueDate else { return false }
            return calendar.isDate(due, inSameDayAs: day)
        }

        let done = todosOfDay.filter { $0.isDone }.count

        let overdue = todosOfDay.filter { item in
            guard !item.isDone, let due = item.dueDate else { return false }
            let d = calendar.startOfDay(for: due)
            let today = calendar.startOfDay(for: Date())
            return d < today
        }.count

        return (total: todosOfDay.count, done: done, overdue: overdue, todos: todosOfDay)
    }

    /// 今天的统计
    func todayStats() -> (total: Int, done: Int, overdue: Int, todos: [TodoItem]) {
        stats(for: Date())
    }

    /// 今天即将要做的任务（未完成 + 按提醒时间/到期时间排序）
    func topTodayTodos(limit: Int = 2) -> [TodoItem] {
        let info = todayStats()

        return info.todos
            .filter { !$0.isDone }
            .sorted { a, b in
                let aKey = a.reminderTime ?? a.dueDate ?? Date.distantFuture
                let bKey = b.reminderTime ?? b.dueDate ?? Date.distantFuture
                return aKey < bKey
            }
            .prefix(limit)
            .map { $0 }
    }
}

// MARK: - Widget 1: Today Summary（锁屏顶部单行）

struct TodaySummaryLockWidget: Widget {
    let kind: String = "TodaySummaryLockWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: LockScreenProvider()) { entry in
            TodaySummaryLockView(entry: entry)
        }
        .configurationDisplayName("今日概览")
        .description("在锁屏上显示今天的待办概况。")
        .supportedFamilies([.accessoryInline]) // 锁屏顶部单行
    }
}

struct TodaySummaryLockView: View {
    var entry: LockScreenEntry

    // 计算属性：今天统计
    private var stats: (total: Int, done: Int, overdue: Int, todos: [TodoItem]) {
        entry.appData.todayStats()
    }

    // 计算属性：今天 yyyy-MM-dd 字符串
    private var todayDateString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.string(from: Date())
    }

    private var deepLinkURL: URL? {
        URL(string: "todos://day?date=\(todayDateString)")
    }

    var body: some View {
        Group {
            if stats.total == 0 {
                Text("今天无待办")
            } else {
                if stats.overdue > 0 {
                    Text("\(stats.total) 待办 · \(stats.overdue) 逾期")
                } else {
                    Text("\(stats.total) 待办")
                }
            }
        }
        .containerBackground(.background, for: .widget)
        .widgetURL(deepLinkURL)
    }
}

// MARK: - Widget 2: Progress Ring（锁屏圆环）

struct ProgressRingLockWidget: Widget {
    let kind: String = "ProgressRingLockWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: LockScreenProvider()) { entry in
            ProgressRingLockView(entry: entry)
        }
        .configurationDisplayName("今日完成度")
        .description("以进度圆环的形式显示今日任务完成情况。")
        .supportedFamilies([.accessoryCircular]) // 锁屏圆形
    }
}

struct ProgressRingLockView: View {
    var entry: LockScreenEntry

    private var stats: (total: Int, done: Int, overdue: Int, todos: [TodoItem]) {
        entry.appData.todayStats()
    }

    private var progress: Double {
        let total = max(stats.total, 1)
        return min(max(Double(stats.done) / Double(total), 0), 1) // clamp 到 0...1
    }

    private var todayDateString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.string(from: Date())
    }

    private var deepLinkURL: URL? {
        URL(string: "todos://day?date=\(todayDateString)")
    }

    var body: some View {
        ZStack {
            // 背景圈（更细一点）
            Circle()
                .stroke(Color.secondary.opacity(0.25), lineWidth: 3)

            // 进度圈
            Circle()
                .trim(from: 0, to: progress)
                .rotation(Angle(degrees: -90)) // 从 12 点方向开始
                .stroke(
                    Color.accentColor,
                    style: StrokeStyle(lineWidth: 3, lineCap: .round)
                )

            // 中间内容：不显示任何图标或数字，保持极简
            Group {}
        }
        .containerBackground(.background, for: .widget)
        .widgetURL(deepLinkURL)
    }
}

// MARK: - Widget 3: Mini List（锁屏矩形）

struct MiniListLockWidget: Widget {
    let kind: String = "MiniListLockWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: LockScreenProvider()) { entry in
            MiniListLockView(entry: entry)
        }
        .configurationDisplayName("今日任务列表")
        .description("在锁屏上展示 1–2 条即将到来的任务。")
        .supportedFamilies([.accessoryRectangular]) // 锁屏矩形
    }
}

struct MiniListLockView: View {
    var entry: LockScreenEntry

    private var stats: (total: Int, done: Int, overdue: Int, todos: [TodoItem]) {
        entry.appData.todayStats()
    }

    private var todos: [TodoItem] {
        entry.appData.topTodayTodos(limit: 2)
    }

    private var todayDateString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.string(from: Date())
    }

    private var deepLinkURL: URL? {
        URL(string: "todos://day?date=\(todayDateString)")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            if stats.total == 0 {
                Text("今日无任务")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            } else {
                Text("今日 \(stats.total) 个 · 完成 \(stats.done)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                ForEach(todos) { item in
                    HStack(spacing: 4) {
                        Image(systemName: item.isDone ? "checkmark.circle.fill" : "circle")
                            .font(.caption2)

                        Text(item.title)
                            .lineLimit(1)
                            .font(.caption2)
                    }
                }
            }
        }
        .containerBackground(.background, for: .widget)
        .widgetURL(deepLinkURL)
    }
}

// MARK: - 预览

#if DEBUG
struct LockScreenWidgets_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            TodaySummaryLockView(entry: .init(date: Date(), appData: .initial()))
                .previewContext(WidgetPreviewContext(family: .accessoryInline))

            ProgressRingLockView(entry: .init(date: Date(), appData: .initial()))
                .previewContext(WidgetPreviewContext(family: .accessoryCircular))

            MiniListLockView(entry: .init(date: Date(), appData: .initial()))
                .previewContext(WidgetPreviewContext(family: .accessoryRectangular))
        }
    }
}
#endif
