import CoreGraphics
import Foundation
import ImageIO
import SwiftData
import Testing
import UniformTypeIdentifiers
@testable import MyApp

struct PhotoRecordsTests {
    private func makeStore() throws -> PhotoStore {
        try PhotoStore(directory: FileManager.default.temporaryDirectory.appending(path: "PhotoRecordsTests-\(UUID().uuidString)"))
    }

    private func makeContext() throws -> ModelContext {
        ModelContext(try AppModelContainer.makeInMemory())
    }

    private func jpeg() throws -> Data {
        let context = try #require(CGContext(
            data: nil, width: 40, height: 40, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        context.setFillColor(CGColor(red: 0.5, green: 0.5, blue: 0.5, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: 40, height: 40))
        let image = try #require(context.makeImage())
        let output = NSMutableData()
        let destination = try #require(CGImageDestinationCreateWithData(output, UTType.jpeg.identifier as CFString, 1, nil))
        CGImageDestinationAddImage(destination, image, nil)
        #expect(CGImageDestinationFinalize(destination))
        return output as Data
    }

    @Test func addThenDeleteKeepsFileAndRecordInStep() async throws {
        let store = try makeStore()
        let context = try makeContext()
        let photo = try await PhotoRecords.add(imageData: jpeg(), zoneID: "back.elbow.left", store: store, context: context)

        #expect(store.exists(fileName: photo.fileName))
        #expect(try context.fetchCount(FetchDescriptor<Photo>()) == 1)
        #expect(photo.zoneID == "back.elbow.left")

        let fileName = photo.fileName
        try PhotoRecords.delete(photo, store: store, context: context)
        #expect(!store.exists(fileName: fileName))
        #expect(try context.fetchCount(FetchDescriptor<Photo>()) == 0)
    }

    @Test func badImageAddsNothing() async throws {
        let store = try makeStore()
        let context = try makeContext()
        await #expect(throws: PhotoStore.PhotoError.self) {
            _ = try await PhotoRecords.add(imageData: Data("nope".utf8), zoneID: "quick.scalp", store: store, context: context)
        }
        #expect(try context.fetchCount(FetchDescriptor<Photo>()) == 0)
        #expect(try FileManager.default.contentsOfDirectory(atPath: store.directory.path(percentEncoded: false)).isEmpty)
    }

    @Test func zonesAreGroupedNewestFirst() {
        let old = Photo(day: .now.addingTimeInterval(-86_400 * 3), zoneID: "quick.scalp", fileName: "a.jpg")
        let mid = Photo(day: .now.addingTimeInterval(-86_400), zoneID: "back.elbow.left", fileName: "b.jpg")
        let new = Photo(day: .now, zoneID: "quick.scalp", fileName: "c.jpg")
        let zones = PhotoRecords.zonesWithPhotos([new, mid, old])
        #expect(zones.map(\.zoneID) == ["quick.scalp", "back.elbow.left"])
        #expect(zones.first?.latest.fileName == "c.jpg")
        #expect(zones.first?.count == 2)
    }
}
