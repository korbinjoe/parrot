# Review

## Code Review
Pass. `ResultView` now renders the language/action toolbar above the `ScrollView`, so vertical scrolling only affects notices, source content, result states, and provider cards.

## Architecture Review
Pass. The change stays within macOS floating panel presentation. No data model, translation engine, plugin, iOS, or persistence contracts changed.

## UI Review
Pass. The fixed toolbar keeps the existing visual treatment, uses the panel background to avoid scroll bleed, and preserves preferred panel sizing by accounting for fixed toolbar chrome.

## Verification
- `swift test` passed with 87 tests.
- `.codex/skills/ui-acceptance-review/scripts/parrot-ui-acceptance.sh` passed, including release app build, launch, AX/menu checks, URL smoke checks, and result panel smoke check.
