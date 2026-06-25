# Design: Desktop Performance Optimization

## Performance Baseline

Observed hot paths from source inspection:

1. `AppState.translate` calls `reloadProviders()` and `loadPlugins()` for every translation.
2. `AppState.retryProvider` calls `reloadProviders()` for each provider retry.
3. `ResultView.orderedSlots` calls `EngineBootstrap.resolvedProviderOrder(settings:)` on each render.
4. `AppState.refreshLearningHistory` computes `LearningRecommendationEngine.occurrenceCounts(records:)` from all history records inside the main-actor task.
5. `HistoryModel.filtered` lowercases and scans all loaded records as a computed property during view updates.

## Approach

### Provider Refresh Boundary

Provider construction, credential probing, model expansion, OCR/TTS setup, and plugin scanning should happen at explicit configuration boundaries:

- app startup
- `AppState.applySettings()`
- future plugin-management changes

Translation execution should reuse the current registry snapshot. This keeps hotkey/selection translation from paying setup costs before network work even starts.

### Cached UI Ordering

`AppState` will expose cached display data derived during provider refresh:

- `providerDisplayOrder: [String]`
- `missingConfigurationOutcomes: [AggregatedOutcome]`

`ResultView` consumes these arrays instead of recomputing order and missing-configuration cards during body evaluation.

### Background Learning Statistics

History loading remains actor-isolated in `HistoryStore`, but occurrence counting runs in a detached utility-priority task. A monotonically increasing refresh token prevents stale background work from overwriting newer counts.

### History Browser Filtering

`HistoryModel` will materialize `filteredRecords` when records/query/scope/language filters change. The SwiftUI body renders that published array instead of repeatedly evaluating a computed filter during layout.

## Decisions

1. Provider/plugin reloads are configuration-boundary work, not translation-boundary work.
2. Result ordering is application state, not view-local derived state.
3. Learning occurrence counts can lag behind history writes slightly; UI responsiveness takes priority over synchronous freshness.
4. History browser filtering remains in memory for now because the current JSON store is capped and no storage format migration is required.

## Verification

- Focused Swift tests for cached provider ordering and history query slices.
- `swift test` or narrower Swift package tests where environment time permits.
- OpenSpec validation for the new change artifacts.
