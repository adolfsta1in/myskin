import Foundation

// MARK: - Question model

struct QuestionOption: Hashable, Sendable {
    let title: String
    /// Points added to the total when this option is chosen.
    let score: Int
}

struct Question: Identifiable, Hashable, Sendable {
    /// 1-based number.
    let id: Int
    let text: String
    let options: [QuestionOption]
}

/// MySkin's own questionnaires (not validated clinical scores). Stored answers are option indices
/// in question order (`QuestionnaireResult.answers`).
/// Retired kinds (`dlqi`, `pest`) have no questions: they can't be taken again, only shown.
enum Questionnaires {
    static func questions(for kind: QuestionnaireKind) -> [Question] {
        switch kind {
        case .skinImpact: SkinImpact.questions
        case .jointCheck: JointCheck.questions
        case .dlqi, .pest: []
        }
    }

    /// Total score, or nil if the answers are incomplete or out of range.
    static func score(_ kind: QuestionnaireKind, answers: [Int]) -> Int? {
        let questions = questions(for: kind)
        guard !questions.isEmpty, answers.count == questions.count else { return nil }
        var total = 0
        for (question, answer) in zip(questions, answers) {
            guard question.options.indices.contains(answer) else { return nil }
            total += question.options[answer].score
        }
        return total
    }

    /// Joint symptoms noted in the latest joint questionnaire (new or retired), if any was taken by `date`.
    static func jointSymptomsNoted(
        results: [(kind: QuestionnaireKind, date: Date, score: Int)],
        by date: Date = .distantFuture
    ) -> Bool {
        let latest = results
            .filter { ($0.kind == .jointCheck || $0.kind == .pest) && $0.date <= date }
            .max { $0.date < $1.date }
        return latest.map { needsAttention($0.kind, score: $0.score) } ?? false
    }
}

// MARK: - Skin impact

/// How much psoriasis got in the way of the last 7 days: 6 questions, 0–3 each, 0–18.
/// Levels are plain words, not clinical bands.
enum SkinImpact {
    private static let scale = [
        QuestionOption(title: "Not at all", score: 0),
        QuestionOption(title: "A little", score: 1),
        QuestionOption(title: "Quite a bit", score: 2),
        QuestionOption(title: "A lot", score: 3),
    ]

    static let questions: [Question] = [
        Question(id: 1, text: "In the past 7 days, how much did your skin get in the way of your sleep?", options: scale),
        Question(id: 2, text: "In the past 7 days, how much did your skin affect your mood — feeling low, irritable or worried?", options: scale),
        Question(id: 3, text: "In the past 7 days, how much did your skin get in the way of work, study or everyday tasks?", options: scale),
        Question(id: 4, text: "In the past 7 days, how much did your skin hold you back from seeing people or going out?", options: scale),
        Question(id: 5, text: "In the past 7 days, how much did your skin affect what you chose to wear?", options: scale),
        Question(id: 6, text: "In the past 7 days, how much of a burden was looking after your skin — time, mess or routine?", options: scale),
    ]

    static let maxScore = 18
    /// From this score on, the result suggests talking to the doctor.
    static let attentionThreshold = 10

    enum Level: Sendable {
        case none, small, moderate, large

        var title: String {
            switch self {
            case .none: "No impact this week"
            case .small: "Small impact"
            case .moderate: "Moderate impact"
            case .large: "Large impact"
            }
        }
    }

    static func level(for score: Int) -> Level {
        switch score {
        case ...0: .none
        case 1...4: .small
        case 5..<attentionThreshold: .moderate
        default: .large
        }
    }

    static func needsAttention(_ score: Int) -> Bool { score >= attentionThreshold }

    static func interpretation(for score: Int) -> String {
        switch level(for: score) {
        case .none: "Your skin didn't get in the way of your week."
        case .small, .moderate: "Your skin affected part of your week. You can mention it at your next visit."
        case .large: "Your skin affected a lot of your week. It's worth discussing with your doctor — show them these answers."
        }
    }
}

// MARK: - Joint check

/// Joint symptoms: 6 yes/no questions, 0–6. A reason to talk to a doctor, not a diagnosis.
enum JointCheck {
    private static let yesNo = [QuestionOption(title: "Yes", score: 1), QuestionOption(title: "No", score: 0)]

    static let questions: [Question] = [
        Question(id: 1, text: "In the past month, has any joint been painful for more than a few days?", options: yesNo),
        Question(id: 2, text: "In the past month, has any joint looked or felt swollen?", options: yesNo),
        Question(id: 3, text: "Do your joints feel stiff for more than 30 minutes after you get up?", options: yesNo),
        Question(id: 4, text: "In the past month, have you had pain at the back of your heel or under your foot?", options: yesNo),
        Question(id: 5, text: "In the past month, has a whole finger or toe been swollen and sore?", options: yesNo),
        Question(id: 6, text: "Do you have back pain that wakes you at night and eases when you move?", options: yesNo),
    ]

    static let maxScore = 6
    /// From this many «yes» answers on, the result suggests discussing joints with a doctor.
    static let attentionThreshold = 2

    static func needsAttention(_ score: Int) -> Bool { score >= attentionThreshold }

    static func headline(for score: Int) -> String {
        switch score {
        case ...0: "No joint symptoms noted"
        case ..<attentionThreshold: "One joint symptom noted"
        default: "Discuss your joints with a doctor"
        }
    }

    static func interpretation(for score: Int) -> String {
        switch score {
        case ...0: "Tell your doctor if joint pain, swelling or stiffness appears."
        case ..<attentionThreshold: "Keep an eye on it and mention it at your next visit."
        default: "You noted symptoms in your joints. Show these answers to your doctor or a rheumatologist — psoriasis can affect joints, and it's worth checking early."
        }
    }
}

// MARK: - Retired questionnaires

/// Results of the licensed questionnaires the app used before (DLQI 0–30, PEST 0–5).
/// Only their scores remain, for history and the arthritis mark.
enum RetiredQuestionnaire {
    static func maxScore(_ kind: QuestionnaireKind) -> Int { kind == .pest ? 5 : 30 }

    /// The thresholds those questionnaires were used with.
    static func needsAttention(_ kind: QuestionnaireKind, score: Int) -> Bool {
        kind == .pest ? score >= 3 : score > 10
    }

    static let interpretation = "From an earlier version of this questionnaire. Take the new one to keep tracking."
}
