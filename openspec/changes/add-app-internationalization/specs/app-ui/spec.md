## ADDED Requirements

### Requirement: Application language preference

The macOS app SHALL provide a persisted application language preference independent of translation source and target language settings.

#### Scenario: First launch defaults to English

- **WHEN** no app language preference has been saved
- **THEN** user-facing macOS app chrome and settings labels SHALL resolve through English localization

#### Scenario: User switches to Simplified Chinese

- **WHEN** the user selects Simplified Chinese in Settings > General
- **THEN** subsequent localized UI strings SHALL resolve to Simplified Chinese where available
- **AND** Chinese source keys MAY be used as the Simplified Chinese fallback

#### Scenario: Unsupported saved language

- **WHEN** `app.languageCode` contains an unsupported value
- **THEN** the localization runtime SHALL fall back to English

### Requirement: Major language catalog foundation

The macOS app SHALL expose major app-language choices and use a deterministic fallback chain for incomplete catalogs.

#### Scenario: Missing translated key

- **WHEN** the selected language does not contain a localized value for a key
- **THEN** the runtime SHALL fall back to English
- **AND** if English is also missing, it SHALL return the original key

#### Scenario: Formatted localized strings

- **WHEN** a localized string contains format placeholders such as `%d` or `%@`
- **THEN** formatting SHALL use the selected app language locale rather than the host system locale

## MODIFIED Requirements

### Requirement: Settings window sections

The General settings section SHALL include application language selection alongside default translation source and target language settings.

#### Scenario: Change app language in Settings

- **WHEN** the user changes the app language picker
- **THEN** the preference SHALL persist immediately
- **AND** visible SwiftUI settings content SHALL refresh without requiring an app restart
