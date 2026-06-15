import Foundation

/// Declarative plugin manifest (`info.json`). Mirrors the structure described in
/// specs/plugin-system/spec.md.
public struct PluginManifest: Codable, Sendable {
    public struct Option: Codable, Sendable {
        public let key: String
        public let type: String          // "string" | "secret" | "text"
        public let label: String?
        public let `default`: String?
        public let required: Bool?
    }
    public struct Permissions: Codable, Sendable {
        public let network: [String]     // allowed hosts (whitelist)
    }

    public let identifier: String
    public let name: String
    public let version: String
    public let author: String?
    public let minOpenBobVersion: String?
    public let capabilities: [String]?   // "translate" | "lookup" | "polish"
    public let permissions: Permissions?
    public let options: [Option]?

    public var allowedHosts: [String] { permissions?.network ?? [] }

    public static func parse(_ data: Data) throws -> PluginManifest {
        do {
            return try JSONDecoder().decode(PluginManifest.self, from: data)
        } catch {
            throw PluginError.invalidManifest(String(describing: error))
        }
    }
}

public enum PluginError: Error, Equatable {
    case invalidManifest(String)
    case missingScript
    case scriptLoadFailed(String)
    case noTranslateFunction
    case networkNotPermitted(String)
    case timeout
    case runtime(String)
}
