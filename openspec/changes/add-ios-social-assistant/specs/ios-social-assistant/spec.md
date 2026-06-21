## ADDED Requirements

### Requirement: Monorepo with target isolation

The system SHALL keep macOS and iOS Parrot products in one repository while separating shared libraries, app targets, extension targets, and platform adapter targets.

#### Scenario: Shared core stays platform-neutral

- **WHEN** `ParrotCore`, `ParrotSocial`, or `ParrotPlatform` is built
- **THEN** those targets SHALL NOT import AppKit, UIKit, SwiftUI, Carbon, or ApplicationServices

#### Scenario: iOS target dependency boundary

- **WHEN** `ParrotiOS` or `ParrotShareExtension` is built
- **THEN** it SHALL NOT import macOS app code, AppKit-only platform adapters, or the macOS plugin runtime

#### Scenario: macOS target dependency boundary

- **WHEN** the existing macOS app is built
- **THEN** it SHALL NOT depend on iOS app targets, iOS extension targets, or iOS-only platform adapters

#### Scenario: Repository split deferred

- **WHEN** adding iOS support in this change
- **THEN** implementation SHALL use the existing repository with new targets/modules rather than creating a second repository

### Requirement: iOS social assistant positioning

The system SHALL provide an iOS product experience focused on social reading and social writing, with first-class Understand and Express modes for X, Reddit, and similar social/community contexts.

#### Scenario: User understands a social post

- **WHEN** a user shares or opens a social post/comment in Parrot iOS
- **THEN** the first result SHALL explain the practical meaning and tone before showing any full literal translation

#### Scenario: User writes a social reply

- **WHEN** a user enters Chinese, mixed-language text, bullet points, or rough English as reply intent
- **THEN** the system SHALL generate native speaker-style English reply candidates while preserving the user's stance

### Requirement: SocialTextSession shared state model

The system SHALL route shared text, copied text, OCR text, manual input, keyboard input, and history reuse through a shared editable `SocialTextSession` model.

#### Scenario: Shared source remains editable

- **WHEN** a session is created from Share Extension text
- **THEN** the source text SHALL appear as editable `sourceDraft` and the user SHALL be able to edit and rerun Understand or Express in the same workspace

#### Scenario: Understand becomes Express

- **WHEN** a user taps Reply from an Understand result
- **THEN** the same session SHALL preserve the original source as reply context and open an editable intent composer

#### Scenario: Generated output preserves drafts

- **WHEN** the user generates, copies, refines, or saves a reply candidate
- **THEN** the system SHALL NOT clear `sourceDraft` or `userIntentDraft`

### Requirement: Quick Peek Understand surface

The iOS app SHALL implement a Quick Peek-style Understand surface matching the interaction model in `docs/mockups/ios-social-assistant/index.html`.

#### Scenario: Meaning summary appears first

- **WHEN** an Understand request completes
- **THEN** the surface SHALL show a meaning summary card, tone tags, phrase explanations, and an optional collapsed full translation

#### Scenario: Phrase explanations

- **WHEN** the source contains slang, idioms, abbreviations, sarcasm, or community-specific phrasing
- **THEN** the result SHOULD include phrase-level explanations when the provider can infer them

#### Scenario: Inline copy feedback

- **WHEN** the user copies the meaning or a translation
- **THEN** the confirmation SHALL appear inline without dismissing the session

### Requirement: Express reply composer

The iOS app SHALL implement an Express composer that turns rough user intent into multiple native English reply candidates with tone controls and refinement actions.

#### Scenario: Tone preset generation

- **WHEN** the user selects a tone preset such as Natural, Friendly, Firm, Reddit-style, or X-short
- **THEN** generated candidate cards SHALL reflect that tone while preserving the user's meaning

#### Scenario: Candidate refinement

- **WHEN** the user taps refinement actions such as Shorter, More polite, More casual, or Keep my attitude
- **THEN** the selected candidate SHALL be regenerated or updated in place without losing context or draft text

#### Scenario: Multiple candidates

- **WHEN** Express generation succeeds
- **THEN** the system SHALL provide at least three candidate cards for the MVP default generation path

### Requirement: Share Extension MVP

The system SHALL provide an iOS Share Extension as the primary MVP external entry point for social reading and writing flows.

#### Scenario: Text share handoff

- **WHEN** the user shares plain text from another app to Parrot
- **THEN** the Share Extension SHALL persist a handoff in App Group storage and the containing app SHALL open an editable Understand session

#### Scenario: Image share handoff

- **WHEN** the user shares a screenshot or image to Parrot
- **THEN** the Share Extension SHALL persist an image handoff and the containing app SHALL route it into OCR cleanup

#### Scenario: Unsupported payload

- **WHEN** the share payload cannot be parsed
- **THEN** the extension SHALL offer a recoverable path to open Parrot for manual input rather than failing silently

### Requirement: OCR cleanup before social analysis

The system SHALL provide a screenshot/photo OCR cleanup flow before Understand or Express analysis.

#### Scenario: OCR text is editable

- **WHEN** OCR completes for a screenshot
- **THEN** recognized text SHALL appear in an editable source editor before or alongside analysis

#### Scenario: Cleanup actions

- **WHEN** OCR text contains usernames, timestamps, broken lines, or empty lines
- **THEN** the user SHALL have cleanup actions to remove or normalize those artifacts before analysis

#### Scenario: OCR failure recovery

- **WHEN** OCR fails or returns no useful text
- **THEN** the system SHALL preserve the image handoff and show retry/import/manual-entry actions

### Requirement: iOS storage and privacy boundaries

The system SHALL use iOS Keychain for secrets, App Group storage for app/extension handoff and non-secret session data, and foreground-only clipboard suggestions.

#### Scenario: Provider secret storage

- **WHEN** a user configures an API key or token on iOS
- **THEN** the secret SHALL be stored in iOS Keychain and SHALL NOT be written to App Group files, history, logs, or generated prompt records

#### Scenario: Share Extension shared data

- **WHEN** Share Extension passes data to the containing app
- **THEN** it SHALL store only non-secret handoff data in the App Group container

#### Scenario: Clipboard suggestion

- **WHEN** Parrot iOS is foregrounded and the clipboard contains text
- **THEN** the app MAY show an explicit "Explain copied text" action
- **AND** the app SHALL NOT monitor clipboard content in the background

### Requirement: iOS history reuse

The system SHALL persist Understand and Express sessions as reusable history records.

#### Scenario: Reopen explanation

- **WHEN** the user reopens an Understand history item
- **THEN** it SHALL open as an editable session with source, meaning, tone tags, phrase explanations, and full translation when available

#### Scenario: Reopen reply

- **WHEN** the user reopens an Express history item
- **THEN** it SHALL preserve context, user intent draft, selected tone, and generated candidates for further editing/regeneration

### Requirement: Optional post-MVP input surfaces

The system SHALL treat Parrot Keyboard, App Shortcuts, and Safari Extension as post-MVP entry points that build on `SocialTextSession` rather than separate workflows.

#### Scenario: Keyboard extension

- **WHEN** Parrot Keyboard is implemented
- **THEN** it SHALL provide explicit writing commands such as Native, Shorter, Kinder, Sharper, and To English, and SHALL insert generated text only after user confirmation

#### Scenario: App Shortcuts

- **WHEN** App Shortcuts are implemented
- **THEN** shortcuts such as Explain Clipboard and Rewrite Clipboard SHALL create or update `SocialTextSession` records using the same privacy rules as the main app

#### Scenario: Safari Extension

- **WHEN** Safari Extension is implemented
- **THEN** selected webpage text or page snippets SHALL enter the same Understand/Express session model
