#if os(iOS)
import RosaryCore
import SwiftUI

struct JournalView: View {
    let model: AppModel
    @State private var editing: SessionRecord?

    var body: some View {
        List {
            Section {
                streakSummary
            }
            let sessions = model.sessionsNewestFirst
            Section("Sessions") {
                if sessions.isEmpty {
                    Text("Nothing here yet. After you pray, you can add a one-line note, and it will appear here.")
                        .foregroundStyle(Theme.secondaryInk)
                }
                ForEach(sessions) { session in
                    Button { editing = session } label: { row(session) }
                        .swipeActions {
                            Button(role: .destructive) { model.deleteSession(session.id) } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle("Journal")
        .toolbar {
            if !model.sessions.isEmpty {
                ToolbarItem(placement: .primaryAction) {
                    ShareLink(
                        item: model.journalExportText(),
                        subject: Text("Rosary Journal"),
                        preview: SharePreview("Rosary Journal")
                    ) {
                        Label("Export as text", systemImage: "square.and.arrow.up")
                    }
                }
            }
        }
        .sheet(item: $editing) { session in
            JournalEntryEditor(model: model, session: session)
        }
    }

    private var streakSummary: some View {
        let streak = model.streak
        return HStack {
            stat(value: streak.current, label: "Current streak")
            Divider()
            stat(value: streak.longest, label: "Longest")
            Divider()
            stat(value: streak.totalDays, label: "Days prayed")
        }
        .padding(.vertical, 6)
    }

    private func stat(value: Int, label: String) -> some View {
        VStack(spacing: 2) {
            Text("\(value)")
                .font(.prayer(.title, weight: .semibold))
                .foregroundStyle(Theme.gold)
            Text(label)
                .font(.caption)
                .foregroundStyle(Theme.secondaryInk)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    private func row(_ session: SessionRecord) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(session.startedAt.formatted(date: .complete, time: .omitted))
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Theme.secondaryInk)
            Text(session.summary)
                .font(.headline)
                .foregroundStyle(Theme.ink)
            if let journal = session.journal {
                Text(journal)
                    .font(.prayer(.body))
                    .italic()
                    .foregroundStyle(Theme.ink)
            } else {
                Text("Add a line…")
                    .font(.subheadline)
                    .foregroundStyle(Theme.secondaryInk.opacity(0.8))
            }
            if !session.leaders.isEmpty {
                Text("Led by " + session.leaders.joined(separator: ", "))
                    .font(.caption)
                    .foregroundStyle(Theme.secondaryInk)
            }
            let offered = session.intentionIDs.compactMap { model.intention($0)?.text }
            if !offered.isEmpty {
                Label(offered.joined(separator: " · "), systemImage: "heart")
                    .font(.caption)
                    .foregroundStyle(Theme.secondaryInk)
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityHint("Double-tap to edit the journal line.")
    }
}

private struct JournalEntryEditor: View {
    let model: AppModel
    let session: SessionRecord
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("One line about this prayer", text: $text)
                        .submitLabel(.done)
                        .onSubmit(save)
                } header: {
                    Text(session.summary)
                } footer: {
                    Text(session.startedAt.formatted(date: .complete, time: .shortened))
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.background)
            .navigationTitle("Journal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save", action: save) }
            }
            .onAppear { text = session.journal ?? "" }
        }
        .presentationDetents([.medium])
    }

    private func save() {
        model.setJournal(text, for: session.id)
        dismiss()
    }
}
#endif
