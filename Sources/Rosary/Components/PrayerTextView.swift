#if os(iOS)
import RosaryCore
import SwiftUI

/// The words of the prayer being said now, as large as the person has chosen.
struct PrayerTextView: View {
    let snapshot: SessionSnapshot
    let textSize: PrayerTextSize
    let card: MeditationCard?

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            if let intention = snapshot.intention {
                Text(intention.label)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.background)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
                    .background(Theme.gold, in: Capsule())
            }

            Text(snapshot.title)
                .font(.prayer(textSize.headingStyle, weight: .semibold))
                .foregroundStyle(Theme.gold)
                .accessibilityAddTraits(.isHeader)

            switch snapshot.step.content {
            case .mysteryAnnouncement(let mystery):
                announcement(mystery)
            case .prayer:
                prayerParts
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func announcement(_ mystery: Mystery) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(mystery.title)
                .font(.prayer(textSize.prayerStyle, weight: .medium))
                .foregroundStyle(Theme.ink)
            VStack(alignment: .leading, spacing: 6) {
                Label(mystery.scripture, systemImage: "book")
                Label("Fruit of the mystery: \(mystery.fruit)", systemImage: "leaf")
            }
            .font(.callout)
            .foregroundStyle(Theme.secondaryInk)
            if let card {
                MeditationCardView(card: card)
                    .padding(.top, 4)
            }
        }
    }

    @ViewBuilder
    private var prayerParts: some View {
        let leader = snapshot.leaderText
        let response = snapshot.responseText
        let split = !leader.isEmpty && !response.isEmpty
        VStack(alignment: .leading, spacing: 16) {
            if !leader.isEmpty {
                part(label: split ? leaderLabel : nil, text: leader, emphasized: leaderEmphasized)
            }
            if !response.isEmpty {
                part(label: split ? responseLabel : nil, text: response, emphasized: responseEmphasized)
            }
        }
    }

    private func part(label: String?, text: String, emphasized: Bool) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            if let label {
                Text(label.uppercased())
                    .font(.caption.weight(.bold))
                    .tracking(1.2)
                    .foregroundStyle(emphasized ? Theme.gold : Theme.secondaryInk)
            }
            Text(text)
                .font(.prayer(textSize.prayerStyle))
                .foregroundStyle(emphasized ? Theme.ink : Theme.secondaryInk)
                .lineSpacing(6)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }

    private var leaderLabel: String {
        switch snapshot.mode {
        case .guided: "Rosary leads"
        case .tracking: snapshot.leader ?? "Leader"
        }
    }

    private var responseLabel: String {
        switch snapshot.mode {
        case .guided: snapshot.leader == nil ? "You answer" : "All answer"
        case .tracking: "All"
        }
    }

    private var leaderEmphasized: Bool {
        snapshot.mode == .tracking || snapshot.phase == .speaking || snapshot.responseText.isEmpty
    }

    private var responseEmphasized: Bool {
        snapshot.mode == .tracking || snapshot.phase != .speaking || snapshot.leaderText.isEmpty
    }
}
#endif
