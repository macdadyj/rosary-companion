#if os(iOS)
import RosaryCore
import SwiftUI
import UIKit

enum Theme {
    /// Parchment in light mode, candlelit brown-black in dark mode.
    static let background = adaptive(light: (0.96, 0.93, 0.86), dark: (0.07, 0.035, 0.025))
    static let surface = adaptive(light: (0.99, 0.96, 0.91), dark: (0.14, 0.08, 0.05))
    static let raisedSurface = adaptive(light: (0.93, 0.86, 0.74), dark: (0.22, 0.13, 0.08))
    static let ink = adaptive(light: (0.16, 0.09, 0.05), dark: (0.98, 0.93, 0.84))
    static let secondaryInk = adaptive(light: (0.38, 0.26, 0.16), dark: (0.82, 0.72, 0.58))
    /// Icon gold. Dark enough on parchment and bright enough on candlelit brown for contrast.
    static let gold = adaptive(light: (0.48, 0.32, 0.06), dark: (0.95, 0.78, 0.42))
    static let lapis = adaptive(light: (0.10, 0.22, 0.38), dark: (0.45, 0.62, 0.78))
    static let burgundy = adaptive(light: (0.45, 0.12, 0.14), dark: (0.72, 0.28, 0.24))
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

    /// Meditation text: a step below the prayer so the prayer stays the thing being said.
    var meditationStyle: Font.TextStyle {
        switch self {
        case .large: .title3
        case .larger: .title2
        case .largest: .title
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
    func uiTag(_ identifier: String) -> some View { accessibilityIdentifier(identifier) }
}

/// Warm dark with a candle glow at the top, parchment in light mode.
struct CandleBackground: View {
    var body: some View {
        ZStack {
            Theme.background
            RadialGradient(
                colors: [Theme.gold.opacity(0.28), Theme.burgundy.opacity(0.08), .clear],
                center: .top,
                startRadius: 12,
                endRadius: 460
            )
        }
        .ignoresSafeArea()
    }
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
