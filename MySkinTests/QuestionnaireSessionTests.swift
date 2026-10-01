import Foundation
import SwiftData
import Testing
@testable import MyApp

struct QuestionnaireSessionTests {
    @Test func dlqiAllVeryMuchScoresThirty() throws {
        var session = QuestionnaireSession(kind: .dlqi)
        for _ in 0..<10 { session.answer(0) }
        #expect(session.isFinished)
        #expect(session.score == 30)
        let result = try #require(session.makeResult())
        #expect(result.kind == .dlqi)
        #expect(result.answers == Array(repeating: 0, count: 10))
        #expect(Questionnaires.headline(.dlqi, score: 30) == "Extremely large effect")
    }

    @Test func unfinishedHasNoScore() {
        var session = QuestionnaireSession(kind: .dlqi)
        session.answer(1)
        #expect(!session.isFinished)
        #expect(session.score == nil)
        #expect(session.makeResult() == nil)
        #expect(session.progress == 0.1)
    }

    @Test func goingBackKeepsTheAnswerAndCanChangeIt() {
        var session = QuestionnaireSession(kind: .pest)
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
        var session = QuestionnaireSession(kind: .pest)
        session.answer(5)
        #expect(session.index == 0)
        #expect(session.answers[0] == nil)
    }

    @Test func notRelevantScoresZeroButIsKept() {
        var session = QuestionnaireSession(kind: .dlqi)
        session.answer(3) // Q1: not at all
        session.answer(3) // Q2: not at all
        for _ in 0..<8 { session.answer(4) } // Q3–10: not relevant
        #expect(session.score == 0)
        #expect(session.makeResult()?.answers.last == 4)
        #expect(Questionnaires.headline(.dlqi, score: 0) == "No effect on your life")
    }

    @Test func pestThreeYesSuggestsRheumatologist() {
        var session = QuestionnaireSession(kind: .pest)
        [0, 0, 0, 1, 1].forEach { session.answer($0) }
        #expect(session.score == 3)
        #expect(Questionnaires.headline(.pest, score: 3) == "Tell a rheumatologist")
        #expect(Questionnaires.needsAttention(.pest, score: 3))
        #expect(!Questionnaires.needsAttention(.pest, score: 2))
    }

    @Test func resultSurvivesFetch() throws {
        let context = ModelContext(try AppModelContainer.makeInMemory())
        var session = QuestionnaireSession(kind: .dlqi)
        for _ in 0..<10 { session.answer(2) }
        context.insert(try #require(session.makeResult()))
        try context.save()
        let stored = try context.fetch(FetchDescriptor<QuestionnaireResult>())
        #expect(stored.count == 1)
        #expect(stored.first?.score == 10)
    }
}
