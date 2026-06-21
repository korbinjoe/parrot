# Proposal: Parrot iOS Social Assistant

- **Change name**: `add-ios-social-assistant`
- **Status**: Proposed
- **Author**: product-designer / fullstack-engineer
- **Date**: 2026-06-18
- **References**:
  - Product UX: `docs/ios-social-assistant-ux.md`
  - High-fidelity prototype: `docs/mockups/ios-social-assistant/index.html`

## Summary

Build an iOS version of Parrot focused on social reading and social writing. The product is not a generic mobile translation app. It helps users understand English and multilingual content while browsing X, Reddit, and similar communities, then turns Chinese, mixed-language thoughts, or awkward English into native speaker-style replies.

The initial iOS release SHALL include a native SwiftUI app, Share Extension, editable Understand/Express workspace, screenshot OCR cleanup flow, local history, iOS Keychain-backed credentials, and App Group-safe shared state between the app and extension. Parrot Keyboard, App Shortcuts, and Safari Extension are planned follow-up surfaces after the core read/write loop is proven.

## Why

The main iOS use case differs from macOS. On macOS, Parrot's strongest pattern is selected-text translation through global shortcuts. On iOS, the high-frequency user need is social context:

1. Users read posts and comments in X, Reddit, and other apps where literal translation is insufficient because tone, sarcasm, slang, and community-specific phrases matter.
2. Users want to reply or post in natural English, but their input may start as Chinese, mixed language, bullet points, or rough English.
3. iOS does not provide a universal global selected-text hotkey model comparable to macOS Accessibility capture, so the product must be designed around Share Extension, clipboard foreground actions, OCR, and optional keyboard/shortcut entry points.

The product value is "read confidently and respond naturally" rather than "open an app and translate text."

## What Changes

- Add a new iOS containing app for social Understand and Express workflows.
- Add a Share Extension MVP for text, URL, and screenshot/image handoff.
- Add `ParrotSocial` for social session models, prompt building, structured result parsing, tone presets, and reply candidates.
- Add platform abstraction targets so secrets, handoff storage, OCR, clipboard, and session persistence can have macOS and iOS implementations without mixing platform APIs.
- Keep macOS and iOS in one repository while separating app targets, extension targets, shared libraries, and platform adapters.
- Defer Parrot Keyboard, Safari Extension, cloud sync, and user-installed iOS plugins until after the MVP.

## Compatibility Position

This change MUST NOT regress the existing macOS menu-bar app. iOS work should be isolated behind new app/extension targets and shared protocol-based libraries. Existing macOS flows (`ParrotApp`, global hotkeys, floating panel, OCR, history, settings, plugin runtime) should continue to build and run without depending on iOS-only code.

## Repository Strategy

macOS and iOS SHOULD live in the same repository as a monorepo. They are two platform experiences for the same product system, not two unrelated products. Keeping them together preserves one source of truth for:

- core translation models and coordinator behavior,
- shared text/LLM engines,
- social Understand/Express session models and prompts,
- test fixtures and regression tests,
- OpenSpec product decisions, UX documentation, and visual prototypes.

The repository MUST still keep app entry points and platform implementations separate. The intended structure is one repository with multiple library targets, one macOS app target, one iOS containing app target, and iOS extension targets. Shared code lives in platform-neutral modules; AppKit/Carbon/Accessibility code stays in macOS-only modules; UIKit/App Group/Keychain extension code stays in iOS-only modules.

Splitting into separate repositories is deferred until there is a strong organizational reason such as independent teams, unrelated release cycles, or a genuinely divergent iOS product. At this stage, two repositories would mostly add synchronization cost and increase the risk that engines, history models, prompt contracts, and specs drift apart.

## Goals

1. **Understand Mode**: explain social text by meaning, tone, phrase/slang interpretation, and optional full translation.
2. **Express Mode**: generate native speaker-style replies from rough user intent, with tone presets and in-place refinement.
3. **Share Extension MVP**: receive text, links, and images from supported social apps and open a compact Quick Peek experience.
4. **Editable workspace**: every shared/copied/OCR/history source enters an editable session; generated output never destroys the user's draft.
5. **Screenshot OCR cleanup**: imported or shared screenshots are OCR'd into an editable source editor before analysis.
6. **Cross-surface persistence**: history, drafts, and share-extension handoff use App Group-safe storage; secrets use iOS Keychain.
7. **Reuse core translation infrastructure**: reuse `ParrotCore` models and compatible `ParrotEngines` where possible, with iOS-specific app state and storage adapters.
8. **High-fidelity UI contract**: implementation should match the interaction model demonstrated by `docs/mockups/ios-social-assistant/index.html`.

## Non-goals

- No attempt to reproduce macOS global hotkeys or arbitrary selected-text capture on iOS.
- No mandatory Parrot Keyboard in MVP; keyboard is P2 because setup friction and privacy sensitivity are high.
- No plugin marketplace or user-installed JavaScript plugins in the initial iOS release.
- No account system or cloud sync in MVP.
- No full social network client, timeline reader, or automated posting. Parrot generates/copies/inserts text; the user remains in control.
- No background clipboard monitoring. Clipboard suggestions are shown only when the app is foregrounded and user intent is clear.

## Approach

- Add iOS platform support to the Swift package and create a new `ParrotiOS` app target.
- Introduce an iOS-specific session layer:
  - `SocialTextSession`
  - `UnderstandResult`
  - `ExpressResult`
  - `SourceOrigin`
  - `TonePreset`
- Build the main SwiftUI app around two first-class modes:
  - `UnderstandWorkspaceView`
  - `ExpressWorkspaceView`
- Build `ParrotShareExtension` as the MVP external entry point.
- Add an OCR ingestion pipeline for screenshot/photo attachments using the existing OCR abstraction where possible and an iOS Vision adapter where platform APIs differ.
- Replace file-backed macOS-only secret storage with a cross-platform `SecretStoreProtocol`, using iOS Keychain for iOS and preserving current macOS behavior.
- Persist history and shared handoff data through a storage abstraction that supports App Group containers on iOS.
- Add prompt templates and result parsers for social explanation and social reply generation on top of existing LLM providers.

## Risks

| Risk | Impact | Mitigation |
| --- | --- | --- |
| Social apps expose inconsistent share payloads | Some apps may share only URLs or screenshots instead of selected text | Support text, URL metadata, and image OCR ingestion; keep copy/paste foreground flow |
| Share Extension execution limits | Long network calls may time out or feel slow | Quick Peek can open the containing app for full processing; extension persists handoff state immediately |
| Generated replies sound AI-polished | Users may be embarrassed or lose authenticity | Provide platform/tone presets, "keep my attitude", and shorter/native variants |
| Keyboard extension privacy concern | Users may avoid enabling it | Keep keyboard optional and post-MVP; make Share Extension and main app useful without it |
| Core code contains macOS assumptions | Build failures or awkward abstractions | Introduce protocols for storage/secrets/platform OCR; isolate AppKit-only code in `ParrotApp` |
| LLM latency breaks social flow | Users abandon before results arrive | Show meaning first, stream/replace results in place, and keep draft/context stable |

## Reviewers

- architect — iOS target architecture, extension boundaries, storage/security design
- ui-designer — fidelity to the high-fidelity prototype and interaction model
- fullstack-engineer — implementation sequencing and reuse of existing core modules
- code-reviewer — extension-safe API usage, tests, privacy and data handling
