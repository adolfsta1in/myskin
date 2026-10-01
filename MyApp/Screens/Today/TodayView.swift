import SwiftData
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
/// Loads today's `DailyCheckIn` if there is one; saving updates it in place.
private struct CheckInCard: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var todayCheckIns: [DailyCheckIn]
    @Query(sort: \DailyCheckIn.day, order: .reverse) private var allCheckIns: [DailyCheckIn]
    let mode: AppMode
    private let day: Date

    @State private var draft = CheckInDraft()
    @State private var showsDetails = false
    @State private var isAddingTag = false
    @State private var newTag = ""
    @State private var isSaved = false
    @State private var saveCount = 0
    @State private var saveError: String?

    init(mode: AppMode, day: Date = .now) {
        self.mode = mode
        let start = Calendar.current.startOfDay(for: day)
        self.day = start
        _todayCheckIns = Query(filter: #Predicate<DailyCheckIn> { $0.day == start })
    }

    private var existing: DailyCheckIn? { todayCheckIns.first }

    /// Earlier custom tags plus the ones picked today.
    private var customTags: [String] {
        let known = CheckInDraft.knownTags(from: allCheckIns)
        return known + draft.customTags.filter { !known.contains($0) }
    }

    private var itchDescription: String {
        switch draft.itch {
        case ..<1: "Barely there"
        case ..<4: "Noticeable"
        case ..<7: "Hard to ignore"
        default: "Very intense"
        }
    }

    var body: some View {
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
                    Text("\(draft.itch)")
                        .font(.rounded(.title2, weight: .bold))
                        .foregroundStyle(Theme.ink)
                        .contentTransition(.numericText())
                    Text("· \(itchDescription)")
                        .font(.rounded(.subheadline))
                        .foregroundStyle(Theme.inkSoft)
                }
                Slider(value: Binding(get: { Double(draft.itch) }, set: { draft.itch = Int($0) }), in: 0...10, step: 1) {
                    Text("Itch")
                } minimumValueLabel: {
                    Text("0").font(.rounded(.caption)).foregroundStyle(Theme.inkSoft)
                } maximumValueLabel: {
                    Text("10").font(.rounded(.caption)).foregroundStyle(Theme.inkSoft)
                }
                .tint(Theme.accent)
                .sensoryFeedback(.selection, trigger: draft.itch)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Anything that might matter?")
                    .font(.rounded(.subheadline, weight: .medium))
                    .foregroundStyle(Theme.ink)
                GlassEffectContainer(spacing: 8) {
                    FlowLayout(spacing: 8) {
                        TagChip(title: "New or spreading spots", systemImage: "circle.dotted.circle", isSelected: draft.newSpots) {
                            draft.newSpots.toggle()
                        }
                        ForEach(Trigger.allCases) { trigger in
                            TagChip(title: trigger.title, systemImage: trigger.systemImage, isSelected: draft.triggers.contains(trigger)) {
                                draft.toggle(trigger)
                            }
                        }
                        ForEach(customTags, id: \.self) { tag in
                            TagChip(title: tag, systemImage: "tag", isSelected: draft.customTags.contains(tag)) {
                                draft.toggleCustomTag(tag)
                            }
                        }
                        TagChip(title: "Add", systemImage: "plus") { isAddingTag = true }
                    }
                }
            }

            if mode == .flare || showsDetails {
                details
                    .transition(.opacity.combined(with: .move(edge: .top)))
            } else {
                Button("Add pain, sleep, mood or a note", systemImage: "plus.circle") {
                    withAnimation(.smooth) { showsDetails = true }
                }
                .font(.rounded(.subheadline, weight: .medium))
                .foregroundStyle(Theme.accent)
            }

            Button(action: save) {
                Text(existing == nil ? "Save check-in" : "Update check-in")
                    .font(.rounded(.headline, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
            }
            .buttonStyle(.glassProminent)
            .tint(Theme.accent)
            .sensoryFeedback(.success, trigger: saveCount)
        }
        .glassCard()
        // Reload when today's record appears (first save, or data changed elsewhere).
        .task(id: existing?.persistentModelID) {
            if let existing {
                draft = CheckInDraft(existing)
                showsDetails = existing.pain != nil || existing.sleep != nil || existing.mood != nil || !existing.note.isEmpty
            }
        }
        .alert("Add a tag", isPresented: $isAddingTag) {
            TextField("e.g. Hot shower", text: $newTag)
                .submitLabel(.done)
            Button("Add") {
                draft.addCustomTag(newTag, known: customTags)
                newTag = ""
            }
            Button("Cancel", role: .cancel) { newTag = "" }
        }
        .alert("Couldn't save", isPresented: Binding(get: { saveError != nil }, set: { if !$0 { saveError = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(saveError ?? "")
        }
    }

    private var details: some View {
        VStack(alignment: .leading, spacing: 14) {
            Divider()
            OptionalScaleRow(title: "Burning or pain", value: $draft.pain, range: 0...10, lowLabel: "None", highLabel: "Worst")
            OptionalScaleRow(title: "Sleep last night", value: $draft.sleep, range: 0...10, lowLabel: "Poor", highLabel: "Great")

            VStack(alignment: .leading, spacing: 6) {
                Text("Mood")
                    .font(.rounded(.subheadline, weight: .medium))
                    .foregroundStyle(Theme.ink)
                Picker("Mood", selection: $draft.mood) {
                    ForEach(1...5, id: \.self) { value in
                        Text(Self.moodTitle(value)).tag(Optional(value))
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }

            TextField("Anything else? (optional)", text: $draft.note, axis: .vertical)
                .font(.rounded(.body))
                .submitLabel(.done)
                .padding(12)
                .background(.white.opacity(0.45), in: .rect(cornerRadius: 16))
        }
    }

    private func save() {
        if let existing {
            draft.apply(to: existing)
        } else {
            modelContext.insert(draft.makeCheckIn(day: day))
        }
        do {
            try modelContext.save()
            saveCount += 1
            withAnimation(.bouncy) { isSaved = true }
        } catch {
            modelContext.rollback()
            saveError = error.localizedDescription
        }
    }

    private static func moodTitle(_ value: Int) -> String {
        switch value {
        case 1: "Low"
        case 2: "Meh"
        case 3: "Okay"
        case 4: "Good"
        default: "Great"
        }
    }
}

/// 0–10 slider that stays "Not set" until it is moved.
private struct OptionalScaleRow: View {
    let title: String
    @Binding var value: Int?
    let range: ClosedRange<Int>
    let lowLabel: String
    let highLabel: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(.rounded(.subheadline, weight: .medium))
                    .foregroundStyle(Theme.ink)
                Spacer()
                Text(value.map(String.init) ?? "Not set")
                    .font(.rounded(.subheadline, weight: value == nil ? .regular : .semibold))
                    .foregroundStyle(value == nil ? Theme.inkSoft : Theme.ink)
                    .contentTransition(.numericText())
            }
            Slider(
                value: Binding(get: { Double(value ?? range.lowerBound) }, set: { value = Int($0) }),
                in: Double(range.lowerBound)...Double(range.upperBound),
                step: 1
            ) {
                Text(title)
            } minimumValueLabel: {
                Text(lowLabel).font(.rounded(.caption)).foregroundStyle(Theme.inkSoft)
            } maximumValueLabel: {
                Text(highLabel).font(.rounded(.caption)).foregroundStyle(Theme.inkSoft)
            }
            .tint(Theme.accent)
        }
    }
}

// MARK: - Cards

/// Calm days this month: days with a check-in and no flare signal (`TodayStats.calmDaysThisMonth`).
private struct CalmDaysCard: View {
    @Query private var checkIns: [DailyCheckIn]
    @Query private var assessments: [ZoneAssessment]

    private var calmDays: Int {
        TodayStats.calmDaysThisMonth(on: .now, checkIns: checkIns.map(\.sample), zones: assessments.map(\.datedScore))
    }

    var body: some View {
        let count = calmDays
        HStack(spacing: 14) {
            Image(systemName: "leaf.fill")
                .font(.title2)
                .foregroundStyle(Theme.sageDeep)
                .frame(width: 48, height: 48)
                .background(Theme.sageSoft, in: .circle)
            VStack(alignment: .leading, spacing: 2) {
                Text(count == 0 ? "No calm days logged yet" : "\(count) calm \(count == 1 ? "day" : "days") this month")
                    .font(.rounded(.headline, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                    .contentTransition(.numericText())
                Text(count == 0 ? "Check in daily and calm days will add up here." : "Days you checked in without signs of a flare.")
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
    @Query private var checkIns: [DailyCheckIn]

    var body: some View {
        let samples = checkIns.map(\.sample)
        let history = TodayStats.itchHistory(endingOn: .now, checkIns: samples)
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                SectionHeader(title: "Itch · last \(TodayStats.Threshold.chartDays) days")
                if let trend = TodayStats.itchTrend(endingOn: .now, checkIns: samples) {
                    TrendBadge(trend: trend)
                }
            }
            if history.count >= TodayStats.Threshold.minChartPoints {
                ItchMiniChart(data: history)
            } else {
                Text("Your itch chart will appear after a few check-ins.")
                    .font(.rounded(.subheadline))
                    .foregroundStyle(Theme.inkSoft)
                    .frame(maxWidth: .infinity, minHeight: 80)
            }
        }
        .glassCard()
    }
}

private struct TrendBadge: View {
    let trend: ItchTrend

    private var title: String {
        switch trend {
        case .down: "Trending down"
        case .steady: "Steady"
        case .up: "Trending up"
        }
    }

    private var background: Color {
        switch trend {
        case .down: Theme.sageSoft
        case .steady: Theme.accentSoft
        case .up: Theme.sand
        }
    }

    private var foreground: Color {
        switch trend {
        case .down: Theme.sageDeep
        case .steady: Theme.accent
        case .up: Theme.ink
        }
    }

    var body: some View {
        Text(title)
            .font(.rounded(.caption, weight: .semibold))
            .foregroundStyle(foreground)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(background, in: .capsule)
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
