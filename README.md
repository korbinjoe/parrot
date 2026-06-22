# Parrot

开源的 macOS 翻译 + OCR 工具，对标主流商业翻译工具的核心能力：划词翻译、截图 OCR 翻译、输入翻译、查词、多引擎聚合对比、可扩展插件系统（接入任意 LLM）、历史/收藏、TTS。完全免费、无次数限制。

> 规划与设计见 `openspec/changes/macos-translator/`。

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

## 从 Bob 迁移

Parrot 与 [Bob 服务矩阵](https://bobtranslate.com/guide/advance/service.html) 对标，完整对照见 **[docs/bob-service-matrix.md](./docs/bob-service-matrix.md)**（含各引擎密钥申请链接）。

- **文本翻译**：设置 → 引擎 中开启对应内置引擎，在「密钥」页填入 API Key（腾讯/百度/有道格式为 `Id:Secret`）。
- **LLM**：OpenAI、DeepSeek、Gemini、Groq、Ollama、通义、豆包、Kimi、智谱、硅基流动均已 Swift 内置，无需安装插件。
- **OCR**：默认 Apple Vision（离线）；云端 OCR（百度/腾讯）后续版本提供。
- Bob 零配置免费 LLM 代理（智谱 Flash、硅基免费 tier）Parrot 不提供，请自备官方 Key。

## 引擎与密钥

- **Google**：免费 Web 端点，无需 Key，默认开启。
- **DeepL / OpenAI / 腾讯 / 百度 / 有道 / 彩云 / Microsoft**：Swift 内置，需 API Key。
- **LLM 全家桶**：DeepSeek、Gemini、Groq、Ollama、通义、豆包、Kimi、智谱、硅基流动 — Swift 内置。
- **系统翻译**：macOS 15+（开发中）。
- **术语表**：在「设置 → 术语」维护专业名词，详见 [docs/terminology.md](./docs/terminology.md)。

API Key 在「设置 → 密钥」录入，默认存储于 `~/Library/Application Support/Parrot/secrets.json`（文件权限 `0600`）。亦支持环境变量（如 `OPENAI_API_KEY`、`DEEPSEEK_API_KEY`），且环境变量优先于本地配置。

## 构建与测试

```bash
# 需安装 Xcode（CommandLineTools 不含 SwiftUI/AppKit GUI 构建）
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer

swift build                 # 编译
swift test                  # 单元测试（Swift Testing）
bash scripts/build-app.sh   # 产出 build/Parrot.app（菜单栏常驻）
```

技术栈与最低系统：Swift 6 + SwiftUI + AppKit，macOS 13+。

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

详见 `openspec/changes/macos-translator/design.md`。

## 插件开发

见 [docs/plugin-development.md](./docs/plugin-development.md)。示例：`examples/echo.parrotplugin`、`examples/openai.parrotplugin`。

## 贡献与安全

- 贡献流程：[CONTRIBUTING.md](./CONTRIBUTING.md)
- 安全策略：[SECURITY.md](./SECURITY.md)

## License

[AGPL-3.0](./LICENSE)
