# Design: Bob 引擎服务对标 — 技术方案

## Context

### Bob 服务模型（三类）

Bob 将能力拆为三个独立的服务槽位，用户在「偏好设置 → 翻译/OCR → 服务」中分别配置：

| 服务类型 | 用途 | Bob 已接入数量 |
|----------|------|----------------|
| 文本翻译 | 每次翻译调用 | 27 |
| 文本识别 | 截图/OCR 取词 | 8 |
| 语音合成 | 朗读原文/译文 | 5 |

服务来源分三类：**Bob 内置（免费代理/离线）**、**用户自备 API Key**、**JavaScript 插件**。

### Parrot 现状

| 能力 | 当前实现 | 缺口 |
|------|----------|------|
| 文本翻译 | `GoogleEngine`、`DeepLEngine`、`OpenAIEngine` + 用户插件 | 缺 Apple/Microsoft/国内五家机翻及多数 LLM |
| OCR | Apple Vision（硬编码，无 `OCRProvider`） | 缺云端 OCR、插件 OCR |
| TTS | `Speaker`（`AVSpeechSynthesizer` 单例，无 Provider） | 缺云端 TTS、Provider 抽象 |
| 配置 | 环境变量/部分 Settings | 无三 Tab 服务管理、无申请教程链 |

Parrot 已有 `TranslationProvider` 协议、`PluginProvider` 适配、Keychain 注入模式，扩展成本主要在**新增引擎实现**而非架构重构。

## Goals / Non-Goals

**Goals:**

1. 制定与 Bob 服务矩阵 **1:1 对照**的分阶段路线图，每项服务有明确实现路径（Built-in / Community Plugin / System / Deferred）。
2. P0 完成后用户可用 **≥8 个文本翻译引擎**并排对比（含 Google/DeepL + 5 家国内机翻 + Apple）；P1 完成后主流 LLM 亦全部 Swift 内置，无需安装插件。
3. 落地 `OCRProvider` 协议，P1 接入百度 OCR + 腾讯 OCR；Vision 保持默认离线引擎。
4. 落地 `TTSProvider` 协议，P2 接入至少 1 个云端 TTS（腾讯或 Google）；离线系统 TTS 保持默认。
5. 在 `docs/bob-service-matrix.md` 维护 Bob↔Parrot 对照表与密钥申请链接。

**Non-Goals:**

- **不复刻 Bob 内置免费代理**（智谱 GLM-Flash、硅基流动 Qwen2.5-7B、金山词霸、简明词典、百度 OCR 试用版等）：无稳定公开 API，Parrot 不提供等价的「零配置无限免费」通道；用户改用 Gemini/Groq 免费额度或自备 Key。
- **不做 Bob 插件 100% 兼容**：Parrot 使用 `.parrotplugin` + `info.json`，结构参考 Bob 但 identifier/桥接 API 不同；可提供迁移指南而非二进制兼容。
- **首阶段不做 Amazon Translate、火山 OCR/TTS、阿里翻译、小牛翻译** 等 P3 长尾（除非 P0/P1 提前完成）。
- **不自建翻译/OCR/TTS 云服务**。

## Decisions

### D1 — 实现路径分类标准

| 路径 | 适用条件 | 示例 |
|------|----------|------|
| **Swift Built-in（机翻）** | 官方 REST API、请求/响应格式固定 | 腾讯 TMT、百度 MT、有道、彩云、Microsoft Translator、DeepL |
| **Swift Built-in（LLM）** | 主流 LLM，OpenAI-compat 或独立 REST；设置可配 model/endpoint | OpenAI、DeepSeek、Gemini、Groq、Ollama、通义、豆包、Kimi、智谱、硅基流动 |
| **System Built-in** | macOS 系统 API，离线/免费 | Apple Translation（macOS 15+）、Vision OCR、AVSpeechSynthesizer |
| **Community Plugin** | 长尾/实验性 API、用户自定义、Bob 社区插件迁移 | 非官方 LLM、特殊 prompt 模板、第三方词典 |
| **Deferred** | Bob 内置代理、无公开 API、或稳定性/合规风险 | Bob 智谱/硅基免费代理、金山词霸、简明词典、百度 OCR 试用 |

**理由**：对标 Bob，主流 LLM 与机翻一样在设置里开关即用；通过 `OpenAICompatEngine` 基类 + 薄 subclass 控制代码量；`model`/`endpoint` 用户可配，缓解 API 变更需发版的问题。插件留给社区长尾，不再维护官方 LLM 插件包。

### D2 — Bob 文本翻译服务对照表

| Bob 服务 | Parrot 路径 | 阶段 | 备注 |
|----------|-------------|------|------|
| Google 翻译 | ✅ Built-in `GoogleEngine` | 已有 | 免费 web 端点 |
| DeepL 翻译 | ✅ Built-in `DeepLEngine` | 已有 | Key 以 `:fx` 区分 Free |
| OpenAI | Built-in `OpenAIEngine` | **P1** | 重构为 `OpenAICompatEngine` 基类；已有实现，P1 完成基类抽取与设置对齐 |
| 腾讯翻译君 | Built-in `TencentEngine` | **P0** | TMT API，每月 500 万字符免费额度 |
| 百度翻译 | Built-in `BaiduEngine` | **P0** | 通用翻译 API |
| 有道翻译 | Built-in `YoudaoEngine` | **P0** | 有道智云 |
| 彩云小译 | Built-in `CaiyunEngine` | **P0** | 彩云 API v2 |
| Microsoft 翻译 | Built-in `MicrosoftEngine` | **P0** | Azure Cognitive Services |
| 系统翻译 | Built-in `AppleTranslationEngine` | **P0** | `Translation` framework，macOS 15+，离线 |
| DeepSeek | Built-in `DeepSeekEngine` | **P1** | `OpenAICompatEngine` 子类，默认 `deepseek-chat` |
| Gemini | Built-in `GeminiEngine` | **P1** | Google Generative Language API，独立实现 |
| Groq | Built-in `GroqEngine` | **P1** | OpenAI-compat |
| Ollama | Built-in `OllamaEngine` | **P1** | 默认 `localhost:11434`，endpoint 可配 |
| 通义千问 | Built-in `QwenEngine` | **P1** | DashScope OpenAI-compat |
| 豆包 | Built-in `DoubaoEngine` | **P1** | 火山方舟 OpenAI-compat |
| Kimi | Built-in `KimiEngine` | **P1** | Moonshot OpenAI-compat |
| 智谱 GLM | Built-in `ZhipuEngine` | **P1** | 用户自备 Key；不做 Bob 零配置免费代理 |
| 硅基流动 | Built-in `SiliconFlowEngine` | **P1** | OpenAI-compat 聚合 |
| 文心一言 | Built-in `ErnieEngine` | **P2** | 千帆 API |
| 混元 | Built-in `HunyuanEngine` | **P2** | 腾讯混元 API |
| 零一万物 | Built-in `YiEngine` | **P2** | Yi API |
| Azure OpenAI | Built-in `AzureOpenAIEngine` | **P2** | OpenAI-compat + deployment 名 |
| 火山翻译 | Built-in `VolcengineEngine` | **P3** | 字节火山引擎 |
| 阿里翻译 | Built-in `AliyunEngine` | **P3** | 阿里云机器翻译 |
| 小牛翻译 | Built-in `NiutransEngine` | **P3** | 小牛 API |
| Amazon 翻译 | Built-in `AmazonTranslateEngine` | **P3** | AWS Translate |
| 金山词霸 | Deferred | — | 无公开 API；查词用 `lookup` 模式 + 有道/插件 |
| 简明英汉词典 | Deferred | — | 离线词典包体积大，单列 future |

### D3 — Bob 文本识别（OCR）服务对照表

| Bob 服务 | Parrot 路径 | 阶段 | 备注 |
|----------|-------------|------|------|
| 离线文本识别 | ✅ `AppleVisionOCRProvider` | 已有 | 对应 Vision，`OCRProvider` 协议化 |
| 百度 OCR | Built-in `BaiduOCRProvider` | **P1** | 通用文字识别 |
| 腾讯 OCR | Built-in `TencentOCRProvider` | **P1** | 通用印刷体识别 |
| 腾讯图片翻译 | Built-in `TencentImageTranslateProvider` | **P2** | OCR+翻译一体，截图场景可选 |
| Google OCR | Built-in `GoogleOCRProvider` | **P2** | Cloud Vision API |
| 有道 OCR | Built-in `YoudaoOCRProvider` | **P2** | 有道 OCR API |
| 火山 OCR | Built-in `VolcengineOCRProvider` | **P3** | |
| 百度 OCR 试用版 | Deferred | — | Bob 内置不稳定代理，不做 |

**默认策略**：`AppleVisionOCRProvider` 始终为默认（离线免费）；用户在设置中可切换云端 OCR（需 Key）。

### D4 — Bob 语音合成（TTS）服务对照表

| Bob 服务 | Parrot 路径 | 阶段 | 备注 |
|----------|-------------|------|------|
| 离线语音合成 | ✅ `SystemTTSProvider` | 已有 | 封装现有 `Speaker` |
| 腾讯语音合成 | Built-in `TencentTTSProvider` | **P2** | 腾讯云 TTS |
| Google 语音合成 | Built-in `GoogleTTSProvider` | **P2** | Cloud Text-to-Speech |
| Microsoft 语音合成 | Built-in `MicrosoftTTSProvider` | **P2** | Azure Speech |
| 火山语音合成 | Built-in `VolcengineTTSProvider` | **P3** | |

**接口 sketch：**

```swift
protocol TTSProvider {
    var id: String { get }
    var displayName: String { get }
    var isOfflineCapable: Bool { get }
    func speak(_ text: String, language: Language) async throws
    func stop()
}
```

`Speaker` 重构为 `TTSCoordinator`，按用户设置选择 Provider；默认 `SystemTTSProvider`。

### D5 — 引擎注册与配置

沿用现有模式：

```swift
// AppState.init
registry.register(GoogleEngine(), enabled: settings.googleEnabled)
registerKeyed(TencentEngine(), key: settings.tencentKey(), enabled: settings.tencentEnabled)
// ...
loadPlugins() // 仅社区/用户插件
loadOCRProviders()
loadTTSProviders()
```

- 每个 Keyed 引擎：`AppSettings` 增加 `xxxEnabled` + `xxxKey()` Keychain 读取；LLM 引擎额外支持 `model` / `endpoint`（可选覆盖默认值）。
- 设置 UI 三 Tab：**文本翻译** / **文本识别** / **语音合成**，列表项含开关、排序、密钥字段、「验证」按钮、申请教程外链（Bob 文档链接或 Parrot 镜像）。

### D6 — LLM 引擎：`OpenAICompatEngine` 基类

将现有 `OpenAIEngine` 重构为可复用基类，各 LLM 以薄 subclass 注册：

```swift
/// 共享 Chat Completions 请求/解析/流式；子类只定义 id、displayName、默认 endpoint/model。
open class OpenAICompatEngine: TranslationProvider {
    // configure: apiKey + optional model/endpoint override
}

final class DeepSeekEngine: OpenAICompatEngine {
    override init(...) {
        super.init(defaultEndpoint: "https://api.deepseek.com/v1/chat/completions",
                   defaultModel: "deepseek-chat", ...)
    }
}
```

**非 compat 例外**：`GeminiEngine` 单独实现 Google AI `generateContent` API；P2 国内 LLM（文心/混元）各一个 Swift 类。

**设置项**：每个 LLM 引擎暴露 `apiKey`（Keychain）、`model`（String，默认随引擎）、`endpoint`（String，可选，Ollama/Azure 必填）。

### D7 — 与 macos-translator M3 任务的关系

`macos-translator/tasks.md` M3 已列「接入其余引擎：腾讯、百度、有道、彩云、Microsoft、Apple Translation」。本变更将其**具体化**为 Bob 对照表 + P0–P3 排期，并扩展到 OCR/TTS 服务类型。

## Risks / Trade-offs

| 风险 | 缓解 |
|------|------|
| 国内云 API 鉴权方式各异（签名算法、多 Key） | 每引擎独立 `*Auth.swift` 工具类 + 单测 fixture；文档写清申请步骤 |
| Apple Translation 仅 macOS 15+ | `isAvailable` 运行时检测；不可用则设置中灰显 |
| Google 免费 web 端点可能失效 | 已有风险；P0 不依赖其稳定性，鼓励用户启用国内引擎 |
| LLM 模型名/API 变更需发版改默认值 | 设置 UI 允许用户覆盖 `model`/`endpoint`；默认值随 minor 版本更新 |
| 多个 LLM Engine 类看似重复 | `OpenAICompatEngine` 基类 + 子类仅 10～20 行 |
| OCR/TTS Provider 抽象增加 AppState 复杂度 | Coordinator 模式与翻译层一致；默认行为不变 |
| Bob 内置免费 LLM 无法对等 | 文档明确说明；推荐 Gemini/Groq 免费 Key 或 Ollama 本地 |

## Migration Plan

1. **Phase P0**（文本翻译 Swift 内置 6 个 + Apple Translation）：无 breaking change，默认仅启用 Google；用户手动开启国内引擎。
2. **Phase P1**（`OpenAICompatEngine` + **10 个 LLM 内置**（含 OpenAI 重构、智谱、硅基流动）+ OCR 协议 + 百度/腾讯 OCR）：截图流程改走 `OCRCoordinator`，默认仍为 Vision。
3. **Phase P2**（TTS Provider + 云端 TTS + P2 LLM 内置（文心/混元/零一/Azure）+ 扩展 OCR）：`Speaker` API 保持，`speak()` 内部路由到 Coordinator。
4. **Phase P3**（长尾引擎）：按需交付，不阻塞 P0 发布。

回滚：每引擎独立开关；移除某 Built-in 仅需取消注册，不影响其它引擎。

## Open Questions

1. **Apple Translation** 在 macOS 14 是否通过 `NLLanguageTranslator` 等替代方案部分覆盖？需 spike 验证最低系统版本策略。
2. **查词（lookup）** 是否 P0 绑定有道引擎，还是单独做离线词典包？建议 P0 有道 API 的 lookup 模式，简明词典继续 Deferred。
3. **设置 UI** 是否本变更实现，还是依赖 `redesign-app-ui` 的引擎 Tab？建议 P0 可在现有 Form 上扩展，完整三 Tab 随 UI 重设计合并。
