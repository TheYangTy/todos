import Foundation
import UserNotifications

final class NotificationManager {
    static let shared = NotificationManager()
    private init() {}
    
    // 请求通知权限
    func requestAuthorization(completion: @escaping (Bool) -> Void) {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            DispatchQueue.main.async {
                completion(granted)
            }
        }
    }

    /// 同步本地通知：
    /// - 如果 enabled == false：清空所有待触发通知
    /// - 否则：清空后，按当前 todos 中的 reminderTime 重新创建
    func syncNotifications(for todos: [TodoItem], enabled: Bool) {
        let center = UNUserNotificationCenter.current()
        
        // 先清空所有待触发通知，防止重复 / 过期
        center.removeAllPendingNotificationRequests()
        
        guard enabled else { return }
        
        let now = Date()
        
        let needNotify = todos.filter { todo in
            guard todo.deletedAt == nil,
                  !todo.isDone,
                  let reminder = todo.reminderTime else {
                return false
            }
            // 只为未来时间创建通知
            return reminder > now
        }
        
        for todo in needNotify {
            guard let reminder = todo.reminderTime else { continue }
            
            let content = UNMutableNotificationContent()
            content.title = todo.title
            if let due = todo.dueDate {
                let f = DateFormatter()
                f.dateStyle = .medium
                f.timeStyle = .none
                content.body = "截止日期：\(f.string(from: due))"
            } else {
                content.body = "待办事项提醒"
            }
            content.sound = .default
            
            // 用任务 id 作为通知 id
            let identifier = todo.id.uuidString
            
            let calendar = Calendar.current
            let comps = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: reminder)
            
            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
            
            let request = UNNotificationRequest(
                identifier: identifier,
                content: content,
                trigger: trigger
            )
            
            center.add(request) { error in
                if let error = error {
                    print("Add notification error:", error)
                }
            }
        }
    }
}
