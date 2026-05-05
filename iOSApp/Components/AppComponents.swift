import SwiftUI
import UIKit

// MARK: - Color Hex Extension

extension Color {
    /// Initialises a Color from a CSS-style hex string, e.g. "#FF8200" or "FF8200".
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r, g, b: Double
        switch hex.count {
        case 6:
            r = Double((int >> 16) & 0xFF) / 255
            g = Double((int >> 8) & 0xFF) / 255
            b = Double(int & 0xFF) / 255
        default:
            r = 1
            g = 1
            b = 1
        }
        self.init(red: r, green: g, blue: b)
    }
}

// MARK: - Theme

enum AppTheme {
    static let background = Color(UIColor.systemGroupedBackground)
    static let backgroundMid = Color(UIColor.systemGroupedBackground)

    static let accent = Color(red: 0.14, green: 0.44, blue: 0.92)
    static let success = Color(red: 0.13, green: 0.62, blue: 0.46)
    static let warning = Color(red: 0.91, green: 0.54, blue: 0.09)
    static let danger = Color(red: 0.86, green: 0.21, blue: 0.18)

    static let ink = Color(red: 0.06, green: 0.07, blue: 0.10)
    static let cardBackground = Color(UIColor.systemBackground)
    static let cardBorder = Color(red: 0.88, green: 0.89, blue: 0.91)
}

// MARK: - Team name abbreviation

/// Short label for school names (box scores, transfer portal, career tables).
enum TeamNameAbbreviation {
    private static let overrides: [String: String] = [
        "North Carolina": "UNC",
    ]

    static func abbreviated(_ fullName: String) -> String {
        let trimmed = fullName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "—" }
        if let over = overrides[trimmed] { return over }
        let words = trimmed.split(whereSeparator: { $0.isWhitespace })
        if words.count >= 2 {
            return words.prefix(4).map { String($0.first!).uppercased() }.joined()
        }
        let single = String(words.first ?? "")
        return String(single.prefix(3)).uppercased()
    }
}

// MARK: - GameCard

struct GameCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppTheme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(AppTheme.cardBorder, lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 1)
    }
}

// MARK: - GamePill

struct GamePill: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.caption.weight(.bold))
            .foregroundStyle(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(color.opacity(0.14))
            .clipShape(Capsule())
    }
}

// MARK: - GameBadge

struct GameBadge: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.caption.weight(.bold))
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.13))
            .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
    }
}

// MARK: - GameSectionHeader

struct GameSectionHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.headline.weight(.bold))
            .foregroundStyle(AppTheme.ink)
            .textCase(nil)
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.bottom, 4)
    }
}

// MARK: - GameButtonStyle

enum GameButtonVariant { case primary, secondary, success, danger }
enum GameButtonSize { case regular, compact }

struct GameButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    let variant: GameButtonVariant
    var size: GameButtonSize = .regular

    private var foreground: Color {
        switch variant {
        case .primary: return .white
        case .secondary: return AppTheme.ink
        case .success: return .white
        case .danger: return .white
        }
    }

    private var background: Color {
        switch variant {
        case .primary: return Color(red: 0.10, green: 0.34, blue: 0.86)
        case .secondary: return Color(UIColor.secondarySystemBackground)
        case .success: return Color(red: 0.11, green: 0.58, blue: 0.42)
        case .danger: return Color(red: 0.78, green: 0.23, blue: 0.19)
        }
    }

    private var border: Color {
        switch variant {
        case .primary: return Color(red: 0.08, green: 0.27, blue: 0.72)
        case .secondary: return Color(red: 0.81, green: 0.84, blue: 0.89)
        case .success: return Color(red: 0.09, green: 0.48, blue: 0.34)
        case .danger: return Color(red: 0.65, green: 0.17, blue: 0.13)
        }
    }

    private var font: Font {
        switch size {
        case .regular: return .callout.weight(.bold)
        case .compact: return .caption.weight(.bold)
        }
    }

    private var horizontalPadding: CGFloat {
        switch size {
        case .regular: return 11
        case .compact: return 8
        }
    }

    private var verticalPadding: CGFloat {
        switch size {
        case .regular: return 8
        case .compact: return 6
        }
    }

    private var minimumHeight: CGFloat {
        switch size {
        case .regular: return 44
        case .compact: return 32
        }
    }

    func makeBody(configuration: Configuration) -> some View {
        let shape = RoundedRectangle(cornerRadius: 10, style: .continuous)
        let fgOpacity = isEnabled ? (configuration.isPressed ? 0.8 : 1.0) : 0.5
        let bgOpacity = isEnabled ? (configuration.isPressed ? 0.84 : 1.0) : 0.45

        return configuration.label
            .font(font)
            .lineLimit(1)
            .minimumScaleFactor(0.75)
            .allowsTightening(true)
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
            .frame(minHeight: minimumHeight)
            .foregroundStyle(foreground.opacity(fgOpacity))
            .background(background.opacity(bgOpacity))
            .overlay(shape.strokeBorder(border.opacity(isEnabled ? 1.0 : 0.55), lineWidth: 1))
            .clipShape(shape)
            .contentShape(shape)
            .shadow(
                color: variant == .secondary ? .clear : Color.black.opacity(configuration.isPressed ? 0.05 : 0.12),
                radius: configuration.isPressed ? 1 : 4,
                x: 0,
                y: configuration.isPressed ? 1 : 2
            )
            .scaleEffect(configuration.isPressed ? 0.99 : 1.0)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

