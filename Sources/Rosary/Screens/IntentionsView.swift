#if os(iOS)
import RosaryCore
import SwiftUI

struct IntentionsView: View {
    let model: AppModel

    @State private var status: IntentionStatus = .ongoing
    @State private var newIntention = ""
    @State private var editing: Intention?
    @FocusState private var addFocused: Bool

    var body: some View {
        List {
            Section {
                HStack(spacing: 12) {
                    TextField("Add an intention", text: $newIntention)
                        .focused($addFocused)
                        .submitLabel(.done)
                        .onSubmit(add)
                    Button(action: add) {
                        Image(systemName: "plus.circle.fill").font(.title2)
                    }
                    .disabled(newIntention.trimmingCharacters(in: .whitespaces).isEmpty)
                    .accessibilityLabel("Add intention")
                }
            } footer: {
                Text("Choose intentions on the Pray tab to offer a session for them.")
            }

            Section {
                Picker("Show", selection: $status) {
                    ForEach(IntentionStatus.allCases, id: \.self) { status in
                        Text(status.title).tag(status)
                    }
                }
                .pickerStyle(.segmented)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
            }

            let items = model.intentions(with: status)
            Section {
                if items.isEmpty {
                    Text(status == .ongoing
                        ? "No ongoing intentions. Add someone or something you’re praying for."
                        : "When a prayer is answered, swipe it and mark it answered. It will be kept here.")
                        .foregroundStyle(Theme.secondaryInk)
                }
                ForEach(items) { intention in
                    Button { editing = intention } label: { row(intention) }
                        .swipeActions(edge: .leading) {
                            if intention.status == .ongoing {
                                Button { model.setStatus(.answered, for: intention.id) } label: {
                                    Label("Answered", systemImage: "checkmark.seal")
                                }
                                .tint(Theme.listening)
                            } else {
                                Button { model.setStatus(.ongoing, for: intention.id) } label: {
                                    Label("Ongoing", systemImage: "arrow.uturn.backward")
                                }
                                .tint(Theme.gold)
                            }
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) { model.deleteIntention(intention.id) } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle("Intentions")
        .sheet(item: $editing) { intention in
            IntentionEditor(model: model, intention: intention)
        }
    }

    private func row(_ intention: Intention) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(intention.text)
                .font(.prayer(.title3))
                .foregroundStyle(Theme.ink)
            Text(detail(intention))
                .font(.footnote)
                .foregroundStyle(Theme.secondaryInk)
            if let note = intention.note {
                Text(note)
                    .font(.subheadline)
                    .foregroundStyle(Theme.secondaryInk)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityHint("Double-tap to edit. Swipe to mark answered or ongoing.")
    }

    private func detail(_ intention: Intention) -> String {
        let count = model.sessionCount(for: intention.id)
        let offered = count == 0 ? "Not yet offered" : count == 1 ? "Offered once" : "Offered \(count) times"
        if intention.status == .answered, let answered = intention.answeredAt {
            return "Answered \(answered.formatted(date: .abbreviated, time: .omitted)) · \(offered)"
        }
        return "Since \(intention.createdAt.formatted(date: .abbreviated, time: .omitted)) · \(offered)"
    }

    private func add() {
        if model.addIntention(newIntention) != nil {
            newIntention = ""
            status = .ongoing
        }
    }
}

private struct IntentionEditor: View {
    let model: AppModel
    let intention: Intention
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    @State private var note = ""
    @State private var status: IntentionStatus = .ongoing

    var body: some View {
        NavigationStack {
            Form {
                Section("Intention") {
                    TextField("Intention", text: $text, axis: .vertical)
                }
                Section("Note") {
                    TextField("How it’s going, or how it was answered", text: $note, axis: .vertical)
                        .lineLimit(2...6)
                }
                Section {
                    Picker("Status", selection: $status) {
                        ForEach(IntentionStatus.allCases, id: \.self) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.background)
            .navigationTitle("Edit intention")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        model.updateIntention(intention.id, text: text, note: note)
                        if status != intention.status { model.setStatus(status, for: intention.id) }
                        dismiss()
                    }
                    .disabled(text.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear {
                text = intention.text
                note = intention.note ?? ""
                status = intention.status
            }
        }
    }
}
#endif
