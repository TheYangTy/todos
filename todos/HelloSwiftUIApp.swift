import SwiftUI
import UIKit
import Combine

// App 主题：跟随系统 / 浅色 / 深色
enum AppTheme: String, CaseIterable, Identifiable {
    case system
    case light
    case dark
    
    var id: Self { self }
    
    var displayName: String {
        switch self {
        case .system: return "自动"
        case .light:  return "浅色"
        case .dark:   return "深色"
        }
    }
    
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light:  return .light
        case .dark:   return .dark
        }
    }
}

// 快捷动作类型，目前只有一个「新建待办」
enum QuickActionType: String {
    case quickAdd = "com.marcus.todos.quickAdd"
}

// 用于在 App 内传递快捷动作事件
final class QuickActionCenter: ObservableObject {
    static let shared = QuickActionCenter()
    
    @Published var lastAction: QuickActionType?
    
    func handle(shortcutItem: UIApplicationShortcutItem) {
        guard let type = QuickActionType(rawValue: shortcutItem.type) else { return }
        DispatchQueue.main.async {
            self.lastAction = type
        }
    }
}

// AppDelegate，用来配置图标长按菜单 & 接收快捷动作
class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        
        // 配置图标长按菜单里的「新建待办」
        let icon = UIApplicationShortcutIcon(systemImageName: "plus.circle")
        let item = UIApplicationShortcutItem(
            type: QuickActionType.quickAdd.rawValue,
            localizedTitle: "新建待办",
            localizedSubtitle: nil,
            icon: icon,
            userInfo: nil
        )
        application.shortcutItems = [item]
        
        return true
    }
    
    func application(_ application: UIApplication,
                     performActionFor shortcutItem: UIApplicationShortcutItem,
                     completionHandler: @escaping (Bool) -> Void) {
        QuickActionCenter.shared.handle(shortcutItem: shortcutItem)
        completionHandler(true)
    }
}

// App 入口
@main
struct HelloSwiftUIApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var quickActions = QuickActionCenter.shared
    
    @AppStorage("appTheme") private var appThemeRaw: String = AppTheme.system.rawValue
    
    private var appTheme: AppTheme {
        AppTheme(rawValue: appThemeRaw) ?? .system
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(quickActions)
                // 使用设置选择的主题（自动 / 浅色 / 深色）
                .preferredColorScheme(appTheme.colorScheme)
        }
    }
}
