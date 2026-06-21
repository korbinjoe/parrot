import ParrotPlatform
import ParrotPlatformiOS
import ParrotSocial
import UIKit
import UniformTypeIdentifiers

final class ShareViewController: UIViewController {
    private let container = AppGroupContainer(identifier: "group.dev.parrot.shared")
    private lazy var handoffStore = AppGroupStoreFactory.handoffStore(container: container)

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        Task { await processInput() }
    }

    private func processInput() async {
        do {
            let handoff = try await extractHandoff()
            try await handoffStore.write(handoff)
            complete()
        } catch {
            let fallback = ShareHandoff(kind: .unsupported, text: "Unable to parse shared content.")
            try? await handoffStore.write(fallback)
            complete()
        }
    }

    private func extractHandoff() async throws -> ShareHandoff {
        guard let items = extensionContext?.inputItems as? [NSExtensionItem] else {
            return ShareHandoff(kind: .unsupported)
        }
        for provider in items.flatMap({ $0.attachments ?? [] }) {
            if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
                if let text = try await loadPlainText(provider) {
                    return ShareHandoff(kind: .text, text: text, platformHint: platformHint(from: text))
                }
            }
            if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                if let url = try await loadURL(provider) {
                    return ShareHandoff(kind: .url, url: url, platformHint: platformHint(from: url.absoluteString))
                }
            }
            if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
                return try await persistImageHandoff(provider)
            }
        }
        return ShareHandoff(kind: .unsupported)
    }

    private func loadPlainText(_ provider: NSItemProvider) async throws -> String? {
        try await withCheckedThrowingContinuation { continuation in
            provider.loadItem(forTypeIdentifier: UTType.plainText.identifier) { item, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                if let text = item as? String {
                    continuation.resume(returning: text)
                } else if let data = item as? Data {
                    continuation.resume(returning: String(data: data, encoding: .utf8))
                } else {
                    continuation.resume(returning: nil)
                }
            }
        }
    }

    private func loadURL(_ provider: NSItemProvider) async throws -> URL? {
        try await withCheckedThrowingContinuation { continuation in
            provider.loadItem(forTypeIdentifier: UTType.url.identifier) { item, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                if let url = item as? URL {
                    continuation.resume(returning: url)
                } else if let url = item as? NSURL {
                    continuation.resume(returning: url as URL)
                } else if let text = item as? String {
                    continuation.resume(returning: URL(string: text))
                } else {
                    continuation.resume(returning: nil)
                }
            }
        }
    }

    private func persistImageHandoff(_ provider: NSItemProvider) async throws -> ShareHandoff {
        let directory = container.handoffImagesDirectory
        let fileName = "HandoffImages/\(UUID().uuidString).png"
        let destination = container.handoffImageURL(fileName: fileName)

        return try await withCheckedThrowingContinuation { continuation in
            provider.loadDataRepresentation(forTypeIdentifier: UTType.image.identifier) { data, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let data else {
                    continuation.resume(returning: ShareHandoff(kind: .unsupported, text: "The shared image could not be read."))
                    return
                }
                do {
                    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                    try data.write(to: destination, options: .atomic)
                    let handoff = ShareHandoff(kind: .image, imageFileName: fileName, platformHint: .general)
                    continuation.resume(returning: handoff)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private func platformHint(from text: String) -> PlatformPreset {
        let lower = text.lowercased()
        if lower.contains("reddit.com") || lower.contains("r/") || lower.contains("u/") { return .reddit }
        if lower.contains("x.com") || lower.contains("twitter.com") { return .x }
        return .general
    }

    private func complete() {
        guard let url = URL(string: "parrot://share") else {
            extensionContext?.completeRequest(returningItems: nil)
            return
        }
        extensionContext?.open(url) { _ in }
        extensionContext?.completeRequest(returningItems: nil)
    }
}
