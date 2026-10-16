import Foundation
import Testing
@testable import MySkin

/// Recovery when the store can't be opened: copies for support, and setting the store aside.
struct StoreRecoveryTests {
    private let manager = FileManager.default

    private func makeStore(_ root: URL, contents: String) throws -> URL {
        let store = root.appending(path: "Store", directoryHint: .isDirectory)
        try manager.createDirectory(at: store, withIntermediateDirectories: true)
        for name in ["MySkin.store", "MySkin.store-wal", "MySkin.store-shm"] {
            try Data(contents.utf8).write(to: store.appending(path: name))
        }
        return store
    }

    @Test func copiesEveryStoreFile() throws {
        let root = manager.temporaryDirectory.appending(path: "StoreRecoveryTests-\(UUID().uuidString)")
        defer { try? manager.removeItem(at: root) }
        let store = try makeStore(root, contents: "diary")

        let copies = try AppModelContainer.copyStoreFiles(from: store, to: root.appending(path: "Export"))
        #expect(Set(copies.map(\.lastPathComponent)) == ["MySkin.store", "MySkin.store-wal", "MySkin.store-shm"])
        #expect(try String(contentsOf: copies[0], encoding: .utf8) == "diary")
        // The originals stay where they were.
        #expect(manager.fileExists(atPath: store.appending(path: "MySkin.store").path(percentEncoded: false)))
    }

    @Test func setAsideMovesStoreAndKeepsOnlyLatest() throws {
        let root = manager.temporaryDirectory.appending(path: "StoreRecoveryTests-\(UUID().uuidString)")
        defer { try? manager.removeItem(at: root) }
        let aside = root.appending(path: "Store-unreadable", directoryHint: .isDirectory)

        let first = try makeStore(root, contents: "first")
        try AppModelContainer.setStoreAside(from: first, to: aside)
        #expect(!manager.fileExists(atPath: first.path(percentEncoded: false)))

        let second = try makeStore(root, contents: "second")
        try AppModelContainer.setStoreAside(from: second, to: aside)
        let kept = try String(contentsOf: aside.appending(path: "MySkin.store"), encoding: .utf8)
        #expect(kept == "second")
    }
}
