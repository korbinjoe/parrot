## ADDED Requirements

### Requirement: Translation context profiles

Translation requests SHALL support optional context profiles that describe the user's task intent and guide prompts, provider routing, terminology strictness, privacy policy, and result layout.

#### Scenario: Request carries a profile

- **WHEN** the app starts translation from a contextual workflow
- **THEN** `TranslateRequest` SHALL carry an optional context profile such as quick translate, understand, native polish, reply, strict terminology, private/local, social, github, email, or document

#### Scenario: Provider ignores context

- **WHEN** a provider or plugin does not understand context profiles
- **THEN** the request SHALL remain compatible and the provider SHALL continue to translate using existing request fields

#### Scenario: LLM provider supports context

- **WHEN** an LLM-capable provider receives an Understand, Reply, GitHub, Email, or Document profile
- **THEN** Parrot SHALL adapt the prompt to the profile while preserving user terminology and language direction

### Requirement: Local privacy masking

Parrot SHALL be able to mask sensitive entities locally before sending text to cloud translation or LLM providers.

#### Scenario: Sensitive entities are detected

- **WHEN** source text contains supported sensitive entities and masking is enabled
- **THEN** Parrot SHALL replace those entities with stable placeholders before provider calls and restore them before displaying results

#### Scenario: Masking status is reported

- **WHEN** masking is applied
- **THEN** translation result metadata SHALL include a masking report with entity counts but SHALL NOT include the secret values

#### Scenario: Private/local profile is active

- **WHEN** the Private/local profile is active
- **THEN** Parrot SHALL avoid cloud providers unless the user explicitly overrides the policy

#### Scenario: Logs and history are written

- **WHEN** Parrot writes logs or history records
- **THEN** transient mask maps SHALL NOT be persisted or logged

### Requirement: Result quality evaluation

Parrot SHALL evaluate provider results for obvious quality failures and expose quality metadata for recommendation and UI status.

#### Scenario: Result has obvious failure

- **WHEN** a provider returns empty output, unchanged source, wrong-language output, extreme length ratio, leaked placeholders, terminology misses, timeout, or malformed plugin response
- **THEN** the result SHALL receive quality issues in metadata

#### Scenario: Recommended result is selected

- **WHEN** multiple provider outcomes are available
- **THEN** Parrot SHALL select a recommended result using user order, profile preference, and quality metadata

#### Scenario: Result quality is visible

- **WHEN** a provider result has quality issues
- **THEN** the UI SHALL be able to show a compact quality status without hiding the provider card

### Requirement: Paragraph segmentation support

Translation workflows SHALL support deterministic paragraph segmentation metadata for bilingual reading presentations.

#### Scenario: Long source text is segmented

- **WHEN** source text contains paragraphs, lists, OCR line groups, or markdown/code blocks
- **THEN** Parrot SHALL segment it locally and preserve paragraph hints in translation context for UI alignment

#### Scenario: Protected blocks are present

- **WHEN** source text contains code fences, inline code, markdown tables, or identifiers in GitHub/document profiles
- **THEN** segmentation SHALL preserve those blocks and SHOULD avoid translating code unless explicitly requested

## MODIFIED Requirements

### Requirement: 并发聚合

Concurrent provider aggregation SHALL remain failure-isolated while supporting context-aware routing and recommendation.

#### Scenario: Context routing is active

- **WHEN** a context profile supplies provider routing hints
- **THEN** the coordinator SHALL use those hints to order, prefer, or skip providers without preventing the user from seeing configured provider outcomes when appropriate

### Requirement: 错误模型

Provider errors and quality failures SHALL both be recoverable from the workspace.

#### Scenario: Provider fails or result quality is poor

- **WHEN** a provider errors or returns a low-quality result
- **THEN** Parrot SHALL keep the source draft editable and SHALL provide retry, configure, fallback, or profile-adjustment actions

