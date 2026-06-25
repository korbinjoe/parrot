# Design: Language Polish Interactive Mockup

## Product Decision

Language polishing is an Express workspace mode, not a separate translation card. The user is trying to publish a better paragraph, so the UI should optimize for editable intent, a trusted primary rewrite, and fast copy/replace actions.

## UX Structure

The mockup contains four coordinated surfaces:

- **Today**: entry points for Native Polish, Clipboard, and Screenshot.
- **Workspace**: source draft editor, mode selector, tone controls, primary native rewrite, variants, and intent-preservation notes.
- **Compare**: source-to-native diff and change explanation.
- **History**: recent polished drafts and reusable results.

## Interaction Contract

- Mode pills switch between `Understand`, `Translate`, and `Polish`.
- Tone chips update the active native result without clearing the draft.
- `Copy` shows inline feedback and preserves context.
- `Replace draft` moves the active native result back into the source editor.
- Refinement actions change the active tone/result in place.
- Source edits mark the draft as changed and keep prior output visible until rerun.
- A desktop preview panel demonstrates how the same capability appears in macOS.

## Visual Language

- Background: quiet paper tone matching iOS `IOSTheme.paper`.
- Cards: `surface` / `surface2` with 8px radius, thin line, restrained shadow.
- Accents: green for primary polish action, cyan for navigation/context, coral for expressive/writing emphasis, amber for review/change notes.
- Typography: system font, compact rounded feel through weight and spacing; no decorative hero treatment.

## Data Model For Prototype

```js
scenario = {
  source,
  context,
  tone,
  result,
  variants,
  kept,
  changed,
  diffTokens
}
```

## Decisions

- The primary result card displays one best native version first; alternatives are secondary.
- Diff is explanatory rather than exhaustive, highlighting only the changes a user needs to trust.
- The mockup opens as a direct HTML file and does not require a dev server; Lucide icons load from CDN.
