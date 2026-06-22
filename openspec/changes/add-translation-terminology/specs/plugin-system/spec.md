## ADDED Requirements

### Requirement: Plugin terminology query field

The plugin runtime SHALL include an optional `terminology` array on the `query` object passed to `translate(query, completion)`.

#### Scenario: Terminology-aware plugin

- **WHEN** a plugin receives a translation query for text containing `AI Agent`
- **AND** the active terminology snapshot contains `AI Agent -> AI Agent`
- **THEN** `query.terminology` SHALL include an object describing that entry

#### Scenario: Existing plugin compatibility

- **WHEN** an existing plugin ignores `query.terminology`
- **THEN** the plugin SHALL continue to translate successfully using the existing `query.text`, `query.from`, `query.to`, and `query.mode` fields

### Requirement: Plugin terminology support declaration

Plugin manifests MAY declare whether the plugin handles terminology itself. The host SHALL use that declaration to decide whether to apply host-side placeholder protection around plugin calls.

#### Scenario: Plugin declares terminology support

- **WHEN** a plugin manifest includes `supportsTerminology: true`
- **THEN** the host SHALL pass `query.terminology` and MAY skip host-side placeholder protection for that plugin

#### Scenario: Plugin does not declare terminology support

- **WHEN** a plugin does not declare terminology support
- **THEN** the host SHALL preserve backward compatibility and MAY apply host-side terminology protection before invoking the plugin

## MODIFIED Requirements

### Requirement: Plugin development documentation

The plugin development guide SHALL document `query.terminology`, the optional manifest declaration, and an example of adding terminology constraints to an LLM system prompt.

#### Scenario: Developer builds LLM plugin with terminology

- **WHEN** a plugin developer reads `docs/plugin-development.md`
- **THEN** they SHALL find an example showing how to include terminology entries in an LLM request
