---
name: ui-acceptance-review
description: Automated UI acceptance and product-review gate for Parrot after feature development, UI changes, interaction changes, window/menu changes, shortcut changes, permission-flow changes, URL scheme changes, or before declaring a Parrot feature complete. Use to run deterministic macOS GUI checks, review interaction quality, and reject obvious UX regressions for rework.
---

# UI Acceptance Review

## Workflow

Run this skill after every Parrot feature implementation that can affect the user experience.

1. Inspect the changed UI surface and list the expected user-facing behavior.
2. Run `scripts/parrot-ui-acceptance.sh` from this skill.
3. Treat any script failure as a hard gate unless the failure is an external OS permission blocker.
4. Review the UI from first principles: the user should know what happened, what is possible, what is blocked, and how to recover.
5. If there is an obvious UX issue, do not mark the feature complete. Implement the fix and run the gate again.

## Hard Gates

Reject the implementation and return to development if any of these are true:

- Build or tests fail.
- The app cannot launch from `build/Parrot.app`.
- `parrot://translate?...` does not route to the current build.
- Result, settings, history, or input windows do not appear when triggered.
- Standard App menu fallback entries are missing.
- A permission-dependent action can fail silently.
- A window opens off the visible screen or away from the user's likely attention area.
- A user-moved, user-resized, or pinned workspace jumps back to a previous cursor anchor or default size after in-place translation, provider updates, OCR completion, retry, or content resize.
- A required control is inaccessible to AX automation without a fallback path.
- Error states do not include a clear recovery action.

## Script

Use:

```bash
.codex/skills/ui-acceptance-review/scripts/parrot-ui-acceptance.sh
```

The script runs Swift tests, builds the release app, launches the built app, validates menu fallback entries through Accessibility APIs, opens settings/history/input windows, triggers URL Scheme translation against the built app, checks that a result panel window appears, and tails the debug log for the routed URL.

If the script reports that the test runner lacks Accessibility access, request or grant Accessibility permission for the terminal/agent host and rerun. Do not count that as a product pass.

## Manual Review Checklist

After the script passes, do a short review of the changed screens:

- Is the primary action available without relying on hidden state?
- Are disabled actions visibly disabled and explained?
- Does each failure state tell the user exactly what to do next?
- Are settings dense but scannable, with advanced controls visually secondary?
- Do windows open on the current mouse or active screen and stay within visible bounds?
- If the user drags or resizes the workspace, does it stay there after pressing `Enter`, provider cards arriving, OCR completion, and retry actions?
- Do menu, keyboard, and URL Scheme entry points converge on the same behavior?
- Are accessibility labels present for icon-only or non-obvious controls?

Only finish the task when both the automated gate and this review are clean.
