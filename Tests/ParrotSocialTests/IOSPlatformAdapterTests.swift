import Foundation
import ParrotCore
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

@Test func appGroupFactoryCreatesTerminologyStoreInSharedContainer() throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("parrot-app-group-\(UUID().uuidString)", isDirectory: true)
    let container = AppGroupContainer(identifier: nil, fallbackDirectory: directory)
    let store = AppGroupStoreFactory.terminologyStore(container: container)
    let entry = TerminologyEntry(source: "AI Agent", target: "AI Agent", from: .en, to: .zh)

    try store.upsert(entry)

    let restored = TerminologyStore(fileURL: directory.appendingPathComponent("terminology.json"))
    #expect(restored.loadState().entries == [entry])
}
