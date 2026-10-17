import Foundation

/// Sends anonymous usage counts (`UsageEvent`) to our site. Off in tests and previews; Debug builds are marked
/// `debug` so the server keeps them apart. Switched off by the user in Settings — then nothing is queued or sent.
final class UsageStats {
    static let shared = UsageStats(endpoint: UsageStats.isRealRun ? AppLinks.usageStats : nil)

    /// Never rename: existing installs read these.
    enum Key {
        static let sent = "usageSentEvents"
        static let pending = "usagePendingEvents"
    }

    private let endpoint: URL?
    private let defaults: UserDefaults
    private let send: @Sendable (URL, Data) async throws -> Void
    private var flushTask: Task<Void, Never>?

    init(endpoint: URL?, defaults: UserDefaults = .standard, send: @escaping @Sendable (URL, Data) async throws -> Void = UsageStats.post) {
        self.endpoint = endpoint
        self.defaults = defaults
        self.send = send
        defaults.register(defaults: [AppSettings.Key.shareUsageStats: true])
    }

    var isEnabled: Bool { defaults.bool(forKey: AppSettings.Key.shareUsageStats) }

    var sent: Set<String> { Set(defaults.stringArray(forKey: Key.sent) ?? []) }

    var pending: [UsageRecord] {
        defaults.data(forKey: Key.pending).flatMap { try? JSONDecoder().decode([UsageRecord].self, from: $0) } ?? []
    }

    /// Queues the event once per install and tries to send it.
    func record(_ event: UsageEvent) {
        guard endpoint != nil, UsagePolicy.shouldRecord(event, isEnabled: isEnabled, sent: sent) else { return }
        defaults.set(Array(sent.union([event.onceKey])).sorted(), forKey: Key.sent)
        let record = UsageRecord(event, app: Self.appVersion, lang: UsagePolicy.language(Bundle.main.preferredLocalizations.first), build: Self.build)
        save(UsagePolicy.enqueue(record, into: pending))
        Task { await flush() }
    }

    /// Sends what's waiting; on any failure keeps it for the next try (app becomes active).
    /// A call during a send waits for that send.
    func flush() async {
        if let flushTask { return await flushTask.value }
        let task = Task { await sendPending() }
        flushTask = task
        await task.value
        flushTask = nil
    }

    private func sendPending() async {
        guard let endpoint else { return }
        guard isEnabled else {
            save([])
            return
        }
        while true {
            let batch = Array(pending.prefix(UsagePolicy.maxBatch))
            guard !batch.isEmpty, let body = try? UsagePolicy.body(for: batch),
                  (try? await send(endpoint, body)) != nil else { return }
            // Anything queued while sending stays.
            save(Array(pending.dropFirst(batch.count)))
        }
    }

    /// Switched off: drop what hasn't gone yet.
    func discardPending() {
        save([])
    }

    /// «Delete all data»: as after a fresh install.
    func reset() {
        defaults.removeObject(forKey: Key.sent)
        defaults.removeObject(forKey: Key.pending)
    }

    private func save(_ records: [UsageRecord]) {
        if records.isEmpty {
            defaults.removeObject(forKey: Key.pending)
        } else if let data = try? JSONEncoder().encode(records) {
            defaults.set(data, forKey: Key.pending)
        }
    }

    private static var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
    }

    private static var build: String {
        #if DEBUG
        "debug"
        #else
        "release"
        #endif
    }

    /// Not in unit tests (the app is their host) and not in Xcode previews.
    private static var isRealRun: Bool {
        let environment = ProcessInfo.processInfo.environment
        return environment["XCTestConfigurationFilePath"] == nil
            && environment["XCODE_RUNNING_FOR_PREVIEWS"] != "1"
            && NSClassFromString("XCTestCase") == nil
    }

    /// A plain POST without cookies or cache, like the remote config request.
    @concurrent
    nonisolated static func post(_ url: URL, _ body: Data) async throws {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.httpCookieStorage = nil
        configuration.urlCache = nil
        configuration.timeoutIntervalForRequest = 10
        let session = URLSession(configuration: configuration)
        defer { session.finishTasksAndInvalidate() }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = body
        let (_, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
    }
}
