import Foundation
import ParrotCore

#if canImport(Photos)
@preconcurrency import Photos
#endif

public enum PhotoAccessStatus: String, Sendable, Equatable {
    case notDetermined
    case authorized
    case limited
    case denied
    case restricted
    case unavailable
}

public struct LatestScreenshotAsset: Sendable, Equatable {
    public var localIdentifier: String
    public var createdAt: Date
    public var pixelWidth: Int
    public var pixelHeight: Int
    public var imageData: Data
    public var uniformTypeIdentifier: String?

    public init(
        localIdentifier: String,
        createdAt: Date,
        pixelWidth: Int,
        pixelHeight: Int,
        imageData: Data,
        uniformTypeIdentifier: String? = nil
    ) {
        self.localIdentifier = localIdentifier
        self.createdAt = createdAt
        self.pixelWidth = pixelWidth
        self.pixelHeight = pixelHeight
        self.imageData = imageData
        self.uniformTypeIdentifier = uniformTypeIdentifier
    }
}

public protocol LatestScreenshotProviding: Sendable {
    func authorizationStatus() -> PhotoAccessStatus
    func requestAuthorization() async -> PhotoAccessStatus
    func latestScreenshot(maxAge: TimeInterval) async throws -> LatestScreenshotAsset?
}

public struct LatestScreenshotCandidate: Sendable, Equatable {
    public var localIdentifier: String
    public var createdAt: Date
    public var isScreenshot: Bool
    public var pixelWidth: Int
    public var pixelHeight: Int

    public init(
        localIdentifier: String,
        createdAt: Date,
        isScreenshot: Bool,
        pixelWidth: Int,
        pixelHeight: Int
    ) {
        self.localIdentifier = localIdentifier
        self.createdAt = createdAt
        self.isScreenshot = isScreenshot
        self.pixelWidth = pixelWidth
        self.pixelHeight = pixelHeight
    }
}

public struct LatestScreenshotSelector: Sendable {
    public init() {}

    public func select(
        from candidates: [LatestScreenshotCandidate],
        now: Date,
        maxAge: TimeInterval
    ) -> LatestScreenshotCandidate? {
        let cutoff = now.addingTimeInterval(-maxAge)
        return candidates
            .filter { $0.isScreenshot && $0.createdAt >= cutoff }
            .sorted { $0.createdAt > $1.createdAt }
            .first
    }
}

public struct LatestScreenshotProvider: LatestScreenshotProviding {
    private let now: @Sendable () -> Date

    public init(now: @escaping @Sendable () -> Date = { Date() }) {
        self.now = now
    }

    public func authorizationStatus() -> PhotoAccessStatus {
        #if canImport(Photos)
        return Self.map(PHPhotoLibrary.authorizationStatus(for: .readWrite))
        #else
        return .unavailable
        #endif
    }

    public func requestAuthorization() async -> PhotoAccessStatus {
        #if canImport(Photos)
        let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        return Self.map(status)
        #else
        return .unavailable
        #endif
    }

    public func latestScreenshot(maxAge: TimeInterval) async throws -> LatestScreenshotAsset? {
        #if canImport(Photos)
        let status = authorizationStatus()
        guard status == .authorized || status == .limited else {
            throw ProviderError.auth
        }

        let cutoff = now().addingTimeInterval(-maxAge)
        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        options.predicate = NSPredicate(format: "creationDate >= %@", cutoff as NSDate)
        options.fetchLimit = 20

        let asset = latestScreenshotAsset(options: options)
        guard let asset else { return nil }
        return try await loadAsset(asset)
        #else
        _ = maxAge
        throw ProviderError.unsupportedLanguage
        #endif
    }

    #if canImport(Photos)
    private func latestScreenshotAsset(options: PHFetchOptions) -> PHAsset? {
        let collections = PHAssetCollection.fetchAssetCollections(
            with: .smartAlbum,
            subtype: .smartAlbumScreenshots,
            options: nil
        )

        var selected: PHAsset?
        collections.enumerateObjects { collection, _, stop in
            let assets = PHAsset.fetchAssets(in: collection, options: options)
            if let first = assets.firstObject {
                selected = first
                stop.pointee = true
            }
        }
        if let selected { return selected }

        let assets = PHAsset.fetchAssets(with: .image, options: options)
        var fallback: PHAsset?
        assets.enumerateObjects { asset, _, stop in
            if asset.mediaSubtypes.contains(.photoScreenshot) {
                fallback = asset
                stop.pointee = true
            }
        }
        return fallback
    }

    private func loadAsset(_ asset: PHAsset) async throws -> LatestScreenshotAsset {
        try await withCheckedThrowingContinuation { continuation in
            let options = PHImageRequestOptions()
            options.deliveryMode = .highQualityFormat
            options.isNetworkAccessAllowed = false
            options.version = .current

            var didResume = false
            PHImageManager.default().requestImageDataAndOrientation(for: asset, options: options) { data, uti, _, info in
                if didResume { return }
                didResume = true

                if let error = info?[PHImageErrorKey] as? Error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let data else {
                    continuation.resume(throwing: ProviderError.service("Unable to load screenshot data."))
                    return
                }
                continuation.resume(returning: LatestScreenshotAsset(
                    localIdentifier: asset.localIdentifier,
                    createdAt: asset.creationDate ?? Date(),
                    pixelWidth: asset.pixelWidth,
                    pixelHeight: asset.pixelHeight,
                    imageData: data,
                    uniformTypeIdentifier: uti
                ))
            }
        }
    }

    private static func map(_ status: PHAuthorizationStatus) -> PhotoAccessStatus {
        switch status {
        case .notDetermined:
            return .notDetermined
        case .authorized:
            return .authorized
        case .limited:
            return .limited
        case .denied:
            return .denied
        case .restricted:
            return .restricted
        @unknown default:
            return .unavailable
        }
    }
    #endif
}
