import Foundation
import UserNotifications

final class NotificationManager {
    static let shared = NotificationManager()
    
    private init() {}
    
    func requestAuthorization(completion: @escaping (Bool) -> Void) {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            DispatchQueue.main.async {
                completion(granted)
            }
        }
    }
    
    private func scheduleNotification(for item: TodoItem,
                                      center: UNUserNotificationCenter) {
        guard let due = item.dueDate else { return }
        
        // 只给未来的任务设置提醒
        if due <= Date() { return }
        
        let content = UNMutableNotificationContent()
        content.title = "待办提醒"
        content.body = item.title
        content.sound = .default
        
        let triggerDate = Calendar.current.dateComponents([.year, .month, .day],
                                                          from: due)
        let trigger = UNCalendarNotificationTrigger(dateMatching: triggerDate,
                                                    repeats: false)
        
        let request = UNNotificationRequest(
            identifier: item.id.uuidString,
            content: content,
            trigger: trigger
        )
        
        center.add(request, withCompletionHandler: nil)
    }
    
    func syncNotifications(for todos: [TodoItem], enabled: Bool) {
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()
        
        guard enabled else { return }
        
        for item in todos where item.deletedAt == nil && !item.isDone {
            scheduleNotification(for: item, center: center)
        }
    }
}
