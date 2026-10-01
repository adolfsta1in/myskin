import SwiftUI

// MARK: - O7 First body map

struct FirstBodyMapStep: View {
    @Environment(AppStore.self) private var store
    @State private var side: BodySide = .front
    let next: () -> Void

    var body: some View {
        OnboardingPage(
            title: "Where is your skin affected?",
            subtitle: "Tap areas on the body. Tap again to change intensity.",
            why: "Doctors estimate how much skin is involved — this helps you both see change over time."
        ) {
            VStack(spacing: 14) {
                Picker("Side", selection: $side) {
                    ForEach(BodySide.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()

                BodySilhouette(side: side, intensities: store.zoneIntensity) { zone in
                    store.cycleIntensity(for: zone.id)
                }
                .frame(height: 300)

                FlowLayout(spacing: 8) {
                    ForEach(BodyZone.quickZones) { zone in
                        TagChip(title: zone.name, isSelected: (store.zoneIntensity[zone.id] ?? 0) > 0) {
                            store.cycleIntensity(for: zone.id)
                        }
                    }
                }
            }
            .glassCard(padding: 16)
        } footer: {
            HStack(spacing: 12) {
                Image(systemName: "flag.checkered")
                    .foregroundStyle(Theme.sageDeep)
                VStack(alignment: .leading, spacing: 0) {
                    Text("≈ \(store.affectedArea, format: .number.precision(.fractionLength(0)))% of body area")
                        .font(.rounded(.headline, weight: .bold))
                        .foregroundStyle(Theme.ink)
                        .contentTransition(.numericText())
                    Text("This is your starting point")
                        .font(.rounded(.subheadline))
                        .foregroundStyle(Theme.inkSoft)
                }
                Spacer()
            }
            .glassCard(padding: 14, tint: Theme.sageSoft)
            .animation(.smooth, value: store.affectedArea)
            PrimaryButton(title: "Continue", action: next)
        }
    }
}

// MARK: - O8 Treatments

struct TreatmentsStep: View {
    @Environment(AppStore.self) private var store
    @State private var query = ""
    let next: () -> Void

    private let quick: [(String, String)] = [
        ("Cream", "hand.point.up.left"),
        ("Ointment", "drop"),
        ("Tablets", "pills"),
        ("Injections", "syringe"),
        ("Phototherapy", "sun.max"),
        ("Nothing right now", "minus.circle"),
    ]

    private let catalog = [
        "Tacrolimus", "Pimecrolimus", "Hydrocortisone", "Clobetasol", "Betamethasone", "Calcipotriol",
        "Methotrexate", "Ciclosporin", "Dupilumab", "Adalimumab", "Secukinumab", "Ustekinumab", "Apremilast",
    ]

    private var results: [String] {
        guard !query.isEmpty else { return [] }
        return catalog.filter { $0.localizedCaseInsensitiveContains(query) && !store.currentTreatments.contains($0) }
    }

    var body: some View {
        OnboardingPage(
            title: "What are you using right now?",
            why: "Knowing when a treatment started lets us show whether it's making a difference."
        ) {
            VStack(alignment: .leading, spacing: 18) {
                GlassEffectContainer(spacing: 10) {
                    FlowLayout(spacing: 10) {
                        ForEach(quick.indices, id: \.self) { index in
                            let (title, symbol) = quick[index]
                            TagChip(title: title, systemImage: symbol, isSelected: store.currentTreatments.contains(title)) {
                                toggle(title)
                            }
                        }
                    }
                }

                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(Theme.inkSoft)
                    TextField("Search, e.g. tacrolimus", text: $query)
                        .textFieldStyle(.plain)
                        .font(.rounded(.body))
                }
                .padding(14)
                .glassEffect(.regular, in: .capsule)

                if !results.isEmpty {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(results.prefix(4), id: \.self) { name in
                            Button {
                                toggle(name)
                                query = ""
                            } label: {
                                HStack {
                                    Text(name).foregroundStyle(Theme.ink)
                                    Spacer()
                                    Image(systemName: "plus.circle").foregroundStyle(Theme.accent)
                                }
                                .font(.rounded(.body))
                                .padding(.vertical, 10)
                                .contentShape(.rect)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .glassCard(padding: 14)
                }

                let named = store.currentTreatments.filter { catalog.contains($0) }.sorted()
                if !named.isEmpty {
                    FlowLayout(spacing: 8) {
                        ForEach(named, id: \.self) { name in
                            TagChip(title: name, systemImage: "xmark", isSelected: true) { toggle(name) }
                        }
                    }
                }
            }
        } footer: {
            PrimaryButton(title: "Continue", action: next)
        }
    }

    private func toggle(_ item: String) {
        withAnimation(.snappy) {
            if store.currentTreatments.contains(item) {
                store.currentTreatments.remove(item)
            } else {
                store.currentTreatments.insert(item)
            }
        }
    }
}

// MARK: - O8 Notifications (soft ask)

struct NotificationsStep: View {
    @Environment(AppStore.self) private var store
    @Environment(AppSettings.self) private var settings
    let next: () -> Void

    var body: some View {
        @Bindable var settings = settings
        @Bindable var store = store
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
                        Text("Time for your evening ointment on the elbows.")
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
                    Divider()
                    Toggle(isOn: $store.notifyForecast) {
                        toggleLabel("Flare forecast", "Heads-up when dry air or pollen is coming")
                    }
                }
                .tint(Theme.accent)
                .glassCard()
                .animation(.smooth, value: settings.checkInReminder)
            }
        } footer: {
            PermissionButtons(allowTitle: "Turn on", onAllow: next, onNotNow: next)
        }
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
