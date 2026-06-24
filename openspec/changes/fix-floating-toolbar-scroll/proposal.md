# Fix Floating Toolbar Scroll

## Summary
Keep the macOS floating result panel's top action toolbar visible while users scroll translation results.

## Root Cause
`ResultView` renders the language/action header as the first child inside the panel `ScrollView`. When source text or translation cards exceed the visible height, vertical scrolling moves that header out of the viewport with the rest of the content.

## Motivation
The toolbar contains persistent controls for language direction, retry, pinning, favorite, copy, speech, settings, and close. Losing access to those controls during scroll makes the floating panel feel unstable and forces users to scroll back to the top for common actions.

## Goals
- Render the toolbar as fixed panel chrome above the scrollable content.
- Keep source text, notices, loading, empty states, and translation cards scrollable.
- Preserve the current visual style and panel sizing constraints.

## Non-Goals
- Redesign the floating panel.
- Change result card behavior, learning UI behavior, or translation actions.

## Approach
Move `header` out of `ScrollView` into a dedicated top bar container. Adjust the scroll content padding and preferred-height calculation so the fixed toolbar remains accounted for in panel sizing.

## Risks
- Panel preferred height can shrink if the header is removed from measured scroll content without compensating for fixed chrome height.
- A fixed top bar needs explicit background so scrolled content does not visually bleed underneath it.
