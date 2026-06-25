# App UI Spec Delta

## ADDED Requirements

### Requirement: Keys Page Uses Status-First Provider Management

The iOS Settings Keys page SHALL prioritize provider configuration status over complete provider enumeration.

#### Scenario: User opens Keys without search

- **GIVEN** the user opens Settings > Keys
- **WHEN** no provider search is active
- **THEN** the page SHALL show providers that need action and providers already configured
- **AND** the full provider catalog SHALL remain available through an add/select provider control.

#### Scenario: User adds a provider

- **GIVEN** the user is on Settings > Keys
- **WHEN** the user taps Add Service
- **THEN** a searchable provider picker SHALL open without leaving the Keys page
- **AND** providers SHALL be grouped by common usage, LLM, OCR/TTS, and cloud vendors.

#### Scenario: User selects a provider from picker

- **GIVEN** the provider picker is open
- **WHEN** the user selects a provider
- **THEN** the picker SHALL close
- **AND** the selected provider SHALL expand into a focused configuration form.

#### Scenario: Provider uses environment variable

- **GIVEN** a provider is configured by environment variable
- **WHEN** it appears in Keys
- **THEN** the page SHALL show the environment variable as active
- **AND** local saving SHALL be presented as optional rather than required.
