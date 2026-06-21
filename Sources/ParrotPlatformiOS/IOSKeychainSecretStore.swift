import Foundation
import ParrotPlatform

#if canImport(Security)
import Security
#endif

public struct IOSKeychainSecretStore: SecretStoreProtocol {
    private let service: String

    public init(service: String = "dev.parrot.ios") {
        self.service = service
    }

    public func set(_ value: String, account: String) async throws {
        #if canImport(Security)
        let data = Data(value.utf8)
        let query = baseQuery(account: account)
        SecItemDelete(query as CFDictionary)
        var add = query
        add[kSecValueData as String] = data
        add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        let status = SecItemAdd(add as CFDictionary, nil)
        guard status == errSecSuccess else { throw KeychainError.status(status) }
        #else
        _ = value
        _ = account
        throw KeychainError.unavailable
        #endif
    }

    public func get(account: String) async throws -> String? {
        #if canImport(Security)
        var query = baseQuery(account: account)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess else { throw KeychainError.status(status) }
        guard let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
        #else
        _ = account
        throw KeychainError.unavailable
        #endif
    }

    public func remove(account: String) async throws {
        #if canImport(Security)
        let status = SecItemDelete(baseQuery(account: account) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.status(status)
        }
        #else
        _ = account
        throw KeychainError.unavailable
        #endif
    }

    private func baseQuery(account: String) -> [String: Any] {
        #if canImport(Security)
        return [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        #else
        return [:]
        #endif
    }

    public enum KeychainError: Error, Equatable {
        case unavailable
        case status(OSStatus)
    }
}
