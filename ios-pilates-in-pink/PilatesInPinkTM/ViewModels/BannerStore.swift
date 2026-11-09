import Foundation
import Observation

/// Home banners from `home_banners`. The last good list is kept on the device so Home shows
/// instantly; it's refreshed on launch, on pull-to-refresh and when the app comes back.
@Observable
final class BannerStore {
    private(set) var banners: [HomeBanner]
    /// True once there's a list to show (from the device or the network).
    private(set) var hasBanners: Bool
    private let service = StudioService()
    private var isRefreshing = false

    private static var fileURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base.appendingPathComponent("home_banners.json")
    }

    init() {
        if let data = try? Data(contentsOf: Self.fileURL),
           let saved = try? JSONDecoder().decode([HomeBanner].self, from: data) {
            banners = saved
            hasBanners = true
        } else {
            banners = []
            hasBanners = false
        }
    }

    func refresh() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }
        let service = self.service
        switch await captureResult({ try await service.banners() }) {
        case .success(let rows):
            let sorted = rows.sorted { ($0.sortOrder ?? 0) < ($1.sortOrder ?? 0) }
            if sorted != banners { banners = sorted }
            hasBanners = true
            if let data = try? JSONEncoder().encode(sorted) {
                try? data.write(to: Self.fileURL, options: .atomic)
            }
        case .failure(let error):
            // Keep showing the last good list.
            if !FriendlyError.isCancellation(error) {
                print("Banners load failed: \(error.localizedDescription)")
            }
        }
    }
}
