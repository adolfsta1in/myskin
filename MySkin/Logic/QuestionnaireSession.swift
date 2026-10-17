import Foundation

/// Step-by-step progress through one questionnaire. Answers are option indices (`Questionnaires.score`).
struct QuestionnaireSession: Equatable {
    let kind: QuestionnaireKind
    private(set) var answers: [Int?]
    /// Index of the question on screen; equals `questions.count` once every question is answered.
    private(set) var index = 0

    init(kind: QuestionnaireKind) {
        self.kind = kind
        answers = Array(repeating: nil, count: Questionnaires.questions(for: kind).count)
    }

    var questions: [Question] { Questionnaires.questions(for: kind) }

    var current: Question? { questions.indices.contains(index) ? questions[index] : nil }

    var isFinished: Bool { index >= questions.count }

    /// 0…1 for the progress bar.
    var progress: Double { Double(index) / Double(max(questions.count, 1)) }

    var canGoBack: Bool { index > 0 }

    /// Total once every question is answered.
    var score: Int? {
        let given = answers.compactMap { $0 }
        guard given.count == answers.count else { return nil }
        return Questionnaires.score(kind, answers: given)
    }

    /// Records the answer to the current question and moves on. Out-of-range options are ignored.
    mutating func answer(_ option: Int) {
        guard let question = current, question.options.indices.contains(option) else { return }
        answers[index] = option
        index += 1
    }

    /// Back to the previous question; its answer stays selected.
    mutating func goBack() {
        guard canGoBack else { return }
        index -= 1
    }

    /// The record to store, once finished.
    func makeResult(date: Date = .now) -> QuestionnaireResult? {
        guard let score else { return nil }
        return QuestionnaireResult(kind: kind, date: date, answers: answers.compactMap { $0 }, score: score)
    }
}

extension Questionnaires {
    static func maxScore(_ kind: QuestionnaireKind) -> Int {
        switch kind {
        case .skinImpact: SkinImpact.maxScore
        case .jointCheck: JointCheck.maxScore
        case .dlqi, .pest: RetiredQuestionnaire.maxScore(kind)
        }
    }

    /// Short headline for a score.
    static func headline(_ kind: QuestionnaireKind, score: Int) -> String {
        switch kind {
        case .skinImpact: SkinImpact.level(for: score).title
        case .jointCheck: JointCheck.headline(for: score)
        case .dlqi: needsAttention(kind, score: score) ? String(localized: "Large impact") : String(localized: "Earlier version")
        case .pest: needsAttention(kind, score: score) ? String(localized: "Joint symptoms noted") : String(localized: "Earlier version")
        }
    }

    static func interpretation(_ kind: QuestionnaireKind, score: Int) -> String {
        switch kind {
        case .skinImpact: SkinImpact.interpretation(for: score)
        case .jointCheck: JointCheck.interpretation(for: score)
        case .dlqi, .pest: RetiredQuestionnaire.interpretation
        }
    }

    /// The score is worth raising with a doctor.
    static func needsAttention(_ kind: QuestionnaireKind, score: Int) -> Bool {
        switch kind {
        case .skinImpact: SkinImpact.needsAttention(score)
        case .jointCheck: JointCheck.needsAttention(score)
        case .dlqi, .pest: RetiredQuestionnaire.needsAttention(kind, score: score)
        }
    }

    /// What the questionnaire asks about, shown before the first question.
    static func intro(_ kind: QuestionnaireKind) -> String {
        switch kind {
        case .skinImpact: String(localized: "6 questions about how your skin affected your last 7 days. About a minute.")
        case .jointCheck: String(localized: "6 yes/no questions about your joints. Psoriasis can affect joints, so it's worth checking now and then.")
        case .dlqi, .pest: RetiredQuestionnaire.interpretation
        }
    }
}
