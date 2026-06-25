# Fix Manual Learning Selection Lookup

## Summary
Manual source-text selections in the result view can show a hardcoded generic learning meaning when the selected expression is not one of the built-in recommendation entries.

## Root Cause
`LearningRecommendationEngine.expressionForManualSelection` falls back to `genericExpression`, whose `meaning` is static. The result view does not pass lookup/definition information into that path, so selected words that have real dictionary definitions still render the generic learning explanation.

## Goals
- Use real lookup/definition data for manual learning selections when available.
- Preserve the existing generic fallback when no definition is available.
- Keep the change scoped to the manual learning selection path.

## Non-Goals
- Replace the recommendation engine.
- Add new network-backed dictionary providers.
- Redesign the learning UI.

## Risks
- Definitions may be unavailable for phrases or terms not covered by local lookup data.
- The fix must avoid regressing existing built-in recommendation meanings.
