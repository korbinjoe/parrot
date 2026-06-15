# Spec Delta: TTS Providers (new capability)

## ADDED Requirements

### Requirement: TTSProvider abstraction

The system SHALL define a `TTSProvider` protocol with `id`, `displayName`, `isOfflineCapable`, `speak(_:language:)`, and `stop()`, and route all read-aloud actions through a `TTSCoordinator` that selects the user-configured provider.

#### Scenario: Default system TTS

- **WHEN** no cloud TTS provider is configured
- **THEN** `SystemTTSProvider` wrapping `AVSpeechSynthesizer` SHALL be used and behavior SHALL match the current `Speaker` implementation

#### Scenario: Stop speaking

- **WHEN** the user triggers stop or starts a new utterance while speech is active
- **THEN** the active `TTSProvider` SHALL stop playback immediately

### Requirement: Bob TTS service mapping

Each Bob speech-synthesis service SHALL map to a Parrot provider: 离线语音合成 → `SystemTTSProvider`; 腾讯 / Google / Microsoft cloud TTS → built-in P2 providers; 火山语音合成 → P3. Documentation SHALL list this mapping in `docs/bob-service-matrix.md`.

#### Scenario: Cloud TTS requires key

- **WHEN** the user selects Tencent cloud TTS without a configured key
- **THEN** the UI SHALL prompt for key configuration and SHALL NOT attempt unauthorized API calls

### Requirement: P2 cloud TTS minimum

By end of P2, the system SHALL ship at least one cloud `TTSProvider` (Tencent or Google Text-to-Speech) with Keychain-stored credentials and voice selection where the upstream API supports it.

#### Scenario: Tencent TTS playback

- **WHEN** Tencent TTS is enabled with valid credentials and the user clicks read-aloud on Chinese text
- **THEN** audio SHALL be synthesized via Tencent's API and played through the system audio output

### Requirement: TTS settings tab

TTS providers SHALL be configurable under a dedicated "语音合成" settings section separate from translation and OCR services, consistent with Bob's three service-type tabs.

#### Scenario: Offline default preserved

- **WHEN** the user has never configured cloud TTS
- **THEN** offline system TTS SHALL remain the default with no API key required
