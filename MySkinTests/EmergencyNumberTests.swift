import Foundation
import Testing
@testable import MyApp

struct EmergencyNumberTests {
    @Test func regionalNumbers() {
        #expect(EmergencyNumber.number(forRegion: "US") == "911")
        #expect(EmergencyNumber.number(forRegion: "au") == "000")
        #expect(EmergencyNumber.number(forRegion: "KG") == "112")
        #expect(EmergencyNumber.number(forRegion: "DE") == "112")
        #expect(EmergencyNumber.number(forRegion: nil) == "112")
    }

    @Test func callURL() {
        #expect(EmergencyNumber.url("112")?.absoluteString == "tel:112")
    }
}
