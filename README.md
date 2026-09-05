# Parrot

[![CI](https://github.com/korbinjoe/parrot/actions/workflows/ci.yml/badge.svg)](https://github.com/korbinjoe/parrot/actions/workflows/ci.yml)

开源 macOS / iOS 翻译 + OCR 工具：划词翻译、截图 OCR 翻译、输入翻译、查词、多引擎聚合对比、可扩展插件系统（接入任意 LLM）、历史/收藏、TTS。

> 规划与设计见 `openspec/changes/macos-translator/`。

## 预览

<p align="center">
  <img src="docs/screenshots/app-icon.png" alt="Parrot App Icon" width="128">
  <img src="docs/screenshots/menubar-icon.png" alt="Parrot Menu Bar Icon" width="64">
</p>

| 平台 | 说明 |
|------|------|
| **macOS** | 菜单栏常驻 App，全局快捷键 + 悬浮翻译窗。克隆后运行 `bash scripts/build-app.sh` 产出 `build/Parrot.app`。 |
| **iOS** | 社交阅读/写作助手与 Quick Lens OCR（iOS 17+）。用 Xcode 打开 `project.yml` 生成工程后运行 `ParrotiOS` scheme。交互原型见 [docs/mockups/ios-social-assistant/index.html](./docs/mockups/ios-social-assistant/index.html)。 |

## 功能

| 能力 | 说明 | 触发方式 |
|------|------|---------|
| 划词翻译 | 选中任意文本即时翻译 | `⌥D` / 菜单 / PopClip |
| 查词 | 单词释义、音标、词性 | `⌥E` / 菜单 / PopClip |
| 截图翻译 | 框选屏幕区域 OCR 后翻译 | `⌥S` / 菜单 |
| 输入翻译 | 弹窗输入文本翻译 | `⌥A` / 菜单 |
| 多引擎聚合 | Google / DeepL / OpenAI / 腾讯 / 百度 / 有道 / 彩云 / Microsoft / 10+ LLM / 插件 | 自动 |
| 术语表 | 专业名词、产品名、缩写固定译法 | 设置 → 术语 |
| 插件系统 | JS 插件接入任意 LLM/词典（沙箱 + 网络白名单） | `~/Library/Application Support/Parrot/Plugins` |
| 历史 / 收藏 | 自动记录、收藏、检索 | 悬浮窗 ⭐️ |
| TTS 朗读 | 原文 / 译文语音合成 | 悬浮窗 🔊 |
| PopClip | 选中后从 PopClip 调起 Parrot | `examples/Parrot.popclipext` |
| URL Scheme | `parrot://translate?text=` / `parrot://lookup?text=` | 外部集成 |

## 引擎与密钥

- **Google Translation LLM**：使用官方 Cloud Translation Basic API，需配置 Google Cloud Project ID 与 API Key。
- **DeepL / OpenAI / 腾讯 / 百度 / 有道 / 彩云 / Microsoft**：Swift 内置，需 API Key。
- **LLM 全家桶**：DeepSeek、Gemini、Groq、Ollama、通义、豆包、Kimi、智谱、硅基流动 — Swift 内置。
- **系统翻译**：macOS 15+（开发中）。
- **术语表**：在「设置 → 术语」维护专业名词，详见 [docs/terminology.md](./docs/terminology.md)。

完整引擎清单与密钥申请链接见 **[docs/engines.md](./docs/engines.md)**。

API Key 在「设置 → 密钥」录入，默认存储于 `~/Library/Application Support/Parrot/secrets.json`（文件权限 `0600`）。亦支持环境变量（如 `OPENAI_API_KEY`、`DEEPSEEK_API_KEY`），且环境变量优先于本地配置。

## 第三方服务合规说明

Parrot 集成多家翻译 / OCR / TTS 服务，使用时须遵守各服务商条款：

| 服务 | 说明 |
|------|------|
| **Google Translation LLM** | 通过正式的 [Google Cloud Translation API](https://cloud.google.com/translate) 调用 `general/translation-llm`；需自行启用 API、配置 `Project ID:API Key`，用量与费用由 Google Cloud 计费。 |
| **其他云引擎** | DeepL、OpenAI、腾讯、百度等需用户自行申请 API Key，用量与费用由各平台计费规则决定。 |
| **插件** | 第三方 JS 插件的网络请求受 manifest 白名单约束，插件作者对其行为负责。 |

Parrot 本身为 AGPL-3.0 开源软件，**不**提供任何翻译代理或免费额度；所有云服务能力均由用户直连第三方。

## 构建与测试

```bash
# 需安装 Xcode（CommandLineTools 不含 SwiftUI/AppKit GUI 构建）
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer

swift build                 # 编译
swift test                  # 单元测试（Swift Testing）
bash scripts/build-app.sh   # 产出 build/Parrot.app（菜单栏常驻）
```

**macOS**：Swift 6 + SwiftUI + AppKit，macOS 13+。  
**iOS**：SwiftUI，iOS 17+；`xcodegen generate` 后打开 `Parrot.xcodeproj` 运行 `ParrotiOS`。

CI 在每次 push 时自动 `swift build`、`swift test` 并打包 `Parrot.app` artifact（见 [Actions](https://github.com/korbinjoe/parrot/actions)）。

## 架构

```
Interaction（快捷键/菜单/PopClip/URL）
  → Application/Orchestration（AppState / TranslationCoordinator）
  → Engine Abstraction（TranslationProvider 协议 + Registry）
  → Platform Services（Vision OCR / AX / SecretStore / AVSpeech）
```

- `ParrotCore` — 引擎抽象、并发聚合（失败隔离 + 超时）、离线语言检测、历史库（actor + JSON 持久化）、本地密钥存储。
- `ParrotEngines` — Google / DeepL / OpenAI-compat LLM / 国内机翻 / Mock / Vision OCR。
- `ParrotPlugins` — JavaScriptCore 沙箱插件运行时（`$http` 主机白名单、`$option`/`$log` 注入）。
- `ParrotApp` — 菜单栏 App、全局快捷键、悬浮窗、截图 OCR、设置面板、TTS。
- `ParrotSocial` / `ParrotPlatformiOS` — iOS 社交助手与平台适配。

详见 `openspec/changes/macos-translator/design.md`。

## 插件开发

见 [docs/plugin-development.md](./docs/plugin-development.md)。示例：`examples/echo.parrotplugin`、`examples/openai.parrotplugin`。

## 贡献与安全

- 贡献流程：[CONTRIBUTING.md](./CONTRIBUTING.md)
- 安全策略：[SECURITY.md](./SECURITY.md)

## License

[AGPL-3.0](./LICENSE)
