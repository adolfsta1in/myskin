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

    /// Calm / Flare is computed from the data (`FlareDetector`), never chosen by hand.
    private var status: FlareStatus {
        FlareDetector.status(on: .now, checkIns: checkIns, assessments: assessments)
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

                    CheckInCard(mode: status.mode) { symptoms in
                        let flags = RedFlagRules.flags(zones: currentZones, symptoms: symptoms, isFlare: status.mode == .flare)
                        if !flags.isEmpty { shownFlags = flags }
                    }
                    if status.mode == .calm {
                        CalmDaysCard()
                            .transition(.opacity)
                    }
                    RemindersCard()
                    QuestionnaireDueCards { takingQuestionnaire = $0 }
                    ItchChartCard()
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
                        if let day = status.signalDay, !Calendar.current.isDateInToday(day) {
                            Text("Seen on \(day.formatted(.dateTime.weekday(.wide).month().day())):")
                                .font(.rounded(.footnote, weight: .medium))
                                .foregroundStyle(Theme.inkSoft)
                        }
                        ForEach(status.reasons, id: \.self) { reason in
                            Label(reason.explanation, systemImage: "circle.fill")
                                .labelStyle(BulletLabelStyle())
                        }
                        Text("Flare mode ends after \(FlareDetector.Threshold.calmDays) days in a row without these signs. If you're worried, discuss it with your doctor.")
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
                    Text("Your body map shows signs that need urgent attention. Tap for details.")
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
    var onLongPress: () -> Void
    var onSettings: () -> Void

    private var greeting: String {
        switch Calendar.current.component(.hour, from: .now) {
        case 5..<12: "Good morning"
        case 12..<18: "Good afternoon"
        default: "Good evening"
        }
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
                    // Hidden entry point to the design canvas (debug builds only).
                    .onLongPressGesture(perform: onLongPress)
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
    @Query private var todayCheckIns: [DailyCheckIn]
    @Query(sort: \DailyCheckIn.day, order: .reverse) private var allCheckIns: [DailyCheckIn]
    let mode: AppMode
    /// Called after a successful save with the flare safety answers.
    let onSaved: (RedFlagSymptoms) -> Void
    private let day: Date

    @State private var draft = CheckInDraft()
    @State private var showsDetails = false
    @State private var isAddingTag = false
    @State private var newTag = ""
    @State private var isSaved = false
    @State private var saveCount = 0
    @State private var saveError: String?

    init(mode: AppMode, day: Date = .now, onSaved: @escaping (RedFlagSymptoms) -> Void = { _ in }) {
        self.mode = mode
        self.onSaved = onSaved
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
                // Safety answers aren't stored; keep what was ticked in this session.
                let symptoms = draft.symptoms
                draft = CheckInDraft(existing)
                draft.symptoms = symptoms
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
        if let existing {
            draft.apply(to: existing)
        } else {
            modelContext.insert(draft.makeCheckIn(day: day))
        }
        do {
            try modelContext.save()
            saveCount += 1
            withAnimation(.bouncy) { isSaved = true }
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
    let onTake: (QuestionnaireKind) -> Void

    var body: some View {
        let due = QuestionnaireSchedule.due(now: .now, results: results)
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
    TodayView()
        .modelContainer(PreviewData.flareContainer)
        .previewSetup()
}

#Preview("Today · Empty") {
    TodayView()
        .modelContainer(PreviewData.emptyContainer())
        .previewSetup()
}
