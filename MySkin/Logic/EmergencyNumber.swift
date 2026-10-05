import Foundation

/// Emergency phone number for the red-flag screen. 112 works on mobile phones in most countries;
/// a few regions use their own number.
enum EmergencyNumber {
    static func number(forRegion region: String?) -> String {
        switch region?.uppercased() {
        case "US", "CA", "MX", "PR": "911"
        case "AU": "000"
        case "NZ": "111"
        case "IN": "112"
        case "JP", "KR", "TW": "119"
        case "CN": "120"
        default: "112"
        }
    }

    static var current: String { number(forRegion: Locale.current.region?.identifier) }

    static func url(_ number: String) -> URL? { URL(string: "tel:\(number)") }
}
