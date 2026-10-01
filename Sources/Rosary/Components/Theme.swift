#if os(iOS)
import RosaryCore
import SwiftUI
import UIKit

enum Theme {
    /// Deep night blue in dark mode, warm parchment in light mode.
    static let background = adaptive(light: (0.97, 0.95, 0.91), dark: (0.035, 0.05, 0.09))
    static let surface = adaptive(light: (1.0, 0.99, 0.96), dark: (0.085, 0.105, 0.16))
    static let raisedSurface = adaptive(light: (0.93, 0.90, 0.84), dark: (0.13, 0.155, 0.22))
    static let ink = adaptive(light: (0.11, 0.09, 0.08), dark: (0.96, 0.94, 0.89))
    static let secondaryInk = adaptive(light: (0.33, 0.30, 0.28), dark: (0.74, 0.72, 0.68))
    /// Candle gold. Dark enough on parchment and bright enough on night blue for 4.5:1 contrast.
    static let gold = adaptive(light: (0.52, 0.36, 0.05), dark: (0.94, 0.79, 0.47))
    static let beadEmpty = adaptive(light: (0.80, 0.76, 0.70), dark: (0.25, 0.28, 0.36))
    static let listening = adaptive(light: (0.12, 0.42, 0.36), dark: (0.55, 0.85, 0.75))
    static let warning = adaptive(light: (0.62, 0.22, 0.12), dark: (0.98, 0.62, 0.50))

    private static func adaptive(light: (Double, Double, Double), dark: (Double, Double, Double)) -> Color {
        Color(UIColor { traits in
            let c = traits.userInterfaceStyle == .light ? light : dark
            return UIColor(red: c.0, green: c.1, blue: c.2, alpha: 1)
        })
    }
}

extension Font {
    static func prayer(_ style: Font.TextStyle, weight: Font.Weight = .regular) -> Font {
        .system(style, design: .serif, weight: weight)
    }
}

extension PrayerTextSize {
    /// Every size scales further with Dynamic Type.
    var prayerStyle: Font.TextStyle {
        switch self {
        case .large: .title2
        case .larger: .title
        case .largest: .largeTitle
        }
    }

    var headingStyle: Font.TextStyle {
        switch self {
        case .large: .title
        case .larger: .largeTitle
        case .largest: .largeTitle
        }
    }
}

extension AppearancePreference {
    var colorScheme: ColorScheme? {
        switch self {
        case .dark: .dark
        case .light: .light
        case .system: nil
        }
    }
}

extension PrayerMode {
    var shortTitle: String {
        switch self {
        case .guided: "Guided"
        case .tracking: "Tracking"
        }
    }

    var systemImage: String {
        switch self {
        case .guided: "person.wave.2"
        case .tracking: "ear"
        }
    }
}

struct CardBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(Theme.gold.opacity(0.18), lineWidth: 1)
            )
    }
}

extension View {
    func card() -> some View { modifier(CardBackground()) }
}

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.title3.weight(.semibold))
            .foregroundStyle(Theme.background)
            .frame(maxWidth: .infinity, minHeight: 60)
            .background(Theme.gold, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .opacity(configuration.isPressed ? 0.8 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }
}
#endif
