#if os(iOS)
import RosaryCore
import SwiftUI

/// Shown when a session ends: what was prayed, who begins next time, and a one-line journal entry.
struct SessionSummaryView: View {
    let session: ActiveSession
    let onDone: () -> Void

    @State private var journal = ""
    @FocusState private var journalFocused: Bool

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                VStack(spacing: 10) {
                    Image(systemName: session.record == nil ? "moon.stars" : "sparkle")
                        .font(.system(size: 40))
                        .foregroundStyle(Theme.gold)
                        .accessibilityHidden(true)
                    Text(title)
                        .font(.prayer(.largeTitle, weight: .semibold))
                        .foregroundStyle(Theme.ink)
                        .multilineTextAlignment(.center)
                        .accessibilityAddTraits(.isHeader)
                    Text(subtitle)
                        .font(.body)
                        .foregroundStyle(Theme.secondaryInk)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 40)

                if let name = session.nextStarterName, session.record != nil {
                    VStack(spacing: 6) {
                        Text("Next time")
                            .font(.headline)
                            .foregroundStyle(Theme.secondaryInk)
                        Text(name)
                            .font(.system(size: 56, weight: .semibold, design: .serif))
                            .minimumScaleFactor(0.5)
                            .lineLimit(1)
                            .foregroundStyle(Theme.gold)
                        Text("begins")
                            .font(.prayer(.title3))
                            .foregroundStyle(Theme.secondaryInk)
                    }
                    .card()
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Next time, \(name) begins")
                }

                if session.record != nil {
                    streakRow
                    journalField
                }

                if !session.offeredIntentions.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Offered for")
                            .font(.headline)
                            .foregroundStyle(Theme.secondaryInk)
                        ForEach(session.offeredIntentions) { intention in
                            Label(intention.text, systemImage: "heart")
                                .foregroundStyle(Theme.ink)
                        }
                    }
                    .card()
                }

                Button {
                    session.saveJournal(journal)
                    onDone()
                } label: {
                    Text("Done")
                }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.bottom, 24)
            }
            .padding(.horizontal, 24)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    private var streakRow: some View {
        let streak = session.streak
        return HStack(spacing: 14) {
            Image(systemName: "calendar.badge.checkmark")
                .font(.title)
                .foregroundStyle(Theme.gold)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(streak.current == 1 ? "1 day in a row" : "\(streak.current) days in a row")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Theme.ink)
                Text("Longest: \(streak.longest) · \(streak.totalDays) days of prayer")
                    .font(.subheadline)
                    .foregroundStyle(Theme.secondaryInk)
            }
            Spacer()
        }
        .card()
        .accessibilityElement(children: .combine)
    }

    private var journalField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Journal")
                .font(.headline)
                .foregroundStyle(Theme.secondaryInk)
            TextField("One line about today’s prayer (optional)", text: $journal)
                .font(.prayer(.title3))
                .foregroundStyle(Theme.ink)
                .focused($journalFocused)
                .submitLabel(.done)
                .onSubmit { journalFocused = false }
                .padding(14)
                .background(Theme.raisedSurface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }

    private var title: String {
        guard let record = session.record else { return "Prayer ended" }
        if record.completedAll {
            switch record.scope {
            case .fullRosary: return "The Rosary is complete"
            case .fiveDecades: return "Five decades complete"
            case .singleDecade: return "Decade complete"
            }
        }
        let count = record.decadesCompleted.count
        return count == 1 ? "1 decade prayed" : "\(count) decades prayed"
    }

    private var subtitle: String {
        guard let record = session.record else {
            return "No decade was finished this time, so nothing was saved. You can begin again whenever you’re ready."
        }
        return "\(record.mysterySet.title) · Saved on this iPhone"
    }
}
#endif
