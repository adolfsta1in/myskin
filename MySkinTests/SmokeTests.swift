import Testing
@testable import MyApp

/// Checks that the test target is wired to the app module.
struct SmokeTests {
    @Test func appModuleIsReachable() {
        #expect(!BodyZone.all.isEmpty)
    }
}
