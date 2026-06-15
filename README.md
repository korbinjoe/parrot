# OpenBob

开源的 macOS 翻译 + OCR 工具，复刻 [Bob](https://bobtranslate.com/) 的核心能力：划词翻译、截图 OCR 翻译、输入翻译、查词、多引擎聚合对比、可扩展插件系统（接入任意 LLM）、历史/收藏、TTS。完全免费、无次数限制。

> 规划与设计见 `openspec/changes/macos-translator-bob-clone/`。

## 功能

| 能力 | 说明 | 触发方式 |
|------|------|---------|
| 划词翻译 | 选中任意文本即时翻译 | `⌥D` / 菜单 / PopClip |
| 查词 | 单词释义、音标、词性 | `⌥E` / 菜单 / PopClip |
| 截图翻译 | 框选屏幕区域 OCR 后翻译 | `⌥S` / 菜单 |
| 输入翻译 | 弹窗输入文本翻译 | `⌥A` / 菜单 |
| 多引擎聚合 | Google / DeepL / OpenAI / 插件并发对比 | 自动 |
| 插件系统 | JS 插件接入任意 LLM/词典（沙箱 + 网络白名单） | `~/Library/Application Support/OpenBob/Plugins` |
| 历史 / 收藏 | 自动记录、收藏、检索 | 悬浮窗 ⭐️ |
| TTS 朗读 | 原文 / 译文语音合成 | 悬浮窗 🔊 |
| PopClip | 选中后从 PopClip 调起 OpenBob | `examples/OpenBob.popclipext` |
| URL Scheme | `openbob://translate?text=` / `openbob://lookup?text=` | 外部集成 |

## 引擎与密钥

- **Google**：免费 Web 端点，无需 Key，默认开启，开箱即用。
- **DeepL**：需 API Key（免费版以 `:fx` 结尾）。
- **OpenAI**：需 API Key，LLM 翻译/润色。

API Key 在「设置」面板录入，存储于 **macOS 钥匙串**，绝不写入 UserDefaults、历史库或日志。亦支持环境变量 `DEEPL_API_KEY` / `OPENAI_API_KEY` 作为开发期回退。

## 构建与测试

```bash
# 需安装 Xcode（CommandLineTools 不含 SwiftUI/AppKit GUI 构建）
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer

swift build                 # 编译
swift test                  # 单元测试（Swift Testing，24 passing）
bash scripts/build-app.sh   # 产出 build/OpenBob.app（菜单栏常驻）
```

技术栈与最低系统：Swift 6 + SwiftUI + AppKit，macOS 13+。

## 架构

```
Interaction（快捷键/菜单/PopClip/URL）
  → Application/Orchestration（AppState / TranslationCoordinator）
  → Engine Abstraction（TranslationProvider 协议 + Registry）
  → Platform Services（Vision OCR / AX / Keychain / AVSpeech）
```

- `OpenBobCore` — 引擎抽象、并发聚合（失败隔离 + 超时）、离线语言检测、历史库（actor + JSON 持久化）、钥匙串封装。
- `OpenBobEngines` — Google / DeepL / OpenAI / Mock。
- `OpenBobPlugins` — JavaScriptCore 沙箱插件运行时（`$http` 主机白名单、`$option`/`$log` 注入）。
- `OpenBobApp` — 菜单栏 App、全局快捷键、悬浮窗、截图 OCR、设置面板、TTS。

详见 `openspec/changes/macos-translator-bob-clone/design.md`。

## 插件开发

见 [docs/plugin-development.md](./docs/plugin-development.md)。示例：`examples/echo.bobplugin`、`examples/openai.bobplugin`。

## 贡献与安全

- 贡献流程：[CONTRIBUTING.md](./CONTRIBUTING.md)
- 安全策略：[SECURITY.md](./SECURITY.md)

## License

[AGPL-3.0](./LICENSE)
