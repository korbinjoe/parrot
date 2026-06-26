# Design: Custom Result Panel Bar

## Architecture
The result panel remains an AppKit `WorkspacePanel` hosted by SwiftUI. AppKit continues to own floating level, resizing, collapse frame management, and close interception. SwiftUI owns the only visible panel chrome.

## Result Bar Layout
The expanded panel bar contains:

- Left cluster: language direction control, short state chips.
- Right cluster: retry/translate, copy primary translation, pin, favorite, copy source, speak source, vocabulary, collapse, settings, close.

The collapsed panel uses the same visual surface and removes the former native-titlebar leading inset.

## Decisions
- Use custom SwiftUI chrome instead of `NSTitlebarAccessoryViewController`; this keeps all high-frequency actions visible without AppKit titlebar layout constraints.
- Keep the `NSPanel` style mask titled/resizable, but hide native title and standard window buttons. This preserves resize and window lifecycle behavior while eliminating the double visible bar.
- Keep action buttons icon-only with help/accessibility labels to control density.
- Keep expanded result panel minimum width at 520pt so exposed actions do not crowd the language/status cluster.

## Impact Scope
- `Sources/ParrotApp/FloatingPanel.swift`: native chrome visibility.
- `Sources/ParrotApp/ResultView.swift`: custom bar layout and action exposure.
- `openspec/changes/custom-result-panel-bar/*`: change documentation.
