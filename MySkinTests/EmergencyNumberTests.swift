import Foundation
import Testing
@testable import MySkin

struct EmergencyNumberTests {
    @Test func regionalNumbers() {
        #expect(EmergencyNumber.number(forRegion: "US") == "911")
        #expect(EmergencyNumber.number(forRegion: "au") == "000")
        #expect(EmergencyNumber.number(forRegion: "KG") == "112")
        #expect(EmergencyNumber.number(forRegion: "DE") == "112")
        #expect(EmergencyNumber.number(forRegion: nil) == "112")
        #expect(EmergencyNumber.number(forRegion: "BR") == "192")
        #expect(EmergencyNumber.number(forRegion: "MX") == "911")
        #expect(EmergencyNumber.number(forRegion: "CO") == "123")
        #expect(EmergencyNumber.number(forRegion: "ES") == "112")
    }

    @Test func callURL() {
        #expect(EmergencyNumber.url("112")?.absoluteString == "tel:112")
    }
}
