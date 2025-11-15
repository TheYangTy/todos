import Foundation

struct TodoItem: Identifiable, Codable, Equatable {
    enum Priority: String, Codable, CaseIterable, Identifiable {
        case low
        case medium
        case high
        
        var id: Self { self }
        
        var displayName: String {
            switch self {
            case .low: return "低"
            case .medium: return "中"
            case .high: return "高"
            }
        }
    }
    
    // 重复规则
    enum RepeatRule: String, Codable, CaseIterable, Identifiable {
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
    
    let id: UUID
    var title: String
    var isDone: Bool
    var dueDate: Date?
    var priority: Priority
    var listId: UUID
    var deletedAt: Date?      // 回收站时间
    var repeatRule: RepeatRule
    
    init(id: UUID = UUID(),
         title: String,
         isDone: Bool = false,
         dueDate: Date? = nil,
         priority: Priority = .medium,
         listId: UUID,
         deletedAt: Date? = nil,
         repeatRule: RepeatRule = .none) {
        
        self.id = id
        self.title = title
        self.isDone = isDone
        self.dueDate = dueDate
        self.priority = priority
        self.listId = listId
        self.deletedAt = deletedAt
        self.repeatRule = repeatRule
    }
}
