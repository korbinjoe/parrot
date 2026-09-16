# Changelog

## 2026-09-16

### Fixed

- Fixed severe Settings window lag on macOS 26/27 and Apple silicon Macs: `SettingsView` no longer observes the entire `AppState`, so unrelated high-frequency changes (typing in the floating panel, translation progress, network status) stop repainting the 2,500-line settings tree on every emission.
- Removed the `AppSettings.objectWillChange → AppState.objectWillChange` fan-out in `AppState.init`, eliminating the double-refresh that hit `SettingsView` on every settings toggle.
- Moved permission state into a dedicated `PermissionsHolder` observable so only permission-aware views (settings sheet, menu-bar popover) re-render on `refreshPermissions`.
- Dropped the pane-switch `.id` + `.transition(.opacity)` + `.easeInOut` animation in the Settings window; switching tabs is now a single frame instead of an alpha-blended crossfade of two large SwiftUI subtrees.

### Added

- Added `SettingsViewReactivityTests` (4 tests) locking down the new observation graph: settings toggles must not bump `AppState.objectWillChange`, keystrokes in `sourceDraft` must not bump settings/permissions observers, and `refreshPermissions()` must only bump the permissions holder.

## 2026-06-27

### Added

- Added a persisted app language preference with English as the default UI language.
- Added Settings > General app language selection for English, Simplified Chinese, Japanese, Korean, French, German, and Spanish.
- Added starter localization catalogs for Japanese, Korean, French, German, and Spanish, plus Simplified Chinese fallback resources.
- Added localization tests for default language behavior, unsupported saved-language fallback, and selected-locale formatted strings.
- Added OpenSpec artifacts for the app internationalization change.
- Added Xiaohongshu research notes on translation and English-learning pain points.

### Changed

- Updated localized string resolution to use the selected app language with English fallback for incomplete catalogs.
- Refreshed app menus and known window titles immediately after app language changes.
- Localized additional macOS app chrome, settings, history, learning, vocabulary, input, and result-panel labels.
- Updated the Parrot UI acceptance script to validate the English default UI.

### Removed

- Removed the local Codex stop-hook configuration from the repository.
