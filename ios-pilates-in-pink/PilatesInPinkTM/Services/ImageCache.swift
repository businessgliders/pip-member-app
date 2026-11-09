import Foundation
import Observation
import UIKit
import CryptoKit

/// Small on-disk + in-memory image cache (Caches/images). Used for banner photos and member photos.
nonisolated final class ImageCache: @unchecked Sendable {
    static let shared = ImageCache()

    private let memory = NSCache<NSString, UIImage>()
    private let directory: URL

    private init() {
        let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        directory = base.appendingPathComponent("images", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        memory.countLimit = 40
    }

    private func fileURL(for key: String) -> URL {
        let digest = SHA256.hash(data: Data(key.utf8)).map { String(format: "%02x", $0) }.joined()
        return directory.appendingPathComponent(digest)
    }

    /// Memory or disk, never the network.
    func cached(_ key: String) -> UIImage? {
        if let image = memory.object(forKey: key as NSString) { return image }
        guard let data = try? Data(contentsOf: fileURL(for: key)), let image = UIImage(data: data) else { return nil }
        memory.setObject(image, forKey: key as NSString)
        return image
    }

    /// How old the disk copy is, if there is one.
    func age(_ key: String) -> TimeInterval? {
        let attributes = try? FileManager.default.attributesOfItem(atPath: fileURL(for: key).path)
        guard let date = attributes?[.modificationDate] as? Date else { return nil }
        return Date().timeIntervalSince(date)
    }

    func store(_ data: Data, for key: String) {
        guard let image = UIImage(data: data) else { return }
        try? data.write(to: fileURL(for: key), options: .atomic)
        memory.setObject(image, forKey: key as NSString)
    }

    func remove(_ key: String) {
        memory.removeObject(forKey: key as NSString)
        try? FileManager.default.removeItem(at: fileURL(for: key))
    }

    /// Cached copy, else downloads and stores it. Nil when the download fails.
    func image(at url: URL, key: String? = nil) async -> UIImage? {
        let key = key ?? url.absoluteString
        if let image = cached(key) { return image }
        return await download(url, key: key)
    }

    func download(_ url: URL, key: String) async -> UIImage? {
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) { return nil }
            guard UIImage(data: data) != nil else { return nil }
            store(data, for: key)
            return cached(key)
        } catch {
            return nil
        }
    }
}

/// Member photos live in the private `avatars` bucket: fetched through a 1-hour signed link,
/// kept on disk, and re-fetched at most once an hour. `version` bumps when the member changes
/// their photo, so every avatar on screen reloads.
@Observable
final class MemberPhotoCache {
    static let shared = MemberPhotoCache()
    private(set) var version = 0
    private let service = StudioService()
    private static let refreshAge: TimeInterval = 3600

    private func key(_ path: String) -> String { "avatar:" + path }

    func cached(path: String) -> UIImage? { ImageCache.shared.cached(key(path)) }

    /// Disk copy if fresh, otherwise a new signed link + download (falling back to the old copy).
    func load(path: String) async -> UIImage? {
        let key = key(path)
        if let image = ImageCache.shared.cached(key),
           let age = ImageCache.shared.age(key), age < Self.refreshAge {
            return image
        }
        let service = self.service
        if case .success(let url) = await captureResult({ try await service.signedPhotoURL(path: path) }),
           let fresh = await ImageCache.shared.download(url, key: key) {
            return fresh
        }
        return ImageCache.shared.cached(key)
    }

    /// The member just uploaded this photo: show it everywhere at once.
    func replace(path: String, with data: Data) {
        ImageCache.shared.store(data, for: key(path))
        version += 1
    }
}
