---
name: parrot-ux-journey-review
description: Product-level UX journey review for Parrot. Use when asked to review, redesign, optimize, or plan Parrot interactions from the user's perspective across selection translation, input translation, OCR, lookup, history, settings, permissions, shortcuts, menu bar, result panels, editing, retries, and recovery. Produces a full-chain interaction audit and rework plan, and rejects flows that feel broken, uneditable, surprising, or context-switch heavy.
---

# Parrot UX Journey Review

## Purpose

Use this skill to review Parrot as a real user trying to get translation work done, not as a set of isolated SwiftUI screens. The output must identify broken journey links, classify severity, and produce an implementation-ready optimization plan.

## Start

1. Run `scripts/collect-parrot-ux-context.sh` to gather current UI entry points and relevant files.
2. Read `references/journey-rubric.md`.
3. Map every user journey before proposing UI changes.
4. If a journey has no edit path, no recovery path, or an unexpected screen switch, mark it P0 and send it back for redesign.

## Required Journey Map

Cover these journeys every time unless the user narrows scope:

- Selected text translation: select text -> `Option+D` -> review -> edit source -> retranslate -> copy/use -> return.
- Manual input translation: `Option+A` -> type/paste -> translate -> edit again -> compare engines -> copy/use.
- Lookup: select/type word -> lookup -> inspect pronunciation/definition -> switch to translation if needed.
- OCR translation: `Option+S` -> capture -> OCR text enters editable workspace -> auto-translate -> inspect/remove noise/edit -> retranslate -> copy/use.
- History reuse: open history -> search -> reopen prior item -> edit -> retranslate.
- Error recovery: missing permission, missing key, timeout, offline, unsupported language.
- Settings/configuration: enable engine -> reorder enabled engines in the same list -> configure key/model/endpoint -> validate -> return to original task.
- Spatial continuity: user moves/pins/resizes workspace -> edit/retranslate/result updates -> workspace keeps the user's position and size.

For each journey, document:

- User goal.
- Entry point.
- Current state transitions.
- Friction and surprise.
- Missing edit/retry/recovery affordance.
- Desired state transitions.
- Acceptance checks.

## Design Bar

Parrot should behave like a single translation workspace with multiple entry points, not like several disconnected popups.

Reject designs where:

- Captured text becomes read-only with no obvious edit path.
- `Option+A` sends the user to a different surface after submit.
- Pressing Enter destroys the editing context or clears text unexpectedly.
- The user cannot revise source text and rerun translation in place.
- A result panel steals focus but cannot accept meaningful input.
- A transient panel hides while the user is editing or before results are consumed.
- A dragged, resized, or pinned workspace jumps back to an old cursor anchor or default size after retranslation, provider updates, OCR completion, or content resize.
- OCR text is translated into a read-only or disconnected surface before the user can remove noise and retranslate in place.
- History retranslation bypasses the editing workspace.
- Result ordering is separated from enabled engines, forcing users to mentally connect two settings areas for one result-list behavior.
- Errors tell the user what failed but not what to do next.

## Output Format

Use this structure:

1. **North Star** - one sentence describing the target interaction model.
2. **Current Journey Findings** - table with journey, P-level, symptom, root cause, user impact.
3. **Target Interaction Model** - state model and surface model.
4. **Optimization Plan** - P0/P1/P2 implementation steps with file/module targets.
5. **Acceptance Criteria** - user-facing checks and automated checks.
6. **Open Risks** - OS permission, AX, multi-screen, engine latency, migration risks.

## Coordination With Acceptance Skill

After the rework plan is implemented, run:

```bash
.codex/skills/ui-acceptance-review/scripts/parrot-ui-acceptance.sh
```

The acceptance script is necessary but not sufficient. It verifies that windows open and core routes work. This skill verifies whether the journeys make sense to a human.
