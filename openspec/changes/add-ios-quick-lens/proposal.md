# Proposal: iOS Quick Lens for Latest Screenshot Translation

- **Change name**: `add-ios-quick-lens`
- **Status**: Proposed
- **Author**: product-designer / ios-engineer
- **Date**: 2026-06-21
- **Related change**: `add-ios-social-assistant`

## Summary

Add Quick Lens to Parrot iOS: a low-friction entry point that translates the most recent screenshot without requiring the user to share the screenshot, manually crop it, or clean OCR text before seeing value.

The target daily flow is:

```text
Take screenshot -> invoke Parrot Quick Lens -> see the most likely text block translated
```

Parrot will fetch a user-initiated recent screenshot, run OCR, cluster recognized lines into candidate text blocks, auto-select the most likely post/comment body, and immediately show the Understand result. Manual block selection, crop selection, and source editing remain available as correction paths, not mandatory steps.

## Why

On iOS, many high-value reading surfaces such as X, Reddit, image posts, screenshots, and quote cards do not reliably expose selectable text through Share Extension or copy. A screenshot OCR flow works, but the obvious version has too many steps: screenshot, open share sheet, pick Parrot, inspect OCR, crop or clean text, then translate.

Quick Lens shifts effort from the user to the system:

1. The system retrieves the likely screenshot the user just took.
2. The system detects text blocks and guesses the intended block.
3. The user only corrects when the guess is wrong.

This preserves the product principle from `add-ios-social-assistant`: Parrot should feel like a social reading assistant, not an OCR utility.

## What Changes

- Add an iOS Quick Lens entry point available from:
  - App Shortcuts / Shortcuts action: `Translate Latest Screenshot`
  - URL scheme: `parrot://quick-lens`
  - in-app Lens button for fallback/manual testing
- Add a PhotoKit-backed latest screenshot provider with explicit permission handling.
- Add an OCR block clustering and ranking pipeline that turns Vision OCR line observations into tappable candidate text blocks.
- Add a Quick Lens surface that shows:
  - screenshot preview with highlighted text blocks,
  - auto-selected block,
  - immediate Understand result,
  - correction paths: tap another block, manual crop, edit source.
- Extend the iOS social session model with Quick Lens metadata while keeping translation and history inside `SocialTextSession`.
- Add tests for screenshot selection, OCR block clustering, candidate scoring, fallback states, and UI rerun behavior.

## Goals

1. Reduce the common unselectable-text flow to two user actions: screenshot and invoke Parrot.
2. Show a useful translation before asking the user to crop or edit OCR text.
3. Keep every recognized source editable and rerunnable.
4. Make wrong auto-selection cheap to correct by tapping another detected block.
5. Bound privacy risk: only process recent screenshots after explicit user action; do not background-scan the photo library.
6. Reuse `ParrotSocial`, `IOSOCRService`, App Group image storage, history, and Understand result rendering from the iOS social assistant work.

## Non-goals

- No global screen capture or macOS-style arbitrary selection on iOS.
- No background screenshot monitoring.
- No automatic processing of old photo library content.
- No requirement that the user enables Parrot Keyboard.
- No social-network-specific private APIs.
- No automatic posting, replying, or text insertion into X/Reddit.

## User Journey

### Primary Path

1. User sees unselectable text in X, Reddit, or an image post.
2. User takes a screenshot.
3. User invokes `Translate Latest Screenshot` through Action Button, Back Tap via Shortcuts, Siri, Spotlight, or the Shortcuts app.
4. Parrot opens Quick Lens, fetches the most recent screenshot from the last 60 seconds, OCRs it, chooses the best candidate text block, and starts Understand.
5. User reads meaning/tone/phrase explanations.
6. User returns to the original app or opens Reply from the result.

### Correction Path

1. If Parrot chose the wrong block, the user taps a different highlighted block.
2. Parrot updates `sourceDraft`, reruns Understand in place, and keeps the screenshot stable.
3. If block detection is poor, the user uses manual crop or edit source.

### Recovery Path

1. If no recent screenshot exists, Parrot offers import/share/manual input.
2. If Photos permission is missing, Parrot explains the exact permission and offers Settings plus share-sheet fallback.
3. If OCR fails, Parrot preserves the screenshot and offers retry, crop, and manual entry.

## Risks

| Risk | Impact | Mitigation |
| --- | --- | --- |
| Photo Library permission feels heavy | User may abandon first use | Ask only after explicit Quick Lens invocation; explain that Parrot reads recent screenshots only; keep share-extension fallback |
| Auto-selected block is wrong | User loses trust | Show detected blocks; one tap switches block and reruns translation |
| OCR line grouping fails on dense social UI | Translation includes usernames/buttons/noise | Add block ranking, noise filters, manual crop, and editable source |
| App Shortcut invocation cannot pass image data directly | Shortcut may only open app | Quick Lens app launch fetches latest screenshot inside the app with PhotoKit |
| Vision OCR latency | User waits after invoking Lens | Show screenshot immediately, then progressive OCR/translation states; keep result surface stable |
| Privacy concerns around screenshots | Sensitive screenshots may be processed accidentally | Require explicit invocation, filter to recent screenshots, never background scan, and purge transient image copies |

## Implementation Dependency

This change assumes the iOS app target, `ParrotSocial`, `ParrotPlatform`, `ParrotPlatformiOS`, App Group storage, and base OCR cleanup flow from `add-ios-social-assistant` exist or are implemented first. If implemented before that change is fully archived, Quick Lens should be built as a small vertical slice on top of the current iOS targets already present in the repository.
