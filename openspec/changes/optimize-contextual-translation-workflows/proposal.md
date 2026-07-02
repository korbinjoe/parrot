# Proposal: Contextual Translation Workflows

- **Change name**: `optimize-contextual-translation-workflows`
- **Status**: Proposed
- **Date**: 2026-07-01
- **Author**: product-design / fullstack-engineer
- **Related**:
  - `docs/current-product-competitiveness-analysis.md`
  - `docs/ux-interaction-optimization-plan.md`
  - `openspec/changes/add-ios-quick-lens/`
  - `openspec/changes/add-translation-terminology/`

## Summary

Upgrade Parrot from a translation-result panel into a contextual translation workspace inspired by the strongest Immersive Translate patterns: low-interruption quick explanations, bilingual paragraph reading, scene-aware profiles, OCR text-block selection, provider quality fallback, and local privacy masking.

The change keeps Parrot's own product shape. It does not attempt to clone full webpage translation, PDF layout preservation, or video subtitles. Instead, every improvement routes back to Parrot's core loop:

```text
select / screenshot / type / share
  -> editable source workspace
  -> context-aware result
  -> retry / refine / copy / reply / save
```

## Motivation

Immersive Translate wins user time because it puts translation inside the user's current reading or input flow. Parrot already has the harder OS-level foundation: macOS hotkeys, OCR, editable source draft, multi-engine aggregation, terminology, plugins, and iOS social Understand/Express. The missing layer is a more contextual product experience:

1. Short text should not always open a full workspace.
2. Long text should not be shown only as one source block and one result block.
3. OCR should start from likely text blocks, not a flat blob of recognized text.
4. Providers should be selected and evaluated by task intent, not only by user ordering.
5. Sensitive content should be locally protected before cloud requests.
6. User-facing modes should say "Understand", "Polish", "Reply", or "Strict terminology" instead of exposing prompt/provider complexity.

These changes directly target Parrot's core metrics: first-pass rate and task success rate.

## Goals

1. Add a **Quick Peek** path for short selection/lookup tasks that gives immediate meaning without forcing a full workspace.
2. Add **paragraph bilingual reading** inside the existing workspace for long source text.
3. Add **context profiles** that tune prompts, provider routing, terminology strictness, and result layout for common scenes.
4. Extend OCR flows with **text-block candidates** and block switching for macOS screenshot OCR and iOS Quick Lens.
5. Add **privacy masking** for sensitive entities before cloud provider calls.
6. Add **quality evaluation and fallback** so obvious bad results do not become the primary recommendation.
7. Preserve the existing editable source draft, provider cards, history, settings, terminology, and plugin model.

## Non-Goals

- No full browser webpage rewriting or DOM injection.
- No full PDF/ePub layout-preserving renderer.
- No video subtitle or live meeting transcription workflow.
- No manga/comic image inpainting.
- No account system or cloud sync in this change.
- No hosted AI credit or billing implementation.
- No removal of BYO Key or existing provider configuration.

## Approach

### P0 Experience Layer

- Add `QuickPeekView` for short selections and lookup-like text.
- Add paragraph segmentation and `BilingualParagraphView` inside `ResultView`.
- Add a mode/profile selector in the workspace header using compact segmented/menu controls.
- Keep every entry point able to expand into the full editable workspace.

### P1 Context Layer

- Add `TranslationContextProfile` to represent task intent and scene:
  - quickTranslate
  - understand
  - nativePolish
  - reply
  - strictTerminology
  - privateLocal
  - github
  - social
  - email
  - document
- Add `TranslationContext` to carry source origin, app/window/URL metadata when available, OCR block metadata, selected profile, and privacy policy.
- Add provider routing hints without making providers responsible for UI choices.

### P1 OCR Layer

- Reuse the Quick Lens candidate model for macOS screenshot OCR where possible.
- Show screenshot context and highlighted text blocks when OCR returns useful geometry.
- Tapping another block updates the editable source draft and reruns translation in place.

### P1 Safety / Quality Layer

- Add local sensitive-entity masking before cloud provider calls.
- Add result quality checks for empty output, wrong language, placeholder leakage, extreme length ratio, terminology misses, and provider timeout.
- Show a recommended result only when it passes basic checks; otherwise fallback or mark the result as needing review.

## Risks

| Risk | Impact | Mitigation |
| --- | --- | --- |
| Workspace becomes too complex | Users may lose the fast utility feel | Gate advanced controls behind compact profile menu and progressive disclosure |
| Quick Peek fragments the unified workspace model | Short tasks may bypass edit/retry | Quick Peek must always offer expand/edit and must not become a separate state model |
| OCR block selection duplicates iOS Quick Lens logic | Divergent behavior across platforms | Share candidate scoring models where platform-neutral; keep only rendering/platform capture separate |
| Privacy masking corrupts text | Translation quality may drop | Default to conservative entity types, show masking count, allow per-request disable |
| Quality fallback hides user-preferred provider output | Power users may distrust routing | Keep provider cards visible; recommended result is additive, not a replacement |
| Context metadata collection feels invasive | Trust risk | Collect only foreground/task metadata, show source labels, never background-scan |

## Impact Scope

| Area | Impact |
| --- | --- |
| `Sources/ParrotApp/AppState.swift` | Add context profile/session metadata, Quick Peek routing, paragraph mode state |
| `Sources/ParrotApp/ResultView.swift` | Add profile selector, paragraph bilingual layout, recommended result affordance |
| `Sources/ParrotApp/FloatingPanel.swift` | Support Quick Peek sizing and expand-to-workspace transition |
| `Sources/ParrotApp/ScreenOCR.swift` / `OCRCoordinator+App.swift` | Preserve OCR block geometry for candidate UI |
| `Sources/ParrotCore/` | Add context profile, privacy masking, result quality metadata, routing hints |
| `Sources/ParrotEngines/` | Consume context/profile hints in LLM prompts and provider requests where applicable |
| `Sources/ParrotSocial/` | Reuse candidate scoring and social profile semantics where possible |
| `Tests/` | Add segmentation, masking, quality evaluation, profile routing, OCR candidate tests |
| `openspec/specs/` | Later archive into `app-ui`, `ocr`, and `translation-engine` |

