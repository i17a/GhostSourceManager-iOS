import SwiftUI

enum GhostTheme {
    static let background = Color(red: 0.045, green: 0.032, blue: 0.095)
    static let cardTop = Color(red: 0.125, green: 0.082, blue: 0.225)
    static let cardBottom = Color(red: 0.075, green: 0.052, blue: 0.145)
    static let violetGlow = Color(red: 0.62, green: 0.28, blue: 0.96)
    static let gold = Color(red: 0.94, green: 0.74, blue: 0.22)
    static let goldDark = Color(red: 0.82, green: 0.60, blue: 0.12)
    static let textPrimary = Color.white
    static let textSecondary = Color.white.opacity(0.66)
    static let borderSubtle = Color.white.opacity(0.12)
    static let success = Color(red: 0.22, green: 0.82, blue: 0.52)
    static let danger = Color(red: 0.95, green: 0.34, blue: 0.36)

    static var heroGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.20, green: 0.09, blue: 0.38),
                Color(red: 0.09, green: 0.05, blue: 0.18),
                Color(red: 0.17, green: 0.07, blue: 0.32)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static var cardGradient: LinearGradient {
        LinearGradient(
            colors: [cardTop, cardBottom],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    static var goldGradient: LinearGradient {
        LinearGradient(
            colors: [gold, goldDark],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

struct GhostCardModifier: ViewModifier {
    var highlighted: Bool = false

    func body(content: Content) -> some View {
        content
            .background(GhostTheme.cardGradient)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(highlighted ? GhostTheme.gold : GhostTheme.borderSubtle, lineWidth: highlighted ? 1.6 : 1)
            )
            .shadow(color: highlighted ? GhostTheme.gold.opacity(0.22) : .black.opacity(0.35), radius: 14, y: 6)
    }
}

extension View {
    func ghostCard(highlighted: Bool = false) -> some View {
        modifier(GhostCardModifier(highlighted: highlighted))
    }
}
