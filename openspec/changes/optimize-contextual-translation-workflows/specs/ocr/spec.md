## ADDED Requirements

### Requirement: OCR candidate text blocks

OCR flows SHALL preserve recognized text block geometry and confidence so users can choose or correct the intended source text before and after translation.

#### Scenario: OCR returns multiple blocks

- **WHEN** screenshot OCR returns multiple positioned blocks or lines
- **THEN** Parrot SHALL group them into candidate text blocks with text, bounding boxes, confidence, and score

#### Scenario: Default block is selected

- **WHEN** candidate scoring identifies a likely body text block
- **THEN** Parrot SHALL copy that block into the editable source draft and start translation when auto-run is appropriate

#### Scenario: Social or UI noise is present

- **WHEN** OCR detects navigation labels, usernames, timestamps, isolated counts, or button labels
- **THEN** Parrot SHALL de-prioritize those items unless they are part of a larger body text block

#### Scenario: Low confidence block is selected

- **WHEN** the selected candidate contains low-confidence text
- **THEN** Parrot SHALL keep the source editable and SHOULD show a non-blocking confidence note

### Requirement: OCR block correction

OCR result surfaces SHALL let users switch the selected text block or edit recognized text without leaving the active workspace.

#### Scenario: User selects another block

- **WHEN** the user selects another OCR candidate block
- **THEN** Parrot SHALL update the source draft, keep screenshot/OCR context available, and rerun translation in the same workspace

#### Scenario: User edits OCR source

- **WHEN** the user edits recognized OCR text in the source composer
- **THEN** the edited text SHALL become the translation source and the user SHALL be able to rerun translation without reopening OCR capture

#### Scenario: OCR has no useful block

- **WHEN** OCR produces no useful candidate blocks
- **THEN** Parrot SHALL preserve recovery actions such as retry screenshot, recapture, manual input, or OCR settings

## MODIFIED Requirements

### Requirement: 版面还原规则

OCR layout reconstruction SHALL support candidate block selection in addition to flat full-text reconstruction.

#### Scenario: Layout reconstruction completes

- **WHEN** OCR layout reconstruction completes
- **THEN** Parrot SHALL expose both the reconstructed `fullText` and candidate block metadata for UI and translation context consumers

### Requirement: 流程

Screenshot OCR SHALL route recognized text into the editable workspace with correction paths.

#### Scenario: Screenshot OCR auto-runs

- **WHEN** OCR produces a selected candidate or reconstructed text
- **THEN** Parrot SHALL open the editable workspace with source draft populated and SHALL keep correction/retry actions available

