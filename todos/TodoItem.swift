import Foundation

struct TodoItem: Identifiable, Codable, Equatable {
    // 优先级
    enum Priority: String, CaseIterable, Codable, Identifiable {
        case high
        case medium
        case low

        var id: Self { self }

        var displayName: String {
            switch self {
            case .high:   return "高"
            case .medium: return "中"
            case .low:    return "低"
            }
        }
    }

    // 重复规则
    enum RepeatRule: String, CaseIterable, Codable, Identifiable {
        case none
        case daily
        case weekly
        case monthly

        var id: Self { self }

        var displayName: String {
            switch self {
            case .none:    return "不重复"
            case .daily:   return "每天"
            case .weekly:  return "每周"
            case .monthly: return "每月"
            }
        }
    }

    // 地点信息
    struct TodoLocation: Codable, Equatable {
        var name: String
        var latitude: Double
        var longitude: Double
    }

    // 基本字段
    let id: UUID
    var title: String
    var isDone: Bool
    /// 完成时间（用于“已完成”列表倒序/顺序排序）
    var completedAt: Date?
    var dueDate: Date?
    var priority: Priority
    var listId: UUID
    var deletedAt: Date?

    // 重复 & 通知
    var repeatRule: RepeatRule
    var reminderTime: Date?

    // 地点
    var location: TodoLocation?

    /// 🔑 重复任务的“基准日期”
    /// 比如第一次设置为 1 月 7 日交房租，这里就是 1 月 7 日。
    /// 不管这条任务是 7 号做，还是 10 号做，下一次都按「每月 7 号」来算。
    var repeatBaseDate: Date?

    init(
        id: UUID = UUID(),
        title: String,
        isDone: Bool = false,
        completedAt: Date? = nil,
        dueDate: Date? = nil,
        priority: Priority = .medium,
        listId: UUID,
        deletedAt: Date? = nil,
        repeatRule: RepeatRule = .none,
        reminderTime: Date? = nil,
        location: TodoLocation? = nil,
        repeatBaseDate: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.isDone = isDone
        self.completedAt = completedAt
        self.dueDate = dueDate
        self.priority = priority
        self.listId = listId
        self.deletedAt = deletedAt
        self.repeatRule = repeatRule
        self.reminderTime = reminderTime
        self.location = location
        self.repeatBaseDate = repeatBaseDate
    }
}
