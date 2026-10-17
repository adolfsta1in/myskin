import Foundation
import Testing
@testable import MySkin

struct RemoteConfigTests {
    private func parse(_ json: String) -> RemoteConfig? { RemoteConfig.parse(Data(json.utf8)) }

    @Test func parsesAFullFile() throws {
        let config = try #require(parse("""
        {"schema":1,"minimumVersion":"1.0.2","updateURL":"https://apps.apple.com/app/id123",
         "disabledFeatures":["weather","somethingNew"],
         "announcement":{"id":"a1","title":"Hello","message":"News","link":"https://myskin.example/news","until":"2026-12-01T00:00:00Z"}}
        """))
        #expect(config.minimumVersion == "1.0.2")
        #expect(config.updateURL?.absoluteString == "https://apps.apple.com/app/id123")
        #expect(config.disabledFeatures == [.weather])
        #expect(!config.isEnabled(.weather))
        #expect(config.announcement?.id == "a1")
        #expect(config.announcement?.link != nil)
    }

    @Test func badOptionalPartKeepsTheRest() throws {
        let config = try #require(parse("""
        {"schema":1,"minimumVersion":"1.2","updateURL":42,"disabledFeatures":["weather",7],
         "announcement":{"id":"a1","title":"Hello","message":"News","until":"soon"}}
        """))
        #expect(config.minimumVersion == "1.2")
        #expect(config.updateURL == nil)
        #expect(config.disabledFeatures == [.weather])
        // An unreadable end date drops the notice instead of showing it forever.
        #expect(config.announcement == nil)
    }

    @Test func dateOnlyUntilLastsThroughThatDay() throws {
        let config = try #require(parse("""
        {"schema":1,"announcement":{"id":"a1","title":"Hello","message":"","until":"2026-11-01"}}
        """))
        let until = try #require(config.announcement?.until)
        #expect(until == Date(timeIntervalSince1970: 1_793_577_600)) // 2026-11-02T00:00:00Z
    }

    @Test func wrongSchemaOrBrokenJSONIsIgnored() {
        #expect(parse(#"{"schema":2}"#) == nil)
        #expect(parse(#"{"minimumVersion":"1.0"}"#) == nil)
        #expect(parse("not json") == nil)
        #expect(RemoteConfig.parse(Data(repeating: 32, count: RemoteConfig.maxBytes + 1)) == nil)
    }

    @Test func minimalFileTurnsNothingOff() throws {
        let config = try #require(parse(#"{"schema":1}"#))
        #expect(config == .builtIn)
        #expect(RemoteFeature.allCases.allSatisfy(config.isEnabled))
        #expect(!config.requiresUpdate(currentVersion: "1.0"))
    }

    @Test func unsafeLinksAreDropped() throws {
        let config = try #require(parse("""
        {"schema":1,"updateURL":"https://evil.example/app",
         "announcement":{"id":"a","title":"T","message":"M","link":"http://myskin.example"}}
        """))
        #expect(config.updateURL == nil)
        #expect(config.announcement?.link == nil)
        #expect(RemoteConfig.safeURL("https://myskin.example/a?utm_source=app", hosts: nil) == nil)
        #expect(RemoteConfig.safeURL("https://myskin.example/a#x", hosts: nil) == nil)
        #expect(RemoteConfig.safeURL("https://myskin.example/a", hosts: nil) != nil)
    }

    @Test func badAnnouncementIsDroppedButTheRestKept() throws {
        let long = String(repeating: "x", count: RemoteConfig.maxTitleLength + 1)
        let config = try #require(parse("""
        {"schema":1,"minimumVersion":"2.0","announcement":{"id":"a","title":"\(long)","message":""}}
        """))
        #expect(config.announcement == nil)
        #expect(config.minimumVersion == "2.0")
        #expect(parse(#"{"schema":1,"announcement":{"id":" ","title":"T","message":""}}"#)?.announcement == nil)
    }

    @Test func versionComparison() {
        #expect(AppVersion.isOlder("1.0", than: "1.0.1"))
        #expect(AppVersion.isOlder("1.9", than: "1.10"))
        #expect(!AppVersion.isOlder("1.0", than: "1.0.0"))
        #expect(!AppVersion.isOlder("1.1", than: "1.0.9"))
        // Unparsable versions never force an update.
        #expect(!AppVersion.isOlder("1.0", than: "two"))
        #expect(!AppVersion.isOlder("1.0", than: "+2"))
        #expect(parse(#"{"schema":1,"minimumVersion":"latest"}"#)?.minimumVersion == nil)
    }

    @Test func requiresUpdateOnlyBelowMinimum() {
        var config = RemoteConfig.builtIn
        config.minimumVersion = "1.1"
        #expect(config.requiresUpdate(currentVersion: "1.0"))
        #expect(!config.requiresUpdate(currentVersion: "1.1"))
        #expect(!config.requiresUpdate(currentVersion: "1.2"))
    }

    @Test func announcementExpiresAndCanBeDismissed() {
        let until = Date(timeIntervalSince1970: 1_000_000)
        var config = RemoteConfig.builtIn
        config.announcement = RemoteAnnouncement(id: "a1", title: "T", message: "", link: nil, until: until)
        #expect(config.activeAnnouncement(now: until.addingTimeInterval(-1), dismissedID: nil)?.id == "a1")
        #expect(config.activeAnnouncement(now: until, dismissedID: nil) == nil)
        #expect(config.activeAnnouncement(now: until.addingTimeInterval(-1), dismissedID: "a1") == nil)
        #expect(config.activeAnnouncement(now: until.addingTimeInterval(-1), dismissedID: "old") != nil)
    }

    @Test func fetchesAtMostEverySixHours() {
        let start = Date(timeIntervalSince1970: 1_000_000)
        #expect(RemoteConfigPolicy.mayFetch(now: start, lastAttempt: nil))
        #expect(!RemoteConfigPolicy.mayFetch(now: start.addingTimeInterval(60), lastAttempt: start))
        #expect(RemoteConfigPolicy.mayFetch(now: start.addingTimeInterval(RemoteConfigPolicy.refreshInterval), lastAttempt: start))
        #expect(RemoteConfigPolicy.mayFetch(now: start.addingTimeInterval(-60), lastAttempt: start))
    }

    @Test func storeUsesTheCachedFileAndNoEndpointMeansNoRequest() async throws {
        let folder = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        let file = folder.appending(path: "config.json")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        try Data(#"{"schema":1,"disabledFeatures":["weather"]}"#.utf8).write(to: file)
        let defaults = try #require(UserDefaults(suiteName: "RemoteConfigTests.\(UUID().uuidString)"))

        let store = RemoteConfigStore(endpoint: nil, cacheFile: file, defaults: defaults)
        #expect(!store.isEnabled(.weather))
        await store.refresh()
        #expect(!store.isEnabled(.weather))

        // A broken cache falls back to the built-in config.
        try Data("broken".utf8).write(to: file)
        #expect(RemoteConfigStore(endpoint: nil, cacheFile: file, defaults: defaults).config == .builtIn)
    }

    @Test func dismissedAnnouncementIsRemembered() throws {
        let defaults = try #require(UserDefaults(suiteName: "RemoteConfigTests.\(UUID().uuidString)"))
        let store = RemoteConfigStore(endpoint: nil, cacheFile: nil, defaults: defaults)
        store.dismiss(RemoteAnnouncement(id: "a1", title: "T", message: "", link: nil, until: nil))
        #expect(RemoteConfigStore(endpoint: nil, cacheFile: nil, defaults: defaults).dismissedAnnouncementID == "a1")
    }
}
