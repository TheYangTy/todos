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

    // 关注 / Pin
    var isPinned: Bool
    var pinnedAt: Date?

    var dueDate: Date?
    var priority: Priority
    var listId: UUID
    var deletedAt: Date?

    // 重复 & 通知
    var repeatRule: RepeatRule
    var reminderTime: Date?

    // 地点
    var location: TodoLocation?

    // “每月固定某一天”用的基准日期（例如每月 7 号）
    var repeatBaseDate: Date?

    private enum CodingKeys: String, CodingKey {
        case id
        case title
        case isDone
        case isPinned
        case pinnedAt
        case dueDate
        case priority
        case listId
        case deletedAt
        case repeatRule
        case reminderTime
        case location
        case repeatBaseDate
    }

    init(
        id: UUID = UUID(),
        title: String,
        isDone: Bool = false,
        isPinned: Bool = false,
        pinnedAt: Date? = nil,
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
        self.isPinned = isPinned
        self.pinnedAt = pinnedAt
        self.dueDate = dueDate
        self.priority = priority
        self.listId = listId
        self.deletedAt = deletedAt
        self.repeatRule = repeatRule
        self.reminderTime = reminderTime
        self.location = location
        self.repeatBaseDate = repeatBaseDate
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        isDone = try container.decode(Bool.self, forKey: .isDone)
        isPinned = try container.decodeIfPresent(Bool.self, forKey: .isPinned) ?? false
        pinnedAt = try container.decodeIfPresent(Date.self, forKey: .pinnedAt)
        dueDate = try container.decodeIfPresent(Date.self, forKey: .dueDate)
        priority = try container.decode(Priority.self, forKey: .priority)
        listId = try container.decode(UUID.self, forKey: .listId)
        deletedAt = try container.decodeIfPresent(Date.self, forKey: .deletedAt)
        repeatRule = try container.decodeIfPresent(RepeatRule.self, forKey: .repeatRule) ?? .none
        reminderTime = try container.decodeIfPresent(Date.self, forKey: .reminderTime)
        location = try container.decodeIfPresent(TodoLocation.self, forKey: .location)
        repeatBaseDate = try container.decodeIfPresent(Date.self, forKey: .repeatBaseDate)
    }
}
