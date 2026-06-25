# Review

## Code Review
Pass. The fix reuses the existing `VocabularyWindow` and adds only the missing callback path from `AppDelegate` through `FloatingPanel` into `ResultView`.

## Architecture Review
Pass. The change stays within macOS floating panel presentation and does not alter vocabulary persistence, learning selection, review scheduling, engines, or iOS surfaces.

## UI Review
Pass. The result toolbar now exposes personal vocabulary with an icon-only book control using the existing `IconButton` size, tooltip, hover treatment, and accessibility label.

## Verification
- `swift test --filter EngineValidatorTests` passed with 9 tests.
- `git diff --check` passed.
- `.codex/skills/ui-acceptance-review/scripts/parrot-ui-acceptance.sh` passed, including 91 Swift tests, release app build, launch, menu fallback checks, URL smoke checks, and result panel smoke check.
