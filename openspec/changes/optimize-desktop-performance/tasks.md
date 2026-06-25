# Tasks: Optimize Desktop Performance

- [x] Add cached provider display order and missing-configuration outcomes to `AppState`.
- [x] Remove provider/plugin reloads from translation start and provider retry hot paths.
- [x] Update `ResultView` to use cached provider ordering instead of recomputing from settings.
- [x] Move learning occurrence-count calculation off the main actor with stale-refresh protection.
- [x] Materialize filtered records in `HistoryModel` rather than filtering during every body render.
- [x] Add focused tests for provider display-order caching and history-store latest/slice behavior.
- [x] Run OpenSpec validation and Swift test verification.
- [x] Write verification review notes in `review.md`.
