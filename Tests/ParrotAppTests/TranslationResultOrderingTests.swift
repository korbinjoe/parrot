import Foundation
import Testing
import ParrotCore
@testable import ParrotApp

@MainActor
struct TranslationResultOrderingTests {
    @Test func asynchronouslyCompletedAndFailedCardsKeepTheirConfiguredSlots() {
        let order = ["opencode", "ollama", "apple"]
        let waiting = order.map(pending)
        #expect(slots([], waiting, order).map(\.id) == order)

        // The last configured engine finishes first. The first two stay above it.
        let apple = success("apple")
        #expect(slots([apple], Array(waiting.prefix(2)), order).map(\.id) == order)
        let failed = failure("ollama")
        let partial = slots([apple, failed], [pending("opencode")], order)
        #expect(partial.map(\.id) == order)
        if case .outcome(let outcome) = partial[1] {
            #expect(outcome.error == .network)
        } else {
            Issue.record("Failed engine must stay in its own slot")
        }
        #expect(slots([apple, failed, success("opencode")], [], order).map(\.id) == order)
    }

    @Test func recommendationAndEngineTypeDoNotMoveResultsAboveConfiguredEngines() {
        let order = ["baidu", "apple", "doubao", "openai#alternate"]
        let recommended = success("doubao", recommended: true)
        let outcomes = [recommended, success("openai#alternate"), success("apple"), success("baidu")]
        let presented = slots(outcomes, [], order)
        #expect(presented.map(\.id) == order)
        if case .outcome(let outcome) = presented[2] {
            #expect(outcome.result?.qualitySummary?.isRecommended == true)
        } else {
            Issue.record("The recommendation must remain attached to its configured card")
        }
    }

    @Test func retryReplacesTheSameSlotAndDoesNotDuplicateAnArrivingResult() {
        let order = ["ollama", "apple", "opencode"]
        let completed = [success("apple"), success("opencode")]
        #expect(slots(completed + [failure("ollama")], [], order).map(\.id) == order)
        #expect(slots(completed, [pending("ollama")], order).map(\.id) == order)
        let arrived = slots(completed + [success("ollama")], [pending("ollama")], order)
        #expect(arrived.map(\.id) == order)
        if case .outcome = arrived[0] {} else { Issue.record("Completed result must replace pending state") }
    }

    @Test func settingsReorderingUpdatesExistingCardsAndPreservesModelOrder() {
        let suite = "parrot.result-order.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        for engine in EngineBootstrap.defaultOrder { defaults.set(false, forKey: "engine.\(engine).enabled") }
        let settings = AppSettings(defaults: defaults)
        settings.setModelConfigs([
            EngineModelConfig(id: "alternate", name: "second-model"),
            EngineModelConfig(id: "primary", name: "first-model")
        ], for: "ollama")
        settings.setEngineOrder(["ollama", "apple", "opencode"])
        let historyFile = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let state = AppState(settings: settings, history: HistoryStore(fileURL: historyFile))
        state.outcomes = [success("opencode"), success("ollama"), success("apple"), success("ollama#alternate")]
        let initial = slots(state.outcomes, [], state.providerDisplayOrder)
        #expect(initial.map(\.id) == ["ollama#alternate", "ollama", "apple", "opencode"])

        settings.setEngineOrder(["opencode", "apple", "ollama"])
        state.applySettings()
        let reordered = slots(state.outcomes, [], state.providerDisplayOrder)
        #expect(reordered.map(\.id) == ["opencode", "apple", "ollama#alternate", "ollama"])
        #expect(state.outcomes.count == 4)
        #expect(!state.isTranslating)
    }

    @Test func savedResultsUseCurrentOrderAndKeepUnconfiguredProvidersAtTheEnd() {
        let ids = ["legacy#removed", "apple", "custom-plugin", "opencode", "legacy#other"]
        let saved = ids.map { TranslationRecordOutcome(providerId: $0, displayName: $0, translated: "saved") }
        let ordered = TranslationResultOrdering.ordered(
            saved, providerOrder: ["opencode", "ollama", "apple", "opencode"], providerID: \.providerId
        )
        #expect(ordered.map(\.providerId) == ["opencode", "apple", "legacy#removed", "custom-plugin", "legacy#other"])
        #expect(ordered.count == saved.count)
    }

    private func slots(_ outcomes: [AggregatedOutcome], _ pending: [PendingProviderViewState], _ order: [String]) -> [TranslationSlot] {
        translationSlotsForPresentation(outcomes: outcomes, pendingProviders: pending, providerOrder: order)
    }

    private func pending(_ id: String) -> PendingProviderViewState {
        PendingProviderViewState(id: id, displayName: id, modelName: nil, isSlow: id != "apple")
    }

    private func success(_ id: String, recommended: Bool = false) -> AggregatedOutcome {
        AggregatedOutcome(providerId: id, displayName: id,
            result: TranslateResult(providerId: id, translated: "translated \(id)",
                qualitySummary: ResultQualitySummary(score: 1, isRecommended: recommended)),
            error: nil, latencyMs: 1)
    }

    private func failure(_ id: String) -> AggregatedOutcome {
        AggregatedOutcome(providerId: id, displayName: id, result: nil, error: .network, latencyMs: 2)
    }
}
