import SwiftUI

struct TreatmentView: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Treatment")
                            .font(.rounded(.largeTitle, weight: .bold))
                            .foregroundStyle(Theme.ink)
                        Text("\(store.treatments.count) active · all on schedule")
                            .font(.rounded(.subheadline))
                            .foregroundStyle(Theme.inkSoft)
                    }
                    .padding(.top, 12)

                    SectionHeader(title: "Creams & ointments", systemImage: "hand.point.up.left")
                    ForEach(store.treatments.filter { $0.kind == .cream || $0.kind == .ointment }) { treatment in
                        topicalCard(treatment)
                    }

                    SectionHeader(title: "Tablets", systemImage: "pills")
                    ForEach(store.treatments.filter { $0.kind == .pill }) { treatment in
                        simpleCard(treatment)
                    }

                    SectionHeader(title: "Biologics", systemImage: "syringe")
                    ForEach(store.treatments.filter { $0.kind == .biologic }) { treatment in
                        biologicCard(treatment)
                    }

                    injectionSitesCard
                }
                .padding(.horizontal, Theme.screenPadding)
                .padding(.bottom, 32)
            }
            .screenScaffold()
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {} label: { Label("Add treatment", systemImage: "plus") }
                }
            }
        }
    }

    private func treatmentHeader(_ treatment: Treatment) -> some View {
        HStack(spacing: 12) {
            Image(systemName: treatment.kind.systemImage)
                .foregroundStyle(Theme.accent)
                .frame(width: 40, height: 40)
                .background(Theme.accentSoft.opacity(0.7), in: .circle)
            VStack(alignment: .leading, spacing: 2) {
                Text(treatment.name)
                    .font(.rounded(.headline, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                Text("\(treatment.kind.title) · \(treatment.frequency)")
                    .font(.rounded(.subheadline))
                    .foregroundStyle(Theme.inkSoft)
            }
            Spacer(minLength: 0)
        }
    }

    private func topicalCard(_ treatment: Treatment) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            treatmentHeader(treatment)
            FlowLayout(spacing: 6) {
                ForEach(treatment.zones, id: \.self) { zone in
                    Text(zone)
                        .font(.rounded(.caption, weight: .medium))
                        .foregroundStyle(Theme.sageDeep)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Theme.sageSoft, in: .capsule)
                }
            }
            if let ftu = treatment.fingertipUnits {
                HStack(spacing: 14) {
                    FingerIllustration()
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(ftu, format: .number.precision(.fractionLength(0))) fingertip unit\(ftu == 1 ? "" : "s")")
                            .font(.rounded(.headline, weight: .semibold))
                            .foregroundStyle(Theme.ink)
                        Text(ftu == 1
                             ? "A line of cream from the tip to the first crease — enough for both elbows."
                             : "About \(Int(ftu / 2)) g for the whole body. One unit covers two adult palms.")
                            .font(.rounded(.subheadline))
                            .foregroundStyle(Theme.inkSoft)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(12)
                .background(.white.opacity(0.35), in: .rect(cornerRadius: 20))
            }
            Text("Started \(treatment.started.formatted(.dateTime.month(.wide).day()))")
                .font(.rounded(.caption))
                .foregroundStyle(Theme.inkSoft)
        }
        .glassCard()
    }

    private func simpleCard(_ treatment: Treatment) -> some View {
        treatmentHeader(treatment)
            .glassCard()
    }

    private func biologicCard(_ treatment: Treatment) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            treatmentHeader(treatment)
            HStack(spacing: 6) {
                // Next 14 days; the injection day is highlighted.
                ForEach(0..<14, id: \.self) { day in
                    let isDose = day == (treatment.nextDoseInDays ?? 0)
                    VStack(spacing: 4) {
                        Circle()
                            .fill(isDose ? Theme.accent : (day == 0 ? Theme.sage : Theme.sand))
                            .frame(width: isDose ? 16 : 10, height: isDose ? 16 : 10)
                        if day == 0 || isDose {
                            Text(day == 0 ? "Today" : "Fri")
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
            Label("Next injection in \(treatment.nextDoseInDays ?? 0) days", systemImage: "calendar.badge.clock")
                .font(.rounded(.subheadline, weight: .semibold))
                .foregroundStyle(Theme.accent)
        }
        .glassCard()
    }

    private var injectionSitesCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Injection sites", subtitle: "Rotating helps your skin recover")
            HStack(spacing: 18) {
                // Mini torso diagram
                ZStack {
                    RoundedRectangle(cornerRadius: 30).fill(Theme.sand).frame(width: 96, height: 90).offset(y: -40)
                    Capsule().fill(Theme.sand).frame(width: 40, height: 92).offset(x: -26, y: 50)
                    Capsule().fill(Theme.sand).frame(width: 40, height: 92).offset(x: 26, y: 50)
                    siteDot(.abdomenRight).offset(x: -22, y: -34)
                    siteDot(.abdomenLeft).offset(x: 22, y: -34)
                    siteDot(.thighRight).offset(x: -26, y: 44)
                    siteDot(.thighLeft).offset(x: 26, y: 44)
                }
                .frame(width: 110, height: 190)

                VStack(alignment: .leading, spacing: 10) {
                    ForEach(InjectionSite.allCases) { site in
                        HStack(spacing: 8) {
                            Circle()
                                .fill(color(for: site))
                                .frame(width: 10, height: 10)
                            Text(site.title)
                                .font(.rounded(.subheadline, weight: site == store.suggestedInjectionSite ? .semibold : .regular))
                                .foregroundStyle(Theme.ink)
                            if site == store.lastInjectionSite {
                                Text("last").font(.rounded(.caption2)).foregroundStyle(Theme.inkSoft)
                            } else if site == store.suggestedInjectionSite {
                                Text("next").font(.rounded(.caption2, weight: .bold)).foregroundStyle(Theme.accent)
                            }
                        }
                    }
                }
            }
        }
        .glassCard()
    }

    private func color(for site: InjectionSite) -> Color {
        if site == store.suggestedInjectionSite { return Theme.accent }
        if site == store.lastInjectionSite { return Theme.sandDeep }
        return Theme.sage
    }

    private func siteDot(_ site: InjectionSite) -> some View {
        Circle()
            .fill(color(for: site))
            .frame(width: 18, height: 18)
            .overlay(Circle().stroke(.white, lineWidth: 2))
            .accessibilityLabel(site.title)
    }
}

#Preview {
    TreatmentView()
        .previewSetup()
}
