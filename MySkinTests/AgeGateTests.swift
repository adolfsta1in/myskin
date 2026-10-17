import Testing
@testable import MySkin

struct AgeGateTests {
    @Test func notRequiredOutsideRegulatedRegions() {
        #expect(AgeGate.status(isRequired: false, answer: nil) == .notRequired)
        #expect(!AgeGate.isBlocked(.notRequired))
    }

    @Test func unknownWhenTheCheckCantRun() {
        #expect(AgeGate.status(isRequired: nil, answer: nil) == .unknown)
        #expect(AgeGate.status(isRequired: true, answer: .failed) == .unknown)
        #expect(AgeGate.status(isRequired: true, answer: .declined) == .unknown)
        #expect(!AgeGate.isBlocked(.unknown))
    }

    @Test func sixteenAndOlderAreAllowed() {
        #expect(AgeGate.status(isRequired: true, answer: .sharing(lowerBound: 16)) == .allowed)
        #expect(AgeGate.status(isRequired: true, answer: .sharing(lowerBound: 18)) == .allowed)
    }

    @Test func underSixteenIsBlocked() {
        // nil lower bound: below the lowest age gate (16).
        #expect(AgeGate.status(isRequired: true, answer: .sharing(lowerBound: nil)) == .underMinimum)
        // Regional rules may override our gates, e.g. a 13–15 range.
        #expect(AgeGate.status(isRequired: true, answer: .sharing(lowerBound: 13)) == .underMinimum)
        #expect(AgeGate.isBlocked(.underMinimum))
    }
}
