# Proposal: App Internationalization

- **Change name**: `add-app-internationalization`
- **Status**: Proposed
- **Date**: 2026-06-26
- **Owner**: fullstack-engineer
- **Related**: `app-ui`

## Summary

Add a first-class application language preference for the macOS Parrot app. English becomes the default UI language, and users can switch the app UI to Simplified Chinese or other major international languages from Settings.

## Motivation

Parrot already wraps most macOS UI copy in `L(...)`, but the current behavior still depends on Bundle/system localization and uses Chinese source strings as the visible fallback. That makes the first-run experience Chinese on machines where English should be the product default, and it gives users no explicit control over the app UI language.

Language selection should be a user preference, not an OS side effect. This also gives the product a stable foundation for expanding translation catalogs without rewriting every UI call site.

## Goals

- Default the macOS app UI to English on first launch.
- Add a persisted Settings > General app language picker.
- Support Simplified Chinese as a selectable app language.
- Expose major international language options with starter catalogs that can be filled incrementally without changing UI architecture.
- Keep existing Chinese string keys and `L(...)` call sites to avoid a risky all-at-once rewrite.
- Update UI acceptance expectations for the new English default.

## Non-goals

- Do not change translation source/target language defaults.
- Do not localize iOS screens in this change; iOS currently uses a separate hardcoded-English UI surface.
- Do not require an app restart for SwiftUI settings content to refresh.
- Do not block language selection on 100% translated catalogs for every listed major language; starter catalogs cover core chrome/settings and missing deep keys fall back to English.

## Approach

- Extend `Localization.swift` with a supported app-language catalog, English default, per-language resource lookup, English fallback, and a language-change notification.
- Add `AppSettings.appLanguageCode` persisted in `UserDefaults`.
- Add an app-language picker to `SettingsView.generalPane`.
- Refresh app menus and known window titles when the language preference changes.
- Fill the existing English catalog gaps for current macOS `L(...)` keys and keep Simplified Chinese as identity fallback because current keys are Chinese.

## Risks

- Existing UI acceptance automation expects Chinese menu/window titles; it must be updated with the English default.
- Some non-literal or non-`L(...)` strings may remain untranslated; this change establishes the mechanism and covers the current macOS localized-string surface.
- Major-language options beyond English and Simplified Chinese may initially use English fallback where catalogs are incomplete.
