# Proposal: Native Polish Workspace

## Summary

Implement Native Polish as a production iOS workspace mode that turns a rough draft into a native-speaker rewrite while preserving the editable source draft and existing Express workflow.

## Motivation

The language polish mockup established the product direction, but the app still only supports Understand and reply generation. Users need a first-class path for polishing their own writing, not only translating source text or generating social replies from intent.

## Goals

- Add a Native Polish entry point from Today.
- Add an in-workspace mode selector for Understand, Reply, and Polish.
- Generate a primary polished rewrite plus secondary variants using the existing social expression result model.
- Support copy, replace-draft, tone switching, and refinement actions without clearing the source draft.
- Persist polished sessions in history using the existing session store.

## Non-Goals

- No new provider integration or provider settings UI.
- No schema migration beyond Codable-compatible model additions.
- No automatic posting or insertion into third-party apps.
- No production diff engine; compare notes can be lightweight and deterministic.

## Approach

- Add `SocialMode.polish` and keep using `ExpressResult` / `ReplyCandidate` for polish outputs.
- Branch prompt and rule-based service behavior when a session is in polish mode.
- Extend `IOSAppState` with Native Polish opening, generation, copy/replace, and UI-test fixture helpers.
- Reshape `UnderstandWorkspaceView` into a mode-aware workspace while preserving existing Understand and Reply behavior.
- Add focused Swift tests for prompt and rule-based Native Polish behavior.

## Risks

| Risk | Mitigation |
| --- | --- |
| Existing Reply flow regresses | Keep Reply mode on the existing `generateReplies` path and cover with existing tests. |
| New mode bloats the work screen | Use compact segmented controls and reuse existing card components. |
| Polish output feels like generic reply generation | Branch service copy, titles, and rule-based samples around draft rewriting. |
