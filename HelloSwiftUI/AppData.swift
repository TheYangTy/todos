import Foundation

struct TodoList: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    
    init(id: UUID = UUID(), name: String) {
        self.id = id
        self.name = name
    }
}

struct AppData: Codable, Equatable {
    var lists: [TodoList]
    var todos: [TodoItem]
    
    static let storageKey = "AppData_v1_lists_dynamic"
    
    // 使用 App Group 的 UserDefaults（给 App + Widget 共享）
    private static func sharedDefaults() -> UserDefaults {
        if let ud = UserDefaults(suiteName: "group.com.marcus.todos") {
            return ud
        } else {
            return .standard
        }
    }
    
    // 初始示例数据
    static func initial() -> AppData {
        let inbox = TodoList(name: "收件箱")
        let work  = TodoList(name: "工作")
        let life  = TodoList(name: "生活")
        
        return AppData(
            lists: [inbox, work, life],
            todos: [
                TodoItem(title: "学习 Swift 基础语法",
                         priority: .medium,
                         listId: inbox.id),
                TodoItem(title: "看一遍 SwiftUI 教程",
                         priority: .medium,
                         listId: inbox.id),
                TodoItem(title: "完成第一个 iOS App",
                         priority: .high,
                         listId: work.id)
            ]
        )
    }
    
    // 本地（App Group）持久化
    static func loadFromLocal() -> AppData? {
        let defaults = sharedDefaults()
        guard let data = defaults.data(forKey: storageKey) else {
            return nil
        }
        return try? JSONDecoder().decode(AppData.self, from: data)
    }
    
    static func saveToLocal(_ data: AppData) {
        let defaults = sharedDefaults()
        if let encoded = try? JSONEncoder().encode(data) {
            defaults.set(encoded, forKey: storageKey)
        }
    }
    
    // iCloud Key-Value（可选）
    static func loadFromICloud() -> AppData? {
        let kvs = NSUbiquitousKeyValueStore.default
        guard let data = kvs.data(forKey: storageKey) else {
            return nil
        }
        return try? JSONDecoder().decode(AppData.self, from: data)
    }
    
    static func saveToICloud(_ data: AppData) {
        let kvs = NSUbiquitousKeyValueStore.default
        if let encoded = try? JSONEncoder().encode(data) {
            kvs.set(encoded, forKey: storageKey)
            kvs.synchronize()
        }
    }
}
