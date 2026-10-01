import SwiftUI

/// In-memory app state with realistic sample data for the prototype.
@Observable
final class AppStore {
    // MARK: Flow
    /// Session-only lock state. Persistent flags live in `AppSettings`.
    var isLocked = false

    // MARK: Onboarding answers
    var condition: Condition?

    // MARK: Body map (zone id → intensity 0...3)
    var zoneIntensity: [String: Int] = [
        "back.elbow.left": 3,
        "back.elbow.right": 3,
        "front.knee.right": 2,
        "front.knee.left": 2,
        "back.torso.lower": 1,
        "quick.scalp": 2,
    ]

    // MARK: History
    let itchHistory: [DayValue]
    let weeklyScores: [DayValue]

    let treatments: [DemoTreatment]
    let insights: [Insight]
    let experiment = Experiment(
        title: "Dairy-free",
        day: 9,
        totalDays: 21,
        note: "Keep logging itch daily — at the end we'll compare with your previous 3 weeks."
    )
    var photoZones: [PhotoZone]

    init() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        func daysAgo(_ n: Int) -> Date { calendar.date(byAdding: .day, value: -n, to: today) ?? today }

        let itch: [Double] = [6, 7, 6, 5, 6, 4, 5, 4, 3, 4, 3, 2, 3, 3]
        itchHistory = itch.enumerated().map { DayValue(date: daysAgo(itch.count - 1 - $0.offset), value: $0.element) }

        let poem: [Double] = [16, 17, 15, 18, 14, 13, 14, 12, 11, 10, 9, 9, 8]
        weeklyScores = poem.enumerated().map { DayValue(date: daysAgo((poem.count - 1 - $0.offset) * 7), value: $0.element) }


        treatments = [
            DemoTreatment(name: "Tacrolimus 0.1% ointment", kind: .ointment, zones: ["Elbows", "Knees"], frequency: "Twice a day", started: daysAgo(46), fingertipUnits: 1),
            DemoTreatment(name: "Rich emollient cream", kind: .cream, zones: ["Whole body"], frequency: "After every shower", started: daysAgo(120), fingertipUnits: 20),
            DemoTreatment(name: "Vitamin D3", kind: .pill, zones: [], frequency: "1 tablet · morning", started: daysAgo(60)),
            DemoTreatment(name: "Adalimumab 40 mg", kind: .biologic, zones: [], frequency: "Every 2 weeks", started: daysAgo(30), nextDoseInDays: 3),
        ]

        insights = [
            Insight(text: "Flares tend to appear 5–7 days after weeks with poor sleep.", evidence: "Noticed 4 times since June", systemImage: "moon.zzz", confidence: 0.7),
            Insight(text: "Itch is higher on days when humidity drops below 30%.", evidence: "Noticed 6 times", systemImage: "humidity", confidence: 0.8),
            Insight(text: "Calmer weeks often follow regular evening moisturizing.", evidence: "Noticed 3 times · early pattern", systemImage: "drop", confidence: 0.45),
            Insight(text: "No clear link with alcohol so far.", evidence: "Logged 9 times — keep logging to be sure", systemImage: "wineglass", confidence: 0.2),
        ]

        photoZones = [
            PhotoZone(
                id: "back.elbow.left",
                name: "Left elbow",
                photos: (0..<8).map { PhotoEntry(date: daysAgo(84 - $0 * 12), seed: $0 + 1, calmness: 0.1 + Double($0) * 0.11) },
                treatmentMarkers: [
                    TreatmentMarker(date: daysAgo(46), title: "Tacrolimus"),
                    TreatmentMarker(date: daysAgo(30), title: "Adalimumab"),
                ]
            ),
            PhotoZone(
                id: "front.knee.right",
                name: "Right knee",
                photos: (0..<5).map { PhotoEntry(date: daysAgo(70 - $0 * 16), seed: $0 + 20, calmness: 0.2 + Double($0) * 0.12) },
                treatmentMarkers: [TreatmentMarker(date: daysAgo(46), title: "Tacrolimus")]
            ),
            PhotoZone(
                id: "quick.scalp",
                name: "Scalp",
                photos: (0..<3).map { PhotoEntry(date: daysAgo(40 - $0 * 18), seed: $0 + 40, calmness: 0.35 + Double($0) * 0.1) },
                treatmentMarkers: []
            ),
            PhotoZone(
                id: "front.hand.right",
                name: "Right hand",
                photos: [PhotoEntry(date: daysAgo(12), seed: 60, calmness: 0.6)],
                treatmentMarkers: []
            ),
        ]
    }

    // MARK: Derived values

    /// Estimated affected body surface. Each intensity level covers part of the zone.
    var affectedArea: Double {
        let coverage: [Int: Double] = [1: 0.25, 2: 0.5, 3: 0.8]
        return BodyZone.all.reduce(0) { total, zone in
            total + zone.area * (coverage[zoneIntensity[zone.id] ?? 0] ?? 0)
        }
    }

    var scoreName: String {
        condition == .psoriasis ? "Self-assessment" : "POEM"
    }

    /// Sample store used by previews and the design canvas.
    static var preview: AppStore {
        let store = AppStore()
        store.condition = .eczema
        return store
    }
}
