import Foundation

/// Emergency phone number for the red-flag screen. 112 works on mobile phones in most countries;
/// a few regions use their own number.
enum EmergencyNumber {
    static func number(forRegion region: String?) -> String {
        switch region?.uppercased() {
        case "US", "CA", "MX", "PR": "911"
        // Latin America: most countries use 911; a few have their own ambulance number.
        case "UY", "EC", "VE", "CR", "PA", "PY", "DO", "SV": "911"
        case "BR": "192"
        case "AR": "107"
        case "CO": "123"
        case "CL": "131"
        case "PE": "106"
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
