# Review: App Internationalization

## Code Review

- Result: Pass.
- Scope reviewed: localization runtime, persisted app language setting, Settings UI picker, English catalog coverage, UI acceptance script expectations, and focused localization tests.
- Notes: The implementation keeps current Chinese source keys to avoid a broad call-site migration. Japanese, Korean, French, German, and Spanish ship starter catalogs; missing deep entries fall back to English by design.

## Architecture Review

- Result: Pass.
- Decision: macOS `ParrotApp` owns this MVP because it already uses `L(...)` and ships `Resources/*.lproj` through `scripts/build-app.sh`.
- Residual follow-up: iOS should get a shared localization layer later; it is intentionally outside this change.

## UI Review

- Result: Pass.
- Expected behavior: first launch defaults to English; Settings > General exposes App Language; Simplified Chinese restores Chinese copy through identity fallback; window titles and menus refresh on language changes.
- Automated gate: `.codex/skills/ui-acceptance-review/scripts/parrot-ui-acceptance.sh` passed.

## Verification

- `swift test` passed with 103 tests.
- `openspec validate add-app-internationalization` passed.
- `git diff --check` passed.
- macOS UI acceptance passed.
