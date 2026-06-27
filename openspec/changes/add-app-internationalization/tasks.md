# Tasks: App Internationalization

## Phase 0 - OpenSpec

- [x] Create proposal, design, task list, and app-ui delta spec.

## Phase 1 - Localization Runtime

- [x] Add app language catalog, English default, supported-code normalization, selected-locale formatting, and fallback lookup to `Localization.swift`.
- [x] Add focused unit tests for language resolution and formatted strings.

## Phase 2 - Settings and App Refresh

- [x] Persist `app.languageCode` in `AppSettings`.
- [x] Add Settings > General app language picker.
- [x] Refresh app menu and known window titles after language changes.

## Phase 3 - Catalogs and Automation

- [x] Fill missing English catalog entries for current macOS `L(...)` keys.
- [x] Add Simplified Chinese identity resource note / fallback behavior.
- [x] Add starter catalogs for Japanese, Korean, French, German, and Spanish.
- [x] Update UI acceptance labels for English default.

## Phase 4 - Verification

- [x] Run `swift test`.
- [x] Run Parrot UI acceptance gate, or document external blocker.
