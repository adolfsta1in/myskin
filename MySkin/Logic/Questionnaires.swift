import Foundation

// MARK: - Question model

struct QuestionOption: Hashable, Sendable {
    let title: String
    /// Points added to the total when this option is chosen.
    let score: Int
}

struct Question: Identifiable, Hashable, Sendable {
    /// 1-based number, as in the original questionnaire.
    let id: Int
    let text: String
    let options: [QuestionOption]
}

/// Stored answers are option indices in question order (`QuestionnaireResult.answers`),
/// so "Not relevant" stays distinguishable from "Not at all" even though both score 0.
enum Questionnaires {
    static func questions(for kind: QuestionnaireKind) -> [Question] {
        switch kind {
        case .dlqi: DLQI.questions
        case .pest: PEST.questions
        }
    }

    /// Total score, or nil if the answers are incomplete or out of range.
    static func score(_ kind: QuestionnaireKind, answers: [Int]) -> Int? {
        let questions = questions(for: kind)
        guard answers.count == questions.count else { return nil }
        var total = 0
        for (question, answer) in zip(questions, answers) {
            guard question.options.indices.contains(answer) else { return nil }
            total += question.options[answer].score
        }
        return total
    }
}

// MARK: - DLQI

/// Dermatology Life Quality Index: 10 questions about the last week, 0–30.
enum DLQI {
    private static let veryMuch = QuestionOption(title: "Very much", score: 3)
    private static let aLot = QuestionOption(title: "A lot", score: 2)
    private static let aLittle = QuestionOption(title: "A little", score: 1)
    private static let notAtAll = QuestionOption(title: "Not at all", score: 0)
    private static let notRelevant = QuestionOption(title: "Not relevant", score: 0)

    private static let basic = [veryMuch, aLot, aLittle, notAtAll]
    private static let withNotRelevant = basic + [notRelevant]

    static let questions: [Question] = [
        Question(id: 1, text: "Over the last week, how itchy, sore, painful or stinging has your skin been?", options: basic),
        Question(id: 2, text: "Over the last week, how embarrassed or self-conscious have you been because of your skin?", options: basic),
        Question(id: 3, text: "Over the last week, how much has your skin interfered with you going shopping or looking after your home or garden?", options: withNotRelevant),
        Question(id: 4, text: "Over the last week, how much has your skin influenced the clothes you wear?", options: withNotRelevant),
        Question(id: 5, text: "Over the last week, how much has your skin affected any social or leisure activities?", options: withNotRelevant),
        Question(id: 6, text: "Over the last week, how much has your skin made it difficult for you to do any sport?", options: withNotRelevant),
        // Question 7 merges "Has your skin prevented you from working or studying?" (Yes = 3)
        // with the follow-up "If no, how much has it been a problem at work or studying?".
        Question(id: 7, text: "Over the last week, has your skin prevented you from working or studying? If not, how much has it been a problem at work or studying?", options: [
            QuestionOption(title: "Yes, it prevented me", score: 3),
            QuestionOption(title: "No, but a lot of a problem", score: 2),
            QuestionOption(title: "No, but a little problem", score: 1),
            QuestionOption(title: "Not at all", score: 0),
            notRelevant,
        ]),
        Question(id: 8, text: "Over the last week, how much has your skin created problems with your partner or any of your close friends or relatives?", options: withNotRelevant),
        Question(id: 9, text: "Over the last week, how much has your skin caused any sexual difficulties?", options: withNotRelevant),
        Question(id: 10, text: "Over the last week, how much of a problem has the treatment for your skin been, for example by making your home messy, or by taking up time?", options: withNotRelevant),
    ]

    static let maxScore = 30

    /// Effect on quality of life, by the standard DLQI score bands.
    enum Band: Sendable {
        case none, small, moderate, veryLarge, extremelyLarge

        var title: String {
            switch self {
            case .none: "No effect on your life"
            case .small: "Small effect"
            case .moderate: "Moderate effect"
            case .veryLarge: "Very large effect"
            case .extremelyLarge: "Extremely large effect"
            }
        }
    }

    static func band(for score: Int) -> Band {
        switch score {
        case ...1: .none
        case 2...5: .small
        case 6...10: .moderate
        case 11...20: .veryLarge
        default: .extremelyLarge
        }
    }

    /// 0–1 is the treatment goal (research §6).
    static func isAtGoal(_ score: Int) -> Bool { score <= 1 }

    /// Above 10 counts in the «rule of tens».
    static func isVeryLargeEffect(_ score: Int) -> Bool { score > 10 }

    static func interpretation(for score: Int) -> String {
        if isVeryLargeEffect(score) {
            return "\(band(for: score).title). Your skin is strongly affecting daily life — discuss with your doctor whether your treatment plan is right for you."
        }
        if isAtGoal(score) {
            return "\(band(for: score).title). This is the usual treatment goal."
        }
        return "\(band(for: score).title). Consider discussing it with your doctor at your next visit."
    }
}

// MARK: - PEST

/// Psoriasis Epidemiology Screening Tool: 5 yes/no questions about joints, 0–5.
enum PEST {
    private static let yesNo = [QuestionOption(title: "Yes", score: 1), QuestionOption(title: "No", score: 0)]

    static let questions: [Question] = [
        Question(id: 1, text: "Have you ever had a swollen joint (or joints)?", options: yesNo),
        Question(id: 2, text: "Has a doctor ever told you that you have arthritis?", options: yesNo),
        Question(id: 3, text: "Do your fingernails or toenails have holes or pits?", options: yesNo),
        Question(id: 4, text: "Have you had pain in your heel?", options: yesNo),
        Question(id: 5, text: "Have you had a finger or toe that was completely swollen and painful for no apparent reason?", options: yesNo),
    ]

    static let maxScore = 5
    /// A score of 3 or more suggests a rheumatology referral.
    static let referralThreshold = 3

    static func suggestsRheumatologist(_ score: Int) -> Bool { score >= referralThreshold }

    static func interpretation(for score: Int) -> String {
        suggestsRheumatologist(score)
            ? "Your answers suggest that a rheumatologist should check your joints. Discuss a referral with your doctor."
            : "Your answers do not point to joint problems right now. Tell your doctor if joint pain, swelling or stiffness appears."
    }
}
