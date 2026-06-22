## ADDED Requirements

### Requirement: Terminology management settings

The settings UI SHALL provide a Terminology section where users can create, edit, search, enable, disable, import, and export terminology entries.

#### Scenario: Add AI Agent terminology

- **WHEN** the user opens Settings and adds source `AI Agent` with target `AI Agent` for English-to-Chinese
- **THEN** the entry SHALL appear in the terminology list and SHALL be applied to later English-to-Chinese translations

#### Scenario: Search terminology

- **WHEN** the user types `agent` in the terminology search field
- **THEN** the terminology list SHALL show entries whose source, target, or note contains `agent` case-insensitively

### Requirement: Terminology entry validation

The terminology UI SHALL prevent saving empty entries and duplicate source-term plus language-pair entries, and SHALL warn when entries overlap by containment.

#### Scenario: Duplicate terminology

- **WHEN** an enabled entry already exists for source `AI Agent`, source language `en`, and target language `zh`
- **AND** the user tries to create another entry with the same source and language pair
- **THEN** the UI SHALL block saving and direct the user to edit the existing entry

#### Scenario: Overlapping terminology warning

- **WHEN** the user has an entry for `Agent` and creates `AI Agent`
- **THEN** the UI SHALL allow saving but SHALL show a warning that longer matches take priority

### Requirement: Terminology application status in results

Result cards SHALL display terminology application status when terminology is enabled, without displacing primary translation actions such as copy and speak.

#### Scenario: Terminology matched and applied

- **WHEN** a translation result used two terminology entries successfully
- **THEN** the result card SHALL show a compact status such as `术语已应用 · 2`

#### Scenario: Terminology enabled but no matches

- **WHEN** terminology is enabled but the source text has no matching entries
- **THEN** result cards SHALL show no intrusive warning and MAY show `术语未命中` in secondary metadata

#### Scenario: Terminology restoration failed

- **WHEN** placeholder restoration fails for a provider result
- **THEN** the result card SHALL show a recoverable warning status without hiding the translation text

### Requirement: Terminology import and export

The settings UI SHALL support CSV import and export using the fields `source,target,from,to,caseSensitive,note,enabled`.

#### Scenario: Import CSV terminology

- **WHEN** the user imports a CSV containing valid terminology entries
- **THEN** the UI SHALL preview added, overwritten, and conflicted counts before writing to the terminology store

#### Scenario: Export CSV terminology

- **WHEN** the user exports terminology
- **THEN** the app SHALL write a CSV containing all current terminology entries and their enabled states

## MODIFIED Requirements

### Requirement: Settings window sections

The settings window SHALL include Terminology as a first-class section alongside General, Engines, Keys, Shortcuts, Plugins, and About.

#### Scenario: User manages domain language

- **WHEN** the user needs professional terms preserved
- **THEN** they SHALL be able to reach terminology management directly from Settings without editing provider prompts or plugin files
