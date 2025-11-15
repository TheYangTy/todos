import SwiftUI

/// 可选的优先级颜色，供用户在设置中选择
enum PriorityColorOption: String, CaseIterable, Identifiable {
    case red
    case orange
    case yellow
    case green
    case mint
    case teal
    case blue
    case indigo
    case purple
    case pink
    case brown
    case gray

    var id: Self { self }

    var displayName: String {
        switch self {
        case .red:    return "红色"
        case .orange: return "橙色"
        case .yellow: return "黄色"
        case .green:  return "绿色"
        case .mint:   return "薄荷绿"
        case .teal:   return "蓝绿"
        case .blue:   return "蓝色"
        case .indigo: return "靛蓝"
        case .purple: return "紫色"
        case .pink:   return "粉色"
        case .brown:  return "棕色"
        case .gray:   return "灰色"
        }
    }

    var color: Color {
        switch self {
        case .red:    return .red
        case .orange: return .orange
        case .yellow: return .yellow
        case .green:  return .green
        case .mint:   return .mint
        case .teal:   return .teal
        case .blue:   return .blue
        case .indigo: return .indigo
        case .purple: return .purple
        case .pink:   return .pink
        case .brown:  return .brown
        case .gray:   return .gray
        }
    }
}
