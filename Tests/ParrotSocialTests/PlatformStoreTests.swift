import Foundation
import Testing
import ParrotSocial
@testable import ParrotPlatform

private func tempURL(_ name: String) -> URL {
    FileManager.default.temporaryDirectory
        .appendingPathComponent("parrot-social-\(name)-\(UUID().uuidString).json")
}

@Test func jsonSocialSessionStorePersistsAndSearches() async throws {
    let url = tempURL("sessions")
    let store = JSONSocialSessionStore(fileURL: url)
    var session = SocialTextSession(
        origin: .manualInput,
        platform: .x,
        sourceDraft: "The onboarding is confusing.",
        userIntentDraft: "产品不差，但新用户会迷路。"
    )
    session.apply(UnderstandResult(meaningSummary: "它在批评新手引导。"))

    try await store.save(session)

    let recent = try await store.recent(limit: 5)
    let searched = try await store.search("新手")

    #expect(recent.count == 1)
    #expect(searched.first?.id == session.id)
}

@Test func jsonSocialSessionStoreFavoritesAndDeletes() async throws {
    let url = tempURL("favorite-delete")
    let store = JSONSocialSessionStore(fileURL: url)
    let session = SocialTextSession(
        origin: .manualInput,
        platform: .reddit,
        sourceDraft: "Good idea, confusing first run."
    )

    try await store.save(session)
    try await store.setFavorite(session.id, true)
    let favorites = try await store.recent(limit: 1)
    let favorite = favorites.first

    try await store.delete(session.id)
    let remaining = try await store.recent(limit: 5)

    #expect(favorite?.isFavorite == true)
    #expect(remaining.isEmpty)
}

@Test func fileHandoffStoreConsumesOnce() async throws {
    let url = tempURL("handoff")
    let store = FileHandoffStore(fileURL: url)
    let handoff = ShareHandoff(kind: .text, text: "Hello world", platformHint: .reddit)

    try await store.write(handoff)
    let first = try await store.consumeLatest()
    let second = try await store.consumeLatest()

    #expect(first?.text == "Hello world")
    #expect(first?.makeSession().platform == .reddit)
    #expect(second == nil)
}

@Test func urlHandoffRoundTripsAndBuildsEditableSession() async throws {
    let url = tempURL("url-handoff")
    let store = FileHandoffStore(fileURL: url)
    let link = URL(string: "https://reddit.com/r/product/comments/123")!
    let handoff = ShareHandoff(kind: .url, text: "Discussion title", url: link, platformHint: .reddit)

    try await store.write(handoff)
    let consumed = try await store.consumeLatest()
    let session = consumed?.makeSession()

    #expect(consumed?.url == link)
    #expect(session?.origin == .shareExtension)
    #expect(session?.platform == .reddit)
    #expect(session?.sourceDraft.contains("Discussion title") == true)
    #expect(session?.sourceDraft.contains(link.absoluteString) == true)
}

@Test func imageHandoffPreservesFileReferenceInSession() async throws {
    let handoff = ShareHandoff(kind: .image, imageFileName: "HandoffImages/sample.png", platformHint: .general)

    let session = handoff.makeSession()

    #expect(session.mode == .ocr)
    #expect(session.origin == .screenshot)
    #expect(session.sourceImageFileName == "HandoffImages/sample.png")
}
