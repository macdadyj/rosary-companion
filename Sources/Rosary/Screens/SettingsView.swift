#if os(iOS)
import AVFoundation
import RosaryCore
import SwiftUI

struct SettingsView: View {
    let model: AppModel

    @State private var narrationRate = 0.42
    @State private var voices: [AVSpeechSynthesisVoice] = []
    @State private var previewNarrator: NarratorService?
    @State private var previewAudio: AudioSessionCoordinator?

    private var settings: AppSettings { model.settings }

    var body: some View {
        Form {
            prayerSection
            voiceSection
            displaySection
            familySection
            privacySection
        }
        .scrollContentBackground(.hidden)
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle("Settings")
        .onAppear {
            narrationRate = settings.narrationRate
            voices = NarratorService.availableVoices()
        }
        .onDisappear { previewNarrator?.stop() }
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

    private var voiceSection: some View {
        Section {
            Toggle("Voice tracking", isOn: binding(\.voiceTracking))
            Toggle("Haptics", isOn: binding(\.haptics))
            Picker("Narrator", selection: binding(\.narratorVoiceID)) {
                Text("Automatic").tag(String?.none)
                ForEach(voices, id: \.identifier) { voice in
                    Text(voiceName(voice)).tag(Optional(voice.identifier))
                }
            }
            VStack(alignment: .leading, spacing: 6) {
                Text("Speaking pace")
                Slider(value: $narrationRate, in: 0.30...0.55) {
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
            Button("Hear a sample", systemImage: "speaker.wave.2", action: previewVoice)
        } header: {
            Text("Voice")
        } footer: {
            Text("Voice tracking listens for key phrases, such as the Glory Be and the Fatima Prayer, using speech recognition on this iPhone only. Nothing is recorded or sent anywhere. With it off, tap anywhere to move to the next prayer. For better narrators, download Enhanced or Premium voices in iPhone Settings › Accessibility › Spoken Content › Voices.")
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
        } header: {
            Text("Display")
        } footer: {
            Text("Prayer text also grows with the iPhone’s Text Size setting.")
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

    private func voiceName(_ voice: AVSpeechSynthesisVoice) -> String {
        let quality: String
        switch voice.quality {
        case .premium: quality = " (Premium)"
        case .enhanced: quality = " (Enhanced)"
        default: quality = ""
        }
        let region = Locale.current.localizedString(forIdentifier: voice.language) ?? voice.language
        return "\(voice.name)\(quality) · \(region)"
    }

    private func previewVoice() {
        let audio = previewAudio ?? AudioSessionCoordinator()
        audio.activate(listening: false)
        previewAudio = audio
        let narrator = previewNarrator ?? NarratorService(voiceID: settings.narratorVoiceID, rate: narrationRate)
        narrator.configure(voiceID: settings.narratorVoiceID, rate: narrationRate)
        previewNarrator = narrator
        narrator.stop()
        narrator.speak("Hail Mary, full of grace, the Lord is with thee.", preDelay: 0) {}
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
