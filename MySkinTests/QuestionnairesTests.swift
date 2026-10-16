import Foundation
import Testing
@testable import MySkin

struct QuestionnairesTests {
    /// Index of the option with the given score in every question.
    private func answers(_ kind: QuestionnaireKind, scoring points: [Int]) -> [Int] {
        zip(Questionnaires.questions(for: kind), points).map { question, point in
            question.options.firstIndex { $0.score == point } ?? -1
        }
    }

    // MARK: - Skin impact

    @Test func skinImpactHasSixQuestionsScoredZeroToThree() {
        #expect(SkinImpact.questions.count == 6)
        #expect(SkinImpact.questions.map(\.id) == Array(1...6))
        #expect(SkinImpact.questions.allSatisfy { $0.options.map(\.score) == [0, 1, 2, 3] })
    }

    @Test func skinImpactRangeIsZeroToEighteen() {
        #expect(Questionnaires.score(.skinImpact, answers: answers(.skinImpact, scoring: Array(repeating: 0, count: 6))) == 0)
        #expect(Questionnaires.score(.skinImpact, answers: answers(.skinImpact, scoring: Array(repeating: 3, count: 6))) == SkinImpact.maxScore)
    }

    @Test func incompleteOrInvalidAnswersHaveNoScore() {
        #expect(Questionnaires.score(.skinImpact, answers: [0, 0, 0]) == nil)
        #expect(Questionnaires.score(.skinImpact, answers: Array(repeating: 9, count: 6)) == nil)
        #expect(Questionnaires.score(.skinImpact, answers: Array(repeating: -1, count: 6)) == nil)
    }

    @Test(arguments: [
        (0, SkinImpact.Level.none), (1, .small), (4, .small), (5, .moderate), (9, .moderate), (10, .large), (18, .large),
    ])
    func skinImpactLevels(score: Int, expected: SkinImpact.Level) {
        #expect(SkinImpact.level(for: score) == expected)
    }

    @Test func largeSkinImpactSuggestsTheDoctor() {
        #expect(!Questionnaires.needsAttention(.skinImpact, score: 9))
        #expect(Questionnaires.needsAttention(.skinImpact, score: 10))
        #expect(SkinImpact.interpretation(for: 10).contains("doctor"))
    }

    // MARK: - Joint check

    @Test func jointCheckHasSixYesNoQuestions() {
        #expect(JointCheck.questions.count == 6)
        #expect(JointCheck.questions.allSatisfy { $0.options.map(\.score) == [1, 0] })
    }

    @Test(arguments: [(0, false), (1, false), (2, true), (6, true)])
    func jointCheckThreshold(yesCount: Int, attention: Bool) throws {
        let points = Array(repeating: 1, count: yesCount) + Array(repeating: 0, count: 6 - yesCount)
        let score = try #require(Questionnaires.score(.jointCheck, answers: answers(.jointCheck, scoring: points)))
        #expect(score == yesCount)
        #expect(Questionnaires.needsAttention(.jointCheck, score: score) == attention)
    }

    @Test func positiveJointCheckPointsToADoctorWithoutDiagnosis() {
        let text = JointCheck.interpretation(for: 2)
        #expect(text.contains("rheumatologist"))
        #expect(!text.lowercased().contains("arthritis"))
        #expect(JointCheck.headline(for: 2) == "Discuss your joints with a doctor")
    }

    // MARK: - Retired questionnaires

    @Test func retiredKindsCanOnlyBeShown() {
        #expect(QuestionnaireKind.current == [.skinImpact, .jointCheck])
        for kind in [QuestionnaireKind.dlqi, .pest] {
            #expect(kind.isRetired)
            #expect(Questionnaires.questions(for: kind).isEmpty)
            #expect(Questionnaires.score(kind, answers: []) == nil)
        }
        #expect(Questionnaires.maxScore(.dlqi) == 30)
        #expect(Questionnaires.maxScore(.pest) == 5)
        #expect(Questionnaires.needsAttention(.pest, score: 3))
        #expect(!Questionnaires.needsAttention(.dlqi, score: 10))
    }

    @Test func latestJointQuestionnaireDecides() {
        let now = Date.now
        let earlier = now.addingTimeInterval(-86_400)
        #expect(!Questionnaires.jointSymptomsNoted(results: []))
        #expect(Questionnaires.jointSymptomsNoted(results: [(.pest, earlier, 3)]))
        #expect(!Questionnaires.jointSymptomsNoted(results: [(.pest, earlier, 3), (.jointCheck, now, 1)]))
        #expect(Questionnaires.jointSymptomsNoted(results: [(.jointCheck, now, 2), (.skinImpact, now, 0)]))
        #expect(!Questionnaires.jointSymptomsNoted(results: [(.jointCheck, now, 2)], by: earlier))
    }
}
