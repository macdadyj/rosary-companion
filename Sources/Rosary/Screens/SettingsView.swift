#if os(iOS)
import RosaryCore
import SwiftUI

struct SettingsView: View {
    let model: AppModel

    @State private var narrationRate = SpeechPacing.defaultRate
    @State private var narrationPitch = SpeechPacing.defaultPitch
    @State private var catalog = VoiceCatalog(installed: [])
    @State private var preview = VoicePreview()

    private var settings: AppSettings { model.settings }
    private var pacing: SpeechPacing { SpeechPacing(rate: narrationRate, pitch: narrationPitch) }

    var body: some View {
        Form {
            prayerSection
            narratorSection
            listeningSection
            displaySection
            familySection
            privacySection
        }
        .scrollContentBackground(.hidden)
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle("Settings")
        .onAppear {
            narrationRate = settings.narrationRate
            narrationPitch = settings.narrationPitch
            catalog = InstalledVoices.catalog()
        }
        .onDisappear { preview.stop() }
    }

    // MARK: - Sections

    private var prayerSection: some View {
        Section {
            Picker("Start in", selection: binding(\.defaultMode)) {
                ForEach(PrayerMode.allCases) { Text($0.title).tag($0) }
            }
            Picker("Usually pray", selection: binding(\.defaultLength)) {
                ForEach(SessionLength.allCases) { Text($0.title).tag($0) }
            }
            Toggle("Intentions on the first three Hail Marys", isOn: binding(\.openingIntentions))
            Toggle("Say “Holy Ghost”", isOn: binding(\.usesHolyGhost))
            Toggle("Seasonal Sundays", isOn: binding(\.seasonalSundays))
            Picker("Quiet after each mystery", selection: binding(\.meditationPause)) {
                ForEach(AppSettings.meditationPauseChoices, id: \.seconds) { choice in
                    Text("\(choice.title) (\(Int(choice.seconds)) s)").tag(choice.seconds)
                }
            }
        } header: {
            Text("Prayer")
        } footer: {
            Text("Seasonal Sundays: Joyful Mysteries on Sundays of Advent and Christmastide, Sorrowful on Sundays of Lent. Otherwise Sundays are Glorious. In guided mode, the quiet after each mystery gives time to read the meditation; a tap moves on sooner.")
        }
    }

    private var listeningSection: some View {
        Section {
            Toggle("Voice tracking", isOn: binding(\.voiceTracking))
            Toggle("Haptics", isOn: binding(\.haptics))
        } header: {
            Text("Listening")
        } footer: {
            Text("Voice tracking listens for key phrases, such as the Glory Be and the Fatima Prayer, using speech recognition on this iPhone only. Nothing is recorded or sent anywhere. With it off, tap anywhere to move to the next prayer.")
        }
    }

    private var narratorSection: some View {
        Section {
            NavigationLink {
                VoicePickerView(model: model, preview: preview, pacing: pacing)
            } label: {
                LabeledContent("Narrator voice", value: narratorName)
            }
            VStack(alignment: .leading, spacing: 6) {
                Text("Speaking pace")
                Slider(value: $narrationRate, in: SpeechPacing.rateRange) {
                    Text("Speaking pace")
                } minimumValueLabel: {
                    Image(systemName: "tortoise").accessibilityLabel("Slower")
                } maximumValueLabel: {
                    Image(systemName: "hare").accessibilityLabel("Faster")
                } onEditingChanged: { editing in
                    if !editing { model.update { $0.narrationRate = narrationRate } }
                }
                .tint(Theme.gold)
            }
            VStack(alignment: .leading, spacing: 6) {
                Text("Voice pitch")
                Slider(value: $narrationPitch, in: SpeechPacing.pitchRange) {
                    Text("Voice pitch")
                } minimumValueLabel: {
                    Image(systemName: "arrow.down").accessibilityLabel("Lower")
                } maximumValueLabel: {
                    Image(systemName: "arrow.up").accessibilityLabel("Higher")
                } onEditingChanged: { editing in
                    if !editing { model.update { $0.narrationPitch = narrationPitch } }
                }
                .tint(Theme.gold)
            }
            Button {
                preview.toggle(sampleTarget, pacing: pacing)
            } label: {
                Label(
                    preview.playing == sampleTarget ? "Stop sample" : "Hear a sample",
                    systemImage: preview.playing == sampleTarget ? "stop.fill" : "speaker.wave.2"
                )
            }
            if !isCalmDefault {
                Button("Restore the calm default pace", systemImage: "arrow.counterclockwise") {
                    narrationRate = SpeechPacing.defaultRate
                    narrationPitch = SpeechPacing.defaultPitch
                    model.update {
                        $0.narrationRate = SpeechPacing.defaultRate
                        $0.narrationPitch = SpeechPacing.defaultPitch
                    }
                }
            }
            if !catalog.hasNaturalVoice {
                DownloadVoicesHint(prominent: true)
            }
        } header: {
            Text("Narrator")
        } footer: {
            Text("Prayers are read on this iPhone, with short pauses between phrases. For the most natural sound, download a Premium or Enhanced voice in the Settings app › Accessibility › Spoken Content › Voices › English.")
        }
    }

    private var displaySection: some View {
        Section {
            Picker("Appearance", selection: binding(\.appearance)) {
                ForEach(AppearancePreference.allCases) { Text($0.title).tag($0) }
            }
            Picker("Prayer text", selection: binding(\.textSize)) {
                ForEach(PrayerTextSize.allCases) { Text($0.title).tag($0) }
            }
            Text("Hail Mary, full of grace, the Lord is with thee.")
                .font(.prayer(settings.textSize.prayerStyle))
                .foregroundStyle(Theme.ink)
                .padding(.vertical, 4)
                .accessibilityLabel("Sample prayer text")
            Toggle("Meditation while tracking", isOn: binding(\.showsMeditationWhileTracking))
        } header: {
            Text("Display")
        } footer: {
            Text("Prayer text also grows with the iPhone’s Text Size setting. In tracking mode, the mystery’s meditation stays above the prayer for the whole decade; you can also hide or show it there.")
        }
    }

    private var familySection: some View {
        Section {
            Toggle("Family Rosary", isOn: binding(\.family.isEnabled))
            NavigationLink {
                FamilyMembersView(model: model)
            } label: {
                LabeledContent("Family members", value: "\(settings.family.members.count)")
            }
            Picker("Taking turns", selection: binding(\.family.policy)) {
                ForEach(RotationPolicy.allCases) { Text($0.title).tag($0) }
            }
            Toggle("Announce whose turn is next", isOn: binding(\.family.announceNextLeader))
            if let next = model.nextStarter {
                LabeledContent("Starts next time", value: next.name)
            }
        } header: {
            Text("Family")
        } footer: {
            Text("Each person leads a decade in turn. When a decade ends, the next person’s name is shown large on screen and read aloud. The rotation is remembered between sessions.")
        }
    }

    private var privacySection: some View {
        Section("Privacy") {
            Label("No accounts, ads, analytics, or network access.", systemImage: "lock")
            Label("Your journal, intentions, and settings are saved only on this iPhone.", systemImage: "iphone")
            if let error = model.saveError {
                Label(error, systemImage: "exclamationmark.triangle")
                    .foregroundStyle(Theme.warning)
            }
            LabeledContent("Version", value: Self.version)
        }
        .font(.subheadline)
    }

    // MARK: - Helpers

    private func binding<Value>(_ keyPath: WritableKeyPath<AppSettings, Value>) -> Binding<Value> {
        Binding(
            get: { model.settings[keyPath: keyPath] },
            set: { value in model.update { $0[keyPath: keyPath] = value } }
        )
    }

    /// The voice that will actually read, which is the automatic choice if a chosen voice was deleted.
    private var narratorName: String {
        if let id = settings.narratorVoiceID, let chosen = catalog.voices.first(where: { $0.id == id }) {
            return chosen.name
        }
        return catalog.best.map { "Automatic (\($0.name))" } ?? "Automatic"
    }

    private var sampleTarget: VoicePreview.Target {
        settings.narratorVoiceID.map(VoicePreview.Target.voice) ?? .automatic
    }

    private var isCalmDefault: Bool {
        abs(narrationRate - SpeechPacing.defaultRate) < 0.005 && abs(narrationPitch - SpeechPacing.defaultPitch) < 0.005
    }

    private static var version: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        return "\(short) (\(build))"
    }
}

struct FamilyMembersView: View {
    let model: AppModel
    @State private var newName = ""

    var body: some View {
        List {
            Section {
                ForEach(model.settings.family.members) { member in
                    MemberNameRow(member: member) { model.renameMember(member.id, to: $0) }
                }
                .onDelete { model.removeMembers(atOffsets: $0) }
                .onMove { model.moveMembers(fromOffsets: $0, toOffset: $1) }

                HStack {
                    TextField("Add a name", text: $newName)
                        .submitLabel(.done)
                        .onSubmit(add)
                    Button("Add", action: add)
                        .disabled(newName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            } footer: {
                Text("Turns follow this order. Tap Edit to reorder or remove people.")
            }
        }
        .scrollContentBackground(.hidden)
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle("Family")
        .toolbar { EditButton() }
    }

    private func add() {
        model.addMember(named: newName)
        newName = ""
    }
}

private struct MemberNameRow: View {
    let member: FamilyMember
    let onRename: (String) -> Void
    @State private var name = ""
    @FocusState private var focused: Bool

    var body: some View {
        TextField("Name", text: $name)
            .font(.headline)
            .focused($focused)
            .submitLabel(.done)
            .onSubmit { onRename(name) }
            .onChange(of: focused) { _, isFocused in
                if !isFocused { onRename(name) }
            }
            .onAppear { name = member.name }
            .accessibilityLabel("Name")
            .accessibilityValue(name)
    }
}
#endif
