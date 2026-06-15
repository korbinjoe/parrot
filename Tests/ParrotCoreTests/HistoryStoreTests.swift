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
