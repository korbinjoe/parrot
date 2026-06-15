## ADDED Requirements

### Requirement: Bob-aligned translation engine roadmap

The system SHALL maintain a documented mapping from each Bob text-translation service to a Parrot implementation path (Swift built-in, community plugin, system API, or deferred), organized in priority phases P0 through P3 as defined in `design.md`.

#### Scenario: User consults migration guide

- **WHEN** a user opens `docs/bob-service-matrix.md`
- **THEN** each Bob text-translation service listed on the official Bob guide SHALL have a corresponding Parrot status (implemented, planned phase, or deferred with reason)

### Requirement: P0 built-in traditional machine translation engines

The system SHALL ship Swift built-in implementations for the following Bob-equivalent text-translation services by end of P0: Tencent (腾讯翻译君), Baidu (百度翻译), Youdao (有道翻译), Caiyun (彩云小译), and Microsoft (Microsoft 翻译), in addition to existing Google, DeepL, and OpenAI engines.

#### Scenario: Tencent engine with valid key

- **WHEN** the user enables Tencent translation and configures a valid API key in Keychain
- **THEN** the engine SHALL participate in concurrent aggregation and return translated text for supported language pairs

#### Scenario: Engine failure isolation

- **WHEN** one P0 built-in engine returns an auth or network error
- **THEN** other enabled engines SHALL still return results in the result panel without aborting the whole request

### Requirement: Apple Translation system engine

The system SHALL provide an `AppleTranslationEngine` built-in provider that uses the macOS Translation framework when available (macOS 15+), with `isAvailable` false on unsupported OS versions and the engine hidden or disabled in settings.

#### Scenario: Supported macOS version

- **WHEN** the app runs on macOS 15 or later and Apple Translation is enabled
- **THEN** translation requests SHALL be fulfilled offline via the system Translation API without requiring a user API key

#### Scenario: Unsupported macOS version

- **WHEN** the app runs below macOS 15
- **THEN** Apple Translation SHALL NOT appear as an enableable engine in settings

### Requirement: P1 built-in LLM translation engines

Bob-equivalent mainstream LLM text-translation services SHALL ship as Swift built-in engines by end of P1, including: **OpenAI** (refactored onto `OpenAICompatEngine`), DeepSeek, Gemini, Groq, Ollama, 通义千问, 豆包, Kimi, **智谱 GLM**, and **硅基流动**. OpenAI-compatible providers SHALL use the shared `OpenAICompatEngine` base class; `GeminiEngine` SHALL use a separate Google AI API implementation.

#### Scenario: OpenAI engine after P1 refactor

- **WHEN** the user enables OpenAI with a valid API key after the P1 `OpenAICompatEngine` refactor
- **THEN** `OpenAIEngine` SHALL behave as before (translate, stream, lookup) with no regression

#### Scenario: DeepSeek engine enabled with key

- **WHEN** the user enables DeepSeek in settings and configures a valid API key
- **THEN** `DeepSeekEngine` SHALL register as a built-in `TranslationProvider` and participate in aggregation without requiring a plugin install

#### Scenario: Ollama custom endpoint

- **WHEN** the user configures Ollama with a custom base URL (e.g. remote server)
- **THEN** the engine SHALL use the user-supplied endpoint while defaulting to `http://localhost:11434` when unset

#### Scenario: Zhipu GLM with user key

- **WHEN** the user enables 智谱 GLM and configures a valid API key
- **THEN** `ZhipuEngine` SHALL participate in aggregation using the official 智谱 API (not Bob's zero-config proxy)

#### Scenario: SiliconFlow engine enabled

- **WHEN** the user enables 硅基流动 with a valid API key
- **THEN** `SiliconFlowEngine` SHALL translate via SiliconFlow's OpenAI-compatible endpoint

#### Scenario: LLM model override

- **WHEN** the user changes the model name in settings for an OpenAI-compat engine
- **THEN** subsequent translation requests SHALL use the user-selected model without an app update

### Requirement: P2 built-in LLM extensions

Additional Bob-equivalent LLM services (文心一言, 混元, 零一万物, Azure OpenAI) SHALL ship as Swift built-in engines in P2, not as plugins.

#### Scenario: Azure OpenAI with deployment

- **WHEN** the user configures Azure OpenAI with endpoint, deployment name, and API key
- **THEN** `AzureOpenAIEngine` SHALL translate via the Azure OpenAI Chat Completions endpoint

### Requirement: Deferred Bob built-in proxy services

The system SHALL NOT implement Bob-exclusive built-in proxy services (Bob 智谱 GLM-Flash free proxy, 硅基流动 free-tier proxy, 金山词霸, 简明英汉词典) that lack stable public APIs; user-owned API keys for 智谱/硅基 SHALL use `ZhipuEngine` and `SiliconFlowEngine` in **P1**.

#### Scenario: User expects Bob free GLM without key

- **WHEN** a user expects zero-config 智谱 GLM-Flash parity
- **THEN** documentation SHALL explain Bob's built-in proxy is unavailable and direct them to apply for a 智谱 API key and enable `ZhipuEngine`, or use Gemini/Groq free tiers

### Requirement: Translation engine settings parity

Settings for text-translation engines SHALL support per-engine enable toggle, drag-order sort, API key field with validate action, optional model and endpoint fields for LLM engines, and an external link placeholder to key application tutorials aligned with Bob service names.

#### Scenario: Validate API key

- **WHEN** the user clicks Validate on a keyed engine with a correct secret
- **THEN** the UI SHALL show success without persisting the secret outside Keychain

## MODIFIED Requirements

### Requirement: Built-in engine inventory (M3)

Apple Translation、Google、DeepL、腾讯翻译君、百度、有道、彩云小译、Microsoft、OpenAI、DeepSeek、Gemini、Groq、Ollama、通义千问、豆包、Kimi、智谱 GLM、硅基流动 SHALL be implemented as Swift built-in or system providers by P1; 文心一言、混元、零一万物、Azure OpenAI SHALL follow in P2. Each engine MUST expose a configuration schema and store secrets in Keychain only. Community plugins remain available for long-tail services but SHALL NOT be required for mainstream LLM access. P3 engines (火山、阿里、小牛、Amazon) MAY follow in later phases.

#### Scenario: Ten-engine concurrent comparison

- **WHEN** the user enables at least ten built-in translation providers
- **THEN** the coordinator SHALL return up to ten result cards in user-defined order with independent error states
