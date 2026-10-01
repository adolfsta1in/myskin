import SwiftData
import SwiftUI
import UIKit

extension PhotoStore {
    /// The app's photo folder; nil only if Application Support can't be created.
    static let shared: PhotoStore? = try? appFolder()

    /// Encodes and writes off the main actor.
    @concurrent
    func saveInBackground(imageData: Data) async throws -> String {
        try save(imageData: imageData)
    }

    @concurrent
    func thumbnailInBackground(fileName: String, maxPixelSize: Int) async -> Data? {
        try? thumbnail(fileName: fileName, maxPixelSize: maxPixelSize)
    }
}

/// Keeps `Photo` records and their files in step.
enum PhotoRecords {
    /// Saves the image file, then the record. If the record can't be saved, the file is removed again.
    @discardableResult
    static func add(imageData: Data, zoneID: String, store: PhotoStore, context: ModelContext, date: Date = .now) async throws -> Photo {
        let fileName = try await store.saveInBackground(imageData: imageData)
        let photo = Photo(day: date, zoneID: zoneID, fileName: fileName)
        context.insert(photo)
        do {
            try context.save()
        } catch {
            context.delete(photo)
            try? store.delete(fileName: fileName)
            throw error
        }
        return photo
    }

    /// Deletes the file and the record.
    static func delete(_ photo: Photo, store: PhotoStore, context: ModelContext) throws {
        try store.delete(fileName: photo.fileName)
        context.delete(photo)
        try context.save()
    }

    /// Zones that have photos, newest photo first. `photos` must be sorted newest first.
    static func zonesWithPhotos(_ photos: [Photo]) -> [(zoneID: String, latest: Photo, count: Int)] {
        var order: [String] = []
        var groups: [String: [Photo]] = [:]
        for photo in photos {
            if groups[photo.zoneID] == nil { order.append(photo.zoneID) }
            groups[photo.zoneID, default: []].append(photo)
        }
        return order.compactMap { id in
            guard let group = groups[id], let latest = group.first else { return nil }
            return (id, latest, group.count)
        }
    }
}

/// Photo from the protected folder, decoded off the main actor. Shows a neutral placeholder while loading.
struct StoredPhotoImage: View {
    let fileName: String
    var maxPixelSize = 400
    var cornerRadius: CGFloat = 18

    @State private var image: UIImage?

    var body: some View {
        Color.clear
            .overlay {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    Rectangle()
                        .fill(Theme.sand)
                        .overlay {
                            Image(systemName: "photo")
                                .foregroundStyle(Theme.inkSoft.opacity(0.5))
                        }
                }
            }
            .clipShape(.rect(cornerRadius: cornerRadius))
            .task(id: fileName) {
                guard let store = PhotoStore.shared,
                      let data = await store.thumbnailInBackground(fileName: fileName, maxPixelSize: maxPixelSize) else { return }
                image = UIImage(data: data)
            }
    }
}
