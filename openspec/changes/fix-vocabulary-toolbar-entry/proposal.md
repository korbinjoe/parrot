# Fix Vocabulary Toolbar Entry

## Summary
Expose the existing personal vocabulary window from the macOS floating result panel toolbar.

## Root Cause
The personal vocabulary window and menu actions already exist, but `ResultView` only wires toolbar actions for retry, pinning, favorite, copy, speech, settings, and close. No vocabulary callback is passed through `FloatingPanel`, so the fixed toolbar cannot open the wordbook.

## Motivation
Users working in the translation result panel need a direct way to open the vocabulary they are building from selected expressions. Hiding the entry in the menu bar makes the learning workflow feel disconnected from the translation surface.

## Goals
- Add a visible personal vocabulary toolbar action to the floating result panel.
- Reuse the existing `VocabularyWindow` and refresh behavior.
- Keep the change scoped to action wiring and toolbar presentation.

## Non-Goals
- Redesign the learning or vocabulary window.
- Change vocabulary persistence, review scheduling, or selection-learning behavior.
- Add new iOS vocabulary UI.

## Approach
Pass an `onVocabulary` callback from `AppDelegate` into `FloatingPanel`, then into `ResultView`, and render a book icon button in the fixed toolbar that invokes the existing `VocabularyWindow.show()`.

## Risks
- Adding another icon can crowd the fixed toolbar at the minimum floating panel width, so the button should remain icon-only and use the existing 26px toolbar control.
