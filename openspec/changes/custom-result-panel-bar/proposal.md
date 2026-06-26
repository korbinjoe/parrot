# Proposal: Custom Result Panel Bar

## Summary
Merge the result panel's visible chrome into one custom header bar and expose common actions directly on that bar.

## Motivation
The current result panel can show native window chrome plus an in-content toolbar, creating a double-bar interface. Users need frequent actions to be directly visible, not hidden behind native titlebar constraints or secondary menus.

## Goals
- Show only one visible header bar on the result panel.
- Keep common actions directly accessible: translate/retry, pin, favorite, copy, speak, vocabulary, collapse, settings, close.
- Preserve existing panel behavior: floating, resizable, collapsible, pinnable, keyboard close, and focus-loss handling.
- Keep implementation scoped to result-panel chrome and related UI primitives.

## Non-Goals
- Redesign translation cards, history, settings, or engine ordering.
- Change translation, speech, history, or learning data behavior.
- Replace persistent Settings or History windows.

## Approach
Use a custom SwiftUI bar inside `ResultView` as the only visible header. Keep the AppKit `NSPanel` titled/resizable style mask for window behavior, but hide native title and traffic-light controls. Remove the traffic-light padding compensation from the SwiftUI layout.

## Risks
- Hidden native controls require the custom bar to provide close/collapse affordances.
- A dense action row can overflow narrow panel widths, so icon spacing and labels must remain compact.
