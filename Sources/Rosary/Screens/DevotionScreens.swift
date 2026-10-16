#if os(iOS)
import RosaryCore
import SwiftUI

struct DevotionsView: View {
    let model: AppModel
    let content: PrayerContent?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("Other prayers")
                    .font(.prayer(.largeTitle, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                Text("The Rosary is on the Pray tab. These are the other devotions, with the words that have been checked.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.secondaryInk)
                link("Seven Sorrows", "Seven Hail Marys for each sorrow", "heart", UITag.devotionSorrows) {
                    DevotionSessionView(plan: sorrowsPlan, model: model, content: content)
                }
                link("Divine Mercy", "The beads are counted. The Mercy prayers are not included yet.", "sun.max", UITag.devotionMercy) {
                    DevotionSessionView(plan: mercyPlan, model: model, content: content)
                }
                link("Litany of Loreto", "The 1857 Raccolta, word for word", "list.bullet", UITag.devotionLitany) {
                    LitanyView(content: content)
                }
                link("Angelus and Regina Caeli", "The hour changes with the season", "bell", UITag.devotionHours) {
                    HoursView(model: model, content: content)
                }
                link("33-day consecration", "A count of days, and one sourced act of consecration", "calendar", UITag.devotionConsecration) {
                    ConsecrationView(model: model, content: content)
                }
                link("Marian feasts", "Byzantine Ruthenian and Western", "star", UITag.devotionCalendar) {
                    FeastCalendarView(model: model, content: content)
                }
                link("Journal", "Notes and answered prayers you have kept", "book.closed", UITag.devotionJournal) {
                    JournalView(model: model)
                }
            }
            .padding(20)
        }
        .background(CandleBackground())
        .navigationTitle("Devotions")
    }

    private var sorrowsPlan: DevotionPlan? {
        content.map { DevotionCatalog.sevenSorrows(book: PrayerBook(usesHolyGhost: model.settings.usesHolyGhost), content: $0) }
    }

    private var mercyPlan: DevotionPlan? {
        content.map { DevotionCatalog.divineMercy(book: PrayerBook(usesHolyGhost: model.settings.usesHolyGhost), content: $0) }
    }

    private func link<Destination: View>(_ title: String, _ subtitle: String, _ symbol: String, _ tag: String, @ViewBuilder destination: () -> Destination) -> some View {
        NavigationLink {
            destination()
        } label: {
            HStack(spacing: 14) {
                Image(systemName: symbol)
                    .font(.title2)
                    .foregroundStyle(Theme.gold)
                    .frame(width: 32)
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.prayer(.title3, weight: .semibold))
                        .foregroundStyle(Theme.ink)
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(Theme.secondaryInk)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .foregroundStyle(Theme.secondaryInk)
            }
            .card()
        }
        .buttonStyle(.plain)
        .uiTag(tag)
    }
}

struct DevotionSessionView: View {
    let plan: DevotionPlan?
    let model: AppModel
    let content: PrayerContent?

    @State private var controller: DevotionController?
    @State private var speech: SpeechRecognitionService?
    @Environment(\.dismiss) private var dismiss

    init(plan: DevotionPlan?, model: AppModel, content: PrayerContent?) {
        self.plan = plan
        self.model = model
        self.content = content
        _controller = State(initialValue: plan.map(DevotionController.init(plan:)))
    }

    var body: some View {
        Group {
            if let plan, let controller {
                session(plan, controller)
            } else {
                Text("This devotion isn’t available.")
                    .foregroundStyle(Theme.secondaryInk)
            }
        }
        .background(CandleBackground())
        .task { await startListeningIfNeeded() }
        .onDisappear { speech?.stop() }
    }

    private func session(_ plan: DevotionPlan, _ controller: DevotionController) -> some View {
        let bead = controller.bead
        return VStack(spacing: 12) {
            HStack {
                Button("End") { dismiss() }
                    .uiTag(UITag.devotionEnd)
                Spacer()
                Text(plan.title)
                    .font(.caption)
                    .foregroundStyle(Theme.secondaryInk)
                    .lineLimit(1)
            }
            .padding(.horizontal, 16)
            if controller.isFinished {
                Text("Amen.")
                    .font(.prayer(.largeTitle, weight: .semibold))
                    .foregroundStyle(Theme.gold)
                Text(plan.source)
                    .font(.caption)
                    .foregroundStyle(Theme.secondaryInk)
                    .padding(.horizontal, 20)
            } else if let bead {
                if let index = bead.hailMaryIndex, let count = bead.hailMaryCount {
                    BeadRingView(count: count, completed: index - 1, current: index)
                        .padding(.horizontal, 24)
                }
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(bead.title)
                            .font(.prayer(.title2, weight: .semibold))
                            .foregroundStyle(Theme.ink)
                        if let text = bead.text {
                            Text(text)
                                .font(.prayer(.title3))
                                .foregroundStyle(Theme.ink)
                        } else if let slot = bead.slotID.flatMap({ content?.slot($0) }) {
                            SlotCard(slot: slot)
                        }
                    }
                    .padding(20)
                }
            }
            HStack {
                Button("Back") { controller.back() }
                    .uiTag(UITag.devotionBack)
                    .disabled(controller.index == 0)
                Spacer()
                Button("Next") { controller.tap() }
                    .uiTag(UITag.devotionNext)
                    .disabled(controller.isFinished)
            }
            .font(.headline)
            .foregroundStyle(Theme.gold)
            .padding(.horizontal, 20)
            .padding(.bottom, 12)
        }
        .sensoryFeedback(.impact(weight: .medium, intensity: 1), trigger: controller.index)
    }

    private func startListeningIfNeeded() async {
        guard model.settings.voiceTracking, speech == nil, let controller else { return }
        let speech = SpeechRecognitionService()
        speech.onTranscript = { update in
            controller.ingest(update, at: Date().timeIntervalSinceReferenceDate)
        }
        self.speech = speech
        await speech.requestAccess()
        speech.listen(epoch: controller.index)
    }
}

struct LitanyView: View {
    let content: PrayerContent?
    @State private var index = 0

    var body: some View {
        VStack(spacing: 0) {
            if let litany = content?.litany {
                Text(litany.title)
                    .font(.prayer(.title2, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                    .padding(.top, 8)
                Text(litany.note)
                    .font(.caption)
                    .foregroundStyle(Theme.secondaryInk)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 8)
                let row = litany.rows[index]
                Spacer(minLength: 0)
                VStack(spacing: 16) {
                    Text(row.english)
                        .font(.prayer(.largeTitle, weight: .semibold))
                        .foregroundStyle(Theme.ink)
                        .multilineTextAlignment(.center)
                    Text(row.latin)
                        .font(.prayer(.title3))
                        .foregroundStyle(Theme.gold)
                        .multilineTextAlignment(.center)
                    Text("\(index + 1) of \(litany.rows.count)")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(Theme.secondaryInk)
                }
                .padding(.horizontal, 24)
                Spacer(minLength: 0)
                HStack {
                    Button("Back") { if index > 0 { index -= 1 } }
                        .uiTag(UITag.litanyBack)
                    Spacer()
                    Button("Next") { if index + 1 < litany.rows.count { index += 1 } }
                        .uiTag(UITag.litanyNext)
                }
                .font(.headline)
                .foregroundStyle(Theme.gold)
                .padding(20)
            } else {
                Text("The litany text isn’t in this build.")
                    .foregroundStyle(Theme.secondaryInk)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(CandleBackground())
        .navigationTitle("Litany")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct HoursView: View {
    let model: AppModel
    let content: PrayerContent?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                let regina = MarianHours.usesReginaCaeli(on: model.today)
                Text(regina ? "Regina Caeli" : "The Angelus")
                    .font(.prayer(.largeTitle, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                if let hours = content?.hours {
                    Text(hours.seasonNote)
                        .font(.caption)
                        .foregroundStyle(Theme.secondaryInk)
                    ForEach(regina ? hours.reginaCaeli : hours.angelus, id: \.self) { line in
                        Text(line)
                            .font(.prayer(.title3))
                            .foregroundStyle(Theme.ink)
                    }
                    Text(hours.source)
                        .font(.caption2)
                        .foregroundStyle(Theme.secondaryInk)
                }
            }
            .padding(20)
        }
        .background(CandleBackground())
        .navigationTitle("The hours")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct ConsecrationView: View {
    let model: AppModel
    let content: PrayerContent?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("33 days")
                    .font(.prayer(.largeTitle, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                Text("\(model.consecration.finishedCount) of \(ConsecrationProgress.length) days marked.")
                    .foregroundStyle(Theme.secondaryInk)
                if model.consecration.start == nil {
                    Button("Begin today") { model.beginConsecration(on: model.today) }
                        .buttonStyle(PrimaryButtonStyle())
                        .uiTag(UITag.consecrationBegin)
                } else if let start = model.consecration.start {
                    Text("Started \(start.description). Day 33 is \(start.adding(days: 32).description).")
                        .font(.subheadline)
                        .foregroundStyle(Theme.secondaryInk)
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 8) {
                        ForEach(1...ConsecrationProgress.length, id: \.self) { day in
                            let on = model.consecration.isChecked(day)
                            Button("\(day)") { model.setConsecrationDay(day, checked: !on) }
                                .font(.headline.monospacedDigit())
                                .frame(maxWidth: .infinity, minHeight: 40)
                                .background(on ? Theme.gold : Theme.surface, in: Circle())
                                .foregroundStyle(on ? Theme.background : Theme.ink)
                                .uiTag(day == 1 ? UITag.consecrationDay : "consecration.day.\(day)")
                        }
                    }
                }
                if let slot = content?.slot("consecration.daily-readings") {
                    SlotCard(slot: slot)
                }
                if let slot = content?.slot("consecration.montfort-formula") {
                    SlotCard(slot: slot)
                }
                if let act = content?.sorrows.actOfConsecration {
                    Text("Act of Consecration")
                        .font(.prayer(.title2, weight: .semibold))
                        .foregroundStyle(Theme.ink)
                    Text("From the 1883 Seven Dolors chaplet, not from Montfort.")
                        .font(.caption)
                        .foregroundStyle(Theme.secondaryInk)
                    Text(act)
                        .font(.prayer(.body))
                        .foregroundStyle(Theme.ink)
                }
            }
            .padding(20)
        }
        .background(CandleBackground())
        .navigationTitle("Consecration")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct FeastCalendarView: View {
    let model: AppModel
    let content: PrayerContent?
    @State private var rite: Rite = .ruthenian

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Picker("Calendar", selection: $rite) {
                    ForEach(Rite.allCases) { rite in
                        Text(rite.title).tag(rite)
                    }
                }
                .pickerStyle(.segmented)
                if let calendar = content.map({ rite == .ruthenian ? $0.feasts.ruthenian : $0.feasts.western }) {
                    let today = calendar.feasts(on: model.today)
                    Text(today.isEmpty ? "No Marian feast on the calendar today." : today.map(\.name).joined(separator: "\n"))
                        .font(.prayer(.title3, weight: .semibold))
                        .foregroundStyle(Theme.gold)
                        .uiTag(UITag.calendarToday)
                    Text(calendar.source)
                        .font(.caption2)
                        .foregroundStyle(Theme.secondaryInk)
                    ForEach(calendar.ordered) { feast in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(feast.name)
                                .font(.body)
                                .foregroundStyle(Theme.ink)
                            if let rank = feast.rank {
                                Text(rank)
                                    .font(.caption)
                                    .foregroundStyle(Theme.secondaryInk)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 6)
                    }
                }
            }
            .padding(20)
        }
        .background(CandleBackground())
        .navigationTitle("Feasts")
        .navigationBarTitleDisplayMode(.inline)
    }
}
#endif
