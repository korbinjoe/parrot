## ADDED Requirements

### Requirement: Translation hot path avoids provider reloads

Starting a translation or retrying one provider SHALL reuse the current provider registry and SHALL NOT rebuild all providers or rescan plugins unless settings or plugin configuration changed.

#### Scenario: Translate after providers are loaded

- **GIVEN** the app has completed startup provider registration
- **WHEN** the user translates selected text
- **THEN** the translation starts using the existing active providers without invoking provider reload or plugin scan work

#### Scenario: Retry one provider

- **GIVEN** a translation result exists for multiple providers
- **WHEN** the user retries one provider card
- **THEN** only that provider is looked up from the existing registry and rerun

### Requirement: Result rendering uses cached provider order

The floating result panel SHALL render provider slots from cached application state rather than recomputing full engine order during SwiftUI body evaluation.

#### Scenario: Incremental provider result arrives

- **WHEN** one provider returns before the others
- **THEN** the panel SHALL place it in the cached configured slot order without reparsing all engine/model settings in the view

### Requirement: Learning history statistics do not block the main actor

The app SHALL calculate full-history learning occurrence counts away from the main actor and SHALL prevent stale calculations from replacing newer results.

#### Scenario: Translation is saved while history is large

- **WHEN** a completed translation is persisted
- **THEN** the UI SHALL remain interactive while learning occurrence counts refresh asynchronously

### Requirement: History browser avoids repeated render-time full scans

The history browser SHALL materialize filtered records when filter inputs change instead of scanning all records as a computed property during each render.

#### Scenario: User types in history search

- **WHEN** the user updates the history search query
- **THEN** the displayed rows update from model state without repeated body-time full-history filtering
