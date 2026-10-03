import SwiftData
import SwiftUI

/// Month view of the diary: dots show what was logged; tapping a day shows its check-in,
/// assessed areas, doses and photos.
struct DiaryCalendarView: View {
    @Query private var checkIns: [DailyCheckIn]
    @Query private var assessments: [ZoneAssessment]
    @Query(sort: \Photo.createdAt) private var photos: [Photo]
    @Query(sort: \DoseLog.timestamp) private var doses: [DoseLog]
    @State private var month = Date.now
    @State private var selectedDay = Calendar.current.startOfDay(for: .now)

    private let calendar = Calendar.current

    var body: some View {
        let marks = DiaryCalendar.marks(
            month: month,
            checkIns: checkIns.map(\.sample),
            zones: assessments.map(\.datedScore),
            photoDays: photos.map(\.day),
            doseDays: doses.filter { $0.status == .done }.map(\.timestamp)
        )
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                monthCard(marks)
                DayDetail(
                    day: selectedDay,
                    checkIn: checkIns.first { calendar.isDate($0.day, inSameDayAs: selectedDay) },
                    assessments: assessments.filter { calendar.isDate($0.day, inSameDayAs: selectedDay) },
                    doses: doses.filter { $0.status == .done && calendar.isDate($0.timestamp, inSameDayAs: selectedDay) },
                    photos: photos.filter { calendar.isDate($0.day, inSameDayAs: selectedDay) }
                )
            }
            .padding(.horizontal, Theme.screenPadding)
            .padding(.bottom, 32)
        }
        .screenScaffold()
        .navigationTitle("Diary calendar")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: Month

    private func monthCard(_ marks: [Date: DayMark]) -> some View {
        VStack(spacing: 12) {
            HStack {
                Button("Previous month", systemImage: "chevron.left") { shiftMonth(-1) }
                    .labelStyle(.iconOnly)
                Spacer()
                Text(month.formatted(.dateTime.month(.wide).year()))
                    .font(.rounded(.headline, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                Spacer()
                Button("Next month", systemImage: "chevron.right") { shiftMonth(1) }
                    .labelStyle(.iconOnly)
                    .disabled(calendar.isDate(month, equalTo: .now, toGranularity: .month))
            }
            .font(.rounded(.body, weight: .semibold))
            .tint(Theme.accent)

            let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)
            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(Array(DiaryCalendar.weekdaySymbols().enumerated()), id: \.offset) { _, symbol in
                    Text(symbol)
                        .font(.rounded(.caption, weight: .semibold))
                        .foregroundStyle(Theme.inkSoft)
                }
                ForEach(Array(DiaryCalendar.monthGrid(containing: month).enumerated()), id: \.offset) { _, date in
                    if let date {
                        dayCell(date, mark: marks[calendar.startOfDay(for: date)] ?? DayMark())
                    } else {
                        Color.clear.frame(height: 44)
                    }
                }
            }

            HStack(spacing: 14) {
                legend(Theme.sageDeep, "Check-in")
                legend(Theme.intensityModerate, "Flare sign")
                legend(Theme.accent, "Photo")
            }
            .font(.rounded(.caption))
            .foregroundStyle(Theme.inkSoft)
        }
        .glassCard()
    }

    private func dayCell(_ date: Date, mark: DayMark) -> some View {
        let isSelected = calendar.isDate(date, inSameDayAs: selectedDay)
        let isFuture = date > .now
        return Button {
            withAnimation(.snappy) { selectedDay = calendar.startOfDay(for: date) }
        } label: {
            VStack(spacing: 3) {
                Text("\(calendar.component(.day, from: date))")
                    .font(.rounded(.subheadline, weight: calendar.isDateInToday(date) ? .bold : .regular))
                    .foregroundStyle(isSelected ? .white : isFuture ? Theme.inkSoft.opacity(0.5) : Theme.ink)
                HStack(spacing: 2) {
                    if mark.hasCheckIn { dot(mark.hasFlareSign ? Theme.intensityModerate : Theme.sageDeep) }
                    if mark.hasPhoto { dot(Theme.accent) }
                }
                .frame(height: 5)
            }
            .frame(maxWidth: .infinity, minHeight: 44)
            .background(isSelected ? Theme.accent : .clear, in: .rect(cornerRadius: 12))
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .disabled(isFuture)
        .accessibilityLabel(date.formatted(date: .complete, time: .omitted))
        .accessibilityValue(accessibilityValue(mark))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func dot(_ color: Color) -> some View {
        Circle().fill(color).frame(width: 5, height: 5)
    }

    private func legend(_ color: Color, _ title: String) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 7, height: 7)
            Text(title)
        }
    }

    private func accessibilityValue(_ mark: DayMark) -> String {
        var parts: [String] = []
        if mark.hasCheckIn { parts.append(mark.hasFlareSign ? "check-in with flare signs" : "check-in") }
        if mark.hasPhoto { parts.append("photos") }
        if mark.hasZoneAssessment { parts.append("body map") }
        if mark.dosesDone > 0 { parts.append("\(mark.dosesDone) doses") }
        return parts.isEmpty ? "Nothing logged" : parts.formatted(.list(type: .and))
    }

    private func shiftMonth(_ value: Int) {
        guard let next = calendar.date(byAdding: .month, value: value, to: month) else { return }
        withAnimation(.snappy) { month = next }
    }
}

// MARK: - Day

private struct DayDetail: View {
    let day: Date
    let checkIn: DailyCheckIn?
    let assessments: [ZoneAssessment]
    let doses: [DoseLog]
    let photos: [Photo]

    private var isEmpty: Bool { checkIn == nil && assessments.isEmpty && doses.isEmpty && photos.isEmpty }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: day.formatted(.dateTime.weekday(.wide).month(.wide).day()))
            if isEmpty {
                Text("Nothing logged on this day.")
                    .font(.rounded(.subheadline))
                    .foregroundStyle(Theme.inkSoft)
            }
            if let checkIn { checkInSection(checkIn) }
            if !assessments.isEmpty { zonesSection }
            if !doses.isEmpty { dosesSection }
            if !photos.isEmpty { photosSection }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard()
    }

    private func checkInSection(_ checkIn: DailyCheckIn) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            label("Check-in")
            row("Itch", "\(checkIn.itch)/10")
            if let pain = checkIn.pain { row("Burning or pain", "\(pain)/10") }
            if let sleep = checkIn.sleep { row("Sleep", "\(sleep)/10") }
            if let mood = checkIn.mood { row("Mood", "\(mood)/5") }
            if checkIn.newSpots { row("New or spreading spots", "Yes") }
            let tags = checkIn.triggers.map(\.title) + checkIn.customTags
            if !tags.isEmpty { row("Possible triggers", tags.joined(separator: ", ")) }
            if let humidity = checkIn.humidity { row("Humidity", "\(Int(humidity.rounded())) %") }
            if let uv = checkIn.uvIndex { row("UV index", uv.formatted(.number.precision(.fractionLength(0...1)))) }
            if let temperature = checkIn.temperature {
                row("Temperature", Measurement(value: temperature, unit: UnitTemperature.celsius).formatted(.measurement(width: .abbreviated, numberFormatStyle: .number.precision(.fractionLength(0)))))
            }
            if !checkIn.note.isEmpty {
                Text(checkIn.note)
                    .font(.rounded(.subheadline))
                    .foregroundStyle(Theme.ink)
                    .padding(.top, 2)
            }
        }
    }

    private var zonesSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            label("Body map")
            ForEach(assessments.sorted { $0.zoneID < $1.zoneID }) { assessment in
                let level = SeverityCalculator.level(for: assessment.score)
                row(BodyZone.zone(id: assessment.zoneID)?.name ?? assessment.zoneID, IntensityLegend.label(for: level))
            }
        }
    }

    private var dosesSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            label("Treatment")
            ForEach(doses) { dose in
                row(dose.treatment?.name ?? "Treatment", dose.timestamp.formatted(date: .omitted, time: .shortened))
            }
        }
    }

    private var photosSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            label("Photos")
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 90), spacing: 8)], spacing: 8) {
                ForEach(photos) { photo in
                    NavigationLink {
                        ZoneProgressView(zoneID: photo.zoneID)
                    } label: {
                        StoredPhotoImage(fileName: photo.fileName, maxPixelSize: 300, cornerRadius: 14)
                            .aspectRatio(1, contentMode: .fit)
                            .overlay(alignment: .bottomLeading) {
                                Text(BodyZone.zone(id: photo.zoneID)?.name ?? "")
                                    .font(.rounded(.caption2, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .padding(6)
                                    .shadow(radius: 2)
                            }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func label(_ text: String) -> some View {
        Text(text)
            .font(.rounded(.subheadline, weight: .semibold))
            .foregroundStyle(Theme.inkSoft)
    }

    private func row(_ title: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.rounded(.subheadline))
                .foregroundStyle(Theme.ink)
            Spacer()
            Text(value)
                .font(.rounded(.subheadline, weight: .semibold))
                .foregroundStyle(Theme.ink)
                .multilineTextAlignment(.trailing)
        }
    }
}

#Preview {
    NavigationStack {
        DiaryCalendarView()
    }
    .previewSetup()
}
