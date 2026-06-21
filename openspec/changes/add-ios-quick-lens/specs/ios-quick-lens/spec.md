## ADDED Requirements

### Requirement: Quick Lens latest screenshot entry

The iOS app SHALL provide a Quick Lens entry point that translates the latest user-created screenshot without requiring the share sheet as the default path.

#### Scenario: User invokes Quick Lens after taking a screenshot

- **WHEN** the user invokes `Translate Latest Screenshot` within the configured recent screenshot window
- **THEN** Parrot SHALL open Quick Lens, load the latest screenshot, recognize text, select a candidate text block, and start Understand automatically

#### Scenario: User invokes Quick Lens from URL

- **WHEN** the app receives `parrot://quick-lens`
- **THEN** it SHALL route to the same Quick Lens flow used by the App Shortcut entry point

#### Scenario: No recent screenshot exists

- **WHEN** Quick Lens is invoked and no screenshot exists within the recent screenshot window
- **THEN** the app SHALL show inline recovery actions for sharing a screenshot, importing an image, or entering text manually

### Requirement: User-initiated photo access boundary

Quick Lens SHALL access Photos only after explicit user invocation and SHALL bound screenshot lookup to recent screenshot assets.

#### Scenario: Photo access is requested

- **WHEN** the user invokes Quick Lens for the first time and Photos permission has not been decided
- **THEN** the app SHALL request Photos permission with copy explaining that Parrot needs access to find the screenshot the user just took

#### Scenario: Photo access is denied

- **WHEN** Photos permission is denied or restricted
- **THEN** Quick Lens SHALL show a recoverable permission state with actions to open Settings and to use the share-extension/import fallback

#### Scenario: Background scanning is forbidden

- **WHEN** the app is backgrounded or the user has not invoked Quick Lens
- **THEN** Parrot SHALL NOT scan the photo library for screenshots

#### Scenario: Provider privacy boundary

- **WHEN** Quick Lens sends content to a translation or LLM provider
- **THEN** it SHALL send only the selected or edited text, not the full screenshot image

### Requirement: OCR block clustering and candidate ranking

Quick Lens SHALL convert OCR line observations into candidate text blocks and rank them so the most likely post/comment body can be translated first.

#### Scenario: OCR produces multiple lines

- **WHEN** Vision OCR returns multiple recognized text observations
- **THEN** the system SHALL group nearby, visually related lines into candidate text blocks with bounding boxes, confidence, and score

#### Scenario: Social UI noise is present

- **WHEN** OCR detects usernames, timestamps, navigation labels, isolated action counts, or button text
- **THEN** the system SHALL de-prioritize or filter those items unless they are part of a larger body text block

#### Scenario: Default candidate is selected

- **WHEN** candidate ranking completes with at least one non-noise candidate
- **THEN** Quick Lens SHALL select the highest-scoring candidate and copy its text into `SocialTextSession.sourceDraft`

#### Scenario: OCR has low confidence

- **WHEN** the selected block contains low-confidence OCR lines
- **THEN** Quick Lens SHALL still keep the text editable and SHOULD surface a non-blocking confidence note

### Requirement: Quick Lens result surface

The iOS app SHALL show a Quick Lens surface where screenshot context, selected text block, editable source, and Understand result remain connected.

#### Scenario: Translation starts automatically

- **WHEN** Quick Lens selects the default candidate
- **THEN** the Understand result SHALL begin loading without requiring the user to press a translate button

#### Scenario: User selects another text block

- **WHEN** the user taps a different highlighted candidate block
- **THEN** Quick Lens SHALL update `sourceDraft`, keep the screenshot visible, and rerun Understand in the same surface

#### Scenario: User edits OCR text

- **WHEN** the user opens Edit source and modifies recognized text
- **THEN** the edited text SHALL become the translation source and the user SHALL be able to rerun Understand without leaving the session

#### Scenario: User needs manual region selection

- **WHEN** automatic candidate detection is wrong or insufficient
- **THEN** the user SHALL be able to crop/select a region and rerun OCR for that region as a correction path

### Requirement: SocialTextSession integration

Quick Lens SHALL reuse the iOS social assistant session model rather than introducing a disconnected OCR result workflow.

#### Scenario: Quick Lens creates a session

- **WHEN** Quick Lens starts translation from a screenshot candidate
- **THEN** it SHALL create or update a `SocialTextSession` with origin `latestScreenshot`, screenshot metadata, selected candidate text, and editable `sourceDraft`

#### Scenario: Quick Lens result opens Reply

- **WHEN** the user taps Reply from a Quick Lens Understand result
- **THEN** the app SHALL preserve the selected source as reply context and open the existing Express composer

#### Scenario: Quick Lens history is reopened

- **WHEN** the user reopens a Quick Lens history item
- **THEN** the app SHALL reopen an editable session with the recognized source and previous Understand result when available

### Requirement: Quick Lens recoverability

Quick Lens SHALL keep source material available and provide visible next actions for expected failures.

#### Scenario: OCR fails

- **WHEN** OCR fails or returns no useful candidate blocks
- **THEN** Quick Lens SHALL preserve the screenshot and offer retry, manual crop, import image, and manual text entry actions

#### Scenario: Translation fails

- **WHEN** provider translation or social understanding fails
- **THEN** Quick Lens SHALL preserve the selected text and screenshot context and offer retry/configure actions

#### Scenario: Screenshot loading fails

- **WHEN** the latest screenshot asset cannot be loaded
- **THEN** Quick Lens SHALL show an inline error and fallback actions rather than clearing the active session

### Requirement: Quick Lens shortcuts

The iOS app SHALL expose Quick Lens through App Shortcuts-compatible invocation while keeping the in-app and URL paths equivalent.

#### Scenario: Shortcut is run

- **WHEN** the user runs the `Translate Latest Screenshot` App Shortcut
- **THEN** the app SHALL open or foreground Parrot and start the same Quick Lens latest screenshot flow

#### Scenario: Action Button or Back Tap uses Shortcut

- **WHEN** the user maps Action Button or Back Tap to the Quick Lens shortcut
- **THEN** the resulting app behavior SHALL be equivalent to invoking Quick Lens in-app

### Requirement: Quick Lens cleanup policy

Quick Lens SHALL clean up transient screenshot copies while preserving user-saved history records.

#### Scenario: Transient screenshot is unreferenced

- **WHEN** a Quick Lens screenshot copy is not referenced by an active or saved session and is older than 24 hours
- **THEN** the app SHALL delete it from App Group image storage

#### Scenario: History references a screenshot

- **WHEN** a saved Quick Lens history record references a screenshot image
- **THEN** cleanup SHALL NOT delete the image required to reopen that history record
