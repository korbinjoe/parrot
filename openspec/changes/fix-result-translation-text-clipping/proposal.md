# Fix Result Translation Text Clipping

## Summary
Fix translated text clipping in the macOS floating result panel when translated text is selectable for manual learning.

## Root Cause
The translated text view was changed to an `NSTextView` wrapper for selection tracking, but the SwiftUI wrapper forced a fixed estimated height. The estimate capped unlimited text at 16 lines and undercounted wrapped Chinese text, so the result card could cut off the bottom of translated lines before the learning panel.

Follow-up visual testing showed the AppKit measurement still left the selectable `NSTextView` with zero vertical drawing inset. The card had enough layout space, but the text view could clip the final glyph row at its own bounds.

## Motivation
The result card is the primary reading surface. Translation output must be fully visible and readable before any learning controls or metadata, otherwise the core translation task fails.

## Goals
- Let selectable translated text size itself from actual text layout.
- Preserve translated-text selection for manual learning.
- Keep the change scoped to result-card layout.

## Non-Goals
- Redesign the result card.
- Change learning vocabulary behavior or recommendation logic.
- Change iOS surfaces.

## Approach
Replace the fixed estimated height with an `NSViewRepresentable.sizeThatFits` measurement based on AppKit text layout, then let the outer result panel scroll normally when content is tall.

Add explicit vertical text-container inset for selectable translated text and include that inset in the measured height so the final line has real drawing clearance.

## Risks
- The custom AppKit text view must keep SwiftUI sizing stable while still reporting selection changes.
