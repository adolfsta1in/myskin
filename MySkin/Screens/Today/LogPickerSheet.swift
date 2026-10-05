import SwiftUI

/// Full list behind "More": every built-in chip, the user's own entries and a field to add a new one.
/// The check-in card itself only shows `QuickPicks`.
struct LogPickerSheet<Draft: PickDraft>: View {
    struct Section: Identifiable {
        let title: String
        let picks: [LogPick]
        var id: String { title }
    }

    let title: String
    let sections: [Section]
    let addTitle: String
    let addPlaceholder: String
    /// Earlier custom entries, to reuse their spelling.
    let known: [String]
    @Binding var draft: Draft
    let systemImage: (LogPick) -> String

    @Environment(\.dismiss) private var dismiss
    @State private var newEntry = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    // On top, so the field is visible at the medium detent.
                    VStack(alignment: .leading, spacing: 10) {
                        SectionHeader(title: addTitle)
                        HStack(spacing: 10) {
                            TextField(addPlaceholder, text: $newEntry)
                                .font(.rounded(.body))
                                .submitLabel(.done)
                                .onSubmit(add)
                                .padding(12)
                                .background(.white.opacity(0.45), in: .rect(cornerRadius: 16))
                            Button("Add", action: add)
                                .font(.rounded(.subheadline, weight: .semibold))
                                .buttonStyle(.glass)
                                .disabled(newEntry.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                    }
                    ForEach(sections) { section in
                        if !section.picks.isEmpty {
                            VStack(alignment: .leading, spacing: 10) {
                                SectionHeader(title: section.title)
                                GlassEffectContainer(spacing: 8) {
                                    FlowLayout(spacing: 8) {
                                        ForEach(section.picks, id: \.self) { pick in
                                            TagChip(title: pick.title, systemImage: systemImage(pick), isSelected: draft.isSelected(pick)) {
                                                draft.toggle(pick)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(Theme.screenPadding)
            }
            .screenScaffold()
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func add() {
        draft.addCustom(newEntry, known: known)
        newEntry = ""
    }
}
