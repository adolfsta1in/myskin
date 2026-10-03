import Foundation

/// Name, age and greeting rules for the profile.
enum ProfileInfo {
    /// Ages offered in onboarding and settings.
    static let ages = Array(12...100)
    /// Longest name kept; the greeting has to fit on one line.
    static let maxNameLength = 30

    /// Age is stored as a birth year, so it stays right next year.
    static func birthYear(age: Int, now: Date = .now, calendar: Calendar = .current) -> Int {
        calendar.component(.year, from: now) - age
    }

    static func age(birthYear: Int, now: Date = .now, calendar: Calendar = .current) -> Int {
        calendar.component(.year, from: now) - birthYear
    }

    /// Trimmed and shortened; empty means no name.
    static func cleanName(_ raw: String) -> String {
        String(raw.trimmingCharacters(in: .whitespacesAndNewlines).prefix(maxNameLength))
    }

    /// «Good morning, Anna» — or without the name if there is none.
    static func greeting(hour: Int, name: String) -> String {
        let base = switch hour {
        case 5..<12: "Good morning"
        case 12..<18: "Good afternoon"
        default: "Good evening"
        }
        let name = cleanName(name)
        return name.isEmpty ? base : "\(base), \(name)"
    }
}
