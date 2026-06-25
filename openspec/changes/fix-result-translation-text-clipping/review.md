# Review

## Code Review
Pass. Selectable translated text now measures from actual AppKit text layout instead of a fixed line estimate, so the translated output is not clipped before the learning panel.

## Architecture Review
Pass. The fix stays inside macOS result presentation. It does not alter engine output, persistence, learning state, or iOS surfaces.

## UI Review
Pass. The result panel continues to use the outer workspace scroll behavior for tall content. Default width was reduced slightly to preserve manual resize headroom on constrained screens.

## Verification
- `swift test --filter EngineValidatorTests` passed with 10 tests after the learning-card follow-up.
- `git diff --check` passed.
- `.codex/skills/ui-acceptance-review/scripts/parrot-ui-acceptance.sh` passed with 92 Swift tests, release build, launch, menu fallback checks, URL smoke checks, result panel smoke check, and workspace resize stability checks.
