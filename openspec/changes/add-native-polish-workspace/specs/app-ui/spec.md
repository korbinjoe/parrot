# Spec Delta: App UI - Native Polish Workspace

## ADDED Requirements

### Requirement: Native Polish production workspace

The iOS app SHALL provide Native Polish as a workspace mode for rewriting a rough draft into native-speaker writing.

#### Scenario: User starts Native Polish from Today

- **GIVEN** the user is on Today
- **WHEN** they open Native Polish
- **THEN** the app opens Workspace with Polish selected and an editable source draft

#### Scenario: User generates a polished rewrite

- **GIVEN** the user has entered a source draft in Polish mode
- **WHEN** they run Native Polish
- **THEN** the app shows a primary polished rewrite and secondary variants without clearing the draft

#### Scenario: User replaces the draft with a rewrite

- **GIVEN** a polished result is visible
- **WHEN** the user taps Replace draft
- **THEN** the source editor is updated with that result and the workspace remains in Polish mode

#### Scenario: User refines a polished result

- **GIVEN** a polished result is visible
- **WHEN** the user chooses a refinement action
- **THEN** the selected candidate updates in place using the current polish context
