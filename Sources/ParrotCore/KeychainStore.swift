import Foundation
import Security

/// Thin wrapper over the macOS Keychain for storing API keys and plugin secrets.
///
/// Values are stored as generic passwords keyed by `service` + `account`, scoped to a single
/// service namespace so the whole app's secrets can be enumerated/cleared together.
/// Keys are NEVER written to UserDefaults, the history DB, or logs.
public enum KeychainStore {
    /// Namespace under which all Parrot secrets live.
    public static let service = "com.parrot.Parrot.secrets"

    /// Store (or update) a secret for `account`. Passing an empty string deletes the entry.
    @discardableResult
    public static func set(_ value: String, account: String) -> Bool {
        guard !value.isEmpty else { return remove(account: account) }
        guard let data = value.data(using: .utf8) else { return false }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        let attributes: [String: Any] = [kSecValueData as String: data]

        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if status == errSecSuccess { return true }
        if status == errSecItemNotFound {
            var insert = query
            insert[kSecValueData as String] = data
            insert[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
            return SecItemAdd(insert as CFDictionary, nil) == errSecSuccess
        }
        return false
    }

    /// Read a secret. Returns nil if absent.
    public static func get(account: String, allowPrompt: Bool = false) -> String? {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        if !allowPrompt {
            query[kSecUseAuthenticationUI as String] = kSecUseAuthenticationUISkip
        }
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data,
              let value = String(data: data, encoding: .utf8) else {
            return nil
        }
        return value
    }

    /// Delete a secret. Returns true if it was removed or already absent.
    @discardableResult
    public static func remove(account: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }

    public static func has(account: String) -> Bool {
        get(account: account, allowPrompt: false) != nil
    }
}
