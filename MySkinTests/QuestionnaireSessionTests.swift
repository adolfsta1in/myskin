import Foundation
import SwiftData
import Testing
@testable import MySkin

struct QuestionnaireSessionTests {
    @Test func skinImpactAllALotScoresEighteen() throws {
        var session = QuestionnaireSession(kind: .skinImpact)
        for _ in 0..<6 { session.answer(3) }
        #expect(session.isFinished)
        #expect(session.score == 18)
        let result = try #require(session.makeResult())
        #expect(result.kind == .skinImpact)
        #expect(result.answers == Array(repeating: 3, count: 6))
        #expect(Questionnaires.headline(.skinImpact, score: 18) == "Large impact")
    }

    @Test func unfinishedHasNoScore() {
        var session = QuestionnaireSession(kind: .skinImpact)
        session.answer(1)
        session.answer(1)
        #expect(!session.isFinished)
        #expect(session.score == nil)
        #expect(session.makeResult() == nil)
        #expect(abs(session.progress - 2.0 / 6.0) < 0.000_1)
    }

    @Test func goingBackKeepsTheAnswerAndCanChangeIt() {
        var session = QuestionnaireSession(kind: .jointCheck)
        session.answer(0)
        session.answer(0)
        session.goBack()
        #expect(session.index == 1)
        #expect(session.answers[1] == 0)
        session.answer(1)
        #expect(session.answers[1] == 1)
        #expect(session.index == 2)
    }

    @Test func outOfRangeOptionIsIgnored() {
        var session = QuestionnaireSession(kind: .jointCheck)
        session.answer(5)
        #expect(session.index == 0)
        #expect(session.answers[0] == nil)
    }

    @Test func noImpactHeadline() {
        var session = QuestionnaireSession(kind: .skinImpact)
        for _ in 0..<6 { session.answer(0) }
        #expect(session.score == 0)
        #expect(Questionnaires.headline(.skinImpact, score: 0) == "No impact this week")
    }

    @Test func jointCheckTwoYesSuggestsADoctor() {
        var session = QuestionnaireSession(kind: .jointCheck)
        [0, 0, 1, 1, 1, 1].forEach { session.answer($0) }
        #expect(session.score == 2)
        #expect(Questionnaires.headline(.jointCheck, score: 2) == "Discuss your joints with a doctor")
        #expect(Questionnaires.needsAttention(.jointCheck, score: 2))
        #expect(!Questionnaires.needsAttention(.jointCheck, score: 1))
    }

    @Test func retiredKindIsFinishedWithoutAResult() {
        let session = QuestionnaireSession(kind: .dlqi)
        #expect(session.questions.isEmpty)
        #expect(session.makeResult() == nil)
    }

    @Test func resultSurvivesFetch() throws {
        let context = ModelContext(try AppModelContainer.makeInMemory())
        var session = QuestionnaireSession(kind: .skinImpact)
        for _ in 0..<6 { session.answer(2) }
        context.insert(try #require(session.makeResult()))
        try context.save()
        let stored = try context.fetch(FetchDescriptor<QuestionnaireResult>())
        #expect(stored.count == 1)
        #expect(stored.first?.score == 12)
    }
}
