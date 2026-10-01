import SwiftUI

// MARK: - O7 First body map

struct FirstBodyMapStep: View {
    @Environment(OnboardingDraft.self) private var draft
    @State private var side: BodySide = .front
    let next: () -> Void

    var body: some View {
        let bsa = draft.snapshot.bsa
        OnboardingPage(
            title: "Where is your skin affected?",
            subtitle: "Tap areas on the body. Tap again for more: mild, moderate, severe.",
            why: "Doctors estimate how much skin is involved — this helps you both see change over time."
        ) {
            VStack(spacing: 14) {
                Picker("Side", selection: $side) {
                    ForEach(BodySide.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()

                BodySilhouette(side: side, intensities: draft.zoneLevels) { zone in
                    draft.cycleLevel(for: zone.id)
                }
                .frame(height: 300)

                FlowLayout(spacing: 8) {
                    ForEach(BodyZone.quickZones) { zone in
                        let level = draft.zoneLevels[zone.id] ?? 0
                        TagChip(
                            title: level == 0 ? zone.name : "\(zone.name) · \(IntensityLegend.label(for: level))",
                            isSelected: level > 0
                        ) {
                            draft.cycleLevel(for: zone.id)
                        }
                    }
                }
                IntensityLegend()
            }
            .glassCard(padding: 16)
        } footer: {
            HStack(spacing: 12) {
                Image(systemName: "flag.checkered")
                    .foregroundStyle(Theme.sageDeep)
                VStack(alignment: .leading, spacing: 0) {
                    Text("≈ \(bsa, format: .number.precision(.fractionLength(0...1)))% of body area")
                        .font(.rounded(.headline, weight: .bold))
                        .foregroundStyle(Theme.ink)
                        .contentTransition(.numericText())
                    Text("A rough start — you can refine each area in the Body tab")
                        .font(.rounded(.subheadline))
                        .foregroundStyle(Theme.inkSoft)
                }
                Spacer()
            }
            .glassCard(padding: 14, tint: Theme.sageSoft)
            .animation(.smooth, value: bsa)
            PrimaryButton(title: "Continue", action: next)
        }
    }
}

// MARK: - O8 Treatments

struct TreatmentsStep: View {
    @Environment(OnboardingDraft.self) private var draft
    @State private var query = ""
    let next: () -> Void

    private var trimmedQuery: String { query.trimmingCharacters(in: .whitespacesAndNewlines) }

    private var results: [Medication] {
        guard !trimmedQuery.isEmpty else { return [] }
        let chosen = Set(draft.treatments.compactMap(\.catalogID))
        return TreatmentDraft.search(trimmedQuery).filter { !chosen.contains($0.id) }
    }

    var body: some View {
        @Bindable var draft = draft
        OnboardingPage(
            title: "What are you using right now?",
            subtitle: "Search the list or type your own. Schedules can be adjusted later in Treatment.",
            why: "Knowing when a treatment started lets you see whether it's making a difference."
        ) {
            VStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(Theme.inkSoft)
                    TextField("Search, e.g. clobetasol", text: $query)
                        .textFieldStyle(.plain)
                        .font(.rounded(.body))
                        .submitLabel(.done)
                        .onSubmit(addCustom)
                }
                .padding(14)
                .glassEffect(.regular, in: .capsule)

                if !trimmedQuery.isEmpty {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(results.prefix(5)) { medication in
                            resultRow(medication.name, detail: medication.kind.title) {
                                draft.add(medication)
                                query = ""
                            }
                        }
                        resultRow("Add “\(trimmedQuery)”", detail: "Your own medication", action: addCustom)
                    }
                    .glassCard(padding: 14)
                }

                if !draft.treatments.isEmpty {
                    FlowLayout(spacing: 8) {
                        ForEach(Array(draft.treatments.enumerated()), id: \.offset) { index, treatment in
                            TagChip(title: treatment.trimmedName, systemImage: "xmark", isSelected: true) {
                                withAnimation(.snappy) { draft.removeTreatment(at: index) }
                            }
                            .accessibilityHint("Removes it")
                        }
                    }
                }

                TagChip(title: "Nothing right now", systemImage: "minus.circle", isSelected: draft.hasNoTreatment) {
                    withAnimation(.snappy) {
                        draft.hasNoTreatment.toggle()
                        if draft.hasNoTreatment { draft.treatments = [] }
                    }
                }
            }
        } footer: {
            PrimaryButton(title: "Continue", action: next)
        }
    }

    private func addCustom() {
        guard !trimmedQuery.isEmpty else { return }
        withAnimation(.snappy) { draft.addCustom(trimmedQuery) }
        query = ""
    }

    private func resultRow(_ title: String, detail: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).foregroundStyle(Theme.ink)
                    Text(detail).font(.rounded(.caption)).foregroundStyle(Theme.inkSoft)
                }
                Spacer()
                Image(systemName: "plus.circle").foregroundStyle(Theme.accent)
            }
            .font(.rounded(.body))
            .padding(.vertical, 8)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - O8 Notifications (soft ask)

struct NotificationsStep: View {
    @Environment(AppSettings.self) private var settings
    @State private var isAsking = false
    let next: () -> Void

    private var wantsReminders: Bool { settings.doseReminders || settings.checkInReminder }

    var body: some View {
        @Bindable var settings = settings
        OnboardingPage(
            title: "Gentle reminders, only if you want them",
            why: "You choose what we remind you about — and you can change it anytime."
        ) {
            VStack(spacing: 16) {
                // Notification preview
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "leaf.fill")
                        .foregroundStyle(.white)
                        .frame(width: 38, height: 38)
                        .background(Theme.sageDeep, in: .rect(cornerRadius: 9))
                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Text("MySkin").font(.rounded(.subheadline, weight: .semibold))
                            Spacer()
                            Text("now").font(.rounded(.caption)).foregroundStyle(Theme.inkSoft)
                        }
                        Text("Time for your evening routine.")
                            .font(.rounded(.subheadline))
                    }
                    .foregroundStyle(Theme.ink)
                }
                .glassCard(padding: 14)

                VStack(spacing: 14) {
                    Toggle(isOn: $settings.doseReminders) {
                        toggleLabel("Treatment reminders", "Creams, tablets and injections")
                    }
                    Divider()
                    Toggle(isOn: $settings.checkInReminder) {
                        toggleLabel("Daily check-in", "A 10-second note about your skin")
                    }
                    if settings.checkInReminder {
                        DatePicker("Time", selection: $settings.checkInTime, displayedComponents: .hourAndMinute)
                            .font(.rounded(.subheadline))
                            .foregroundStyle(Theme.inkSoft)
                    }
                }
                .tint(Theme.accent)
                .glassCard()
                .animation(.smooth, value: settings.checkInReminder)
            }
        } footer: {
            PermissionButtons(allowTitle: "Turn on", onAllow: turnOn, onNotNow: notNow)
                .disabled(isAsking)
            Text("Reminders never mention your condition or medicines.")
                .font(.rounded(.footnote))
                .foregroundStyle(Theme.inkSoft)
        }
    }

    /// Asks iOS for permission. If it is refused, the toggles are switched off so they match reality.
    private func turnOn() {
        guard wantsReminders else {
            next()
            return
        }
        isAsking = true
        Task {
            let granted = await NotificationPermission.request()
            if !granted {
                settings.doseReminders = false
                settings.checkInReminder = false
            }
            isAsking = false
            next()
        }
    }

    private func notNow() {
        settings.doseReminders = false
        settings.checkInReminder = false
        next()
    }

    private func toggleLabel(_ title: String, _ detail: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.rounded(.body, weight: .medium)).foregroundStyle(Theme.ink)
            Text(detail).font(.rounded(.footnote)).foregroundStyle(Theme.inkSoft)
        }
    }
}

// MARK: - Privacy

struct PrivacyStep: View {
    @Environment(AppSettings.self) private var settings
    let next: () -> Void

    var body: some View {
        @Bindable var settings = settings
        OnboardingPage(
            title: "Your skin, your privacy",
            why: "Skin photos are personal. We keep them away from your camera roll."
        ) {
            VStack(spacing: 16) {
                Toggle(isOn: $settings.faceIDEnabled) {
                    HStack(spacing: 12) {
                        Image(systemName: "faceid")
                            .font(.title2)
                            .foregroundStyle(Theme.accent)
                        Text("Protect MySkin with Face ID")
                            .font(.rounded(.body, weight: .semibold))
                            .foregroundStyle(Theme.ink)
                    }
                }
                .tint(Theme.accent)
                .glassCard()

                VStack(alignment: .leading, spacing: 14) {
                    privacyRow("photo.badge.checkmark", "Photos never go to your shared photo library")
                    privacyRow("iphone", "Everything is stored on this device")
                    privacyRow("person.crop.circle.badge.xmark", "No account needed")
                    privacyRow("square.and.arrow.up", "Nothing leaves your phone unless you share it")
                }
                .glassCard()
            }
        } footer: {
            PrimaryButton(title: "Continue", action: next)
        }
    }

    private func privacyRow(_ symbol: String, _ text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .foregroundStyle(Theme.sageDeep)
                .frame(width: 28)
            Text(text)
                .font(.rounded(.subheadline))
                .foregroundStyle(Theme.ink)
        }
    }
}

// MARK: - Plan ready

struct PlanReadyStep: View {
    @Environment(OnboardingDraft.self) private var draft
    @Environment(AppSettings.self) private var settings
    let next: () -> Void

    private var forms: String {
        draft.orderedTypes.isEmpty ? "Not specified — you can add it later" : draft.orderedTypes.map(\.title).formatted(.list(type: .and))
    }

    private var focus: String {
        let goals = draft.goals.isEmpty ? [.journal] : Goal.allCases.filter { draft.goals.contains($0) }
        return goals.map(\.title).joined(separator: ", ")
    }

    private var startingPoint: String {
        let snapshot = draft.snapshot
        guard !draft.zoneLevels.isEmpty else { return "No areas marked yet — use the Body tab anytime" }
        return "≈ \(snapshot.bsa.formatted(.number.precision(.fractionLength(0...1))))% body area · \(snapshot.category.title.lowercased())"
    }

    var body: some View {
        OnboardingPage(title: "Your plan is ready") {
            VStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 14) {
                    planRow("circle.hexagongrid", "Your psoriasis", forms)
                    planRow("waveform.path.ecg", "We'll track", "Itch daily · body map when it changes")
                    planRow("target", "Your focus", focus)
                    planRow("bell", "First reminder", settings.checkInReminder
                            ? "Tomorrow at \(settings.checkInTime.formatted(date: .omitted, time: .shortened)) · daily check-in"
                            : "None — you can add one anytime")
                    planRow("flag.checkered", "Starting point", startingPoint)
                }
                .glassCard()

                HStack(spacing: 14) {
                    Image(systemName: "camera.viewfinder")
                        .font(.title2)
                        .foregroundStyle(Theme.accent)
                        .frame(width: 52, height: 52)
                        .background(Theme.accentSoft, in: .circle)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Take your first photo")
                            .font(.rounded(.headline, weight: .semibold))
                            .foregroundStyle(Theme.ink)
                        Text("Compare in a month — the difference will show.")
                            .font(.rounded(.subheadline))
                            .foregroundStyle(Theme.inkSoft)
                    }
                }
                .glassCard(tint: Theme.accentSoft)
            }
        } footer: {
            PrimaryButton(title: "Start", action: next)
        }
    }

    private func planRow(_ symbol: String, _ title: String, _ value: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol)
                .foregroundStyle(Theme.sageDeep)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.rounded(.caption, weight: .semibold))
                    .foregroundStyle(Theme.inkSoft)
                Text(value)
                    .font(.rounded(.body, weight: .medium))
                    .foregroundStyle(Theme.ink)
            }
        }
    }
}
