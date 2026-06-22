import Foundation
import ParrotCore
import ParrotPlatform

public struct AppGroupContainer: Sendable {
    public let identifier: String?
    public let fallbackDirectory: URL

    public init(
        identifier: String? = nil,
        fallbackDirectory: URL? = nil
    ) {
        self.identifier = identifier
        self.fallbackDirectory = fallbackDirectory ?? Self.defaultFallbackDirectory()
    }

    public var url: URL {
        if let identifier,
           let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: identifier) {
            return container
        }
        return fallbackDirectory
    }

    public var handoffImagesDirectory: URL {
        url.appendingPathComponent("HandoffImages", isDirectory: true)
    }

    public func handoffImageURL(fileName: String) -> URL {
        url.appendingPathComponent(fileName)
    }

    private static func defaultFallbackDirectory() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        return base.appendingPathComponent("Parrot", isDirectory: true)
    }
}

public enum AppGroupStoreFactory {
    public static func socialSessionStore(container: AppGroupContainer) -> JSONSocialSessionStore {
        JSONSocialSessionStore(fileURL: container.url.appendingPathComponent("social-sessions.json"))
    }

    public static func handoffStore(container: AppGroupContainer) -> FileHandoffStore {
        FileHandoffStore(fileURL: container.url.appendingPathComponent("latest-handoff.json"))
    }

    public static func terminologyStore(container: AppGroupContainer) -> TerminologyStore {
        TerminologyStore(fileURL: container.url.appendingPathComponent("terminology.json"))
    }
}
