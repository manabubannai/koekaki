import SwiftUI

/// NoType共通の配色(superwhisper風のダーク+ブルー)。
enum NT {
    static let bgTop = Color(red: 0.105, green: 0.110, blue: 0.150)
    static let bgBottom = Color(red: 0.055, green: 0.058, blue: 0.085)
    static let card = Color.white.opacity(0.055)
    static let cardStroke = Color.white.opacity(0.09)
    static let accent = Color(red: 0.455, green: 0.575, blue: 1.0)
    static let accentDeep = Color(red: 0.255, green: 0.360, blue: 0.870)
    static let recording = Color(red: 0.945, green: 0.320, blue: 0.310)
    static let textPrimary = Color.white.opacity(0.92)
    static let textSecondary = Color.white.opacity(0.55)

    static var background: LinearGradient {
        LinearGradient(colors: [bgTop, bgBottom], startPoint: .top, endPoint: .bottom)
    }

    static var accentGradient: LinearGradient {
        LinearGradient(colors: [accent, accentDeep], startPoint: .top, endPoint: .bottom)
    }
}
