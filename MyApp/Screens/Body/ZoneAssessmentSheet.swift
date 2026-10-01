import SwiftData
import SwiftUI

/// Assessment form for one body zone: area in palms, redness / thickness / scaling 0–4, pustules.
/// Saves today's record for the zone; «Clear this area» records it as clear.
struct ZoneAssessmentSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    let zone: BodyZone
    private let initial: ZoneAssessmentDraft
    private let wasAssessed: Bool

    @State private var draft: ZoneAssessmentDraft
    @State private var saveError: String?

    /// - Parameter current: the zone's latest stored state, if any.
    init(zone: BodyZone, current: ZoneScore?) {
        self.zone = zone
        let draft = current.map(ZoneAssessmentDraft.init) ?? ZoneAssessmentDraft()
        initial = draft
        wasAssessed = current?.isAffected ?? false
        _draft = State(initialValue: draft)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    areaCard
                    signsCard
                    pustulesCard
                    if wasAssessed || !draft.isClear {
                        Button("Clear this area", systemImage: "eraser", role: .destructive) {
                            draft = ZoneAssessmentDraft()
                            save()
                        }
                        .font(.rounded(.subheadline, weight: .medium))
                        .frame(maxWidth: .infinity)
                    }
                }
                .padding(.horizontal, Theme.screenPadding)
                .padding(.top, 8)
            }
            .screenScaffold()
            .navigationTitle(zone.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", systemImage: "xmark") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", systemImage: "checkmark") { save() }
                        .disabled(draft == initial && wasAssessed)
                }
            }
            .alert("Couldn't save", isPresented: Binding(get: { saveError != nil }, set: { if !$0 { saveError = nil } })) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(saveError ?? "")
            }
        }
    }

    private var areaCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "How much skin is affected?", subtitle: "Your palm with fingers is about 1 % of your body.")
            HStack(alignment: .firstTextBaseline) {
                Text("\(draft.palms, format: .number.precision(.fractionLength(0...1))) \(draft.palms == 1 ? "palm" : "palms")")
                    .font(.rounded(.title2, weight: .bold))
                    .foregroundStyle(Theme.ink)
                    .contentTransition(.numericText())
                Spacer()
                Text("≈ \(draft.palms, format: .number.precision(.fractionLength(0...1))) % of body")
                    .font(.rounded(.subheadline))
                    .foregroundStyle(Theme.inkSoft)
            }
            Slider(
                value: $draft.palms,
                in: ZoneAssessmentDraft.palmsRange(for: zone),
                step: ZoneAssessmentDraft.palmsStep(for: zone)
            ) {
                Text("Affected area")
            } minimumValueLabel: {
                Text("0").font(.rounded(.caption)).foregroundStyle(Theme.inkSoft)
            } maximumValueLabel: {
                Text("Whole area").font(.rounded(.caption)).foregroundStyle(Theme.inkSoft)
            }
            .tint(Theme.accent)
            .sensoryFeedback(.selection, trigger: draft.palms)
        }
        .glassCard()
    }

    private var signsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(title: "How does it look?", subtitle: "Rate the worst patch in this area.")
            SignRow(
                title: "Redness",
                hint: "On darker skin, look for purple, grey or dark brown instead of red.",
                value: $draft.erythema
            )
            SignRow(title: "Thickness", hint: "How raised the patch feels above the skin.", value: $draft.induration)
            SignRow(title: "Scaling", hint: "Flakes or silvery scale on the surface.", value: $draft.scale)
        }
        .glassCard()
    }

    private var pustulesCard: some View {
        Toggle(isOn: $draft.pustules) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Pus-filled bumps")
                    .font(.rounded(.subheadline, weight: .medium))
                    .foregroundStyle(Theme.ink)
                Text("Small white or yellow blisters (pustules).")
                    .font(.rounded(.footnote))
                    .foregroundStyle(Theme.inkSoft)
            }
        }
        .tint(Theme.accent)
        .glassCard()
    }

    private func save() {
        do {
            try draft.save(zoneID: zone.id, day: .now, in: modelContext)
            dismiss()
        } catch {
            modelContext.rollback()
            saveError = error.localizedDescription
        }
    }
}

/// 0–4 scale as five segments with a label for the current value.
private struct SignRow: View {
    let title: String
    let hint: String
    @Binding var value: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(.rounded(.subheadline, weight: .medium))
                    .foregroundStyle(Theme.ink)
                Spacer()
                Text(SignScale.label(for: value))
                    .font(.rounded(.subheadline, weight: .semibold))
                    .foregroundStyle(value == 0 ? Theme.inkSoft : Theme.ink)
            }
            Picker(title, selection: $value) {
                ForEach(0...4, id: \.self) { Text("\($0)").tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            Text(hint)
                .font(.rounded(.footnote))
                .foregroundStyle(Theme.inkSoft)
        }
    }
}

#Preview {
    ZoneAssessmentSheet(
        zone: BodyZone.zone(id: "back.elbow.left") ?? BodyZone.quickZones[0],
        current: ZoneScore(zoneID: "back.elbow.left", palms: 0.5, erythema: 2, induration: 1, scale: 2)
    )
    .previewSetup()
}
