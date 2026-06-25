# Review: Optimize Desktop Performance

## Code Review

No blocking issues found in the implemented changes.

- Translation start and provider retry no longer rebuild all providers or rescan plugins.
- `ProviderRegistry` exposes ordered provider IDs for cached UI ordering without exposing mutable internals.
- `HistoryStore.latest(limit:)` gives menu-bar recents a bounded read path.
- Focused tests cover provider order IDs and bounded newest-history retrieval.

Verification:

- `swift test` passed: 91 tests.
- `git diff --check` passed.

## Architecture Review

The cache boundary is explicit and conservative:

- Provider caches refresh on app startup, `reloadProviders()`, `loadPlugins()`, and `applySettings()`.
- Translation execution reuses the current registry snapshot.
- Learning occurrence counts run off the main actor and use a generation guard to prevent stale writes.

Residual risk:

- Plugin files copied into the plugin directory while the app is running are no longer picked up implicitly by the next translation. They require an existing configuration refresh path or future explicit plugin refresh.

## UI Review

No visual layout or styling changes were intended. The history browser now renders `filteredRecords` from model state instead of recomputing filters in the SwiftUI body.

Automated UI acceptance was run after building `build/Parrot.app`:

- `scripts/parrot-ui-acceptance.sh` passed.
- The built app launched from `build/Parrot.app`.
- App menu fallback entries were present.
- Settings, history, and input/result windows opened through AX automation.
- OCR fixture and `parrot://translate?...` routing reached the current build.
- The manually moved/resized translation workspace kept position and size after in-place translation.

Manual AX walkthrough after launch found:

- `Parrot 设置` exposes dense settings sections and permission recovery controls, including `打开设置`.
- `Parrot 历史` exposes search, scope/filter controls, result cards, copy/speak/delete actions, and stored translation content.
- `Parrot 翻译` exposes source editor, language controls, pin/favorite/copy/speak/settings/close controls, and URL translation content.

Pixel screenshot review was blocked by environment permissions: `CGPreflightScreenCaptureAccess()` returned `false`, so screenshots show the desktop without app windows.
