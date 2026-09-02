## ADDED Requirements

### Requirement: Meaning-first result presentation

The desktop result panel SHALL present structured interpretation in a meaning-first order for Understand and Social results.

#### Scenario: Structured interpretation succeeds

- **WHEN** a provider returns intended meaning, localized translation, tone, cultural notes, ambiguities, or confidence
- **THEN** the result card SHALL show the intended meaning first and SHALL keep the localized translation copyable and speakable

#### Scenario: Literal and localized translations differ

- **WHEN** a useful literal translation differs from the localized translation
- **THEN** the card SHALL show the literal translation as secondary reference rather than as the primary result

#### Scenario: Only plain translation succeeds

- **WHEN** no structured interpretation is available
- **THEN** the existing provider card SHALL continue to display the plain translation without an empty interpretation shell
