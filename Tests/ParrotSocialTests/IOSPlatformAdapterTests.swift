import Foundation
import Testing
@testable import ParrotPlatformiOS

@Test func iosKeychainSecretStoreRoundTripsAndRemovesSecret() async throws {
    let account = "parrot-test-\(UUID().uuidString)"
    let store = IOSKeychainSecretStore(service: "dev.parrot.tests")

    try await store.set("test-secret", account: account)
    let stored = try await store.get(account: account)
    try await store.remove(account: account)
    let removed = try await store.get(account: account)

    #expect(stored == "test-secret")
    #expect(removed == nil)
}
