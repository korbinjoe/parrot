## ADDED Requirements

### Requirement: Terminology data model

The system SHALL provide a first-class terminology model for translation requests, including source term, target term, source language, target language, case-sensitivity, note, enabled state, and stable identifier.

#### Scenario: User defines a protected professional term

- **WHEN** the user creates a terminology entry with source `AI Agent`, target `AI Agent`, source language `en`, and target language `zh`
- **THEN** the terminology store SHALL persist the entry locally and make it available to future English-to-Chinese translation requests

#### Scenario: Invalid terminology entry

- **WHEN** a terminology entry has an empty source term or empty target term after trimming whitespace
- **THEN** the system SHALL reject the entry and SHALL NOT include it in translation snapshots

### Requirement: Terminology snapshot per translation request

The system SHALL generate an immutable `TerminologySnapshot` for each translation request when terminology is enabled, and SHALL pass the same snapshot to every enabled provider participating in that request.

#### Scenario: Multi-engine aggregation with terminology

- **WHEN** the user translates text with Google, DeepL, and OpenAI enabled while terminology is enabled
- **THEN** all provider calls for that aggregation SHALL receive the same terminology snapshot

#### Scenario: Terminology changes during translation

- **WHEN** the user edits the terminology list while a translation request is already running
- **THEN** the in-flight request SHALL continue using the snapshot created at request start

### Requirement: Deterministic terminology matching

The terminology matcher SHALL apply only enabled entries whose target language matches the request target language and whose source language either matches the request source language or is `.auto`. Matching SHALL prefer longer source terms before shorter overlapping terms.

#### Scenario: Longest terminology match wins

- **WHEN** entries exist for `Agent` and `AI Agent`
- **AND** the source text contains `AI Agent`
- **THEN** the matcher SHALL match `AI Agent` as one terminology hit before considering `Agent`

#### Scenario: Case-sensitive terminology

- **WHEN** an entry for `LLM` is marked case-sensitive
- **THEN** the matcher SHALL match `LLM` but SHALL NOT match `llm`

### Requirement: Placeholder-based terminology enforcement

For providers without native glossary support, the system SHALL be able to protect matched source terms before provider calls and restore the configured target terms after translation.

#### Scenario: Preserve AI Agent in machine translation

- **WHEN** English-to-Chinese translation text contains `AI Agent`
- **AND** the terminology entry maps `AI Agent` to `AI Agent`
- **THEN** a non-native provider path SHALL protect the matched term before translation and restore `AI Agent` in the final translated output

#### Scenario: Placeholder restoration failure

- **WHEN** a provider modifies or removes a terminology placeholder so it cannot be restored
- **THEN** the result SHALL include a terminology application status indicating restoration failure without failing the whole provider result

### Requirement: LLM terminology prompt constraints

LLM providers SHALL inject matched terminology entries into the system prompt or equivalent instruction channel, and SHALL use the exact target term whenever the source term appears.

#### Scenario: OpenAI-compatible engine with terminology

- **WHEN** `OpenAICompatEngine` receives a request containing matched terminology entries
- **THEN** its request payload SHALL include terminology constraints in the system message

#### Scenario: Strict terminology mode for LLM

- **WHEN** strict terminology mode is enabled for a request sent to an LLM provider
- **THEN** the provider path SHALL use both prompt constraints and placeholder protection

### Requirement: Terminology application metadata

Each provider outcome SHALL expose terminology application metadata, including strategy, matched entries, match count, and whether restoration succeeded.

#### Scenario: Result card needs terminology status

- **WHEN** a provider returns a translation with two terminology matches applied
- **THEN** the aggregated outcome SHALL include a terminology application object with match count `2` and the strategy used

## MODIFIED Requirements

### Requirement: Provider capabilities

`ProviderCapabilities` SHALL describe terminology support as one of: unsupported, placeholder, prompt, promptAndPlaceholder, or nativeGlossary. Providers MAY override the default strategy when they can enforce terminology more reliably.

#### Scenario: Provider declares native glossary support

- **WHEN** a provider declares `nativeGlossary`
- **THEN** the coordinator SHALL prefer the provider's native glossary path before falling back to placeholder enforcement

### Requirement: Translation request shape

`TranslateRequest` SHALL include an optional terminology snapshot. Providers that do not understand terminology SHALL remain source-compatible by ignoring the optional field through host-side preprocessing.

#### Scenario: Terminology disabled

- **WHEN** terminology is disabled globally
- **THEN** translation requests SHALL omit the terminology snapshot and provider behavior SHALL match the previous implementation
