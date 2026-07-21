# Tasks: Contextual Translation Workflows

## Phase 0 - Spec And Baseline

- [x] [Spec] Review this change with product/architecture before implementation.
- [x] [Spec] Confirm overlap with `add-ios-quick-lens` and `add-translation-terminology`; do not duplicate their archived work.
- [x] [Design] Create high-fidelity interactive HTML mockup for Quick Peek, workspace profiles, OCR blocks, and quality/privacy states.
- [x] [Test] Capture current macOS behavior for `Option+D`, `Option+E`, `Option+S`, `Option+A`, history reopen, and provider error recovery.

## Phase 1 - Core Context Models

- [x] [Implement] Add `TranslationContextProfile`, `TranslationContext`, `PrivacyPolicy`, and `ProviderRoutingHints` to `ParrotCore`.
- [x] [Implement] Extend `TranslateRequest` with optional `context` while preserving existing provider compatibility.
- [x] [Implement] Add default profile selection rules based on mode, source length, origin, and user settings.
- [x] [Test] Cover profile defaulting and app routing for selection, lookup, OCR, manual input, long text, terminology, and polish flows.

## Phase 2 - Privacy Masking

- [x] [Implement] Add local sensitive entity detector and mask/unmask engine in `ParrotCore`.
- [x] [Implement] Apply masking before cloud provider calls and after source segmentation but before provider request construction.
- [x] [Implement] Add `PrivacyMaskingReport` to result metadata and compact status in provider cards.
- [x] [Test] Cover email, phone, URL token, API key, numeric ID, no-match, and unmask round-trip cases.
- [x] [Security] Ensure mask maps are not persisted to history or logs.

## Phase 3 - Quality Evaluation And Recommendation

- [x] [Implement] Add `ResultQualityIssue` and `ResultQualitySummary` to translation result metadata.
- [x] [Implement] Add deterministic quality checks for empty output, unchanged source, wrong language, length ratio, placeholder leak, and terminology miss.
- [x] [Implement] Mark a recommended provider result without hiding other provider cards.
- [x] [Implement] Add fallback behavior when the top ordered provider fails quality checks.
- [x] [Test] Cover quality scoring and recommendation selection across multiple provider outcomes.

## Phase 4 - Quick Peek

- [x] [Implement] Add Quick Peek routing rules in `AppState` / `AppDelegate` for short selection and lookup flows.
- [x] [Implement] Add Quick Peek surface with source, translation/meaning, copy, speak, vocabulary, retry, configure, and expand.
- [x] [Implement] Add compact `FloatingPanel` sizing and expand-to-workspace transition preserving draft and outcomes.
- [x] [Test] Cover short selection opens Quick Peek, long selection opens workspace, and expand preserves session.
- [x] [UX] Keep Quick Peek recoverable by preserving result/error state and providing retry/configure/expand actions.

## Phase 5 - Paragraph Bilingual Workspace

- [x] [Implement] Add deterministic paragraph segmentation utility that preserves markdown/code/list blocks.
- [x] [Implement] Add paragraph-level presentation state in `AppState`.
- [x] [Implement] Add `BilingualParagraphView` inside `ResultView` with per-paragraph copy and full-copy actions.
- [x] [Implement] Keep provider cards available for comparison and error recovery.
- [x] [Test] Cover paragraph segmentation, protected code fences, and workspace long-text routing.
- [x] [UX] Verify long text remains readable at default and resized panel widths.

## Phase 6 - Context Profiles UI

- [x] [Implement] Add compact profile selector to workspace header using existing design tokens.
- [x] [Implement] Map profiles to prompt/routing/terminology/privacy defaults.
- [x] [Implement] Persist last-used profile preference where appropriate without overriding explicit per-session choices.
- [x] [Test] Cover profile prompt behavior and persisted profile preference.

## Phase 7 - OCR Candidate Experience

- [x] [Implement] Preserve OCR block geometry and confidence through macOS OCR flow.
- [x] [Implement] Mirror Quick Lens-style candidate scoring for macOS OCR blocks.
- [x] [Implement] Show selected candidate and alternatives in the workspace; tapping another block updates `sourceDraft` and reruns translation.
- [x] [Implement] Preserve screenshot context while allowing source edits and retry.
- [x] [Test] Cover OCR candidate preservation and block switch draft update.

## Phase 8 - Acceptance And Documentation

- [x] [Test] Run `swift test`.
- [x] [Test] Run focused UI acceptance for workspace entry points where environment permits.
- [x] [Doc] Update README or docs to describe Quick Peek, bilingual workspace, profiles, privacy masking, and recommended results.
- [x] [Review] Write `review.md` with Code Review, Architecture Review, and UI Review sections after implementation.

## Phase 9 - HTML Parity Closure

- [x] [Implement] Honor URL query routing for `surface=peek|workspace` and explicit `profile` values.
- [x] [Implement] Make `privateLocal` strictly local-only, with a recoverable empty-local-engine state.
- [x] [Implement] Add a real "replace in original app" action for native polish results.
- [x] [Implement] Add direct "save expression" and "save research excerpt" actions backed by the learning vocabulary store.
- [x] [Implement] Add a context memory/rules surface and wire automatic profile rules into routing.
- [x] [Test] Cover URL surface routing, strict private-local behavior, memory rules, and save-action persistence.
- [x] [Verify] Re-run `swift test`, `openspec validate`, and UI acceptance.

## Phase 10 - Native Polish Completion

- [x] [Implement] Capture the focused input-field draft when opening Native Polish.
- [x] [Implement] Add explicit polish tones and generate Direct, Softer, and Short variants.
- [x] [Implement] Add a prominent replace-to-original-app button for polish variants.
- [x] [Implement] Use tone intent in LLM polish prompts and replacement fallback behavior.
- [x] [Test] Cover captured draft prefill, tone switching, variant generation, and polish prompt instructions.
- [x] [Verify] Re-run `swift test`, OpenSpec validation, UI acceptance, and rebuild/install the app.

## Verification Notes

- `swift test` passed with 120 tests on 2026-07-02 after OCR candidate default-selection updates.
- UI acceptance passed on 2026-07-02, covering release build, launch, menu fallbacks, input workspace, OCR fixture, URL routing, result panel display, and workspace resize stability.
- AppState route tests cover short selection Quick Peek, long selection full workspace, manual polish workspace, OCR candidate switching, and unreliable OCR geometry fallback.
- Phase 9 parity closure passed on 2026-07-02 with 125 Swift tests, OpenSpec validation, and UI acceptance after URL surface/profile routing, strict private-local routing, original-app replacement, save-expression actions, and rules memory were added.
- Phase 10 native polish completion passed on 2026-07-02 with 128 Swift tests, OpenSpec validation, and UI acceptance after focused input draft capture, tone variants, tone-aware prompts, and replace-to-original-app fallback were added.
