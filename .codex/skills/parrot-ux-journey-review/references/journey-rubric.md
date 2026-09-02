# Parrot Journey Rubric

## First Principles

Parrot is a utility for turning text in the user's current context into useful translated text with minimum interruption. Every interaction should preserve three things:

- **Continuity**: the user should not lose the source text, current task, or previous app context.
- **Editability**: every captured or typed source should be editable before and after translation.
- **Recoverability**: every failure should have a visible next action.
- **Spatial stability**: once the user moves, resizes, or pins a workspace, translation, OCR, provider updates, and content resizing should not move or resize it unexpectedly.

## Severity

- **P0**: prevents a normal user from completing or correcting a translation task, loses input, hides state, or creates a surprising context switch.
- **P1**: makes the task slower or less confidence-inspiring but has a workaround.
- **P2**: polish, discoverability, or efficiency issue.

## Target Surface Model

Prefer one reusable translation workspace:

- Source composer at top: editable captured/typed/OCR/history text.
- Action row: translate, swap language, source/target language, copy source, clear, pin.
- Results below: provider cards update in place.
- Draft state persists while the panel is visible.
- Retrying after edit updates the same panel.
- Dragged/pinned workspace position and user-resized dimensions persist while the panel remains visible; resizing only clamps to the visible screen and never jumps back to an old cursor anchor or default size.

Avoid a split model where input happens in one window and results appear in another with no way back.

## Keyboard Defaults

- `Option+D`: capture selection into workspace and translate automatically, but keep source editable.
- `Option+A`: open workspace with source composer focused.
- `Enter`: translate current source.
- `Shift+Enter`: insert newline while editing multiline text.
- `Command+L`: focus source composer.
- `Escape`: close only when not dirty, or ask/keep draft when source was edited.
- `Command+C`: copy selected text if selection exists; otherwise copy primary result.

## Hard Questions

Ask these for every journey:

- Can the user edit what Parrot captured?
- Can the user rerun translation without reopening another window?
- Can the user recover from a wrong capture, wrong OCR, wrong language, or failed engine?
- Does the panel explain whether it is waiting, failed, partial, or done?
- Does the flow return the user to their original app when the task is done?
- Does history preserve enough context to reuse a previous translation?
- Does the interaction work with keyboard only?
- If the user drags, resizes, or pins the workspace, does it remain stable through retranslation, result growth, OCR completion, and provider retries?

## Common Anti-Patterns In This Project

- Static source blocks that force users to restart the flow to correct one character.
- A dedicated input panel that disappears after submit and sends results to a separate panel.
- Auto-hide behavior that treats editing, reading, and completed consumption the same.
- Resize or result-update behavior that repositions a user-moved panel back to the original mouse/capture anchor, or shrinks a user-resized panel back to a default size.
- OCR auto-translating recognized text without keeping the recognized source editable for removing headers, page numbers, and noise before retranslation.
- A separate result-order panel disconnected from the enabled-engine list; enabled engines should be reordered where they are enabled.
- Settings changes that do not return the user to the task that triggered the configuration need.
