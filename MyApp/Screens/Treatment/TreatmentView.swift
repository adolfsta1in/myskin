import SwiftData
import SwiftUI

struct TreatmentView: View {
    @Query(sort: \Treatment.startDate, order: .reverse) private var treatments: [Treatment]
    @State private var isAdding = false
    @State private var editing: Treatment?

    private var active: [Treatment] { treatments.filter(\.isActive) }
    private var stopped: [Treatment] { treatments.filter { !$0.isActive } }

    /// Sections in display order; topicals cover creams, ointments, foams and shampoos.
    private static let groups: [(title: String, systemImage: String, kinds: Set<TreatmentKind>)] = [
        ("Creams & ointments", "hand.point.up.left", [.cream, .ointment, .foam, .shampoo]),
        ("Tablets", "pills", [.pill]),
        ("Biologics", "syringe", [.biologic]),
        ("Phototherapy", "sun.max", [.phototherapy]),
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Treatment")
                            .font(.rounded(.largeTitle, weight: .bold))
                            .foregroundStyle(Theme.ink)
                        if !treatments.isEmpty {
                            Text("\(active.count) active")
                                .font(.rounded(.subheadline))
                                .foregroundStyle(Theme.inkSoft)
                        }
                    }
                    .padding(.top, 12)

                    if treatments.isEmpty {
                        emptyState
                    } else {
                        ForEach(Self.groups, id: \.title) { group in
                            let items = active.filter { group.kinds.contains($0.kind) }
                            if !items.isEmpty {
                                SectionHeader(title: group.title, systemImage: group.systemImage)
                                ForEach(items) { treatment in
                                    card(treatment)
                                }
                                if group.kinds.contains(.biologic) {
                                    InjectionSitesCard(records: items.flatMap(\.doses).map(\.injectionRecord))
                                }
                            }
                        }
                        if !stopped.isEmpty {
                            SectionHeader(title: "Stopped", systemImage: "stop.circle")
                            ForEach(stopped) { treatment in
                                card(treatment)
                            }
                        }
                    }
                }
                .padding(.horizontal, Theme.screenPadding)
                .padding(.bottom, 32)
            }
            .screenScaffold()
            .sheet(isPresented: $isAdding) {
                AddTreatmentSheet()
            }
            .sheet(item: $editing) { treatment in
                NavigationStack {
                    TreatmentEditor(draft: TreatmentDraft(treatment), treatment: treatment, onDone: { editing = nil })
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Cancel", systemImage: "xmark") { editing = nil }
                            }
                        }
                }
                .fontDesign(.rounded)
            }
            .toolbar {
                if !treatments.isEmpty {
                    ToolbarItem(placement: .primaryAction) {
                        Button("Add treatment", systemImage: "plus") { isAdding = true }
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            SoftIllustration(systemImage: "cross.vial", size: 120)
            Text("No treatments yet")
                .font(.rounded(.title3, weight: .semibold))
                .foregroundStyle(Theme.ink)
            Text("Add the creams, tablets or injections your doctor prescribed to get reminders and track how they work.")
                .font(.rounded(.subheadline))
                .foregroundStyle(Theme.inkSoft)
                .multilineTextAlignment(.center)
            PrimaryButton(title: "Add treatment", systemImage: "plus") { isAdding = true }
        }
        .frame(maxWidth: .infinity)
        .glassCard(padding: 24)
    }

    private func card(_ treatment: Treatment) -> some View {
        Button {
            editing = treatment
        } label: {
            TreatmentCard(treatment: treatment)
        }
        .buttonStyle(.plain)
        .accessibilityHint("Opens the treatment")
    }
}

/// One treatment: header, zones, fingertip units, start or stop date.
private struct TreatmentCard: View {
    let treatment: Treatment

    private var zoneNames: [String] { treatment.zoneIDs.compactMap { BodyZone.zone(id: $0)?.name } }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Image(systemName: treatment.kind.systemImage)
                    .foregroundStyle(Theme.accent)
                    .frame(width: 40, height: 40)
                    .background(Theme.accentSoft.opacity(0.7), in: .circle)
                VStack(alignment: .leading, spacing: 2) {
                    Text(treatment.name)
                        .font(.rounded(.headline, weight: .semibold))
                        .foregroundStyle(Theme.ink)
                    Text(subtitle)
                        .font(.rounded(.subheadline))
                        .foregroundStyle(Theme.inkSoft)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Theme.inkSoft)
            }

            if !zoneNames.isEmpty {
                FlowLayout(spacing: 6) {
                    ForEach(zoneNames, id: \.self) { name in
                        Text(name)
                            .font(.rounded(.caption, weight: .medium))
                            .foregroundStyle(Theme.sageDeep)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Theme.sageSoft, in: .capsule)
                    }
                }
            }

            if treatment.kind == .biologic, treatment.isActive {
                NextDoseStrip(treatment: treatment)
            }

            if let ftu = treatment.fingertipUnits, treatment.isActive {
                HStack(spacing: 14) {
                    FingerIllustration()
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(ftu, format: .number.precision(.fractionLength(0...1))) fingertip unit\(ftu == 1 ? "" : "s")")
                            .font(.rounded(.headline, weight: .semibold))
                            .foregroundStyle(Theme.ink)
                        Text("A line from the fingertip to the first crease. One unit covers about two adult palms.")
                            .font(.rounded(.subheadline))
                            .foregroundStyle(Theme.inkSoft)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(12)
                .background(.white.opacity(0.35), in: .rect(cornerRadius: 20))
            }

            Text(dateLine)
                .font(.rounded(.caption))
                .foregroundStyle(Theme.inkSoft)
        }
        .glassCard()
        .opacity(treatment.isActive ? 1 : 0.7)
    }

    private var subtitle: String {
        var parts = [treatment.kind.title, DoseScheduler.summary(for: treatment.doseSchedule)]
        if let steroidClass = treatment.steroidClass {
            // Same wording as the editor: «Class I», not «Class 1».
            parts.append(steroidClass.title.components(separatedBy: " · ").first ?? steroidClass.title)
        }
        return parts.joined(separator: " · ")
    }

    private var dateLine: String {
        let started = "Started \(treatment.startDate.formatted(.dateTime.month(.wide).day().year()))"
        guard let end = treatment.endDate else { return started }
        let stopped = "stopped \(end.formatted(.dateTime.month(.wide).day().year()))"
        if let reason = treatment.stopReason, !reason.isEmpty {
            return "\(started) · \(stopped) · \(reason)"
        }
        return "\(started) · \(stopped)"
    }
}

/// Next 14 days with the next dose highlighted, from the real schedule and marks.
private struct NextDoseStrip: View {
    let treatment: Treatment

    var body: some View {
        let days = InjectionPlan.daysUntilNextDose(from: .now, schedule: treatment.doseSchedule, logs: treatment.doses.map(\.logged))
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                ForEach(0..<14, id: \.self) { offset in
                    let isDose = offset == days
                    let date = Calendar.current.date(byAdding: .day, value: offset, to: .now) ?? .now
                    VStack(spacing: 4) {
                        Circle()
                            .fill(isDose ? Theme.accent : (offset == 0 ? Theme.sage : Theme.sand))
                            .frame(width: isDose ? 16 : 10, height: isDose ? 16 : 10)
                        if offset == 0 || isDose {
                            Text(offset == 0 ? "Today" : date.formatted(.dateTime.weekday(.abbreviated)))
                                .font(.rounded(.caption2, weight: .medium))
                                .foregroundStyle(Theme.inkSoft)
                                .fixedSize()
                        } else {
                            Text(" ").font(.rounded(.caption2))
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .accessibilityHidden(true)
            if let days {
                Label(InjectionPlan.countdownText(days: days, from: .now), systemImage: "calendar.badge.clock")
                    .font(.rounded(.subheadline, weight: .semibold))
                    .foregroundStyle(Theme.accent)
            }
        }
    }
}

/// Rotation of injection sites from marked doses: last site and the suggested next one.
private struct InjectionSitesCard: View {
    let records: [InjectionRecord]

    var body: some View {
        let last = InjectionPlan.lastSite(records)
        let next = InjectionPlan.suggestedSite(after: last)
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Injection sites", subtitle: "Rotating helps your skin recover")
            HStack(spacing: 18) {
                // Mini torso diagram
                ZStack {
                    RoundedRectangle(cornerRadius: 30).fill(Theme.sand).frame(width: 96, height: 90).offset(y: -40)
                    Capsule().fill(Theme.sand).frame(width: 40, height: 92).offset(x: -26, y: 50)
                    Capsule().fill(Theme.sand).frame(width: 40, height: 92).offset(x: 26, y: 50)
                    siteDot(.abdomenRight, last: last, next: next).offset(x: -22, y: -34)
                    siteDot(.abdomenLeft, last: last, next: next).offset(x: 22, y: -34)
                    siteDot(.thighRight, last: last, next: next).offset(x: -26, y: 44)
                    siteDot(.thighLeft, last: last, next: next).offset(x: 26, y: 44)
                }
                .frame(width: 110, height: 190)
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 10) {
                    ForEach(InjectionSite.allCases) { site in
                        HStack(spacing: 8) {
                            Circle()
                                .fill(color(for: site, last: last, next: next))
                                .frame(width: 10, height: 10)
                            Text(site.title)
                                .font(.rounded(.subheadline, weight: site == next ? .semibold : .regular))
                                .foregroundStyle(Theme.ink)
                            if site == last {
                                Text("last").font(.rounded(.caption2)).foregroundStyle(Theme.inkSoft)
                            } else if site == next {
                                Text("next").font(.rounded(.caption2, weight: .bold)).foregroundStyle(Theme.accent)
                            }
                        }
                    }
                }
            }
            if last == nil {
                Text("Choose the site when you mark an injection on Today.")
                    .font(.rounded(.footnote))
                    .foregroundStyle(Theme.inkSoft)
            }
        }
        .glassCard()
    }

    private func color(for site: InjectionSite, last: InjectionSite?, next: InjectionSite) -> Color {
        if site == next { return Theme.accent }
        if site == last { return Theme.sandDeep }
        return Theme.sage
    }

    private func siteDot(_ site: InjectionSite, last: InjectionSite?, next: InjectionSite) -> some View {
        Circle()
            .fill(color(for: site, last: last, next: next))
            .frame(width: 18, height: 18)
            .overlay(Circle().stroke(.white, lineWidth: 2))
    }
}

#Preview {
    TreatmentView()
        .previewSetup()
}

#Preview("Empty") {
    TreatmentView()
        .modelContainer(PreviewData.emptyContainer())
        .previewSetup()
}
