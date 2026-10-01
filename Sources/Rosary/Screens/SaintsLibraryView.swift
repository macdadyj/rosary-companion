#if os(iOS)
import RosaryCore
import SwiftUI

struct SaintsLibraryView: View {
    let library: SaintsLibrary

    var body: some View {
        List {
            Section {
                Text("Short meditations from the saints for each mystery. A quotation appears only after it has been checked word for word against the cited source. Where none has been verified yet, you’ll see a reflection prompt written for this app, never a made-up quote.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.secondaryInk)
            }
            ForEach(MysterySet.allCases) { set in
                Section(set.title) {
                    ForEach(set.mysteries) { mystery in
                        NavigationLink {
                            MysteryMeditationsView(mystery: mystery, library: library)
                        } label: {
                            row(mystery)
                        }
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle("Saints")
    }

    private func row(_ mystery: Mystery) -> some View {
        let quotes = library.verifiedQuotes(for: mystery.id)
        return VStack(alignment: .leading, spacing: 3) {
            Text(mystery.title)
                .font(.prayer(.headline))
                .foregroundStyle(Theme.ink)
            Text(quotes.isEmpty ? "Reflection prompt" : quotes.map(\.saint).joined(separator: " · "))
                .font(.caption)
                .foregroundStyle(Theme.secondaryInk)
        }
        .padding(.vertical, 2)
    }
}

struct MysteryMeditationsView: View {
    let mystery: Mystery
    let library: SaintsLibrary

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(mystery.heading)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.gold)
                    Text(mystery.title)
                        .font(.prayer(.largeTitle, weight: .semibold))
                        .foregroundStyle(Theme.ink)
                    Text("\(mystery.scripture) · Fruit: \(mystery.fruit)")
                        .font(.subheadline)
                        .foregroundStyle(Theme.secondaryInk)
                }

                ForEach(library.verifiedQuotes(for: mystery.id)) { meditation in
                    VStack(alignment: .leading, spacing: 8) {
                        MeditationCardView(card: .quote(meditation))
                        Text(meditation.license.capitalized)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Theme.secondaryInk)
                        if let note = meditation.copyrightNote {
                            Text(note)
                                .font(.caption)
                                .foregroundStyle(Theme.secondaryInk)
                        }
                    }
                }

                if let prompt = library.entry(for: mystery.id)?.reflectionPrompt {
                    MeditationCardView(card: .reflection(prompt))
                }

                let placeholders = library.placeholders(for: mystery.id)
                if !placeholders.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Waiting for a verified text")
                            .font(.headline)
                            .foregroundStyle(Theme.secondaryInk)
                        ForEach(placeholders) { placeholder in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(placeholder.saint)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(Theme.ink)
                                if let suggestion = placeholder.suggestedSource {
                                    Text(suggestion)
                                        .font(.caption)
                                        .foregroundStyle(Theme.secondaryInk)
                                }
                            }
                        }
                        Text("Nothing is shown for these until someone checks the exact words and source.")
                            .font(.caption)
                            .foregroundStyle(Theme.secondaryInk)
                    }
                    .card()
                }
            }
            .padding(20)
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
    }
}
#endif
