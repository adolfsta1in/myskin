import Foundation
import Testing
@testable import MySkin

struct LocalizationTests {
    nonisolated static let languages = ["de", "pt-BR", "es-419"]

    @Test func appShipsTheSupportedLanguages() {
        let shipped = Set(Bundle.main.localizations)
        for language in Self.languages {
            #expect(shipped.contains(language), "\(language) is missing from the app bundle")
        }
    }

    @Test(arguments: languages)
    func permissionTextsAreTranslated(language: String) throws {
        let path = try #require(Bundle.main.path(forResource: language, ofType: "lproj"))
        let bundle = try #require(Bundle(path: path))
        for key in ["NSCameraUsageDescription", "NSFaceIDUsageDescription", "NSLocationWhenInUseUsageDescription"] {
            let english = try #require(Bundle.main.object(forInfoDictionaryKey: key) as? String)
            let translated = bundle.localizedString(forKey: key, value: nil, table: "InfoPlist")
            #expect(translated != key)
            #expect(translated != english, "\(key) isn't translated into \(language)")
        }
    }
}

struct LocalizedTextTests {
    private func bundle(_ language: String) throws -> Bundle {
        let path = try #require(Bundle.main.path(forResource: language, ofType: "lproj"))
        return try #require(Bundle(path: path))
    }

    @Test(arguments: LocalizationTests.languages)
    func logicAndScreenTextsAreTranslated(language: String) throws {
        let bundle = try bundle(language)
        for key in ["Seek medical care now", "Calm mode", "Time for your diary check-in.", "Left elbow", "Report for your doctor"] {
            let translated = bundle.localizedString(forKey: key, value: nil, table: nil)
            #expect(translated != key, "«\(key)» isn't translated into \(language)")
        }
    }

    @Test func pluralsFollowTheCount() throws {
        let german = try bundle("de")
        let locale = Locale(identifier: "de")
        #expect(String(localized: "Every \(1) days", bundle: german, locale: locale) == "Jeden Tag")
        #expect(String(localized: "Every \(3) days", bundle: german, locale: locale) == "Alle 3 Tage")
        let portuguese = try bundle("pt-BR")
        let brazil = Locale(identifier: "pt-BR")
        #expect(String(localized: "\(1) photos of this area", bundle: portuguese, locale: brazil) == "1 foto desta área")
        #expect(String(localized: "\(4) photos of this area", bundle: portuguese, locale: brazil) == "4 fotos desta área")
    }

    @Test func englishReadsWellForOne() {
        #expect(String(localized: "\(1) photos of this area") == "1 photo of this area")
        #expect(DoseScheduler.summary(for: DoseSchedule(kind: .everyNDays, interval: 3, startDate: .now)) == "Every 3 days")
    }
}

struct AppLanguageTests {
    private func defaults() throws -> (UserDefaults, String) {
        let name = "AppLanguageTests-\(UUID().uuidString)"
        return (try #require(UserDefaults(suiteName: name)), name)
    }

    @Test func followsTheIPhoneUntilChosen() throws {
        let (defaults, name) = try defaults()
        defer { defaults.removePersistentDomain(forName: name) }
        #expect(AppLanguage.chosen(in: defaults, domain: name) == .system)
    }

    @Test(arguments: AppLanguage.languages)
    func remembersTheChoice(language: AppLanguage) throws {
        let (defaults, name) = try defaults()
        defer { defaults.removePersistentDomain(forName: name) }
        AppLanguage.choose(language, in: defaults)
        // Read the app's own domain: the test run passes -AppleLanguages, which shadows `stringArray`.
        #expect(defaults.persistentDomain(forName: name)?[AppLanguage.defaultsKey] as? [String] == [language.rawValue])
        #expect(AppLanguage.chosen(in: defaults, domain: name) == language)
        AppLanguage.choose(.system, in: defaults)
        #expect(AppLanguage.chosen(in: defaults, domain: name) == .system)
    }

    @Test func languagesAreNamedInTheirOwnLanguage() {
        #expect(AppLanguage.german.nativeName == "Deutsch")
        #expect(AppLanguage.portugueseBrazil.nativeName == "Português (Brasil)")
        #expect(AppLanguage.spanishLatinAmerica.nativeName == "Español (Latinoamérica)")
    }
}
