# Proposal: Language Polish Interactive Mockup

## Summary

Create a high-fidelity interactive HTML mockup for a language polishing workflow that helps users turn rough multilingual paragraphs into native-speaker-style writing inside Parrot's existing workspace model.

## Motivation

Parrot already has editable Understand and Express surfaces. Language polishing should extend that flow instead of becoming a separate translation result card. A realistic HTML prototype lets product, design, and engineering evaluate hierarchy, copy, and interaction before implementation.

## Goals

- Show a native-polish workflow based on the current iOS Workspace / Express visual language.
- Preserve source draft continuity and make the primary polished result copy-ready.
- Demonstrate tone switching, result variants, diff-style explanation, copy, replace-draft, and refinement interactions.
- Keep the prototype as a single static HTML file so it can open directly from disk without a dev server.

## Non-Goals

- No production SwiftUI implementation.
- No real translation or LLM calls.
- No provider configuration, persistence, or App Group integration.
- No automatic posting or insertion into third-party apps.

## Approach

- Add a standalone mockup at `docs/mockups/language-polish/index.html`.
- Mirror existing iOS theme tokens: paper, surface, ink, muted, green, cyan, coral, amber.
- Model the feature as an Express workspace mode named Native Polish.
- Use embedded sample scenarios and local JavaScript for interactions; load Lucide icons from CDN for visual fidelity.

## Risks

| Risk | Mitigation |
| --- | --- |
| Mockup diverges from production components | Use current app tokens, compact cards, bottom tabs, and workspace structure. |
| Polish feels like generic grammar correction | Label the workflow around native expression and intent preservation. |
| Too many variants slow decision making | Make one primary result dominant and keep alternatives secondary. |
