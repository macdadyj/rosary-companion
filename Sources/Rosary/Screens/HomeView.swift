#if os(iOS)
import RosaryCore
import SwiftUI

struct HomeView: View {
    let model: AppModel
    let art: SacredArtLibrary
    let content: PrayerContent?
    let onBegin: (SessionSetup) -> Void

    @State private var setup: SessionSetup?
    @State private var choosingIntentions = false

    var body: some View {
        ScrollView {
            if let binding = Binding($setup) {
                content(binding)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 32)
            }
        }
        .background(CandleBackground())
        .navigationTitle("Rosary")
        .toolbarBackground(Theme.background, for: .navigationBar)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            // Pinned above the tab bar. A Begin button at the bottom of the
            // scroll ends up under the iOS 26 tab bar, so the UI test's tap
            // never starts the prayer.
            if let setup {
                beginButton(setup)
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 8)
                    .background(Theme.background)
            }
        }
        .onAppear { refresh() }
        .onChange(of: model.sessions.count) { refresh(afterSession: true) }
        .onChange(of: model.settings.family) { old, new in
            if old.isEnabled != new.isEnabled { setup?.family = new.isEnabled && !new.members.isEmpty }
            refresh()
        }
        .sheet(isPresented: $choosingIntentions) {
            if let binding = Binding($setup) {
                IntentionPickerSheet(model: model, selection: binding.intentionIDs)
            }
        }
    }

    private func content(_ setup: Binding<SessionSetup>) -> some View {
        VStack(alignment: .leading, spacing: 22) {
            todayHeader(setup.wrappedValue)
            artHeader(setup.wrappedValue)
            streakCard
            modeSection(setup)
            lengthSection(setup)
            familySection(setup)
            intentionsSection(setup.wrappedValue)
            moreLinks
        }
    }

    // MARK: - Sections

    private func todayHeader(_ setup: SessionSetup) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(model.now().formatted(.dateTime.weekday(.wide).month(.wide).day()))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.secondaryInk)
            Text(model.todaysSet.title)
                .font(.prayer(.largeTitle, weight: .semibold))
                .foregroundStyle(Theme.ink)
            Text(scheduleReason)
                .font(.subheadline)
                .foregroundStyle(Theme.secondaryInk)
            NavigationLink {
                ReadingsView(model: model)
            } label: {
                Label("Today’s readings", systemImage: "sun.horizon")
                    .font(.headline)
                    .foregroundStyle(Theme.gold)
            }
            .uiTag(UITag.tabToday)
        }
        .padding(.top, 8)
    }

    private var streakCard: some View {
        let streak = model.streak
        return HStack(spacing: 14) {
            Image(systemName: streak.prayedToday ? "checkmark.seal.fill" : "calendar")
                .font(.title)
                .foregroundStyle(Theme.gold)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(streak.current == 0 ? "Begin a streak today"
                     : streak.current == 1 ? "1 day in a row" : "\(streak.current) days in a row")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Theme.ink)
                Text(streak.prayedToday ? "You’ve prayed today." : streakNudge(streak))
                    .font(.subheadline)
                    .foregroundStyle(Theme.secondaryInk)
            }
            Spacer(minLength: 0)
        }
        .card()
        .accessibilityElement(children: .combine)
    }

    private func modeSection(_ setup: Binding<SessionSetup>) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("How would you like to pray?")
            ForEach(PrayerMode.allCases) { mode in
                let selected = setup.wrappedValue.mode == mode
                Button {
                    setup.wrappedValue.mode = mode
                } label: {
                    HStack(alignment: .top, spacing: 14) {
                        Image(systemName: mode.systemImage)
                            .font(.title2)
                            .foregroundStyle(Theme.gold)
                            .frame(width: 32)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(mode.title)
                                .font(.prayer(.title3, weight: .semibold))
                                .foregroundStyle(Theme.ink)
                            Text(mode.summary)
                                .font(.subheadline)
                                .foregroundStyle(Theme.secondaryInk)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: 0)
                        Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                            .font(.title2)
                            .foregroundStyle(selected ? Theme.gold : Theme.beadEmpty)
                    }
                    .multilineTextAlignment(.leading)
                    .padding(16)
                    .background(Theme.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .strokeBorder(selected ? Theme.gold : Theme.gold.opacity(0.15), lineWidth: selected ? 2 : 1)
                    )
                }
                .buttonStyle(.plain)
                .uiTag(mode == .guided ? UITag.modeGuided : UITag.modeTracking)
                .accessibilityElement(children: .combine)
                .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
            }
        }
    }

    private func lengthSection(_ setup: Binding<SessionSetup>) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("What will you pray?")
            Picker("Length", selection: setup.length) {
                ForEach(SessionLength.allCases) { length in
                    Text(length.title).tag(length)
                }
            }
            .pickerStyle(.segmented)

            VStack(alignment: .leading, spacing: 4) {
                Picker(selection: setup.mysterySet) {
                    ForEach(MysterySet.allCases) { set in
                        Text(set == model.todaysSet ? "\(set.title) (today)" : set.title).tag(set)
                    }
                } label: {
                    Text("Mysteries")
                }
                .pickerStyle(.menu)
                .tint(Theme.gold)

                if setup.wrappedValue.length == .oneDecade {
                    Picker(selection: setup.decade) {
                        ForEach(setup.wrappedValue.mysterySet.mysteries) { mystery in
                            Text("\(mystery.number). \(mystery.title)").tag(mystery.number)
                        }
                    } label: {
                        Text("Decade")
                    }
                    .pickerStyle(.menu)
                    .tint(Theme.gold)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .card()
        }
        .onChange(of: setup.wrappedValue.mysterySet) { _, newSet in
            setup.wrappedValue.decade = model.suggestedDecade(for: newSet)
        }
    }

    @ViewBuilder
    private func familySection(_ setup: Binding<SessionSetup>) -> some View {
        let family = model.settings.family
        if family.isEnabled, !family.members.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Toggle(isOn: setup.family) {
                    Label("Pray as a family", systemImage: "person.3")
                        .font(.headline)
                        .foregroundStyle(Theme.ink)
                }
                .tint(Theme.gold)

                if setup.wrappedValue.family {
                    Picker(selection: setup.starterID) {
                        ForEach(family.members) { member in
                            Text(member.name).tag(Optional(member.id))
                        }
                    } label: {
                        Text("Who starts")
                    }
                    .pickerStyle(.menu)
                    .tint(Theme.gold)

                    Text(lineup(setup.wrappedValue))
                        .font(.subheadline)
                        .foregroundStyle(Theme.secondaryInk)
                }
            }
            .card()
        } else {
            Label("Praying together? Add your family in Settings to take turns leading.", systemImage: "person.3")
                .font(.footnote)
                .foregroundStyle(Theme.secondaryInk)
        }
    }

    private func intentionsSection(_ setup: SessionSetup) -> some View {
        Button {
            choosingIntentions = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "heart.text.square")
                    .font(.title2)
                    .foregroundStyle(Theme.gold)
                VStack(alignment: .leading, spacing: 2) {
                    Text(setup.intentionIDs.isEmpty ? "Offer this prayer for…" : "Offered for")
                        .font(.headline)
                        .foregroundStyle(Theme.ink)
                    Text(intentionSummary(setup))
                        .font(.subheadline)
                        .foregroundStyle(Theme.secondaryInk)
                        .lineLimit(2)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .foregroundStyle(Theme.secondaryInk)
            }
            .multilineTextAlignment(.leading)
            .card()
        }
        .buttonStyle(.plain)
        .uiTag(UITag.offerIntentions)
    }

    private func beginButton(_ setup: SessionSetup) -> some View {
        VStack(spacing: 8) {
            Button {
                onBegin(setup)
            } label: {
                Label("Begin", systemImage: "play.fill")
            }
            .buttonStyle(PrimaryButtonStyle())
            .uiTag(UITag.beginRosary)
            .accessibilityHint(beginCaption(setup))

            Text(beginCaption(setup))
                .font(.footnote)
                .foregroundStyle(Theme.secondaryInk)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
        }
        .padding(.top, 4)
    }

    @ViewBuilder
    private func artHeader(_ setup: SessionSetup) -> some View {
        let mystery = setup.length == .oneDecade
            ? setup.mysterySet.mysteries[setup.decade - 1]
            : setup.mysterySet.mysteries[0]
        if model.settings.showSacredArt {
            SacredArtView(
                data: art.imageData(for: mystery.id, content: content, on: model.today),
                credit: art.creditLine(for: mystery.id, content: content, on: model.today),
                height: 260,
                isLoading: art.isLoading(mystery.id),
                token: art.imageToken(for: mystery.id, content: content, on: model.today)
            )
        }
    }

    private var moreLinks: some View {
        VStack(spacing: 10) {
            NavigationLink {
                HoursView(model: model, content: content)
            } label: {
                Label(MarianHours.usesReginaCaeli(on: model.today) ? "Regina Caeli" : "The Angelus", systemImage: "bell")
            }
            .uiTag(UITag.openAngelus)
            NavigationLink {
                FeastCalendarView(model: model, content: content)
            } label: {
                Label("Marian feasts", systemImage: "star")
            }
            .uiTag(UITag.openCalendar)
            NavigationLink {
                JournalView(model: model)
            } label: {
                Label("Journal", systemImage: "book.closed")
            }
            .uiTag(UITag.openJournal)
        }
        .font(.headline)
        .foregroundStyle(Theme.ink)
    }

    // MARK: - Helpers

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.headline)
            .foregroundStyle(Theme.secondaryInk)
            .accessibilityAddTraits(.isHeader)
    }

    private var scheduleReason: String {
        let day = model.today
        if model.settings.seasonalSundays, day.isSunday {
            if LiturgicalCalendar.isInLent(day) { return "Sunday in Lent" }
            if LiturgicalCalendar.isInAdvent(day) { return "Sunday in Advent" }
            if LiturgicalCalendar.isInChristmasSeason(day) { return "Sunday in the Christmas season" }
        }
        return "Prayed on \(model.now().formatted(.dateTime.weekday(.wide)))s"
    }

    private func streakNudge(_ streak: StreakSummary) -> String {
        if streak.current > 0 { return "Pray today to keep it going." }
        if streak.longest > 0 { return "Your longest streak: \(streak.longest) days." }
        return "Even one decade counts."
    }

    private func lineup(_ setup: SessionSetup) -> String {
        let members = model.settings.family.members
        guard let starter = members.first(where: { $0.id == setup.starterID }) ?? members.first else { return "" }
        let decades = setup.scope.decadeNumbers
        let lineup = FamilyRotation.lineup(starter: starter, decades: decades, members: members)
        let names = decades.compactMap { lineup[$0]?.name }
        return names.count == 1 ? "\(names[0]) leads this decade." : "Leading: " + names.joined(separator: " → ")
    }

    private func intentionSummary(_ setup: SessionSetup) -> String {
        let names = setup.intentionIDs.compactMap { model.intention($0)?.text }
        if !names.isEmpty { return names.joined(separator: " · ") }
        let ongoing = model.intentions(with: .ongoing).count
        return ongoing == 0 ? "Add an intention, or simply pray." : "Choose from \(ongoing) ongoing intention\(ongoing == 1 ? "" : "s")."
    }

    private func beginCaption(_ setup: SessionSetup) -> String {
        switch setup.length {
        case .oneDecade:
            let mystery = setup.mysterySet.mysteries[setup.decade - 1]
            return "One decade · \(mystery.title)"
        case .fiveDecades:
            return "Five decades · \(setup.mysterySet.title)"
        case .fullRosary:
            return "Full Rosary with opening and closing prayers · \(setup.mysterySet.title)"
        }
    }

    /// Picks up new defaults while keeping what was chosen. After a session, the next starter
    /// and the suggested decade move on.
    private func refresh(afterSession: Bool = false) {
        let fresh = model.defaultSetup()
        guard var current = setup else {
            setup = fresh
            return
        }
        let members = model.settings.family.members
        if !model.settings.family.isEnabled || members.isEmpty { current.family = false }
        if afterSession || !members.contains(where: { $0.id == current.starterID }) {
            current.starterID = fresh.starterID
        }
        if afterSession { current.decade = model.suggestedDecade(for: current.mysterySet) }
        current.intentionIDs = current.intentionIDs.filter { model.intention($0)?.status == .ongoing }
        setup = current
    }
}

/// Choose which ongoing intentions this prayer is offered for, or add a new one.
struct IntentionPickerSheet: View {
    let model: AppModel
    @Binding var selection: [UUID]
    @Environment(\.dismiss) private var dismiss
    @State private var newIntention = ""

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        TextField("New intention", text: $newIntention)
                            .submitLabel(.done)
                            .onSubmit(add)
                        Button("Add", action: add)
                            .disabled(newIntention.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
                Section("Ongoing") {
                    let ongoing = model.intentions(with: .ongoing)
                    if ongoing.isEmpty {
                        Text("No intentions yet. Add one above.")
                            .foregroundStyle(Theme.secondaryInk)
                    }
                    ForEach(ongoing) { intention in
                        let isOn = selection.contains(intention.id)
                        Button {
                            if isOn { selection.removeAll { $0 == intention.id } } else { selection.append(intention.id) }
                        } label: {
                            HStack {
                                Text(intention.text).foregroundStyle(Theme.ink)
                                Spacer()
                                if isOn { Image(systemName: "checkmark").foregroundStyle(Theme.gold) }
                            }
                        }
                        .accessibilityAddTraits(isOn ? [.isButton, .isSelected] : .isButton)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.background)
            .navigationTitle("Offer for")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func add() {
        if let intention = model.addIntention(newIntention) {
            selection.append(intention.id)
            newIntention = ""
        }
    }
}
#endif
