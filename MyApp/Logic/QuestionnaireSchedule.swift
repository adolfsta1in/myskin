import Foundation

/// When a questionnaire is due again (spec §2.5): DLQI once a month, PEST every 3 months.
enum QuestionnaireSchedule {
    /// Days between two runs of each questionnaire.
    static func intervalDays(_ kind: QuestionnaireKind) -> Int {
        switch kind {
        case .dlqi: 30
        case .pest: 91
        }
    }

    /// Next due day: the start of the day `intervalDays` after the latest result; nil if never taken (due now).
    static func nextDue(_ kind: QuestionnaireKind, lastTaken: Date?, calendar: Calendar = .current) -> Date? {
        guard let lastTaken else { return nil }
        return calendar.date(byAdding: .day, value: intervalDays(kind), to: calendar.startOfDay(for: lastTaken))
    }

    static func isDue(_ kind: QuestionnaireKind, lastTaken: Date?, now: Date, calendar: Calendar = .current) -> Bool {
        guard let next = nextDue(kind, lastTaken: lastTaken, calendar: calendar) else { return true }
        return now >= next
    }

    /// Questionnaires due on `now`, in `QuestionnaireKind.allCases` order.
    /// `results` are (kind, date) pairs of stored results in any order.
    static func due(now: Date, results: [(kind: QuestionnaireKind, date: Date)], calendar: Calendar = .current) -> [QuestionnaireKind] {
        QuestionnaireKind.allCases.filter { kind in
            let last = results.filter { $0.kind == kind }.map(\.date).max()
            return isDue(kind, lastTaken: last, now: now, calendar: calendar)
        }
    }

    static func due(now: Date, results: [QuestionnaireResult], calendar: Calendar = .current) -> [QuestionnaireKind] {
        due(now: now, results: results.map { ($0.kind, $0.date) }, calendar: calendar)
    }

    /// Card text on Today.
    static func reason(_ kind: QuestionnaireKind, neverTaken: Bool) -> String {
        switch (kind, neverTaken) {
        case (.dlqi, true): "How much your skin affects daily life. Takes about 2 minutes."
        case (.dlqi, false): "It's been a month — a quick check of how your skin affects daily life."
        case (.pest, true): "5 questions about your joints. Psoriasis can affect joints, so it's worth checking."
        case (.pest, false): "It's been 3 months — a quick joint check."
        }
    }
}
