import Foundation
import SwiftData

/// Builds the SwiftData containers used by the app, previews and tests.
enum AppModelContainer {
    static let schema = Schema(versionedSchema: SchemaV1.self)

    /// On-disk store in `Application Support/Store`, local only (no CloudKit).
    ///
    /// The folder uses `.completeUnlessOpen`: files are encrypted while the device is locked,
    /// but an already open SQLite store (and its WAL journal) can still finish writing
    /// if the phone locks mid-save. New files in the folder inherit this class.
    static func makePersistent(fileManager: FileManager = .default) throws -> ModelContainer {
        let directory = try storeDirectory(fileManager: fileManager)
        let configuration = ModelConfiguration(
            schema: schema,
            url: directory.appending(path: "MySkin.store"),
            cloudKitDatabase: .none
        )
        let container = try ModelContainer(for: schema, migrationPlan: MySkinMigrationPlan.self, configurations: configuration)
        try protectContents(of: directory, fileManager: fileManager)
        return container
    }

    /// Ephemeral store for previews and tests.
    static func makeInMemory() throws -> ModelContainer {
        try ModelContainer(
            for: schema,
            migrationPlan: MySkinMigrationPlan.self,
            configurations: ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        )
    }

    // MARK: - File protection

    private static let protection = FileProtectionType.completeUnlessOpen

    private static func storeDirectory(fileManager: FileManager) throws -> URL {
        let directory = URL.applicationSupportDirectory.appending(path: "Store", directoryHint: .isDirectory)
        try fileManager.createDirectory(
            at: directory,
            withIntermediateDirectories: true,
            attributes: [.protectionKey: protection]
        )
        // The folder may already exist from an earlier launch.
        try fileManager.setAttributes([.protectionKey: protection], ofItemAtPath: directory.path(percentEncoded: false))
        return directory
    }

    /// Store files created before the folder had a protection class get it explicitly.
    private static func protectContents(of directory: URL, fileManager: FileManager) throws {
        for file in try fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) {
            try fileManager.setAttributes([.protectionKey: protection], ofItemAtPath: file.path(percentEncoded: false))
        }
    }
}
