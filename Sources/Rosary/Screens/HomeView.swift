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
    @State private var query = ""
    @State private var category: PrayerCategory?
    @State private var novenaIntention = ""
    @State private var prayers: [LibraryPrayer] = []

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
        .onAppear {
            refresh()
            prayers = PrayerLibrary.catalog(
                book: PrayerBook(usesHolyGhost: model.settings.usesHolyGhost),
                content: content
            )
        }
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
            modeSection(setup)
            lengthSection(setup)
            familySection(setup)
            intentionsSection(setup.wrappedValue)
            moreLinks
            catalogue
            streakCard
            novenaCard
            artHeader(setup.wrappedValue)
        }
    }

    // MARK: - Sections

    private func todayHeader(_ setup: SessionSetup) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(model.now().formatted(.dateTime.weekday(.wide).month(.wide).day()))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.secondaryInk)
            HStack(alignment: .firstTextBaseline) {
                Text("Pray the Rosary")
                    .font(.prayer(.largeTitle, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                Spacer(minLength: 8)
                FavoriteStar(id: PrayerCatalogue.rosaryID, model: model)
            }
            Text(model.todaysSet.title)
                .font(.prayer(.title2, weight: .semibold))
                .foregroundStyle(Theme.gold)
            Text(scheduleReason)
                .font(.footnote)
                .foregroundStyle(Theme.secondaryInk)
            Text(resumeLine)
                .font(.subheadline)
                .foregroundStyle(Theme.secondaryInk)
            Text(feastLine)
                .font(.subheadline)
                .foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)
                .uiTag(UITag.homeFeast)
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
            HStack(spacing: 8) {
                ForEach(PrayerMode.allCases) { mode in
                    let selected = setup.wrappedValue.mode == mode
                    Button {
                        setup.wrappedValue.mode = mode
                    } label: {
                        Text(mode.shortTitle)
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity, minHeight: 36)
                            .foregroundStyle(selected ? Theme.background : Theme.ink)
                            .background(selected ? Theme.gold : Theme.raisedSurface, in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .uiTag(homeTag(mode))
                    .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
                }
            }
            Text(setup.wrappedValue.mode.title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.ink)
            Text(setup.wrappedValue.mode.summary)
                .font(.footnote)
                .foregroundStyle(Theme.secondaryInk)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func homeTag(_ mode: PrayerMode) -> String {
        switch mode {
        case .guided: UITag.modeGuided
        case .tracking: UITag.modeTracking
        case .guidedRosary: UITag.modeRosary
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
                height: 180,
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

    // MARK: - Catalogue

    private var catalogue: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionTitle("Prayers")
            HStack(spacing: 8) {
                TextField("Search prayers", text: $query)
                    .textFieldStyle(.roundedBorder)
                    .font(.body)
                    .uiTag(UITag.homeSearch)
                    .autocorrectionDisabled()
                if searching {
                    Button("Clear") { query = "" }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.gold)
                        .uiTag(UITag.homeSearchClear)
                }
            }
            if searching {
                ForEach(matches) { prayer in
                    prayerRow(prayer)
                }
            } else {
                categoryChips
                favoritesSection
                recentSection
                if let category {
                    ForEach(prayers.filter { $0.category == category }) { prayer in
                        prayerRow(prayer)
                    }
                }
            }
        }
    }

    private var searching: Bool {
        !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var matches: [LibraryPrayer] {
        PrayerLibrary.matching(query, in: prayers)
    }

    private var categoryChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(PrayerCategory.allCases) { item in
                    let selected = category == item
                    Button(item.title) { category = selected ? nil : item }
                        .font(.subheadline.weight(selected ? .semibold : .regular))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(selected ? Theme.gold : Theme.raisedSurface, in: Capsule())
                        .foregroundStyle(selected ? Theme.background : Theme.ink)
                        .uiTag("home.category.\(item.rawValue)")
                }
            }
        }
    }

    private var favoritesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionTitle("Favorites")
            if model.settings.favoritePrayerIDs.isEmpty {
                Text("Star a prayer to keep it here.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.secondaryInk)
            } else {
                ForEach(model.settings.favoritePrayerIDs, id: \.self) { id in
                    if let prayer = prayers.first(where: { $0.id == id }) {
                        prayerRow(prayer)
                    } else {
                        labelledFavourite(id)
                    }
                }
            }
        }
        .uiTag(UITag.homeFavorites)
    }

    private var recentSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionTitle("Recently prayed")
            if model.settings.recentPrayerIDs.isEmpty {
                Text("Prayers you open will be listed here.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.secondaryInk)
            } else {
                ForEach(model.settings.recentPrayerIDs, id: \.self) { id in
                    if let prayer = prayers.first(where: { $0.id == id }) {
                        prayerRow(prayer)
                    } else {
                        labelledFavourite(id)
                    }
                }
            }
        }
        .uiTag(UITag.homeRecent)
    }

    private func prayerRow(_ prayer: LibraryPrayer) -> some View {
        HStack(spacing: 4) {
            NavigationLink {
                PrayerPageView(prayer: prayer, model: model, content: content)
            } label: {
                VStack(alignment: .leading, spacing: 3) {
                    Text(prayer.title)
                        .font(.prayer(.title3, weight: .semibold))
                        .foregroundStyle(Theme.ink)
                    Text(prayer.category.title)
                        .font(.caption)
                        .foregroundStyle(Theme.secondaryInk)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            .uiTag("library.prayer.\(prayer.id)")
            FavoriteStar(id: prayer.id, model: model)
        }
        .card()
    }

    private func labelledFavourite(_ id: String) -> some View {
        HStack {
            Text(PrayerCatalogue.title(for: id, prayers: prayers))
                .font(.prayer(.title3, weight: .semibold))
                .foregroundStyle(Theme.ink)
            Spacer(minLength: 0)
            FavoriteStar(id: id, model: model)
        }
        .card()
    }

    private var novenaCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let novena = model.settings.novena, let day = novena.dayNumber(on: model.today) {
                Text("Novena · day \(day) of \(novena.length)")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Theme.ink)
                if !novena.intention.isEmpty {
                    Text(novena.intention)
                        .font(.subheadline)
                        .foregroundStyle(Theme.secondaryInk)
                }
                Button("End novena") { model.clearNovena() }
                    .font(.headline)
                    .foregroundStyle(Theme.gold)
            } else {
                Text(model.settings.novena == nil ? "Novena" : "The novena is complete")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Theme.ink)
                TextField("Intention", text: $novenaIntention)
                    .textFieldStyle(.roundedBorder)
                Button("Begin a novena") {
                    model.beginNovena(intention: novenaIntention, on: model.today)
                    novenaIntention = ""
                }
                .font(.headline)
                .foregroundStyle(Theme.gold)
            }
        }
        .card()
        .uiTag(UITag.homeNovena)
    }

    private var resumeLine: String {
        let set = model.todaysSet
        let decade = model.suggestedDecade(for: set)
        let mystery = set.mysteries[decade - 1]
        let resumed = model.sessions.contains { $0.mysterySet == set && !$0.decadesCompleted.isEmpty }
        let place = "Decade \(decade) · \(mystery.title)"
        return resumed ? "Resume · \(place)" : place
    }

    private var feastLine: String {
        let day = model.today
        let east = content?.feasts(on: day, rite: .ruthenian).map(\.name).filter { !$0.isEmpty } ?? []
        let west = content?.feasts(on: day, rite: .western).map(\.name).filter { !$0.isEmpty } ?? []
        let liturgical = LiturgicalCalendar.day(day)
        let eastText = east.isEmpty ? "feria" : east.joined(separator: ", ")
        let westText = west.isEmpty ? liturgical.title : west.joined(separator: ", ")
        return "Ruthenian \(eastText) · Roman \(westText)"
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
