# Parrot UX Interaction Optimization Plan

## North Star

Parrot should be a single, editable translation workspace that can be opened from selection, manual input, OCR, lookup, history, menu, or URL Scheme, with results updating in place and no surprise context switches.

## Current Journey Findings

| Journey | Priority | Symptom | Root cause | User impact |
| --- | --- | --- | --- | --- |
| `Option+D` selected text translation | P0 | Captured text appears as a static source block; user cannot correct capture or adjust text before retranslation. | Result panel is read-only and optimized for display, not task continuation. | A single bad capture forces the user to restart the whole flow. |
| `Option+A` manual input | P0 | User types in one input surface, presses Enter, then input disappears and results appear in another surface. | InputPanel and FloatingPanel are separate mental models. | The user loses editing continuity and cannot revise the source naturally. |
| Result inspection | P0 | Results can be retried, copied, or spoken, but the source cannot be edited in place. | AppState has `sourceText` as committed text only, no editable draft/session state. | Translation feels final too early; common "fix one word and rerun" workflow is broken. |
| OCR translation | P1 | Multi-line OCR can be selected, but the next step still routes to a result panel instead of an editable workspace. | OCR output is treated as final source. | OCR noise cleanup is partly possible, but post-selection editing is still weak. |
| History reuse | P1 | History can retranslate, but it jumps directly into result flow. | History action calls `runTranslation(text)` instead of opening an editable session. | Reusing history for variants is clumsy. |
| Error recovery | P1 | Some errors have retry/configure actions, but recovery does not preserve the user's task context across settings. | Settings is separate from the active translation session. | Users can configure but may lose the task that caused the error. |
| Panel lifecycle | P1 | Transient panels can disappear on focus loss even when the user may still be reading or editing. | Auto-hide behavior is panel-level, not state-aware. | Accidental blur can interrupt work. |

## Target Interaction Model

### One Translation Workspace

Replace the split "input panel -> result panel" mental model with one workspace:

- Source composer at the top, always editable.
- Results below, updated in place.
- Language controls and actions stay visible.
- Source draft survives while the panel is open.
- Every entry point fills the same composer.

### Session State

Introduce an explicit session model in `AppState`:

- `sourceDraft`: editable text in the composer.
- `committedSource`: text currently being translated.
- `mode`: translate or lookup.
- `origin`: selection, input, OCR, history, URL, menu.
- `isDirty`: draft differs from committed source.
- `isEditing`: composer focus state.
- `lastRunID`: current translation run identity.

Translation should run from `sourceDraft`, then set `committedSource`. Results should never make the draft read-only.

### Keyboard Contract

- `Option+D`: capture selected text into the workspace, auto-translate, keep source editable.
- `Option+A`: open the same workspace with composer focused and empty or last draft restored.
- `Command+Enter`: translate current draft.
- `Enter`: insert newline in the composer.
- `Command+L`: focus the source composer.
- `Escape`: close only if not dirty; if dirty, keep draft or require explicit clear.
- `Command+C`: if text is selected, copy selection; otherwise copy primary result.

## Optimization Plan

### P0 - Unify Input And Results

1. Create a `TranslationSession` state inside `AppState`.
   - Files: `AppState.swift`, new `TranslationSession.swift`.
   - Add APIs: `openSession(text:mode:origin:autoRun:)`, `updateDraft(_:)`, `translateDraft()`, `clearDraft()`, `focusComposerSignal`.

2. Replace `InputPanel` as a separate submit-only window.
   - `Option+A` should open the same workspace used by selected text.
   - Keep the composer focused.
   - Do not hide input and jump to another surface.

3. Convert `ResultView.sourceBlock` into an editable `SourceComposer`.
   - Use a multiline editor.
   - Show dirty state: "已修改，Command+Enter 重新翻译".
   - Keep source actions: copy, clear, focus, translate.

4. Change `runTranslation(_:)` routing.
   - `Option+D`, OCR, history, URL Scheme, menu recents should all call `openSession(...)`.
   - Auto-run only where appropriate, but never remove the editable source.

5. Adjust panel lifecycle.
   - Do not auto-hide while composer is focused or draft is dirty.
   - Outside click can hide only transient, clean, non-editing sessions.

### P1 - Make Every Recovery Path Return To The Task

1. Provider error cards should keep the session open and offer:
   - retry provider,
   - retry all,
   - configure provider,
   - continue editing source.

2. Settings should remember the triggering session.
   - After saving key/config, user returns to the same workspace.
   - The failed provider card can be retried from there.

3. OCR should route recognized lines into the composer.
   - Multi-line picker remains useful.
   - After selection, the workspace opens with editable OCR text.
   - User can remove OCR noise before or after first run.

4. History should reopen records as editable sessions.
   - Show prior outcomes below or as "previous result" metadata.
   - User can edit source and run a fresh translation.

### P2 - Polish And Power User Flow

1. Add a compact state strip:
   - "输入中", "翻译中", "部分完成", "全部完成", "有错误", "离线".

2. Add quick source operations:
   - trim whitespace,
   - swap languages,
   - clear,
   - paste and translate,
   - copy primary result.

3. Improve discoverability:
   - visible `Command+Enter` translate hint near composer,
   - tooltip for pinning behavior,
   - first-run explanation only when permissions block actions.

4. Make lookup and translation switchable in the same workspace.
   - A word lookup can be promoted to normal translation.
   - A sentence translation can request dictionary mode for selected words.

## Implementation Order

1. Add `TranslationSession` and route all entry points to it.
2. Merge `InputPanel` behavior into the workspace.
3. Make source editable in `ResultView`.
4. Make panel auto-hide state-aware.
5. Rewire OCR/history/settings recovery into sessions.
6. Expand UI acceptance automation to assert that `Option+A` and URL flows expose an editable source composer.

## Acceptance Criteria

- `Option+D` selected text appears in an editable source composer and auto-translates.
- Editing the captured source and pressing `Command+Enter` updates results in the same panel.
- `Option+A` opens the same composer-first workspace; submitting does not switch surfaces.
- Pressing Enter in the composer does not unexpectedly close or replace the editor.
- OCR selected text lands in the editable composer before or with translation.
- History retranslation opens editable source, not a blind one-shot rerun.
- No user input is lost on accidental blur.
- Provider errors keep the source editable and provide a recovery action.
- Automated GUI acceptance can find the workspace and verify an editable text element exists.

## Open Risks

- SwiftUI `TextEditor` inside non-activating `NSPanel` may require making the panel key-capable during editing.
- Existing transient panel behavior may conflict with text editing and needs explicit state checks.
- AX automation for SwiftUI editors can be inconsistent; standard App menu fallback and debug URL routes should remain.
- Session migration must preserve history saving semantics and avoid duplicate records during retries.
