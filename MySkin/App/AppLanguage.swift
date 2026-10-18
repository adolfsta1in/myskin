import Foundation

/// The app's own language, chosen in Settings. iOS keeps per-app languages in the app's `AppleLanguages`
/// default (the same one the iOS Settings app writes), and reads it at launch — so a change shows
/// after Velvi is reopened.
nonisolated enum AppLanguage: String, CaseIterable, Identifiable, Sendable {
    case system
    case english = "en"
    case german = "de"
    case portugueseBrazil = "pt-BR"
    case spanishLatinAmerica = "es-419"

    var id: String { rawValue }

    static let defaultsKey = "AppleLanguages"

    /// Languages are listed in their own language, so people can find theirs whatever the app shows.
    var nativeName: String {
        switch self {
        case .system: String(localized: "Same as iPhone")
        case .english: "English"
        case .german: "Deutsch"
        case .portugueseBrazil: "Português (Brasil)"
        case .spanishLatinAmerica: "Español (Latinoamérica)"
        }
    }

    static var languages: [AppLanguage] { allCases.filter { $0 != .system } }

    /// The language chosen for this app only; `.system` when it follows the iPhone.
    static func chosen(in defaults: UserDefaults = .standard, domain: String? = Bundle.main.bundleIdentifier) -> AppLanguage {
        guard let domain,
              let preferences = defaults.persistentDomain(forName: domain)?[defaultsKey] as? [String],
              !preferences.isEmpty else { return .system }
        let match = Bundle.preferredLocalizations(from: languages.map(\.rawValue), forPreferences: preferences).first
        return match.flatMap(AppLanguage.init(rawValue:)) ?? .system
    }

    static func choose(_ language: AppLanguage, in defaults: UserDefaults = .standard) {
        if language == .system {
            defaults.removeObject(forKey: defaultsKey)
        } else {
            defaults.set([language.rawValue], forKey: defaultsKey)
        }
    }

    /// The language Velvi is showing in this launch.
    static var shown: AppLanguage {
        Bundle.main.preferredLocalizations.first.flatMap(AppLanguage.init(rawValue:)) ?? .english
    }
}
