# Changelog

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
