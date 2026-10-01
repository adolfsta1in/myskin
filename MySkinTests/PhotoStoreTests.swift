import CoreGraphics
import Foundation
import ImageIO
import Testing
import UniformTypeIdentifiers
@testable import MyApp

struct PhotoStoreTests {
    /// Fresh store in a temporary folder.
    private func makeStore() throws -> PhotoStore {
        try PhotoStore(directory: FileManager.default.temporaryDirectory.appending(path: "PhotoStoreTests-\(UUID().uuidString)"))
    }

    /// Solid-colour PNG of the given size.
    private func imageData(width: Int, height: Int) throws -> Data {
        let context = try #require(CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        context.setFillColor(CGColor(red: 0.8, green: 0.5, blue: 0.4, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        let image = try #require(context.makeImage())
        let output = NSMutableData()
        let destination = try #require(CGImageDestinationCreateWithData(output, UTType.png.identifier as CFString, 1, nil))
        CGImageDestinationAddImage(destination, image, nil)
        #expect(CGImageDestinationFinalize(destination))
        return output as Data
    }

    private func pixelSize(_ data: Data) throws -> (Int, Int) {
        let source = try #require(CGImageSourceCreateWithData(data as CFData, nil))
        let properties = try #require(CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any])
        return (properties[kCGImagePropertyPixelWidth] as? Int ?? 0, properties[kCGImagePropertyPixelHeight] as? Int ?? 0)
    }

    @Test func saveReadDelete() throws {
        let store = try makeStore()
        let fileName = try store.save(imageData: imageData(width: 300, height: 200))
        #expect(fileName.hasSuffix(".jpg"))
        #expect(store.exists(fileName: fileName))
        #expect(try pixelSize(store.data(fileName: fileName)) == (300, 200))

        try store.delete(fileName: fileName)
        #expect(!store.exists(fileName: fileName))
        // Deleting again is fine.
        try store.delete(fileName: fileName)
    }

    @Test func largePhotosAreDownscaled() throws {
        let store = try makeStore()
        let fileName = try store.save(imageData: imageData(width: 4000, height: 3000))
        let (width, height) = try pixelSize(store.data(fileName: fileName))
        #expect(max(width, height) == PhotoStore.maxPixelSize)
        let thumb = try pixelSize(store.thumbnail(fileName: fileName, maxPixelSize: 200))
        #expect(max(thumb.0, thumb.1) == 200)
    }

    @Test func fileIsProtectedAndNotBackedUp() throws {
        let store = try makeStore()
        let fileName = try store.save(imageData: imageData(width: 50, height: 50))
        let url = try store.url(for: fileName)

        let attributes = try FileManager.default.attributesOfItem(atPath: url.path(percentEncoded: false))
        #expect(attributes[.protectionKey] as? FileProtectionType == .complete)
        #expect(try url.resourceValues(forKeys: [.isExcludedFromBackupKey]).isExcludedFromBackup == true)
        #expect(try store.directory.resourceValues(forKeys: [.isExcludedFromBackupKey]).isExcludedFromBackup == true)
    }

    @Test func rejectsPathsAndBadData() throws {
        let store = try makeStore()
        #expect(throws: PhotoStore.PhotoError.self) { try store.url(for: "../secret.jpg") }
        #expect(throws: PhotoStore.PhotoError.self) { try store.url(for: "") }
        #expect(throws: PhotoStore.PhotoError.self) { try store.save(imageData: Data("not an image".utf8)) }
    }
}
