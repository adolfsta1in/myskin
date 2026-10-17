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
