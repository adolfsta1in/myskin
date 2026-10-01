import Testing
@testable import MyApp

struct QuestionnairesTests {
    /// Index of the option with the given score in every question.
    private func answers(_ kind: QuestionnaireKind, scoring points: [Int]) -> [Int] {
        zip(Questionnaires.questions(for: kind), points).map { question, point in
            question.options.firstIndex { $0.score == point } ?? -1
        }
    }

    // MARK: - DLQI

    @Test func dlqiHasTenQuestionsScoredZeroToThree() {
        #expect(DLQI.questions.count == 10)
        #expect(DLQI.questions.map(\.id) == Array(1...10))
        for question in DLQI.questions {
            #expect(question.options.map(\.score).max() == 3)
            #expect(question.options.map(\.score).min() == 0)
        }
    }

    @Test func dlqiRangeIsZeroToThirty() {
        #expect(Questionnaires.score(.dlqi, answers: answers(.dlqi, scoring: Array(repeating: 0, count: 10))) == 0)
        #expect(Questionnaires.score(.dlqi, answers: answers(.dlqi, scoring: Array(repeating: 3, count: 10))) == DLQI.maxScore)
    }

    @Test func dlqiNotRelevantScoresZero() {
        // Question 3 offers "Not relevant" as its last option.
        var raw = answers(.dlqi, scoring: [1, 1, 0, 0, 0, 0, 0, 0, 0, 0])
        raw[2] = DLQI.questions[2].options.count - 1
        #expect(DLQI.questions[2].options[raw[2]].title == "Not relevant")
        #expect(Questionnaires.score(.dlqi, answers: raw) == 2)
    }

    @Test func dlqiWorkQuestionYesScoresThree() {
        #expect(DLQI.questions[6].options.first?.score == 3)
    }

    @Test func incompleteOrInvalidAnswersHaveNoScore() {
        #expect(Questionnaires.score(.dlqi, answers: [0, 0, 0]) == nil)
        #expect(Questionnaires.score(.dlqi, answers: Array(repeating: 9, count: 10)) == nil)
        #expect(Questionnaires.score(.dlqi, answers: Array(repeating: -1, count: 10)) == nil)
    }

    @Test(arguments: [
        (0, DLQI.Band.none), (1, .none), (2, .small), (5, .small), (6, .moderate),
        (10, .moderate), (11, .veryLarge), (20, .veryLarge), (21, .extremelyLarge), (30, .extremelyLarge),
    ])
    func dlqiBands(score: Int, expected: DLQI.Band) {
        #expect(DLQI.band(for: score) == expected)
    }

    @Test func dlqiGoalAndRuleOfTens() {
        #expect(DLQI.isAtGoal(0))
        #expect(DLQI.isAtGoal(1))
        #expect(!DLQI.isAtGoal(2))
        #expect(!DLQI.isVeryLargeEffect(10))
        #expect(DLQI.isVeryLargeEffect(11))
        #expect(DLQI.interpretation(for: 11).contains("discuss with your doctor"))
    }

    // MARK: - PEST

    @Test func pestHasFiveYesNoQuestions() {
        #expect(PEST.questions.count == 5)
        #expect(PEST.questions.allSatisfy { $0.options.map(\.score) == [1, 0] })
    }

    @Test(arguments: [(0, false), (2, false), (3, true), (5, true)])
    func pestReferral(yesCount: Int, referral: Bool) throws {
        let points = Array(repeating: 1, count: yesCount) + Array(repeating: 0, count: 5 - yesCount)
        let score = try #require(Questionnaires.score(.pest, answers: answers(.pest, scoring: points)))
        #expect(score == yesCount)
        #expect(PEST.suggestsRheumatologist(score) == referral)
    }

    @Test func pestPositiveMentionsRheumatologist() {
        #expect(PEST.interpretation(for: 3).contains("rheumatologist"))
    }
}
