import Foundation
import SwiftData
import Testing
@testable import MyApp

struct DoseRowsTests {
    private func makeContext() throws -> ModelContext {
        ModelContext(try AppModelContainer.makeInMemory())
    }

    private var today: Date { Calendar.current.startOfDay(for: .now) }
    private var tomorrow: Date { Calendar.current.date(byAdding: .day, value: 1, to: today) ?? today }

    private func cream(in context: ModelContext) -> Treatment {
        let treatment = Treatment(
            name: "Cream", kind: .cream, scheduleKind: .timesPerDay, timesPerDay: 2,
            startDate: Calendar.current.date(byAdding: .day, value: -5, to: today) ?? today
        )
        context.insert(treatment)
        return treatment
    }

    @Test func twiceADayGivesTwoRows() throws {
        let context = try makeContext()
        _ = cream(in: context)
        let rows = DoseRows.rows(for: try context.fetch(FetchDescriptor<Treatment>()), on: today)
        #expect(rows.count == 2)
        #expect(rows.allSatisfy { !$0.isDone })
    }

    @Test func markingSurvivesFetchAndNextDayIsOpen() throws {
        let context = try makeContext()
        _ = cream(in: context)
        try context.save()
        let first = try #require(DoseRows.rows(for: try context.fetch(FetchDescriptor<Treatment>()), on: today).first)
        try DoseRows.toggle(first, in: context)

        let treatments = try context.fetch(FetchDescriptor<Treatment>())
        let todayRows = DoseRows.rows(for: treatments, on: today)
        #expect(todayRows.map(\.isDone) == [true, false])
        #expect(try context.fetchCount(FetchDescriptor<DoseLog>()) == 1)
        #expect(DoseRows.rows(for: treatments, on: tomorrow).allSatisfy { !$0.isDone })
    }

    @Test func untickingRemovesTheLog() throws {
        let context = try makeContext()
        _ = cream(in: context)
        try context.save()
        let first = try #require(DoseRows.rows(for: try context.fetch(FetchDescriptor<Treatment>()), on: today).first)
        try DoseRows.toggle(first, in: context)
        let done = try #require(DoseRows.rows(for: try context.fetch(FetchDescriptor<Treatment>()), on: today).first)
        try DoseRows.toggle(done, in: context)

        #expect(try context.fetchCount(FetchDescriptor<DoseLog>()) == 0)
        #expect(DoseRows.rows(for: try context.fetch(FetchDescriptor<Treatment>()), on: today).allSatisfy { !$0.isDone })
    }

    @Test func stoppedTreatmentsHaveNoRows() throws {
        let context = try makeContext()
        let treatment = cream(in: context)
        TreatmentDraft.stop(treatment, reason: "", at: Calendar.current.date(byAdding: .day, value: -1, to: today) ?? today)
        #expect(DoseRows.rows(for: [treatment], on: today).isEmpty)
    }
}
