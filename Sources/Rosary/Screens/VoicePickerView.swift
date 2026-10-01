#if os(iOS)
import AVFoundation
import RosaryCore
import SwiftUI

/// Every installed English voice, best first, each with a preview.
struct VoicePickerView: View {
    let model: AppModel
    let preview: VoicePreview
    let pacing: SpeechPacing

    @Environment(\.scenePhase) private var scenePhase
    @State private var catalog = InstalledVoices.catalog()

    private var selectedID: String? { model.settings.narratorVoiceID }

    /// A chosen voice that's since been deleted reads as Automatic, which is what plays.
    private var isAutomatic: Bool {
        guard let selectedID else { return true }
        return !catalog.voices.contains { $0.id == selectedID }
    }

    var body: some View {
        List {
            if !catalog.hasNaturalVoice {
                Section { DownloadVoicesHint(prominent: true) }
            }
            Section {
                automaticRow
            } footer: {
                Text("Automatic uses the most natural English voice on this iPhone: Premium first, then Enhanced, then Standard.")
            }
            ForEach([VoiceQuality.premium, .enhanced, .standard], id: \.self) { quality in
                let voices = catalog.voices(of: quality)
                if !voices.isEmpty {
                    Section {
                        ForEach(voices) { voice in row(voice) }
                    } header: {
                        Text(quality.title)
                    } footer: {
                        if quality == .standard {
                            Text("Standard voices are small and sound more mechanical.")
                        }
                    }
                }
            }
            if catalog.hasNaturalVoice {
                Section("More voices") { DownloadVoicesHint(prominent: false) }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle("Narrator voice")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            let changes = NotificationCenter.default.notifications(named: AVSpeechSynthesizer.availableVoicesDidChangeNotification)
            for await _ in changes { catalog = InstalledVoices.catalog() }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { catalog = InstalledVoices.catalog() }
        }
        .onDisappear { preview.stop() }
    }

    private var automaticRow: some View {
        VoiceRow(
            title: "Automatic",
            detail: catalog.best.map { "Now: \($0.name), \($0.quality.title)" } ?? "Now: the iPhone’s default voice",
            isSelected: isAutomatic,
            isPlaying: preview.playing == .automatic,
            onSelect: { model.update { $0.narratorVoiceID = nil } },
            onPreview: { preview.toggle(.automatic, pacing: pacing) }
        )
    }

    private func row(_ voice: VoiceInfo) -> some View {
        VoiceRow(
            title: voice.name,
            detail: voice.regionName,
            isSelected: !isAutomatic && selectedID == voice.id,
            isPlaying: preview.playing == .voice(voice.id),
            onSelect: { model.update { $0.narratorVoiceID = voice.id } },
            onPreview: { preview.toggle(.voice(voice.id), pacing: pacing) }
        )
    }
}

private struct VoiceRow: View {
    let title: String
    let detail: String
    let isSelected: Bool
    let isPlaying: Bool
    let onSelect: () -> Void
    let onPreview: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onSelect) {
                HStack(spacing: 12) {
                    Image(systemName: "checkmark")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Theme.gold)
                        .opacity(isSelected ? 1 : 0)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .foregroundStyle(Theme.ink)
                        Text(detail)
                            .font(.footnote)
                            .foregroundStyle(Theme.secondaryInk)
                    }
                    Spacer(minLength: 0)
                }
                .frame(minHeight: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(title), \(detail)")
            .accessibilityAddTraits(isSelected ? .isSelected : [])

            Button(action: onPreview) {
                Image(systemName: isPlaying ? "stop.circle.fill" : "play.circle")
                    .font(.title2)
                    .foregroundStyle(Theme.gold)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.borderless)
            .accessibilityLabel(isPlaying ? "Stop preview" : "Preview \(title)")
        }
    }
}

/// How to get a natural-sounding voice. They're free from Apple and work offline once downloaded.
struct DownloadVoicesHint: View {
    let prominent: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if prominent {
                Label("Only Standard voices are installed", systemImage: "waveform")
                    .font(.headline)
                    .foregroundStyle(Theme.gold)
            }
            Text("For a warmer, more natural narrator, download a Premium or Enhanced voice: open the Settings app, go to Accessibility › Spoken Content › Voices › English, pick a voice and tap the download button. Voices are free, stay on this iPhone, and appear here once downloaded.")
                .font(.subheadline)
                .foregroundStyle(prominent ? Theme.ink : Theme.secondaryInk)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }
}
#endif
