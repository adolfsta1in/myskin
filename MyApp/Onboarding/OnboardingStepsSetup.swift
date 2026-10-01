import SwiftUI
import Charts

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
    let next: () -> Void

    var body: some View {
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
                    Toggle(isOn: $store.notifyTreatment) {
                        toggleLabel("Treatment reminders", "Creams, tablets and injections")
                    }
                    Divider()
                    Toggle(isOn: $store.notifyCheckIn) {
                        toggleLabel("Daily check-in", "A 10-second note about your skin")
                    }
                    if store.notifyCheckIn {
                        DatePicker("Time", selection: $store.checkInTime, displayedComponents: .hourAndMinute)
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
                .animation(.smooth, value: store.notifyCheckIn)
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

// MARK: - O9 Location (soft ask)

struct LocationStep: View {
    @Environment(AppStore.self) private var store
    let next: () -> Void

    var body: some View {
        OnboardingPage(
            title: "Get a skin forecast",
            subtitle: "Dry air, heat and pollen often affect skin. We'll warn you a day ahead.",
            why: "We only use your city to check the weather — never your exact location."
        ) {
            SkinForecastCard()
        } footer: {
            PermissionButtons(onAllow: {
                store.locationAllowed = true
                next()
            }, onNotNow: next)
        }
    }
}

// MARK: - O10 Sleep (soft ask)

struct SleepStep: View {
    @Environment(AppStore.self) private var store
    let next: () -> Void

    var body: some View {
        OnboardingPage(
            title: "See how sleep and itch connect",
            subtitle: "Connect Apple Health and we'll add your sleep automatically — no extra logging.",
            why: "Poor sleep is one of the most common delayed triggers."
        ) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 16) {
                    Label("Sleep", systemImage: "moon.fill").foregroundStyle(Theme.accent)
                    Label("Itch", systemImage: "circle.fill").foregroundStyle(Theme.intensityModerate)
                }
                .font(.rounded(.caption, weight: .semibold))
                Chart {
                    ForEach(store.sleepHistory) { day in
                        LineMark(x: .value("Day", day.date), y: .value("Value", day.value), series: .value("Series", "Sleep"))
                            .foregroundStyle(Theme.accent)
                            .interpolationMethod(.catmullRom)
                            .lineStyle(StrokeStyle(lineWidth: 3))
                    }
                    ForEach(store.itchHistory.suffix(store.sleepHistory.count)) { day in
                        LineMark(x: .value("Day", day.date), y: .value("Value", day.value), series: .value("Series", "Itch"))
                            .foregroundStyle(Theme.intensityModerate)
                            .interpolationMethod(.catmullRom)
                            .lineStyle(StrokeStyle(lineWidth: 3, dash: [5, 4]))
                    }
                }
                .chartYAxis(.hidden)
                .chartXAxis(.hidden)
                .frame(height: 150)
                Text("Preview · after poor nights, itch often rises 1–2 days later.")
                    .font(.rounded(.footnote))
                    .foregroundStyle(Theme.inkSoft)
            }
            .glassCard()
        } footer: {
            PermissionButtons(allowTitle: "Connect Apple Health", onAllow: {
                store.healthAllowed = true
                next()
            }, onNotNow: next)
        }
    }
}

// MARK: - O11 Privacy

struct PrivacyStep: View {
    @Environment(AppStore.self) private var store
    let next: () -> Void

    var body: some View {
        @Bindable var store = store
        OnboardingPage(
            title: "Your skin, your privacy",
            why: "Skin photos are personal. We keep them away from your camera roll."
        ) {
            VStack(spacing: 16) {
                Toggle(isOn: $store.faceIDEnabled) {
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

// MARK: - O12 Plan ready

struct PlanReadyStep: View {
    @Environment(AppStore.self) private var store
    let next: () -> Void

    private var focus: String {
        let goals = store.goals.isEmpty ? [.journal] : Goal.allCases.filter { store.goals.contains($0) }
        return goals.map(\.title).joined(separator: ", ")
    }

    var body: some View {
        OnboardingPage(title: "Your plan is ready") {
            VStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 14) {
                    planRow("waveform.path.ecg", "We'll track", "Itch daily · weekly \(store.scoreName)")
                    planRow("target", "Your focus", focus)
                    planRow("bell", "First reminder", store.notifyCheckIn
                            ? "Tomorrow at \(store.checkInTime.formatted(date: .omitted, time: .shortened)) · daily check-in"
                            : "None — you can add one anytime")
                    planRow("flag.checkered", "Starting point", "≈ \(Int(store.affectedArea.rounded()))% body area")
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
            Button("Save a backup to iCloud") {}
                .font(.rounded(.footnote, weight: .medium))
                .foregroundStyle(Theme.inkSoft)
                .buttonStyle(.plain)
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
