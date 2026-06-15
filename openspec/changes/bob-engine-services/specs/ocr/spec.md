## ADDED Requirements

### Requirement: OCRProvider protocol implementation

The system SHALL implement the `OCRProvider` protocol defined in the OCR spec and route all screenshot OCR flows through an `OCRCoordinator` that selects the user-configured default provider, replacing direct hard-coded Apple Vision calls.

#### Scenario: Default offline OCR

- **WHEN** no cloud OCR provider is enabled or keyed
- **THEN** `AppleVisionOCRProvider` SHALL be used as the default and behave identically to the current Vision implementation

#### Scenario: Switch OCR provider in settings

- **WHEN** the user selects Baidu OCR as the default and provides a valid key
- **THEN** subsequent screenshot OCR requests SHALL use `BaiduOCRProvider` instead of Vision

### Requirement: P1 cloud OCR providers

The system SHALL ship built-in `BaiduOCRProvider` and `TencentOCRProvider` matching Bob's 百度 OCR and 腾讯 OCR services, requiring user API keys stored in Keychain.

#### Scenario: Baidu OCR recognition

- **WHEN** Baidu OCR is the active provider and the screenshot contains printed Chinese or English text
- **THEN** the provider SHALL return structured `OCRResult` with `fullText` and `blocks` suitable for layout-aware translation

#### Scenario: Cloud OCR auth failure

- **WHEN** the configured cloud OCR key is invalid
- **THEN** the UI SHALL show an auth error with a link to reconfigure keys and SHALL NOT silently fall back without user opt-in

### Requirement: Bob OCR service mapping

Each Bob text-recognition service SHALL map to a Parrot provider as documented: 离线文本识别 → AppleVisionOCRProvider; 百度/腾讯 OCR → built-in P1; 腾讯图片翻译 / Google / 有道 / 火山 OCR → P2/P3; 百度 OCR 试用版 → deferred.

#### Scenario: Deferred Bob trial OCR

- **WHEN** documentation lists 百度 OCR 试用版
- **THEN** it SHALL be marked deferred with Apple Vision or keyed Baidu OCR as the recommended alternative

### Requirement: OCR settings tab

OCR provider settings SHALL appear under a dedicated "文本识别" section (or settings tab) separate from text-translation engines, with enable toggle, default provider selection, and key validation per Bob's OCR service list.

#### Scenario: OCR settings separate from translation

- **WHEN** the user opens service settings
- **THEN** text-recognition providers SHALL NOT be mixed into the text-translation engine list
