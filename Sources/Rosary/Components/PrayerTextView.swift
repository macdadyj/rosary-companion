#if os(iOS)
import RosaryCore
import SwiftUI

/// The words of the prayer being said now, as large as the person has chosen.
struct PrayerTextView: View {
    let snapshot: SessionSnapshot
    let textSize: PrayerTextSize
    let card: MeditationCard?
    /// Scripture and fruit under a mystery's title; off when the meditation panel already shows them.
    var showsMysteryDetails = true
    var content: PrayerContent?

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
                .uiTag(UITag.sessionPrayer)

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
            if showsMysteryDetails {
                MysteryDetailsView(mystery: mystery, content: content)
                    .font(.callout)
            }
            if let card {
                MeditationCardView(card: card, textStyle: textSize.meditationStyle)
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

struct MysteryDetailsView: View {
    let mystery: Mystery
    var content: PrayerContent?
    var textStyle: Font.TextStyle = .body
    /// Opens the full passage. The preview stays short so the decade still fits on the screen.
    var onRead: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let passage = content?.passage(for: mystery.id), !passage.verses.isEmpty {
                if let onRead {
                    Button(action: onRead) {
                        VStack(alignment: .leading, spacing: 10) {
                            Text(passage.reference)
                                .font(.caption.weight(.semibold))
                                .tracking(0.6)
                                .foregroundStyle(Theme.gold)
                            scriptureRule
                            Text(passage.body)
                                .font(.prayer(textStyle))
                                .foregroundStyle(Theme.ink)
                                .lineSpacing(5)
                                .lineLimit(5)
                                .multilineTextAlignment(.leading)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Text("Read the passage")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Theme.gold)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Read the Scripture passage")
                    .accessibilityAddTraits(.isButton)
                    .accessibilityIdentifier(UITag.sessionScripture)
                } else {
                    Text(passage.reference)
                        .font(.caption.weight(.semibold))
                        .tracking(0.6)
                        .foregroundStyle(Theme.gold)
                    scriptureRule
                    Text(passage.body)
                        .font(.prayer(textStyle))
                        .foregroundStyle(Theme.ink)
                        .lineSpacing(5)
                        .fixedSize(horizontal: false, vertical: true)
                        .uiTag(UITag.sessionScripture)
                }
                Text(content?.scripture.translation ?? "")
                    .font(.caption2)
                    .foregroundStyle(Theme.secondaryInk)
                if let note = passage.note {
                    Text(note)
                        .font(.caption2)
                        .foregroundStyle(Theme.secondaryInk)
                }
            } else if let onRead {
                Button(action: onRead) {
                    Label(mystery.scripture, systemImage: "book")
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Read the Scripture passage")
                .accessibilityIdentifier(UITag.sessionScripture)
                Text("This short name has not been checked against one edition.")
                    .font(.caption2)
            } else {
                Label(mystery.scripture, systemImage: "book")
                    .uiTag(UITag.sessionScripture)
                Text("This short name has not been checked against one edition.")
                    .font(.caption2)
            }
            Text("Fruit of the mystery: \(mystery.fruit)")
                .font(.subheadline)
            if let prayer = content?.fruitPrayer(for: mystery.id) {
                Text(prayer.prayer)
                    .font(.prayer(.footnote))
                    .foregroundStyle(Theme.ink)
                Text(content?.fruits.source ?? "")
                    .font(.caption2)
            } else if let slot = content?.slot("fruit.luminous-prayers"), mystery.set == .luminous {
                Text(slot.reason)
                    .font(.caption2)
            }
        }
        .foregroundStyle(Theme.secondaryInk)
    }

    private var scriptureRule: some View {
        HStack(spacing: 8) {
            Rectangle().frame(height: 1)
            Text("†")
                .font(.caption)
            Rectangle().frame(width: 28, height: 1)
        }
        .foregroundStyle(Theme.gold.opacity(0.8))
        .frame(maxWidth: 160, alignment: .leading)
        .accessibilityHidden(true)
    }
}
#endif
