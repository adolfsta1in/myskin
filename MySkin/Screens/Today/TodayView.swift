import SwiftData
import SwiftUI

struct TodayView: View {
    @Query private var checkIns: [DailyCheckIn]
    @Query private var assessments: [ZoneAssessment]
    @State private var isShowingCanvas = false
    @State private var isShowingSettings = false
    /// Questionnaire opened from a due card. The sheet lives here, so it stays open
    /// when the card disappears after the result is saved.
    @State private var takingQuestionnaire: QuestionnaireKind?
    /// Red flags on the full-screen warning; empty when it is closed.
    @State private var shownFlags: [RedFlag] = []
    /// Today's check-in as it is being edited, so the mode reacts before it is saved.
    @State private var draftSample: CheckInSample?

    /// Calm / Flare is computed from the data (`FlareDetector`), never chosen by hand.
    private var status: FlareStatus {
        let samples = FlareDetector.checkIns(checkIns.map(\.sample), replacingWith: draftSample)
        return FlareDetector.status(on: .now, checkIns: samples, zones: assessments.map(\.datedScore))
    }

    /// Latest assessment of each zone.
    private var currentZones: [ZoneScore] {
        Array(BodyMapSummary.make(zones: assessments.map(\.datedScore)).current.values)
    }

    var body: some View {
        let status = status
        // Flags from the body map alone stay visible until the map changes (they can't be hidden).
        let mapFlags = RedFlagRules.flags(zones: currentZones, symptoms: RedFlagSymptoms(), isFlare: status.mode == .flare)
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    TodayHeader(onLongPress: { isShowingCanvas = true }, onSettings: { isShowingSettings = true })
                    ModeBanner(status: status)
                    if !mapFlags.isEmpty {
                        RedFlagCard { shownFlags = mapFlags }
                    }

                    CheckInCard(mode: status.mode, onDraftChange: { draftSample = $0 }) { symptoms in
                        let flags = RedFlagRules.flags(zones: currentZones, symptoms: symptoms, isFlare: status.mode == .flare)
                        if !flags.isEmpty { shownFlags = flags }
                    }
                    FoodLogCard()
                    if status.mode == .calm {
                        CalmDaysCard()
                            .transition(.opacity)
                    }
                    WeatherCard()
                    RemindersCard()
                    QuestionnaireDueCards { takingQuestionnaire = $0 }
                    NavigationLink {
                        DiaryCalendarView()
                    } label: {
                        ItchChartCard()
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("Opens the diary calendar")
                }
                .padding(.horizontal, Theme.screenPadding)
            }
            .screenScaffold()
            .toolbar(.hidden, for: .navigationBar)
            .animation(.smooth, value: status.mode)
            .sheet(isPresented: $isShowingSettings) {
                SettingsView()
            }
            .sheet(item: $takingQuestionnaire) { kind in
                QuestionnaireView(kind: kind)
            }
            .fullScreenCover(isPresented: Binding(get: { !shownFlags.isEmpty }, set: { if !$0 { shownFlags = [] } })) {
                RedFlagView(flags: shownFlags)
            }
            #if DEBUG
            .fullScreenCover(isPresented: $isShowingCanvas) {
                DesignCanvasView()
            }
            #endif
        }
    }
}

// MARK: - Mode

/// Shows the automatic mode; in Flare it explains which rule fired.
private struct ModeBanner: View {
    let status: FlareStatus
    @State private var showsReasons = false

    var body: some View {
        switch status.mode {
        case .calm:
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Image(systemName: "leaf")
                    .foregroundStyle(Theme.sageDeep)
                Text("Calm mode")
                    .font(.rounded(.subheadline, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                Text("· changes automatically from your check-ins")
                    .font(.rounded(.subheadline))
                    .foregroundStyle(Theme.inkSoft)
            }
            .accessibilityElement(children: .combine)
        case .flare:
            VStack(alignment: .leading, spacing: 10) {
                Button {
                    withAnimation(.smooth) { showsReasons.toggle() }
                } label: {
                    HStack {
                        Label("Flare mode · why?", systemImage: "flame")
                            .font(.rounded(.headline, weight: .semibold))
                            .foregroundStyle(Theme.ink)
                        Spacer()
                        Image(systemName: "chevron.down")
                            .rotationEffect(.degrees(showsReasons ? 180 : 0))
                            .foregroundStyle(Theme.inkSoft)
                    }
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .accessibilityHint(showsReasons ? "Hides the reasons" : "Shows why Flare mode is on")

                if showsReasons {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(entriesHeading)
                            .font(.rounded(.footnote, weight: .medium))
                            .foregroundStyle(Theme.inkSoft)
                        ForEach(status.reasons, id: \.self) { reason in
                            Label(reason.explanation, systemImage: "circle.fill")
                                .labelStyle(BulletLabelStyle())
                        }
                        Text("Flare mode is a label based on your entries, not a diagnosis. It ends after \(FlareDetector.Threshold.calmDays) days in a row without these signs. Discuss any changes in your skin with your doctor.")
                            .font(.rounded(.footnote))
                            .foregroundStyle(Theme.inkSoft)
                            .padding(.top, 4)
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .glassCard(tint: Theme.intensityMild.opacity(0.35))
        }
    }
}

extension ModeBanner {
    private var entriesHeading: String {
        guard let day = status.signalDay, !Calendar.current.isDateInToday(day) else { return "Based on your entries today:" }
        return "Based on your entries on \(day.formatted(.dateTime.weekday(.wide).month().day())):"
    }
}

private struct BulletLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            configuration.icon
                .font(.system(size: 5))
                .foregroundStyle(Theme.inkSoft)
            configuration.title
                .font(.rounded(.subheadline))
                .foregroundStyle(Theme.ink)
        }
    }
}

/// Stays on Today while the body map itself shows a red flag.
private struct RedFlagCard: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.title2)
                    .foregroundStyle(Theme.intensitySevere)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Seek medical care now")
                        .font(.rounded(.headline, weight: .semibold))
                        .foregroundStyle(Theme.ink)
                    Text("What you marked on the body map can need urgent care. Tap for safety information.")
                        .font(.rounded(.subheadline))
                        .foregroundStyle(Theme.inkSoft)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 0)
            }
            .glassCard(tint: Theme.intensityModerate)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Header

private struct TodayHeader: View {
    @Query(sort: \Profile.createdAt) private var profiles: [Profile]
    var onLongPress: () -> Void
    var onSettings: () -> Void

    private var greeting: String {
        ProfileInfo.greeting(hour: Calendar.current.component(.hour, from: .now), name: profiles.first?.name ?? "")
    }

    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text(Date.now.formatted(.dateTime.weekday(.wide).month(.wide).day()))
                    .font(.rounded(.subheadline, weight: .medium))
                    .foregroundStyle(Theme.inkSoft)
                Text(greeting)
                    .font(.rounded(.largeTitle, weight: .bold))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
                    #if DEBUG
                    // Hidden entry point to the design canvas (debug builds only).
                    .onLongPressGesture(perform: onLongPress)
                    #endif
            }
            Spacer()
            Button(action: onSettings) {
                Image(systemName: "gearshape")
                    .font(.title3)
                    .foregroundStyle(Theme.ink)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.glass)
            .buttonBorderShape(.circle)
            .accessibilityLabel("Settings")
        }
        .padding(.top, 12)
    }
}

// MARK: - Check-in

/// Owns all check-in state so slider drags only invalidate this card.
/// Loads today's `DailyCheckIn` if there is one; saving updates it in place.
private struct CheckInCard: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(WeatherModel.self) private var weather: WeatherModel?
    @Query private var todayCheckIns: [DailyCheckIn]
    @Query(sort: \DailyCheckIn.day, order: .reverse) private var allCheckIns: [DailyCheckIn]
    let mode: AppMode
    /// Reports itch and «new spots» while they are edited, before saving.
    let onDraftChange: (CheckInSample) -> Void
    /// Called after a successful save with the flare safety answers.
    let onSaved: (RedFlagSymptoms) -> Void
    private let day: Date

    @State private var draft = CheckInDraft()
    @State private var showsDetails = false
    /// A saved check-in folds down to the itch row; the chevron opens it again.
    @State private var isExpanded = true
    @State private var isPickingTriggers = false
    @State private var saveCount = 0
    @State private var saveError: String?

    init(
        mode: AppMode,
        day: Date = .now,
        onDraftChange: @escaping (CheckInSample) -> Void = { _ in },
        onSaved: @escaping (RedFlagSymptoms) -> Void = { _ in }
    ) {
        self.mode = mode
        self.onDraftChange = onDraftChange
        self.onSaved = onSaved
        let start = Calendar.current.startOfDay(for: day)
        self.day = start
        _todayCheckIns = Query(filter: #Predicate<DailyCheckIn> { $0.day == start })
    }

    private var existing: DailyCheckIn? { todayCheckIns.first }

    /// Saved and not edited since.
    private var isSaved: Bool {
        guard let existing else { return false }
        return !draft.differs(from: existing)
    }

    /// Flare tints the card rose-red so the mode is obvious at a glance.
    private var tint: Color { mode == .flare ? Theme.flare : Theme.accent }

    /// Earlier custom tags plus the ones picked today.
    private var customTags: [String] {
        let known = CheckInDraft.knownTags(from: allCheckIns)
        return known + draft.customTags.filter { !known.contains($0) }
    }

    /// Chips on the card: last time's and frequent ones; the rest is behind "More".
    private var quickPicks: [LogPick] {
        QuickPicks.suggest(
            history: CheckInDraft.pickHistory(from: allCheckIns, before: day),
            defaults: Trigger.allCases.map(LogPick.trigger),
            selected: draft.picks
        )
    }

    private var itchDescription: String {
        switch draft.itch {
        case ..<1: "Barely there"
        case ..<4: "Noticeable"
        case ..<7: "Hard to ignore"
        default: "Very intense"
        }
    }

    /// One line under the itch row while the card is folded.
    private var foldedSummary: String {
        var parts = [draft.picks.isEmpty ? "No triggers" : draft.picks.map(\.title).formatted(.list(type: .and))]
        if draft.newSpots { parts.insert("New spots", at: 0) }
        if let sleep = draft.sleep { parts.append("Sleep \(sleep)") }
        if let pain = draft.pain { parts.append("Pain \(pain)") }
        return parts.joined(separator: " · ")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header

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
                .tint(tint)
                .sensoryFeedback(.selection, trigger: draft.itch)
            }

            if isExpanded {
                expandedContent
                    .transition(.opacity)
            } else {
                Text(foldedSummary)
                    .font(.rounded(.footnote))
                    .foregroundStyle(Theme.inkSoft)
                    .lineLimit(2)
                    .transition(.opacity)
            }

            if isExpanded || !isSaved {
                Button(action: save) {
                    Text(existing == nil ? "Save check-in" : "Update check-in")
                        .font(.rounded(.headline, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4)
                }
                .buttonStyle(.glassProminent)
                .tint(tint)
                .sensoryFeedback(.success, trigger: saveCount)
                .transition(.opacity)
            }
        }
        .glassCard(tint: mode == .flare ? Theme.flare : nil)
        .animation(.smooth, value: isExpanded)
        .animation(.smooth, value: isSaved)
        // Reload when today's record appears (first save, or data changed elsewhere).
        .task(id: existing?.persistentModelID) {
            if let existing {
                // Safety answers aren't stored; keep what was ticked in this session.
                let symptoms = draft.symptoms
                draft = CheckInDraft(existing)
                draft.symptoms = symptoms
                showsDetails = existing.pain != nil || existing.sleep != nil || existing.mood != nil || !existing.note.isEmpty
                isExpanded = false
            }
        }
        // Not reported until the draft changes, so a stored check-in isn't hidden by the empty draft at launch.
        .onChange(of: draft.sample(day: day)) { _, sample in
            onDraftChange(sample)
        }
        .sheet(isPresented: $isPickingTriggers) {
            LogPickerSheet(
                title: "Triggers",
                sections: [
                    .init(title: "Common triggers", picks: Trigger.allCases.map(LogPick.trigger)),
                    .init(title: "Your tags", picks: customTags.map(LogPick.custom)),
                ],
                addTitle: "Add your own",
                addPlaceholder: "e.g. Hot shower",
                known: customTags,
                draft: $draft,
                systemImage: Self.systemImage
            )
        }
        .alert("Couldn't save", isPresented: Binding(get: { saveError != nil }, set: { if !$0 { saveError = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(saveError ?? "")
        }
    }

    private var header: some View {
        HStack {
            SectionHeader(
                title: mode == .calm ? "Quick check-in" : "Flare check-in",
                // Folded and saved: the "Saved" label says enough.
                subtitle: isSaved && !isExpanded ? nil : (mode == .calm ? "About 10 seconds" : "A little more detail helps spot patterns")
            )
            Spacer()
            if isSaved {
                Label("Saved", systemImage: "checkmark.circle.fill")
                    .font(.rounded(.subheadline, weight: .semibold))
                    .foregroundStyle(Theme.sageDeep)
                    .transition(.scale.combined(with: .opacity))
            }
            if existing != nil {
                Button {
                    isExpanded.toggle()
                } label: {
                    Image(systemName: "chevron.down")
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                        .font(.rounded(.subheadline, weight: .semibold))
                        .foregroundStyle(Theme.inkSoft)
                        .frame(width: 32, height: 32)
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(isExpanded ? "Fold check-in" : "Show check-in details")
            }
        }
    }

    private var expandedContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Anything that might matter?")
                    .font(.rounded(.subheadline, weight: .medium))
                    .foregroundStyle(Theme.ink)
                GlassEffectContainer(spacing: 8) {
                    FlowLayout(spacing: 8) {
                        TagChip(title: "New or spreading spots", systemImage: "circle.dotted.circle", isSelected: draft.newSpots) {
                            draft.newSpots.toggle()
                        }
                        ForEach(quickPicks, id: \.self) { pick in
                            TagChip(title: pick.title, systemImage: Self.systemImage(pick), isSelected: draft.isSelected(pick)) {
                                draft.toggle(pick)
                            }
                        }
                        TagChip(title: "More", systemImage: "plus") { isPickingTriggers = true }
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
        }
    }

    private static func systemImage(_ pick: LogPick) -> String {
        switch pick {
        case .trigger(let trigger): trigger.systemImage
        case .food(let food): food.systemImage
        case .custom: "tag"
        }
    }

    private var details: some View {
        VStack(alignment: .leading, spacing: 14) {
            Divider()
            if mode == .flare {
                safetyQuestions
                Divider()
            }
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

    /// Red-flag questions (spec §2.8), asked in Flare mode.
    private var safetyQuestions: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Any of these today?")
                .font(.rounded(.subheadline, weight: .medium))
                .foregroundStyle(Theme.ink)
            GlassEffectContainer(spacing: 8) {
                FlowLayout(spacing: 8) {
                    TagChip(title: "Fever", systemImage: "thermometer.medium", isSelected: draft.symptoms.fever) {
                        draft.symptoms.fever.toggle()
                    }
                    TagChip(title: "Feeling weak or unwell", systemImage: "bed.double", isSelected: draft.symptoms.feelsUnwell) {
                        draft.symptoms.feelsUnwell.toggle()
                    }
                    TagChip(title: "Chills", systemImage: "thermometer.snowflake", isSelected: draft.symptoms.chills) {
                        draft.symptoms.chills.toggle()
                    }
                    TagChip(title: "Pus-filled bumps on a large area", systemImage: "circle.grid.3x3", isSelected: draft.symptoms.widespreadPustules) {
                        draft.symptoms.widespreadPustules.toggle()
                    }
                    TagChip(title: "Redness over most of my body", systemImage: "figure.stand", isSelected: draft.symptoms.widespreadRedness) {
                        draft.symptoms.widespreadRedness.toggle()
                    }
                    TagChip(title: "Recently stopped steroid tablets or injections", systemImage: "pills", isSelected: draft.symptoms.stoppedSystemicSteroids) {
                        draft.symptoms.stoppedSystemicSteroids.toggle()
                    }
                }
            }
            WhyWeAskText(text: "some combinations need urgent medical care, and we'll tell you if so.")
        }
    }

    private func save() {
        draft.weather = weather?.reading
        if let existing {
            draft.apply(to: existing)
        } else {
            modelContext.insert(draft.makeCheckIn(day: day))
        }
        do {
            try modelContext.save()
            saveCount += 1
            isExpanded = false
            onSaved(mode == .flare ? draft.symptoms : RedFlagSymptoms())
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

// MARK: - Food

/// Separate food log for today. It is stored on today's check-in and saved on every tap,
/// so it needs a saved check-in first (itch is required for a check-in).
private struct FoodLogCard: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var todayCheckIns: [DailyCheckIn]
    @Query(sort: \DailyCheckIn.day, order: .reverse) private var allCheckIns: [DailyCheckIn]
    private let day: Date

    @State private var draft = FoodDraft()
    @State private var isPickingFoods = false
    @State private var saveError: String?

    init(day: Date = .now) {
        let start = Calendar.current.startOfDay(for: day)
        self.day = start
        _todayCheckIns = Query(filter: #Predicate<DailyCheckIn> { $0.day == start })
    }

    private var existing: DailyCheckIn? { todayCheckIns.first }

    /// Earlier custom foods plus the ones picked today.
    private var customFoods: [String] {
        let known = FoodDraft.knownFoods(from: allCheckIns)
        return known + draft.customFoods.filter { !known.contains($0) }
    }

    private var quickPicks: [LogPick] {
        QuickPicks.suggest(
            history: FoodDraft.pickHistory(from: allCheckIns, before: day),
            defaults: Food.allCases.map(LogPick.food),
            selected: draft.picks
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(
                title: "Food today",
                subtitle: existing == nil ? "Save today's check-in first, then log what you ate" : "Tap what you ate — saved right away"
            )
            if existing != nil {
                GlassEffectContainer(spacing: 8) {
                    FlowLayout(spacing: 8) {
                        ForEach(quickPicks, id: \.self) { pick in
                            TagChip(title: pick.title, systemImage: Self.systemImage(pick), isSelected: draft.isSelected(pick)) {
                                draft.toggle(pick)
                            }
                        }
                        TagChip(title: "None of these", systemImage: "xmark.circle", isSelected: draft.isNone) {
                            draft.markNone()
                        }
                        TagChip(title: "More", systemImage: "plus") { isPickingFoods = true }
                    }
                }
            }
        }
        .glassCard()
        .task(id: existing?.persistentModelID) {
            if let existing { draft = FoodDraft(existing) }
        }
        // Every change (here or in the full list) is saved at once.
        .onChange(of: draft) { _, draft in
            guard let existing, FoodDraft(existing) != draft else { return }
            draft.apply(to: existing)
            do {
                try modelContext.save()
            } catch {
                modelContext.rollback()
                saveError = error.localizedDescription
            }
        }
        .sheet(isPresented: $isPickingFoods) {
            LogPickerSheet(
                title: "Food today",
                sections: [
                    .init(title: "Common foods", picks: Food.allCases.map(LogPick.food)),
                    .init(title: "Your foods", picks: customFoods.map(LogPick.custom)),
                ],
                addTitle: "Add a food",
                addPlaceholder: "e.g. Eggs",
                known: customFoods,
                draft: $draft,
                systemImage: Self.systemImage
            )
        }
        .alert("Couldn't save", isPresented: Binding(get: { saveError != nil }, set: { if !$0 { saveError = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(saveError ?? "")
        }
    }

    private static func systemImage(_ pick: LogPick) -> String {
        switch pick {
        case .food(let food): food.systemImage
        case .trigger(let trigger): trigger.systemImage
        case .custom: "fork.knife.circle"
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

/// Humidity and UV where the user is (Apple WeatherKit). Asks for location only when tapped.
/// Sky-blue card: UV first (it matters most for psoriasis), then humidity and temperature.
private struct WeatherCard: View {
    @Environment(WeatherModel.self) private var weather: WeatherModel?
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        if let weather {
            VStack(alignment: .leading, spacing: 14) {
                content(weather)
            }
            .glassCard(tint: Theme.accentSoft)
            .task(id: scenePhase) {
                if scenePhase == .active { await weather.refresh() }
            }
        }
    }

    @ViewBuilder
    private func content(_ weather: WeatherModel) -> some View {
        switch weather.state {
        case .needsPermission:
            prompt(
                systemImage: "cloud.sun.fill",
                title: "Weather for your skin",
                text: "See humidity and UV where you are. Dry air and strong sun can affect psoriasis."
            )
            Button {
                Task { await weather.refresh(askPermission: true) }
            } label: {
                Label("Show weather", systemImage: "location.fill")
                    .font(.rounded(.subheadline, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 2)
            }
            .buttonStyle(.glassProminent)
            .tint(Theme.accent)
            Text("Uses your approximate location, sent to Apple for the weather and the place name. It isn't stored.")
                .font(.rounded(.caption))
                .foregroundStyle(Theme.inkSoft)
        case .denied:
            prompt(
                systemImage: "location.slash",
                title: "Weather is off",
                text: "Location is off for MySkin, so humidity and UV can't be shown."
            )
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
            }
            .font(.rounded(.subheadline, weight: .semibold))
            .tint(Theme.accent)
        case .loading:
            HStack(spacing: 12) {
                ProgressView()
                    .tint(Theme.accent)
                Text("Checking the weather…")
                    .font(.rounded(.subheadline))
                    .foregroundStyle(Theme.inkSoft)
            }
            .frame(maxWidth: .infinity, minHeight: 72)
        case .failed:
            prompt(systemImage: "cloud.fill", title: "Weather", text: "Couldn't load the weather.")
            Button("Try again") { Task { await weather.refresh(isManual: true) } }
                .font(.rounded(.subheadline, weight: .semibold))
                .tint(Theme.accent)
        case .loaded(let reading):
            loaded(reading)
        }
    }

    // MARK: Loaded

    private func loaded(_ reading: WeatherReading) -> some View {
        let uv = UVLevel(index: reading.uvIndexMax)
        return VStack(alignment: .leading, spacing: 14) {
            // Hero: today's UV and the temperature now.
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Label("UV today", systemImage: "sun.max.fill")
                        .font(.rounded(.subheadline, weight: .semibold))
                        .foregroundStyle(Theme.accent)
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(reading.uvIndexMax.formatted(.number.precision(.fractionLength(0))))
                            .font(.rounded(.largeTitle, weight: .bold))
                            .foregroundStyle(Theme.ink)
                            .contentTransition(.numericText())
                        Text(uv.title)
                            .font(.rounded(.subheadline, weight: .semibold))
                            .foregroundStyle(Theme.ink)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 3)
                            .background(Self.color(for: uv).opacity(0.55), in: .capsule)
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    HStack(spacing: 8) {
                        if let place = weather?.placeName {
                            Label(place, systemImage: "location.fill")
                                .font(.rounded(.caption, weight: .medium))
                                .foregroundStyle(Theme.inkSoft)
                                .labelStyle(PlaceLabelStyle())
                                .lineLimit(1)
                                .truncationMode(.tail)
                                .frame(maxWidth: 140, alignment: .trailing)
                        }
                        Image(systemName: "thermometer.medium")
                            .font(.subheadline)
                            .foregroundStyle(Theme.accent)
                    }
                    Text(Measurement(value: reading.temperature, unit: UnitTemperature.celsius)
                        .formatted(.measurement(width: .abbreviated, numberFormatStyle: .number.precision(.fractionLength(0)))))
                        .font(.rounded(.title2, weight: .bold))
                        .foregroundStyle(Theme.ink)
                    Text("now")
                        .font(.rounded(.caption))
                        .foregroundStyle(Theme.inkSoft)
                }
                .accessibilityElement(children: .combine)
            }

            UVScale(index: reading.uvIndexMax)

            HStack(spacing: 10) {
                tile(
                    systemImage: "humidity.fill",
                    title: "Humidity",
                    value: "\(Int(reading.humidity.rounded())) %",
                    detail: WeatherInfo.humidityTitle(reading.humidity)
                )
                tile(
                    systemImage: "sun.min",
                    title: "UV now",
                    value: reading.uvIndex.formatted(.number.precision(.fractionLength(0))),
                    detail: UVLevel(index: reading.uvIndex).title
                )
            }

            let notes = WeatherInfo.notes(for: reading)
            if !notes.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(notes, id: \.self) { note in
                        Label(note, systemImage: "info.circle")
                            .font(.rounded(.footnote))
                            .foregroundStyle(Theme.ink)
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.white.opacity(0.45), in: .rect(cornerRadius: 16))
            }

            Text("Saved with today's check-in")
                .font(.rounded(.caption2))
                .foregroundStyle(Theme.inkSoft)
            WeatherAttributionView(credit: weather?.credit)
        }
        .accessibilityElement(children: .contain)
    }

    private func tile(systemImage: String, title: String, value: String, detail: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.title3)
                .foregroundStyle(Theme.accent)
                .frame(width: 36, height: 36)
                .background(.white.opacity(0.6), in: .circle)
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.rounded(.caption, weight: .medium))
                    .foregroundStyle(Theme.inkSoft)
                Text(value)
                    .font(.rounded(.headline, weight: .bold))
                    .foregroundStyle(Theme.ink)
                Text(detail)
                    .font(.rounded(.caption))
                    .foregroundStyle(Theme.inkSoft)
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white.opacity(0.45), in: .rect(cornerRadius: 18))
        .accessibilityElement(children: .combine)
    }

    private func prompt(systemImage: String, title: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: systemImage)
                .font(.title2)
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(Theme.accent)
                .frame(width: 48, height: 48)
                .background(.white.opacity(0.6), in: .circle)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.rounded(.headline, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                Text(text)
                    .font(.rounded(.subheadline))
                    .foregroundStyle(Theme.inkSoft)
            }
        }
    }

    /// UV bands in the app's calm → severe palette.
    fileprivate static func color(for level: UVLevel) -> Color {
        switch level {
        case .low: Theme.intensityCalm
        case .moderate: Theme.intensityMild
        case .high: Theme.intensityModerate
        case .veryHigh, .extreme: Theme.intensitySevere
        }
    }
}

/// Small location arrow before the place name.
private struct PlaceLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 3) {
            configuration.icon
                .font(.system(size: 9))
                .foregroundStyle(Theme.accent)
            configuration.title
        }
    }
}

/// 0–11+ UV bar with a marker at today's maximum.
private struct UVScale: View {
    let index: Double
    private static let maxIndex = 11.0

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            GeometryReader { geo in
                let fraction = min(max(index / Self.maxIndex, 0), 1)
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(LinearGradient(
                            colors: [Theme.intensityCalm, Theme.intensityMild, Theme.intensityModerate, Theme.intensitySevere],
                            startPoint: .leading,
                            endPoint: .trailing
                        ))
                        .frame(height: 8)
                    Circle()
                        .fill(.white)
                        .overlay(Circle().stroke(Theme.ink.opacity(0.7), lineWidth: 2))
                        .frame(width: 16, height: 16)
                        .offset(x: fraction * (geo.size.width - 16))
                }
                .frame(maxHeight: .infinity)
            }
            .frame(height: 16)
            HStack {
                Text("Low")
                Spacer()
                Text("Moderate")
                Spacer()
                Text("High")
                Spacer()
                Text("Extreme")
            }
            .font(.rounded(.caption2))
            .foregroundStyle(Theme.inkSoft)
        }
        .accessibilityHidden(true)
    }
}

/// Today's planned doses from the treatment plan; ticking one writes a `DoseLog`.
private struct RemindersCard: View {
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<Treatment> { $0.endDate == nil }, sort: \Treatment.name) private var treatments: [Treatment]
    @State private var saveError: String?
    /// Injection waiting for its site to be chosen.
    @State private var pendingInjection: DoseRow?

    var body: some View {
        let rows = DoseRows.rows(for: treatments, on: .now)
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Treatment today", systemImage: "calendar")
            if rows.isEmpty {
                Text(treatments.isEmpty
                     ? "Add your treatments in the Treatment tab to see today's doses here."
                     : "Nothing planned for today.")
                    .font(.rounded(.subheadline))
                    .foregroundStyle(Theme.inkSoft)
            }
            ForEach(rows) { row in
                HStack(spacing: 12) {
                    Image(systemName: row.treatment.kind.systemImage)
                        .foregroundStyle(Theme.accent)
                        .frame(width: 36, height: 36)
                        .background(Theme.accentSoft.opacity(0.7), in: .circle)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(row.treatment.name)
                            .font(.rounded(.body, weight: .medium))
                            .foregroundStyle(Theme.ink)
                            .strikethrough(row.isDone, color: Theme.inkSoft)
                        Text(detail(row))
                            .font(.rounded(.footnote))
                            .foregroundStyle(Theme.inkSoft)
                    }
                    Spacer()
                    Button {
                        toggle(row)
                    } label: {
                        Image(systemName: row.isDone ? "checkmark.circle.fill" : "circle")
                            .font(.title2)
                            .foregroundStyle(row.isDone ? Theme.sageDeep : Theme.sandDeep)
                            .frame(width: 44, height: 44)
                            .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                    .sensoryFeedback(.success, trigger: row.isDone) { _, done in done }
                    .accessibilityLabel(row.isDone ? "Done" : "Mark as done")
                }
            }
        }
        .glassCard()
        .confirmationDialog(
            "Where did you inject?",
            isPresented: Binding(get: { pendingInjection != nil }, set: { if !$0 { pendingInjection = nil } }),
            titleVisibility: .visible,
            presenting: pendingInjection
        ) { row in
            let suggested = InjectionPlan.suggestedSite(after: InjectionPlan.lastSite(row.treatment.doses.map(\.injectionRecord)))
            ForEach([suggested] + InjectionSite.allCases.filter { $0 != suggested }) { site in
                Button(site == suggested ? "\(site.title) (suggested)" : site.title) {
                    mark(row, site: site)
                }
            }
            Button("Cancel", role: .cancel) {}
        }
        .alert("Couldn't save", isPresented: Binding(get: { saveError != nil }, set: { if !$0 { saveError = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(saveError ?? "")
        }
    }

    private func detail(_ row: DoseRow) -> String {
        var parts = [row.scheduledAt.formatted(date: .omitted, time: .shortened)]
        let zones = row.treatment.zoneIDs.compactMap { BodyZone.zone(id: $0)?.name }
        if !zones.isEmpty { parts.append(zones.formatted(.list(type: .and))) }
        if let ftu = row.treatment.fingertipUnits {
            parts.append("\(ftu.formatted(.number.precision(.fractionLength(0...1)))) FTU")
        }
        return parts.joined(separator: " · ")
    }

    private func toggle(_ row: DoseRow) {
        // Injections ask for the site first, so the rotation stays accurate.
        if row.treatment.kind == .biologic && !row.isDone {
            pendingInjection = row
        } else {
            mark(row, site: nil)
        }
    }

    private func mark(_ row: DoseRow, site: InjectionSite?) {
        do {
            try withAnimation(.bouncy) { try DoseRows.toggle(row, injectionSite: site, in: modelContext) }
        } catch {
            modelContext.rollback()
            saveError = error.localizedDescription
        }
    }
}

/// «Time for …» cards for questionnaires that are due (`QuestionnaireSchedule`); a card goes away once taken.
private struct QuestionnaireDueCards: View {
    @Query private var results: [QuestionnaireResult]
    @Query(sort: \Profile.createdAt) private var profiles: [Profile]
    let onTake: (QuestionnaireKind) -> Void

    var body: some View {
        let due = QuestionnaireSchedule.due(now: .now, results: results, arthritis: profiles.first?.arthritisStatus)
        ForEach(due) { kind in
            let neverTaken = !results.contains { $0.kind == kind }
            Button {
                onTake(kind)
            } label: {
                HStack(spacing: 14) {
                    Image(systemName: kind.systemImage)
                        .font(.title3)
                        .foregroundStyle(Theme.accent)
                        .frame(width: 44, height: 44)
                        .background(Theme.accentSoft.opacity(0.8), in: .circle)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Time for: \(kind.title)")
                            .font(.rounded(.headline, weight: .semibold))
                            .foregroundStyle(Theme.ink)
                        Text(QuestionnaireSchedule.reason(kind, neverTaken: neverTaken))
                            .font(.rounded(.subheadline))
                            .foregroundStyle(Theme.inkSoft)
                            .multilineTextAlignment(.leading)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                        .foregroundStyle(Theme.inkSoft)
                }
                .glassCard(tint: Theme.accentSoft)
            }
            .buttonStyle(.plain)
            .transition(.opacity)
        }
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
                // The card opens the diary calendar.
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Theme.inkSoft)
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

#if DEBUG
#Preview("Today · Flare") {
    TodayView()
        .modelContainer(PreviewData.flareContainer)
        .previewSetup()
}

#Preview("Today · Empty") {
    TodayView()
        .modelContainer(PreviewData.emptyContainer())
        .previewSetup()
}
#endif

/// Apple Weather mark and the legal link — WeatherKit requires both wherever its data is shown.
private struct WeatherAttributionView: View {
    let credit: WeatherCredit?

    var body: some View {
        HStack(spacing: 8) {
            if let credit {
                AsyncImage(url: credit.markURL) { image in
                    image
                        .resizable()
                        .scaledToFit()
                } placeholder: {
                    Text(credit.serviceName)
                        .font(.rounded(.caption2, weight: .semibold))
                        .foregroundStyle(Theme.inkSoft)
                }
                .frame(height: 12)
                .accessibilityLabel(credit.serviceName)
            } else {
                Text("Apple Weather")
                    .font(.rounded(.caption2, weight: .semibold))
                    .foregroundStyle(Theme.inkSoft)
            }
            if let legal = credit?.legalPageURL ?? WeatherCredit.appleWeatherLegalPage {
                Link("Data sources", destination: legal)
                    .font(.rounded(.caption2, weight: .medium))
                    .tint(Theme.accent)
            }
        }
    }
}
