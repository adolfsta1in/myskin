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
        case .dlqi: DLQI.maxScore
        case .pest: PEST.maxScore
        }
    }

    /// Short headline for a score.
    static func headline(_ kind: QuestionnaireKind, score: Int) -> String {
        switch kind {
        case .dlqi: DLQI.band(for: score).title
        case .pest: PEST.suggestsRheumatologist(score) ? "Tell a rheumatologist" : "No joint signals"
        }
    }

    static func interpretation(_ kind: QuestionnaireKind, score: Int) -> String {
        switch kind {
        case .dlqi: DLQI.interpretation(for: score)
        case .pest: PEST.interpretation(for: score)
        }
    }

    /// The score is worth raising with a doctor (DLQI > 10, PEST ≥ 3).
    static func needsAttention(_ kind: QuestionnaireKind, score: Int) -> Bool {
        switch kind {
        case .dlqi: DLQI.isVeryLargeEffect(score)
        case .pest: PEST.suggestsRheumatologist(score)
        }
    }

    /// What the questionnaire asks about, shown before the first question.
    static func intro(_ kind: QuestionnaireKind) -> String {
        switch kind {
        case .dlqi: "10 questions about how your skin affected your life over the last week. About 2 minutes."
        case .pest: "5 yes/no questions about your joints and nails. Psoriasis can affect joints, and early checks help."
        }
    }
}
