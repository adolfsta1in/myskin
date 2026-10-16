import Foundation
import Observation

/// Remote config for the session: the last good file from disk, refreshed from our site.
/// The request carries nothing about the user — a plain GET without cookies, cache or query.
@Observable
final class RemoteConfigStore {
    /// Our static JSON file. nil until the site exists (release plan A3 / phase C):
    /// then the app makes no request at all and runs on `RemoteConfig.builtIn`.
    static let endpoint: URL? = nil

    private(set) var config: RemoteConfig
    private(set) var dismissedAnnouncementID: String?
    @ObservationIgnored private let endpoint: URL?
    @ObservationIgnored private let cacheFile: URL?
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private var lastAttempt: Date?
    @ObservationIgnored private var isFetching = false

    /// Never rename: existing installs read it.
    enum Key {
        static let dismissedAnnouncementID = "dismissedAnnouncementID"
    }

    init(endpoint: URL? = RemoteConfigStore.endpoint, cacheFile: URL? = RemoteConfigStore.defaultCacheFile(), defaults: UserDefaults = .standard) {
        self.endpoint = endpoint
        self.cacheFile = cacheFile
        self.defaults = defaults
        dismissedAnnouncementID = defaults.string(forKey: Key.dismissedAnnouncementID)
        config = cacheFile.flatMap { try? Data(contentsOf: $0) }.flatMap(RemoteConfig.parse) ?? .builtIn
    }

    var currentVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
    }

    var requiresUpdate: Bool { config.requiresUpdate(currentVersion: currentVersion) }

    func isEnabled(_ feature: RemoteFeature) -> Bool { config.isEnabled(feature) }

    func announcement(now: Date = .now) -> RemoteAnnouncement? {
        config.activeAnnouncement(now: now, dismissedID: dismissedAnnouncementID)
    }

    func dismiss(_ announcement: RemoteAnnouncement) {
        dismissedAnnouncementID = announcement.id
        defaults.set(announcement.id, forKey: Key.dismissedAnnouncementID)
    }

    /// Fetches the file at most every `RemoteConfigPolicy.refreshInterval`. Any failure keeps the last good config.
    func refresh(now: Date = .now) async {
        guard let endpoint, !isFetching, RemoteConfigPolicy.mayFetch(now: now, lastAttempt: lastAttempt) else { return }
        isFetching = true
        lastAttempt = now
        defer { isFetching = false }
        guard let data = try? await Self.download(endpoint), let fresh = RemoteConfig.parse(data) else { return }
        config = fresh
        if let cacheFile { Self.save(data, to: cacheFile) }
    }

    @concurrent
    private static func download(_ url: URL) async throws -> Data {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.httpCookieStorage = nil
        configuration.urlCache = nil
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.timeoutIntervalForRequest = 10
        let session = URLSession(configuration: configuration)
        defer { session.finishTasksAndInvalidate() }
        let (data, response) = try await session.data(from: url)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200,
              http.url?.scheme == "https" else { throw URLError(.badServerResponse) }
        return data
    }

    private static func save(_ data: Data, to file: URL) {
        let manager = FileManager.default
        try? manager.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? data.write(to: file, options: .atomic)
        // Nothing personal, but no reason to put it in backups either.
        var url = file
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try? url.setResourceValues(values)
    }

    static func defaultCacheFile() -> URL? {
        guard let support = try? FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true) else { return nil }
        return support.appending(path: "RemoteConfig/config.json")
    }
}
