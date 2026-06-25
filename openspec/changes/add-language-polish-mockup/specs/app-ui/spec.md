# Spec Delta: App UI - Native Polish Mockup

## ADDED Requirements

### Requirement: Native Polish workspace prototype

The app design SHALL include a high-fidelity interactive HTML prototype for a Native Polish workflow that extends the existing editable workspace model.

#### Scenario: User polishes a rough multilingual paragraph

- **GIVEN** the user opens the Native Polish mockup
- **WHEN** they edit the draft and select a tone
- **THEN** the UI keeps the draft editable and shows a native-speaker rewrite as the primary output

#### Scenario: User compares original and native rewrite

- **GIVEN** a polished result is available
- **WHEN** the user opens Compare
- **THEN** the UI shows concise change highlights and intent-preservation notes

#### Scenario: User refines the generated paragraph

- **GIVEN** a polished result is visible
- **WHEN** the user clicks Shorter, Warmer, Sharper, or More professional
- **THEN** the primary result updates in place without clearing the source draft

#### Scenario: User copies or replaces the draft

- **GIVEN** a polished result is visible
- **WHEN** the user copies or replaces the draft
- **THEN** the UI provides inline confirmation and preserves the workspace context
