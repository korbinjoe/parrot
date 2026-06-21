import Foundation

/// Local file-backed secret storage for API keys and plugin secrets.
///
/// Secrets live in `~/Library/Application Support/Parrot/secrets.json`, with the file restricted
/// to the current user. This deliberately avoids macOS Keychain prompts while still keeping keys
/// out of UserDefaults, history, and logs.
public enum SecretStore {
    private struct SecretFile: Codable {
        var version: Int = 1
        var secrets: [String: String] = [:]
    }

    private static let lock = NSLock()
    private static var testFileURL: URL?

    public static var fileURL: URL {
        lock.lock()
        defer { lock.unlock() }
        return fileURLUnlocked()
    }

    /// Store or update a secret for `account`. Passing an empty string deletes the entry.
    @discardableResult
    public static func set(_ value: String, account: String) -> Bool {
        guard !value.isEmpty else { return remove(account: account) }

        lock.lock()
        defer { lock.unlock() }
        let url = fileURLUnlocked()
        var secrets = readAll(from: url)
        secrets[account] = value
        return writeAll(secrets, to: url)
    }

    /// Read a secret. Returns nil if absent.
    public static func get(account: String) -> String? {
        lock.lock()
        defer { lock.unlock() }
        return readAll(from: fileURLUnlocked())[account]
    }

    /// Delete a secret. Returns true if it was removed or already absent.
    @discardableResult
    public static func remove(account: String) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        let url = fileURLUnlocked()
        var secrets = readAll(from: url)
        guard secrets.removeValue(forKey: account) != nil else { return true }
        return writeAll(secrets, to: url)
    }

    public static func has(account: String) -> Bool {
        get(account: account) != nil
    }

    /// Test-only escape hatch for keeping tests away from a developer's real Parrot config.
    public static func useFileURLForTesting(_ url: URL?) {
        lock.lock()
        testFileURL = url
        lock.unlock()
    }

    private static func fileURLUnlocked() -> URL {
        if let testFileURL { return testFileURL }
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? applicationSupportFallbackURL()
        return base
            .appendingPathComponent("Parrot", isDirectory: true)
            .appendingPathComponent("secrets.json")
    }

    private static func applicationSupportFallbackURL() -> URL {
        #if os(macOS)
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support")
        #else
        URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support")
        #endif
    }

    private static func readAll(from url: URL) -> [String: String] {
        guard let data = try? Data(contentsOf: url), !data.isEmpty else { return [:] }
        let decoder = JSONDecoder()
        if let file = try? decoder.decode(SecretFile.self, from: data) {
            return file.secrets
        }
        return (try? decoder.decode([String: String].self, from: data)) ?? [:]
    }

    private static func writeAll(_ secrets: [String: String], to url: URL) -> Bool {
        do {
            let fm = FileManager.default
            let directory = url.deletingLastPathComponent()
            try fm.createDirectory(
                at: directory,
                withIntermediateDirectories: true,
                attributes: [.posixPermissions: 0o700]
            )
            try? fm.setAttributes([.posixPermissions: 0o700], ofItemAtPath: directory.path)

            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(SecretFile(secrets: secrets))
            try data.write(to: url, options: .atomic)
            try fm.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)

            var resourceURL = url
            var values = URLResourceValues()
            values.isExcludedFromBackup = true
            try? resourceURL.setResourceValues(values)
            return true
        } catch {
            return false
        }
    }
}
