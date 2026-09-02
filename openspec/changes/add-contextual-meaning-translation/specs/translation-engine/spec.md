## ADDED Requirements

### Requirement: Structured contextual interpretation

LLM-capable translation providers SHALL support a structured interpretation result for Understand and Social context profiles while preserving plain translation compatibility.

#### Scenario: Implied meaning is present

- **WHEN** an Understand or Social request contains idiom, sarcasm, indirectness, slang, or culturally dependent phrasing
- **THEN** the result SHALL distinguish intended meaning from localized translation and MAY include literal translation, tone, cultural notes, ambiguity alternatives, and confidence

#### Scenario: Context is insufficient

- **WHEN** more than one pragmatic interpretation is plausible
- **THEN** the provider SHALL avoid presenting an inference as fact and SHALL return alternatives with reduced confidence

#### Scenario: Structured response is invalid

- **WHEN** a provider returns malformed or incomplete interpretation JSON
- **THEN** Parrot SHALL preserve the raw response as a plain translation result without losing the provider outcome

### Requirement: Action-scoped context injection

Parrot SHALL make available context affect LLM interpretation without collecting unrelated background content.

#### Scenario: Source metadata is available

- **WHEN** an explicit translation action includes source App, window title, URL, origin, or surrounding text
- **THEN** the LLM request SHALL include that information as untrusted reference context

#### Scenario: OCR block is selected

- **WHEN** the user translates one block from an OCR result containing other useful blocks
- **THEN** Parrot SHALL provide a bounded subset of those blocks as surrounding context

### Requirement: Interpretation-aware recommendation

Understand and Social requests SHALL prefer providers and results that support structured interpretation.

#### Scenario: Structured and plain results both succeed

- **WHEN** one result contains valid structured interpretation and another only contains a plain translation
- **THEN** the structured result SHALL be recommended unless it has a higher-severity quality failure

## MODIFIED Requirements

### Requirement: Result quality evaluation

Quality evaluation SHALL include profile-specific completeness in addition to structural translation checks.

#### Scenario: Understand result lacks interpretation

- **WHEN** an Understand or Social result contains only a plain translation
- **THEN** the quality summary SHALL record that structured interpretation is missing without discarding the fallback result
