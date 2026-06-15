import Foundation
import OpenBobCore

/// Discovers and instantiates plugins from disk.
///
/// A plugin is a directory (conventionally `*.bobplugin`) containing:
///   - `info.json`  (manifest)
///   - `main.js`    (implements `translate(query, completion)`)
public enum PluginLoader {

    public static let defaultDirectory: URL = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return base.appendingPathComponent("OpenBob/Plugins", isDirectory: true)
    }()

    /// Load a single plugin directory into a ready `PluginProvider`.
    /// - Parameter secrets: resolved secret option values (e.g. API keys from Keychain), merged
    ///   over the manifest defaults before injection into the JS `$option`.
    public static func load(at directory: URL, secrets: [String: String] = [:]) throws -> PluginProvider {
        let manifestURL = directory.appendingPathComponent("info.json")
        let scriptURL = directory.appendingPathComponent("main.js")

        let manifestData = try Data(contentsOf: manifestURL)
        let manifest = try PluginManifest.parse(manifestData)

        guard FileManager.default.fileExists(atPath: scriptURL.path),
              let script = try? String(contentsOf: scriptURL, encoding: .utf8) else {
            throw PluginError.missingScript
        }

        let options = resolveOptions(manifest: manifest, secrets: secrets)
        let runtime = try PluginRuntime(script: script,
                                        allowedHosts: manifest.allowedHosts,
                                        options: options)
        return PluginProvider(manifest: manifest, runtime: runtime)
    }

    /// Scan a directory tree for plugins, skipping any that fail to load.
    public static func loadAll(in directory: URL = defaultDirectory,
                               secrets: [String: [String: String]] = [:]) -> [PluginProvider] {
        let fm = FileManager.default
        guard let entries = try? fm.contentsOfDirectory(at: directory,
                                                        includingPropertiesForKeys: [.isDirectoryKey]) else {
            return []
        }
        var providers: [PluginProvider] = []
        for entry in entries where (try? entry.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true {
            // secrets keyed by manifest identifier; resolved lazily below by directory name fallback.
            if let provider = try? load(at: entry, secrets: secrets[entry.lastPathComponent] ?? [:]) {
                providers.append(provider)
            }
        }
        return providers
    }

    /// Merge manifest defaults with provided secret/config values.
    static func resolveOptions(manifest: PluginManifest, secrets: [String: String]) -> [String: String] {
        var options: [String: String] = [:]
        for opt in manifest.options ?? [] {
            if let secret = secrets[opt.key] {
                options[opt.key] = secret
            } else if let def = opt.default {
                options[opt.key] = def
            }
        }
        return options
    }
}
