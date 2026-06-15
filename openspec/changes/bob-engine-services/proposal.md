# Proposal: Bob 引擎服务对标与分阶段接入方案

- **Change name**: `bob-engine-services`
- **Status**: Proposed
- **Date**: 2026-06-15
- **参考**: [Bob 添加服务指南](https://bobtranslate.com/guide/advance/service.html)

## Why

Parrot 对标 Bob 类 macOS 翻译工具，但当前仅内置 **Google、DeepL、OpenAI** 三个文本翻译引擎，OCR 仅 **Apple Vision**，TTS 仅 **系统离线合成**。Bob 官方已接入 **27 种文本翻译、8 种文本识别、5 种语音合成** 服务（含内置免费、密钥申请、插件扩展三类）。引擎覆盖不足会直接限制用户从 Bob 迁移的意愿，也无法发挥 Parrot 已具备的 `TranslationProvider` / 插件运行时架构优势。需要在研究 Bob 服务矩阵的基础上，制定**可落地的分阶段支持方案**，明确每项服务走「Swift 内置 / 社区插件 / 暂不实现」哪条路径。

## What Changes

- 梳理 Bob 三大服务类型（文本翻译 / 文本识别 / 语音合成）的完整清单，与 Parrot 现状逐项对照。
- 制定 **P0→P3 四阶段**接入优先级：优先补齐高频传统机翻与国内云厂商，再扩展 LLM 引擎，最后覆盖长尾与词典类能力。
- 为每个 Bob 服务指定实现路径：
  - **Built-in Swift（机翻）**：稳定 REST API、需 Keychain 鉴权（腾讯/百度/有道/彩云/Microsoft 等）。
  - **Built-in Swift（LLM）**：主流 LLM 全部内置；P1 含 OpenAI（基类重构）、DeepSeek、Gemini、Groq、Ollama、通义、豆包、Kimi、**智谱 GLM、硅基流动**；设置可配 model/endpoint。
  - **System / Free**：Apple Translation、系统 TTS、Vision OCR（对应 Bob 内置离线类）。
  - **Community Plugin**：长尾/实验性 API、用户自定义（保留现有插件运行时）。
  - **Deferred**：Bob 独占内置代理（智谱/硅基免费代理、金山词霸、简明词典、百度 OCR 试用版等）。
- 扩展 `translation-engine` 与 `ocr` spec 中的内置服务清单与验收标准；新增 `tts-providers` 能力 spec，为云端 TTS 预留统一抽象。
- 在设置 UI（依赖 `app-ui` 变更或后续迭代）中按 Bob 分类展示：**文本翻译 / OCR / TTS** 三个 Tab，每项含申请教程链接占位。
- 提供 **Bob→Parrot 迁移对照表** 文档，帮助用户找到等价内置引擎。

## Capabilities

### New Capabilities

- `tts-providers`: 语音合成 Provider 抽象与内置/云端 TTS 接入规范（当前仅有 `AVSpeechSynthesizer` 封装，无 Provider 协议）。

### Modified Capabilities

- `translation-engine`: 扩展内置引擎清单至 Bob P0/P1 覆盖范围；**主流 LLM 全部 Swift 内置**（`OpenAICompatEngine` + `GeminiEngine`）；更新「≥10 引擎并排对比」验收列表。
- `ocr`: 落地 `OCRProvider` 协议；接入百度 OCR、腾讯 OCR 作为 P1 云端 OCR；保留 Apple Vision 为默认离线引擎。
- `plugin-system`: manifest 与 Bob 能力枚举对齐（translate / ocr / tts）；**不再维护官方 LLM 插件包**，插件定位调整为社区/长尾扩展。

## Impact

| 区域 | 影响 |
|------|------|
| `Sources/ParrotEngines/` | P0 机翻 + P1/P2 LLM（`OpenAICompatEngine` 基类、`GeminiEngine`、各薄 subclass） |
| `examples/` | 保留示例插件（echo/openai），供社区参考；不再新增官方 LLM 插件 |
| `Sources/ParrotCore/` | OCRProvider 协议、TTSProvider 协议（新模块或同层扩展） |
| `Sources/ParrotApp/AppState.swift` | 引擎注册、设置项、Keychain 键名扩展 |
| `Sources/ParrotApp/Settings/` | 三 Tab 服务管理 UI（翻译/OCR/TTS） |
| `Tests/` | 各引擎 parse/鉴权单测；OCR/TTS provider 契约测试 |
| `docs/` | Bob 服务对照表、各引擎申请密钥说明链接 |
| 密钥管理 | 每引擎独立 Keychain ref，遵循现有 `AppSettings` 模式 |
