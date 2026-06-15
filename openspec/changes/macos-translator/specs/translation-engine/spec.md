# Spec: Translation Engine Abstraction Layer

## 目的

提供统一的翻译能力抽象，使内置引擎与第三方插件以相同协议接入，支持并发聚合对比，新增引擎对上层零侵入。

## 核心类型

```swift
enum Language: Equatable { case auto, zh, en, ja, ko, fr, de, /* ... ISO 639-1 */ custom(String) }

enum TranslateMode { case translate, lookup, polish }

struct ProviderCapabilities {
    let supportsLookup: Bool      // 查词
    let supportsStream: Bool      // LLM 流式
    let supportsPolish: Bool      // 润色
}

struct ProviderConfig {           // 引擎配置（密钥引用，不含明文）
    let credentialRef: String?    // Keychain key
    let extra: [String: String]   // model、endpoint、prompt 等
}

struct Phonetic { let type: String; let value: String }   // 美/英音标
struct Definition { let partOfSpeech: String; let meanings: [String]; let examples: [String] }
```

## Provider 协议

```swift
protocol TranslationProvider {
    var id: String { get }
    var displayName: String { get }
    var supportedLanguages: [Language] { get }
    var capabilities: ProviderCapabilities { get }
    func configure(_ config: ProviderConfig) throws
    func translate(_ req: TranslateRequest) async throws -> TranslateResult
    func stream(_ req: TranslateRequest) -> AsyncThrowingStream<String, Error>
}
```

## 行为要求

1. **语言检测**：`from == .auto` 时，Coordinator 先用 `NLLanguageRecognizer` 检测；置信度低时交由引擎自检并回填 `detectedFrom`。
2. **并发聚合**：Coordinator 用 `TaskGroup` 并发调用所有 `enabled` 引擎；
   - 每个引擎独立超时（默认 15s，可配）；
   - 单引擎抛错转为该卡片的错误态（含可重试），不影响其它引擎；
   - 结果按用户配置的 `order` 排序展示。
3. **错误模型**：
   ```swift
   enum ProviderError: Error { case auth, rateLimited, network, unsupportedLanguage, timeout, plugin(String) }
   ```
   UI 按类型渲染（鉴权→去配置、限流→稍后重试、网络→重试）。
4. **流式**：`capabilities.supportsStream == true` 的引擎（LLM）走 `stream()`，UI 增量渲染；否则用 `translate()`。
5. **幂等与缓存**：相同 `(text, from, to, mode, providerId)` 可命中近期缓存（可配 TTL），减少 API 调用。

## 内置引擎清单（M3）

Apple Translation、Google、DeepL、腾讯翻译君、百度、有道、彩云小译、Microsoft、OpenAI。每个引擎：实现协议 + 鉴权配置项 schema + Keychain 存储。

## 验收标准

- [ ] 新增一个引擎仅需实现协议并注册，无需改动 Coordinator/UI
- [ ] 同时启用 ≥10 引擎可并排返回结果，单引擎失败隔离
- [ ] `.auto` 源语言可正确检测中/英/日/韩
- [ ] 查词模式返回结构化音标/释义/例句
- [ ] 所有密钥仅存 Keychain，DB/日志无明文
