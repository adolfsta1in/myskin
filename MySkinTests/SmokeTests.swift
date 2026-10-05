import Testing
@testable import MySkin

/// Checks that the test target is wired to the app module.
struct SmokeTests {
    @Test func appModuleIsReachable() {
        #expect(!BodyZone.all.isEmpty)
    }
}
