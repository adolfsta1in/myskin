import Foundation
import ImageIO
import UniformTypeIdentifiers

/// Zone photos as files in the app container (`Application Support/Photos`), never in the
/// system photo library. Files use `FileProtectionType.complete` and are excluded from backup.
/// Images are re-encoded as JPEG without metadata (no location, no device info).
nonisolated struct PhotoStore: Sendable {
    enum PhotoError: Error, LocalizedError {
        case unreadableImage
        case encodingFailed
        case invalidFileName

        var errorDescription: String? {
            switch self {
            case .unreadableImage: "The image couldn't be read."
            case .encodingFailed: "The image couldn't be saved."
            case .invalidFileName: "The photo file name is invalid."
            }
        }
    }

    /// Longest side of a stored photo, in pixels.
    static let maxPixelSize = 2048
    static let jpegQuality = 0.8

    let directory: URL

    /// Store in `Application Support/Photos`, created on first use.
    static func appStore() throws -> PhotoStore {
        let support = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        return try PhotoStore(directory: support.appending(path: "Photos", directoryHint: .isDirectory))
    }

    /// Creates the folder if needed, with complete protection and no backup.
    init(directory: URL) throws {
        self.directory = directory
        let manager = FileManager.default
        if !manager.fileExists(atPath: directory.path(percentEncoded: false)) {
            try manager.createDirectory(at: directory, withIntermediateDirectories: true, attributes: [.protectionKey: FileProtectionType.complete])
        }
        var folder = directory
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try folder.setResourceValues(values)
    }

    // MARK: Save / load / delete

    /// Downscales and re-encodes image data (JPEG, HEIC, PNG…) and writes it. Returns the file name to store in `Photo`.
    func save(imageData: Data) throws -> String {
        let jpeg = try Self.encode(imageData, maxPixelSize: Self.maxPixelSize)
        let fileName = "\(UUID().uuidString).jpg"
        var fileURL = try url(for: fileName)
        try jpeg.write(to: fileURL, options: [.atomic, .completeFileProtection])
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try fileURL.setResourceValues(values)
        return fileName
    }

    func data(fileName: String) throws -> Data {
        try Data(contentsOf: url(for: fileName))
    }

    /// Small JPEG for grids, decoded straight from the file.
    func thumbnail(fileName: String, maxPixelSize: Int = 400) throws -> Data {
        try Self.encode(data(fileName: fileName), maxPixelSize: maxPixelSize)
    }

    /// Removes the file; a missing file is not an error.
    func delete(fileName: String) throws {
        let fileURL = try url(for: fileName)
        if FileManager.default.fileExists(atPath: fileURL.path(percentEncoded: false)) {
            try FileManager.default.removeItem(at: fileURL)
        }
    }

    func exists(fileName: String) -> Bool {
        guard let fileURL = try? url(for: fileName) else { return false }
        return FileManager.default.fileExists(atPath: fileURL.path(percentEncoded: false))
    }

    /// Only plain file names inside the folder are allowed.
    func url(for fileName: String) throws -> URL {
        guard !fileName.isEmpty, !fileName.contains("/"), !fileName.hasPrefix(".") else { throw PhotoError.invalidFileName }
        return directory.appending(path: fileName, directoryHint: .notDirectory)
    }

    // MARK: Encoding

    /// Decodes, applies orientation, downscales and writes a JPEG without the source metadata.
    static func encode(_ data: Data, maxPixelSize: Int) throws -> Data {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { throw PhotoError.unreadableImage }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { throw PhotoError.unreadableImage }

        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(output, UTType.jpeg.identifier as CFString, 1, nil) else {
            throw PhotoError.encodingFailed
        }
        CGImageDestinationAddImage(destination, image, [kCGImageDestinationLossyCompressionQuality: jpegQuality] as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { throw PhotoError.encodingFailed }
        return output as Data
    }
}
