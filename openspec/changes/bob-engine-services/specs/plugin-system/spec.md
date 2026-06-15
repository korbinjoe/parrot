## ADDED Requirements

### Requirement: Bob capability alignment in manifest

Plugin manifests SHALL declare capabilities using the enum values `translate`, `lookup`, and `ocr` (and `tts` when TTS plugins are supported), matching Bob's service-type split documented in the Bob service guide.

#### Scenario: OCR plugin capability

- **WHEN** a plugin declares `"capabilities": ["ocr"]`
- **THEN** the loader SHALL register it as an `OCRProvider` adapter rather than a `TranslationProvider`

### Requirement: Community plugin scope for long-tail services

The plugin system SHALL remain available for community and long-tail translation/OCR/TTS integrations. Mainstream Bob-equivalent LLM services (OpenAI, DeepSeek, Gemini, Groq, Ollama, 通义, 豆包, Kimi, 智谱, 硅基流动, etc.) SHALL NOT require plugins; they SHALL be delivered as Swift built-in engines per the translation-engine spec.

#### Scenario: User installs community LLM plugin

- **WHEN** a community plugin provides a non-built-in or experimental LLM endpoint
- **THEN** it SHALL load via the existing plugin runtime and participate in aggregation alongside built-in engines

## MODIFIED Requirements

### Requirement: Plugin package structure

```
my-plugin.parrotplugin/  (zip 或 directory)
├── info.json     # manifest
└── main.js       # implements translate and/or ocr entry points per capabilities
```

Community plugins SHALL use the Application Support Plugins directory. The repository SHALL NOT maintain an official `plugins/` directory of LLM translation plugins; `examples/` MAY contain reference plugins only.

#### Scenario: Reference plugin in examples

- **WHEN** a developer reads `examples/openai.parrotplugin`
- **THEN** it SHALL serve as a plugin development reference without being required for mainstream LLM usage
