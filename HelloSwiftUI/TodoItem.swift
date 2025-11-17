import Foundation

struct TodoItem: Identifiable, Codable, Equatable {
    // 放在前面，方便 memberwise init 提供默认值
    var id: UUID = UUID()
    var title: String
    var isDone: Bool = false
    var dueDate: Date? = nil
    var priority: Priority
    var listId: UUID
    var deletedAt: Date? = nil
    var repeatRule: RepeatRule = .none
    
    // 地点模型
    struct TodoLocation: Codable, Equatable {
        var name: String
        var latitude: Double
        var longitude: Double
    }
    
    /// 地点信息（可选）
    var location: TodoLocation? = nil
    
    /// ✅ 新增：提醒时间（仅在有截止日期时可设置，为截止日当天某个时刻）
    var reminderTime: Date? = nil

    // 优先级
    enum Priority: String, CaseIterable, Identifiable, Codable {
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
    enum RepeatRule: String, CaseIterable, Identifiable, Codable {
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
}
