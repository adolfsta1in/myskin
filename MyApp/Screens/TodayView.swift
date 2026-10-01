import SwiftUI

struct TodayView: View {
    @State private var mode: AppMode
    @State private var isShowingCanvas = false

    init(mode: AppMode = .calm) {
        _mode = State(initialValue: mode)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    TodayHeader(onLongPress: { isShowingCanvas = true })
                    Picker("Mode", selection: $mode) {
                        Label("Calm", systemImage: "leaf").tag(AppMode.calm)
                        Label("Flare", systemImage: "flame").tag(AppMode.flare)
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .sensoryFeedback(.selection, trigger: mode)

                    CheckInCard(mode: mode)
                    if mode == .calm {
                        CalmDaysCard()
                            .transition(.opacity)
                    }
                    SkinForecastCard()
                    RemindersCard()
                    ItchChartCard()
                }
                .padding(.horizontal, Theme.screenPadding)
            }
            .screenScaffold()
            .toolbar(.hidden, for: .navigationBar)
            .animation(.smooth, value: mode)
            #if DEBUG
            .fullScreenCover(isPresented: $isShowingCanvas) {
                DesignCanvasView()
            }
            #endif
        }
    }
}

// MARK: - Header

private struct TodayHeader: View {
    var onLongPress: () -> Void

    private var greeting: String {
        switch Calendar.current.component(.hour, from: .now) {
        case 5..<12: "Good morning"
        case 12..<18: "Good afternoon"
        default: "Good evening"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(Date.now.formatted(.dateTime.weekday(.wide).month(.wide).day()))
                .font(.rounded(.subheadline, weight: .medium))
                .foregroundStyle(Theme.inkSoft)
            Text(greeting)
                .font(.rounded(.largeTitle, weight: .bold))
                .foregroundStyle(Theme.ink)
                // Hidden entry point to the design canvas (debug builds only).
                .onLongPressGesture(perform: onLongPress)
        }
        .padding(.top, 12)
    }
}

// MARK: - Check-in

/// Owns all check-in state so slider drags only invalidate this card.
private struct CheckInCard: View {
    @Environment(AppStore.self) private var store
    let mode: AppMode

    @State private var isAddingTag = false
    @State private var newTag = ""
    @State private var isSaved = false

    // Flare-mode extras
    @State private var flareZones: Set<String> = ["Elbows"]
    @State private var sleepQuality = 1
    @State private var burning: Double = 4
    @State private var note = ""

    private var itchDescription: String {
        switch store.todayItch {
        case ..<1: "Barely there"
        case ..<4: "Noticeable"
        case ..<7: "Hard to ignore"
        default: "Very intense"
        }
    }

    var body: some View {
        @Bindable var store = store
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                SectionHeader(
                    title: mode == .calm ? "Quick check-in" : "Flare check-in",
                    subtitle: mode == .calm ? "About 10 seconds" : "A little more detail helps spot patterns"
                )
                if isSaved {
                    Label("Saved", systemImage: "checkmark.circle.fill")
                        .font(.rounded(.subheadline, weight: .semibold))
                        .foregroundStyle(Theme.sageDeep)
                        .transition(.scale.combined(with: .opacity))
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Itch")
                        .font(.rounded(.subheadline, weight: .medium))
                        .foregroundStyle(Theme.ink)
                    Spacer()
                    Text("\(Int(store.todayItch))")
                        .font(.rounded(.title2, weight: .bold))
                        .foregroundStyle(Theme.ink)
                        .contentTransition(.numericText())
                    Text("· \(itchDescription)")
                        .font(.rounded(.subheadline))
                        .foregroundStyle(Theme.inkSoft)
                }
                Slider(value: $store.todayItch, in: 0...10, step: 1) {
                    Text("Itch")
                } minimumValueLabel: {
                    Text("0").font(.rounded(.caption)).foregroundStyle(Theme.inkSoft)
                } maximumValueLabel: {
                    Text("10").font(.rounded(.caption)).foregroundStyle(Theme.inkSoft)
                }
                .tint(Theme.accent)
                .sensoryFeedback(.selection, trigger: store.todayItch)
            }

            GlassEffectContainer(spacing: 8) {
                FlowLayout(spacing: 8) {
                    ForEach(store.tags, id: \.self) { tag in
                        TagChip(title: tag, systemImage: Self.symbol(for: tag), isSelected: store.selectedTags.contains(tag)) {
                            store.toggleTag(tag)
                        }
                    }
                    TagChip(title: "Add", systemImage: "plus") { isAddingTag = true }
                }
            }

            if mode == .flare {
                flareDetails
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }

            Button {
                withAnimation(.bouncy) { isSaved = true }
            } label: {
                Text(isSaved ? "Update check-in" : "Save check-in")
                    .font(.rounded(.headline, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
            }
            .buttonStyle(.glassProminent)
            .tint(Theme.accent)
            .sensoryFeedback(.success, trigger: isSaved)
        }
        .glassCard()
        .alert("Add a tag", isPresented: $isAddingTag) {
            TextField("e.g. Hot shower", text: $newTag)
                .submitLabel(.done)
            Button("Add") {
                let tag = newTag.trimmingCharacters(in: .whitespaces)
                if !tag.isEmpty, !store.tags.contains(tag) {
                    store.tags.append(tag)
                    store.selectedTags.insert(tag)
                }
                newTag = ""
            }
            Button("Cancel", role: .cancel) { newTag = "" }
        }
    }

    private var flareDetails: some View {
        VStack(alignment: .leading, spacing: 14) {
            Divider()
            Text("Where is it flaring?")
                .font(.rounded(.subheadline, weight: .medium))
                .foregroundStyle(Theme.ink)
            GlassEffectContainer(spacing: 8) {
                FlowLayout(spacing: 8) {
                    ForEach(["Elbows", "Knees", "Scalp", "Hands", "Back", "Face"], id: \.self) { zone in
                        TagChip(title: zone, isSelected: flareZones.contains(zone)) {
                            if flareZones.contains(zone) { flareZones.remove(zone) } else { flareZones.insert(zone) }
                        }
                    }
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Burning or pain · \(Int(burning))")
                    .font(.rounded(.subheadline, weight: .medium))
                    .foregroundStyle(Theme.ink)
                Slider(value: $burning, in: 0...10, step: 1)
                    .tint(Theme.accent)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Sleep last night")
                    .font(.rounded(.subheadline, weight: .medium))
                    .foregroundStyle(Theme.ink)
                Picker("Sleep last night", selection: $sleepQuality) {
                    Text("Good").tag(0)
                    Text("Okay").tag(1)
                    Text("Poor").tag(2)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }

            TextField("Anything else? (optional)", text: $note, axis: .vertical)
                .font(.rounded(.body))
                .submitLabel(.done)
                .padding(12)
                .background(.white.opacity(0.45), in: .rect(cornerRadius: 16))

            Label("Take a photo of the flare", systemImage: "camera")
                .font(.rounded(.subheadline, weight: .medium))
                .foregroundStyle(Theme.accent)
        }
    }

    private static func symbol(for tag: String) -> String? {
        switch tag {
        case "Stress": "brain.head.profile"
        case "Alcohol": "wineglass"
        case "Poor sleep": "moon.zzz"
        case "Sick": "thermometer.medium"
        case "New cosmetics": "sparkles"
        default: "tag"
        }
    }
}

// MARK: - Cards

private struct CalmDaysCard: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "leaf.fill")
                .font(.title2)
                .foregroundStyle(Theme.sageDeep)
                .frame(width: 48, height: 48)
                .background(Theme.sageSoft, in: .circle)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(store.calmDaysThisMonth) calm days this month")
                    .font(.rounded(.headline, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                Text("Your skin is settling. That's worth noticing.")
                    .font(.rounded(.subheadline))
                    .foregroundStyle(Theme.inkSoft)
            }
        }
        .glassCard(tint: Theme.sageSoft)
    }
}

private struct RemindersCard: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        @Bindable var store = store
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Treatment today", systemImage: "calendar")
            ForEach($store.reminders) { $reminder in
                HStack(spacing: 12) {
                    Image(systemName: reminder.systemImage)
                        .foregroundStyle(Theme.accent)
                        .frame(width: 36, height: 36)
                        .background(Theme.accentSoft.opacity(0.7), in: .circle)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(reminder.title)
                            .font(.rounded(.body, weight: .medium))
                            .foregroundStyle(Theme.ink)
                            .strikethrough(reminder.isDone, color: Theme.inkSoft)
                        Text(reminder.detail)
                            .font(.rounded(.footnote))
                            .foregroundStyle(Theme.inkSoft)
                    }
                    Spacer()
                    Button {
                        withAnimation(.bouncy) { reminder.isDone.toggle() }
                    } label: {
                        Image(systemName: reminder.isDone ? "checkmark.circle.fill" : "circle")
                            .font(.title2)
                            .foregroundStyle(reminder.isDone ? Theme.sageDeep : Theme.sandDeep)
                            .frame(width: 44, height: 44)
                            .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                    .sensoryFeedback(.success, trigger: reminder.isDone) { _, done in done }
                    .accessibilityLabel(reminder.isDone ? "Done" : "Mark as done")
                }
            }
        }
        .glassCard()
    }
}

private struct ItchChartCard: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                SectionHeader(title: "Itch · last 14 days")
                Text("Trending down")
                    .font(.rounded(.caption, weight: .semibold))
                    .foregroundStyle(Theme.sageDeep)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Theme.sageSoft, in: .capsule)
            }
            ItchMiniChart(data: store.itchHistory)
        }
        .glassCard()
    }
}

#Preview("Today · Calm") {
    TodayView()
        .previewSetup()
}

#Preview("Today · Flare") {
    TodayView(mode: .flare)
        .previewSetup()
}
