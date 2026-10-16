import Foundation

// Small JSON file from our site that can only *restrict* reviewed behaviour or show a notice:
// a minimum app version, switches that turn reviewed features off, an optional announcement.
// It never adds features or code (App Review 2.5.2). Medical texts stay in the build.
// Without a file (no network, bad JSON, wrong schema) the app uses `RemoteConfig.builtIn`.

/// Features the config may switch off. Unknown names in the file are ignored.
nonisolated enum RemoteFeature: String, CaseIterable, Sendable {
    case weather
}

nonisolated struct RemoteAnnouncement: Equatable, Sendable {
    /// Stable id: once dismissed, an announcement with this id isn't shown again.
    let id: String
    let title: String
    let message: String
    let link: URL?
    /// Shown until this moment; nil — until the file changes.
    let until: Date?
}

nonisolated struct RemoteConfig: Equatable, Sendable {
    /// Schema this build understands. A file with another schema is ignored.
    static let schemaVersion = 1
    /// Larger files are ignored: the real file is a few hundred bytes.
    static let maxBytes = 64 * 1024
    static let maxTitleLength = 80
    static let maxMessageLength = 400

    var minimumVersion: String?
    /// App Store page for the update screen; only apps.apple.com links are accepted.
    var updateURL: URL?
    var disabledFeatures: Set<RemoteFeature>
    var announcement: RemoteAnnouncement?

    /// What the app does with no file at all: everything reviewed is on, nothing to announce.
    static let builtIn = RemoteConfig(minimumVersion: nil, updateURL: nil, disabledFeatures: [], announcement: nil)

    func isEnabled(_ feature: RemoteFeature) -> Bool { !disabledFeatures.contains(feature) }

    /// True if this build is older than `minimumVersion`.
    func requiresUpdate(currentVersion: String) -> Bool {
        guard let minimumVersion else { return false }
        return AppVersion.isOlder(currentVersion, than: minimumVersion)
    }

    /// Announcement to show now, unless it's expired or the user dismissed it.
    func activeAnnouncement(now: Date, dismissedID: String?) -> RemoteAnnouncement? {
        guard let announcement, announcement.id != dismissedID else { return nil }
        if let until = announcement.until, now >= until { return nil }
        return announcement
    }

    // MARK: Parsing

    private struct File: Decodable {
        struct Announcement: Decodable {
            let id: String
            let title: String
            let message: String
            let link: String?
            let until: Date?
        }
        let schema: Int
        let minimumVersion: String?
        let updateURL: String?
        let disabledFeatures: [String]?
        let announcement: Announcement?
    }

    /// Parses and checks the file; nil means "ignore it, keep the last good config".
    /// Bad optional parts (a non-https link, an empty announcement) are dropped, not fatal.
    static func parse(_ data: Data) -> RemoteConfig? {
        guard data.count <= maxBytes else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let file = try? decoder.decode(File.self, from: data), file.schema == schemaVersion else { return nil }

        let minimumVersion = file.minimumVersion.flatMap { AppVersion.components($0) == nil ? nil : $0 }
        let updateURL = file.updateURL.flatMap { safeURL($0, hosts: ["apps.apple.com"]) }
        let features = Set((file.disabledFeatures ?? []).compactMap(RemoteFeature.init(rawValue:)))
        let announcement = file.announcement.flatMap { item -> RemoteAnnouncement? in
            let id = item.id.trimmingCharacters(in: .whitespacesAndNewlines)
            let title = item.title.trimmingCharacters(in: .whitespacesAndNewlines)
            let message = item.message.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !id.isEmpty, !title.isEmpty,
                  title.count <= maxTitleLength, message.count <= maxMessageLength else { return nil }
            return RemoteAnnouncement(id: id, title: title, message: message,
                                      link: item.link.flatMap { safeURL($0, hosts: nil) }, until: item.until)
        }
        return RemoteConfig(minimumVersion: minimumVersion, updateURL: updateURL,
                            disabledFeatures: features, announcement: announcement)
    }

    /// Only https links without query or fragment (no tracking parameters); `hosts` limits where they go.
    static func safeURL(_ string: String, hosts: Set<String>?) -> URL? {
        guard let components = URLComponents(string: string),
              components.scheme == "https",
              let host = components.host?.lowercased(), !host.isEmpty,
              components.query == nil, components.fragment == nil,
              components.user == nil, components.password == nil else { return nil }
        if let hosts, !hosts.contains(host) { return nil }
        return components.url
    }
}

/// Dotted numeric versions: "1.0" == "1.0.0" < "1.0.1" < "1.10".
nonisolated enum AppVersion {
    static func components(_ version: String) -> [Int]? {
        let parts = version.trimmingCharacters(in: .whitespaces).split(separator: ".", omittingEmptySubsequences: false)
        guard !parts.isEmpty, parts.count <= 4 else { return nil }
        var numbers: [Int] = []
        for part in parts {
            guard !part.isEmpty, part.allSatisfy({ $0.isASCII && $0.isNumber }), let number = Int(part), number >= 0 else { return nil }
            numbers.append(number)
        }
        return numbers
    }

    /// Unparsable versions never force an update.
    static func isOlder(_ version: String, than other: String) -> Bool {
        guard var lhs = components(version), var rhs = components(other) else { return false }
        let count = max(lhs.count, rhs.count)
        lhs += Array(repeating: 0, count: count - lhs.count)
        rhs += Array(repeating: 0, count: count - rhs.count)
        return lhs.lexicographicallyPrecedes(rhs)
    }
}

/// When the app may fetch the file again: on launch / foreground, at most every 6 hours.
nonisolated enum RemoteConfigPolicy {
    static let refreshInterval: TimeInterval = 6 * 60 * 60

    static func mayFetch(now: Date, lastAttempt: Date?) -> Bool {
        guard let lastAttempt else { return true }
        // A clock moved backwards shouldn't block fetching forever.
        return now.timeIntervalSince(lastAttempt) >= refreshInterval || now < lastAttempt
    }
}
