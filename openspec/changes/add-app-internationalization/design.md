# Design: App Internationalization

## Scope

This change implements macOS `ParrotApp` UI internationalization. The existing macOS app already uses `L(...)` across most user-facing strings and has `Resources/*.lproj` copied into `build/Parrot.app` by `scripts/build-app.sh`, so it is the correct first surface.

iOS screens remain a follow-up because they currently use hardcoded English SwiftUI text and do not share `Sources/ParrotApp/Localization.swift`.

## Decisions

- **Default language**: `en`.
- **Chinese mode**: `zh-Hans`, implemented as identity fallback because current localization keys are Simplified Chinese.
- **Major-language options**: English, Simplified Chinese, Japanese, Korean, French, German, and Spanish.
- **Starter catalogs**: Japanese, Korean, French, German, and Spanish ship core chrome/settings translations first; incomplete deep strings fall back to English.
- **Fallback**: missing strings in non-English languages fall back to English, then finally to the original key.
- **Persistence key**: `app.languageCode` in non-secret `UserDefaults`.
- **No call-site rewrite**: keep Chinese source keys for now; converting to semantic keys would create a large high-risk diff without improving the first-pass behavior.

## Runtime Flow

1. `AppSettings` loads `app.languageCode`; if absent or unsupported, it uses `L10n.defaultLanguageCode`.
2. `L(...)` resolves strings through `L10n.string`.
3. `L10n` selects a language-specific `.lproj` bundle from `Bundle.main`.
4. If the selected language does not provide the key, `L10n` tries English.
5. If English does not provide the key, `L10n` returns the original key.
6. Formatting uses the selected language locale instead of `Locale.current`.

## Settings UX

`Settings > General` adds an `App Language` row above translation language defaults.

- The picker displays language names in their native form.
- Changing the picker persists immediately.
- SwiftUI settings content re-renders through `AppSettings` observation.
- AppKit menu titles and known window titles refresh via a language-change notification.

## Validation

- Unit tests cover default language selection, unsupported-code fallback, Chinese identity fallback, and formatted English strings.
- `swift test` must pass.
- UI acceptance should use English default labels after this change.

## Future Work

- Move localization to a shared package if iOS should use the same runtime language preference.
- Replace Chinese source keys with semantic localization keys once catalogs are complete.
- Expand Japanese, Korean, French, German, and Spanish from starter catalogs to complete coverage.
