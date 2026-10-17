import Foundation
import SwiftData

/// Builds the SwiftData containers used by the app, previews and tests.
enum AppModelContainer {
    static let schema = Schema(versionedSchema: SchemaV3.self)

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
        // Not fatal: reads still map retired ids through `BodyZone.canonicalID`.
        do {
            try RetiredZoneRepair.run(in: container.mainContext)
        } catch {
            print("Could not rewrite retired zone ids: \(error)")
        }
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

    static var storeDirectoryURL: URL { URL.applicationSupportDirectory.appending(path: "Store", directoryHint: .isDirectory) }

    private static func storeDirectory(fileManager: FileManager) throws -> URL {
        let directory = storeDirectoryURL
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

    // MARK: - Recovery

    /// Where an unreadable store is moved by «Start a new diary». Only the latest one is kept.
    static var setAsideDirectoryURL: URL { URL.applicationSupportDirectory.appending(path: "Store-unreadable", directoryHint: .isDirectory) }

    /// Copies the store files (database and its journal) into `folder` for the user to keep
    /// or send to support. The copies are protected like other exports.
    static func copyStoreFiles(
        from directory: URL = storeDirectoryURL,
        to folder: URL = ExportFolder.url,
        fileManager: FileManager = .default
    ) throws -> [URL] {
        let target = try ExportFolder.prepare(folder)
        return try fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil).map { file in
            let copy = target.appending(path: file.lastPathComponent)
            try fileManager.copyItem(at: file, to: copy)
            try ExportFolder.protect(copy)
            return copy
        }
    }

    /// Moves the unreadable store aside, so the next `makePersistent` starts an empty diary.
    /// The old files are kept (replacing an earlier set-aside copy), not deleted.
    static func setStoreAside(
        from directory: URL = storeDirectoryURL,
        to aside: URL = setAsideDirectoryURL,
        fileManager: FileManager = .default
    ) throws {
        if fileManager.fileExists(atPath: aside.path(percentEncoded: false)) {
            try fileManager.removeItem(at: aside)
        }
        try fileManager.moveItem(at: directory, to: aside)
    }
}
