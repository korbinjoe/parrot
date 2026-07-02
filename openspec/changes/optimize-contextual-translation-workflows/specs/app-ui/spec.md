## ADDED Requirements

### Requirement: Quick Peek surface

The macOS app SHALL provide a compact Quick Peek surface for short translation and lookup tasks while preserving the full editable workspace as the expansion path.

#### Scenario: Short selection opens Quick Peek

- **WHEN** the user selects a short text snippet and invokes selected text translation
- **THEN** Parrot SHALL show Quick Peek with the source, primary translation or meaning, and quick actions without requiring the full workspace by default

#### Scenario: Lookup opens Quick Peek

- **WHEN** the user invokes lookup for a word or short phrase
- **THEN** Quick Peek SHALL show lookup-oriented content such as pronunciation, definition, translation, copy, speak, and save/vocabulary actions when available

#### Scenario: User expands Quick Peek

- **WHEN** the user chooses to expand from Quick Peek
- **THEN** Parrot SHALL open the full workspace with the same source draft, outcomes, profile, and recoverable error state

#### Scenario: Quick Peek has an error

- **WHEN** provider configuration, network, permission, or timeout errors occur in Quick Peek
- **THEN** Quick Peek SHALL show visible retry/configure actions and SHALL NOT silently close before the user can recover

### Requirement: Paragraph bilingual workspace

The workspace SHALL provide a paragraph-level bilingual reading presentation for long or multi-paragraph source text.

#### Scenario: Long text is translated

- **WHEN** source text contains multiple paragraphs or exceeds the long-text threshold
- **THEN** the workspace SHALL offer a bilingual paragraph presentation that keeps original paragraphs adjacent to their translated output

#### Scenario: Source remains editable

- **WHEN** paragraph bilingual view is visible
- **THEN** the source composer SHALL remain editable and rerunning translation SHALL update the paragraph presentation in the same workspace

#### Scenario: User copies a paragraph

- **WHEN** the user copies an individual translated paragraph
- **THEN** Parrot SHALL copy only that paragraph and keep the workspace open

#### Scenario: Provider comparison remains available

- **WHEN** paragraph bilingual view is active
- **THEN** provider cards and provider-specific errors SHALL remain accessible for comparison and recovery

### Requirement: Context profile selector

The workspace SHALL expose user-facing context profiles that tune result layout, prompts, routing, terminology behavior, and privacy policy without exposing raw prompt or provider complexity.

#### Scenario: User selects Understand profile

- **WHEN** the user selects the Understand profile
- **THEN** Parrot SHALL prioritize meaning, nuance, tone, and optional literal translation over a single literal output

#### Scenario: User selects Strict terminology profile

- **WHEN** the user selects Strict terminology
- **THEN** Parrot SHALL use terminology-strict request behavior and SHALL display terminology application status in result cards

#### Scenario: User selects Private/local profile

- **WHEN** the user selects Private/local
- **THEN** Parrot SHALL prefer local or user-approved private providers and SHALL clearly mark when a cloud provider would be required

#### Scenario: Switching profiles

- **WHEN** the user switches profile for an active source draft
- **THEN** Parrot SHALL preserve the draft and SHALL either rerun in place or show a clear action to rerun with the new profile

### Requirement: Recommended result

The workspace SHALL identify a recommended result when multiple provider outcomes are available.

#### Scenario: Provider results pass quality checks

- **WHEN** multiple provider results complete and at least one passes quality checks
- **THEN** Parrot SHALL mark one result as recommended based on profile preference, user ordering, and quality summary

#### Scenario: Top provider fails quality checks

- **WHEN** the top ordered provider result fails quality checks and another result passes
- **THEN** Parrot SHALL recommend the passing fallback result while keeping the failed provider card visible with its issue status

#### Scenario: No result passes quality checks

- **WHEN** no provider result passes basic quality checks
- **THEN** Parrot SHALL show the best available result as needing review and SHALL offer retry or profile/provider adjustment actions

## MODIFIED Requirements

### Requirement: 悬浮结果面板

The result panel SHALL function as a contextual workspace, not only a static result list.

#### Scenario: Workspace header exposes task context

- **WHEN** the workspace is visible
- **THEN** its header SHALL show language direction, status, profile, and common actions in a compact tool layout

#### Scenario: Source draft is preserved across surfaces

- **WHEN** the user moves between Quick Peek, full workspace, paragraph view, and provider cards
- **THEN** the editable source draft SHALL be preserved unless the user explicitly clears it

