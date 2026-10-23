import Testing
import Foundation
@testable import ParrotCore

private func tempStore(max: Int = 5000) -> HistoryStore {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("parrot-test-\(UUID().uuidString).json")
    return HistoryStore(fileURL: url, maxRecords: max)
}

private func record(_ src: String, _ dst: String, fav: Bool = false) -> TranslationRecord {
    TranslationRecord(sourceText: src, translated: dst, providerId: "mock",
                      sourceLang: "en", targetLang: "zh", isFavorite: fav)
}

@Test func addAndListNewestFirst() async {
    let store = tempStore()
    await store.add(record("hello", "你好"))
    await store.add(record("world", "世界"))
    let all = await store.all()
    #expect(all.count == 2)
    #expect(all.first?.sourceText == "world")  // newest first
}

@Test func latestReturnsBoundedNewestRecords() async {
    let store = tempStore()
    await store.add(record("oldest", "1"))
    await store.add(record("middle", "2"))
    await store.add(record("newest", "3"))

    let latest = await store.latest(limit: 2)
    let empty = await store.latest(limit: 0)
    #expect(latest.map(\.sourceText) == ["newest", "middle"])
    #expect(empty == [])
}

@Test func historyPersistsStructuredInterpretation() async {
    let fileURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("parrot-interpretation-\(UUID().uuidString).json")
    let store = HistoryStore(fileURL: fileURL)
    let interpretation = InterpretationResult(
        intendedMeaning: "说话者在祝对方好运。",
        localizedTranslation: "祝你好运！",
        literalTranslation: "摔断一条腿。",
        confidence: 0.96
    )
    let item = TranslationRecord(
        sourceText: "Break a leg.",
        translated: interpretation.localizedTranslation,
        providerId: "llm",
        outcomes: [
            TranslationRecordOutcome(
                providerId: "llm",
                displayName: "LLM",
                translated: interpretation.localizedTranslation,
                interpretation: interpretation
            )
        ],
        sourceLang: "en",
        targetLang: "zh"
    )

    await store.add(item)
    let reloaded = HistoryStore(fileURL: fileURL)
    let stored = await reloaded.all().first

    #expect(stored?.displayOutcomes.first?.interpretation == interpretation)
}

@Test func searchMatchesSourceAndTranslation() async {
    let store = tempStore()
    await store.add(record("hello", "你好"))
    await store.add(record("good", "世界好"))
    let bySource = await store.search("hello")
    #expect(bySource.count == 1)
    let byTranslation = await store.search("好")
    #expect(byTranslation.count == 2)
}

@Test func favoriteToggleAndFilter() async {
    let store = tempStore()
    let r = record("hello", "你好")
    await store.add(r)
    _ = await store.setFavorite(r.id, true)
    let favs = await store.favorites()
    #expect(favs.count == 1)
    #expect(favs.first?.id == r.id)
}

@Test func persistsAcrossInstances() async {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("parrot-persist-\(UUID().uuidString).json")
    let s1 = HistoryStore(fileURL: url)
    await s1.add(record("persist", "持久"))
    let s2 = HistoryStore(fileURL: url)
    let all = await s2.all()
    #expect(all.count == 1)
    #expect(all.first?.translated == "持久")
}

@Test func historyDefersDiskReadUntilFirstOperation() async throws {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("parrot-lazy-history-\(UUID().uuidString).json")
    defer { try? FileManager.default.removeItem(at: url) }
    let store = HistoryStore(fileURL: url)
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    let existing = record("saved", "已有记录")
    try encoder.encode([existing]).write(to: url)

    // The store is constructed during app startup; disk I/O belongs to its actor's
    // first operation. Later reads use the loaded snapshot instead of rereading JSON.
    #expect(await store.all().map(\.id) == [existing.id])
    try encoder.encode([record("external", "外部修改")]).write(to: url)
    #expect(await store.all().map(\.id) == [existing.id])
}

@Test func firstHistoryMutationPreservesPreviouslySavedRecords() async {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("parrot-lazy-mutation-\(UUID().uuidString).json")
    defer { try? FileManager.default.removeItem(at: url) }
    let original = HistoryStore(fileURL: url)
    await original.add(record("saved", "已有记录"))

    let reopened = HistoryStore(fileURL: url)
    await reopened.add(record("new", "新记录"))
    #expect(await reopened.all().map(\.sourceText) == ["new", "saved"])
    #expect(await HistoryStore(fileURL: url).all().map(\.sourceText) == ["new", "saved"])
}

@Test func extendingHistoryOutcomesPreservesIdentityFavoriteAndMetadata() async {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("parrot-history-comparison-\(UUID().uuidString).json")
    defer { try? FileManager.default.removeItem(at: url) }
    let original = TranslationRecord(
        sourceText: "Review this sentence.", translated: "原译文", providerId: "primary",
        sourceLang: "en", targetLang: "zh",
        createdAt: Date(timeIntervalSince1970: 1_730_000_000), isFavorite: true
    )
    await HistoryStore(fileURL: url).add(original)
    let compared = [
        TranslationRecordOutcome(providerId: "primary", displayName: "Primary", translated: "原译文"),
        TranslationRecordOutcome(providerId: "comparison", displayName: "Comparison", translated: "比较译文")
    ]
    let reopened = HistoryStore(fileURL: url)
    #expect(await reopened.updateOutcomes(
        id: original.id, translated: "比较译文", providerId: "comparison", outcomes: compared
    ))
    let saved = await HistoryStore(fileURL: url).all().first
    #expect(saved?.id == original.id)
    #expect(saved?.createdAt == original.createdAt)
    #expect(saved?.isFavorite == true)
    #expect(saved?.sourceText == original.sourceText)
    #expect(saved?.sourceLang == "en")
    #expect(saved?.targetLang == "zh")
    #expect(saved?.providerId == "comparison")
    #expect(saved?.translated == "比较译文")
    #expect(saved?.outcomes == compared)
}

@Test func capTrimsNonFavoritesFirst() async {
    let store = tempStore(max: 2)
    let fav = record("keep", "保留", fav: true)
    await store.add(fav)
    _ = await store.setFavorite(fav.id, true)
    await store.add(record("a", "1"))
    await store.add(record("b", "2"))
    await store.add(record("c", "3"))
    let all = await store.all()
    #expect(all.count == 2)
    #expect(all.contains { $0.id == fav.id })  // favorite survives the cap
}
