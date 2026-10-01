import SwiftData
import SwiftUI

/// Add flow: pick a catalog medication or «Custom…», then fill in the form.
struct AddTreatmentSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var path: [TreatmentDraft] = []

    private var results: [Medication] { TreatmentDraft.search(query) }

    var body: some View {
        NavigationStack(path: $path) {
            List {
                Section {
                    Button {
                        path.append(TreatmentDraft(customName: query))
                    } label: {
                        Label(
                            query.trimmingCharacters(in: .whitespaces).isEmpty ? "Custom medication…" : "Add “\(query.trimmingCharacters(in: .whitespaces))” as custom",
                            systemImage: "square.and.pencil"
                        )
                        .foregroundStyle(Theme.accent)
                    }
                }
                ForEach(MedicationCategory.allCases) { category in
                    let items = results.filter { $0.category == category }
                    if !items.isEmpty {
                        Section(category.title) {
                            ForEach(items) { medication in
                                Button {
                                    path.append(TreatmentDraft(medication: medication))
                                } label: {
                                    MedicationRow(medication: medication)
                                }
                            }
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(WarmBackground())
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search, e.g. clobetasol")
            .navigationTitle("Add treatment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", systemImage: "xmark") { dismiss() }
                }
            }
            .navigationDestination(for: TreatmentDraft.self) { draft in
                TreatmentEditor(draft: draft, treatment: nil, onDone: { dismiss() })
            }
        }
        .fontDesign(.rounded)
    }
}

private struct MedicationRow: View {
    let medication: Medication

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: medication.kind.systemImage)
                .foregroundStyle(Theme.accent)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(medication.name)
                    .font(.rounded(.body))
                    .foregroundStyle(Theme.ink)
                Text(detail)
                    .font(.rounded(.caption))
                    .foregroundStyle(Theme.inkSoft)
            }
        }
    }

    private var detail: String {
        var parts = [medication.kind.title]
        if let steroidClass = medication.steroidClass { parts.append("Class \(steroidClass.number)") }
        return parts.joined(separator: " · ")
    }
}

/// Form for a new or stored treatment. For a stored one it also offers stop / resume and delete.
struct TreatmentEditor: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var draft: TreatmentDraft
    private let treatment: Treatment?
    private let onDone: () -> Void

    @State private var isStopping = false
    @State private var stopReason = ""
    @State private var isConfirmingDelete = false
    @State private var saveError: String?

    init(draft: TreatmentDraft, treatment: Treatment?, onDone: @escaping () -> Void) {
        _draft = State(initialValue: draft)
        self.treatment = treatment
        self.onDone = onDone
    }

    var body: some View {
        Form {
            medicationSection
            scheduleSection
            if draft.isTopical {
                areaSection
            }
            Section("Notes") {
                TextField("Optional, e.g. after a shower", text: $draft.notes, axis: .vertical)
            }
            if let treatment {
                manageSection(treatment)
            }
        }
        .scrollContentBackground(.hidden)
        .background(WarmBackground())
        .tint(Theme.accent)
        .navigationTitle(treatment == nil ? "New treatment" : "Edit treatment")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save", systemImage: "checkmark") { save() }
                    .disabled(!draft.isValid)
            }
        }
        .alert("Stop treatment", isPresented: $isStopping) {
            TextField("Reason (optional)", text: $stopReason)
            Button("Stop", role: .destructive) {
                if let treatment {
                    TreatmentDraft.stop(treatment, reason: stopReason)
                    persist()
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Reminders end today. The history stays.")
        }
        .confirmationDialog("Delete this treatment and all its marked doses?", isPresented: $isConfirmingDelete, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                if let treatment {
                    modelContext.delete(treatment)
                    persist()
                }
            }
        }
        .alert("Couldn't save", isPresented: Binding(get: { saveError != nil }, set: { if !$0 { saveError = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(saveError ?? "")
        }
    }

    // MARK: Sections

    private var medicationSection: some View {
        Section {
            TextField("Name", text: $draft.name)
                .font(.rounded(.body, weight: .medium))
            Picker("Type", selection: $draft.kind) {
                ForEach(TreatmentKind.allCases) { Text($0.title).tag($0) }
            }
            if draft.isTopical {
                Picker("Steroid strength", selection: $draft.steroidClass) {
                    Text("Not a steroid").tag(SteroidClass?.none)
                    ForEach(SteroidClass.allCases) { Text($0.title).tag(Optional($0)) }
                }
                Stepper(value: Binding(get: { draft.fingertipUnits ?? 0 }, set: { draft.fingertipUnits = $0 == 0 ? nil : $0 }), in: 0...20, step: 0.5) {
                    LabeledContent("Fingertip units", value: draft.fingertipUnits.map { $0.formatted(.number.precision(.fractionLength(0...1))) } ?? "Not set")
                }
            }
        } header: {
            Text("Medication")
        } footer: {
            if let notes = draft.medication?.notes, !notes.isEmpty {
                Text(notes)
            } else if draft.catalogID == nil {
                Text("Custom medication — check the name and strength on the package.")
            }
        }
    }

    private var scheduleSection: some View {
        Section {
            Picker("How often", selection: $draft.scheduleKind) {
                ForEach(ScheduleKind.allCases) { Text($0.title).tag($0) }
            }
            switch draft.scheduleKind {
            case .timesPerDay:
                Stepper("\(draft.timesPerDay) time\(draft.timesPerDay == 1 ? "" : "s") a day", value: $draft.timesPerDay, in: 1...6)
            case .weekly:
                Picker("Day", selection: Binding(
                    get: { draft.weekday ?? Calendar.current.component(.weekday, from: draft.startDate) },
                    set: { draft.weekday = $0 }
                )) {
                    ForEach(Array(Calendar.current.weekdaySymbols.enumerated()), id: \.offset) { index, name in
                        Text(name).tag(index + 1)
                    }
                }
            case .everyNDays:
                Stepper("Every \(draft.interval) day\(draft.interval == 1 ? "" : "s")", value: $draft.interval, in: 1...30)
            case .everyNWeeks:
                Stepper("Every \(draft.interval) week\(draft.interval == 1 ? "" : "s")", value: $draft.interval, in: 1...12)
            case .asNeeded:
                EmptyView()
            }
            ForEach(0..<draft.timeCount, id: \.self) { index in
                DatePicker(
                    draft.timeCount == 1 ? "Time" : "Dose \(index + 1)",
                    selection: timeBinding(index),
                    displayedComponents: .hourAndMinute
                )
            }
            DatePicker("Started", selection: $draft.startDate, displayedComponents: .date)
        } header: {
            Text("Schedule")
        } footer: {
            Text("Follow the schedule your doctor gave you. Typical schedules are only a starting point.")
        }
    }

    private var areaSection: some View {
        Section {
            NavigationLink {
                ZonePicker(selection: $draft)
            } label: {
                LabeledContent("Areas", value: draft.zoneIDs.isEmpty ? "None" : "\(draft.zoneIDs.count) selected")
            }
            if let warning = draft.sensitiveAreaWarning {
                Label(warning, systemImage: "exclamationmark.triangle")
                    .font(.rounded(.footnote))
                    .foregroundStyle(Theme.ink)
            }
        } header: {
            Text("Where you apply it")
        }
    }

    private func manageSection(_ treatment: Treatment) -> some View {
        Section {
            if treatment.isActive {
                Button("Stop treatment", systemImage: "stop.circle") {
                    stopReason = ""
                    isStopping = true
                }
            } else {
                Button("Resume treatment", systemImage: "play.circle") {
                    TreatmentDraft.resume(treatment)
                    persist()
                }
            }
            Button("Delete treatment", systemImage: "trash", role: .destructive) {
                isConfirmingDelete = true
            }
        }
    }

    // MARK: Actions

    private func timeBinding(_ index: Int) -> Binding<Date> {
        Binding(
            get: {
                let minutes = draft.doseMinutes.indices.contains(index) ? draft.doseMinutes[index] : DoseScheduler.defaultMinute
                return Calendar.current.date(bySettingHour: minutes / 60, minute: minutes % 60, second: 0, of: .now) ?? .now
            },
            set: { date in
                let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
                let minutes = (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
                while draft.doseMinutes.count <= index { draft.doseMinutes.append(DoseScheduler.defaultMinute) }
                draft.doseMinutes[index] = minutes
            }
        )
    }

    private func save() {
        if let treatment {
            draft.apply(to: treatment)
        } else {
            modelContext.insert(draft.makeTreatment())
        }
        persist()
    }

    private func persist() {
        do {
            try modelContext.save()
            onDone()
        } catch {
            modelContext.rollback()
            saveError = error.localizedDescription
        }
    }
}

/// Multi-select of body areas, quick zones first.
private struct ZonePicker: View {
    @Binding var selection: TreatmentDraft

    private var sections: [(title: String, zones: [BodyZone])] {
        let quickIDs = Set(BodyZone.quickZones.map(\.id))
        return [
            ("Special areas", BodyZone.quickZones),
            ("Front", BodyZone.all.filter { $0.id.hasPrefix("front.") && !quickIDs.contains($0.id) }),
            ("Back", BodyZone.all.filter { $0.id.hasPrefix("back.") && !quickIDs.contains($0.id) }),
        ]
    }

    var body: some View {
        List {
            ForEach(sections, id: \.title) { section in
                Section(section.title) {
                    ForEach(section.zones) { zone in
                        Button {
                            selection.toggleZone(zone.id)
                        } label: {
                            HStack {
                                Text(zone.name)
                                    .foregroundStyle(Theme.ink)
                                Spacer()
                                if selection.zoneIDs.contains(zone.id) {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(Theme.accent)
                                }
                            }
                        }
                        .accessibilityAddTraits(selection.zoneIDs.contains(zone.id) ? .isSelected : [])
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(WarmBackground())
        .navigationTitle("Areas")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview("Add") {
    AddTreatmentSheet()
        .previewSetup()
}
