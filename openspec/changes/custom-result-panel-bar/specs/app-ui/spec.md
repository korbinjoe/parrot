# Spec: Result Panel Custom Bar

## ADDED Requirements

### Requirement: Single Visible Result Panel Bar
The result panel SHALL show only one visible header bar.

#### Scenario: Expanded result panel is shown
- **WHEN** the result panel is expanded
- **THEN** native title text and traffic-light controls are not visible
- **AND** the custom SwiftUI bar is the only visible header area

### Requirement: Exposed Result Panel Actions
The result panel custom bar SHALL expose common operations as direct icon buttons.

#### Scenario: User needs frequent result actions
- **WHEN** the result panel has source or translation content
- **THEN** the bar provides direct controls for retry/translate, pin, favorite, copy, speak, vocabulary, collapse, settings, and close

### Requirement: Collapsed Panel Keeps Single-Bar Chrome
The collapsed result panel SHALL not reserve spacing for hidden native traffic-light controls.

#### Scenario: User collapses the panel
- **WHEN** the collapsed summary is shown
- **THEN** content aligns to the custom panel margins
- **AND** no empty native-titlebar gutter is visible
