#if os(iOS)
import RosaryCore
import SwiftUI

struct VoiceIndicatorView: View {
    let indicator: VoiceIndicator
    let listeningFor: String?
    let lastHeard: String

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: symbol)
                    .symbolEffect(.variableColor.iterative, isActive: isAnimating)
                    .foregroundStyle(color)
                Text(label)
                    .foregroundStyle(color)
            }
            .font(.headline)

            if case .listening = indicator, !lastHeard.isEmpty {
                Text(Self.tail(of: lastHeard))
                    .font(.footnote)
                    .foregroundStyle(Theme.secondaryInk.opacity(0.8))
                    .lineLimit(1)
                    .truncationMode(.head)
                    .accessibilityHidden(true)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var symbol: String {
        switch indicator {
        case .speaking: "speaker.wave.2.fill"
        case .listening: "waveform"
        case .quiet: "hourglass"
        case .paused: "pause.circle"
        case .unavailable: "hand.tap"
        }
    }

    private var label: String {
        switch indicator {
        case .speaking: "Leading…"
        case .listening: listeningFor.map { "Listening for “\($0)”" } ?? "Listening…"
        case .quiet: "A moment of quiet…"
        case .paused: "Paused. Tap anywhere to continue."
        case .unavailable(let reason): reason
        }
    }

    private var color: Color {
        switch indicator {
        case .listening: Theme.listening
        case .speaking: Theme.gold
        case .quiet, .paused: Theme.secondaryInk
        case .unavailable: Theme.secondaryInk
        }
    }

    private var isAnimating: Bool {
        switch indicator {
        case .listening, .speaking: true
        case .quiet, .paused, .unavailable: false
        }
    }

    static func tail(of text: String) -> String {
        let words = text.split(separator: " ")
        return words.suffix(8).joined(separator: " ")
    }
}
#endif
