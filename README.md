# Parrot

[English](./README.md) · [简体中文](./README.zh-CN.md) · [日本語](./README.ja.md) · [Deutsch](./README.de.md) · [Français](./README.fr.md)

Open-source translation and OCR for macOS and iOS: translate selected text, capture text from screenshots, look up words, compare translation engines, and connect LLMs through plugins.

[Download the latest release](https://github.com/korbinjoe/parrot/releases/latest)

<p align="center">
  <img src="docs/screenshots/app-icon.png" alt="Parrot" width="128">
  <img src="docs/screenshots/menubar-icon.png" alt="Parrot" width="64">
</p>

## Platforms

- **macOS 13+**: menu bar app with global shortcuts and a floating translation panel. Download the Apple silicon DMG or ZIP from Releases, or build `build/Parrot.app` locally.
- **iOS 17+**: social reading and writing assistant with Quick Lens OCR. Generate the Xcode project and run the `ParrotiOS` scheme. See the [interactive prototype](./docs/mockups/ios-social-assistant/index.html).

## Features

| Feature | How to use it |
| --- | --- |
| Translate selected text | `⌥D`, menu, or PopClip |
| Dictionary lookup | `⌥E`, menu, or PopClip |
| Screenshot OCR and translation | `⌥S` or menu |
| Translate typed text | `⌥A` or menu |
| Compare multiple engines | Automatic aggregation of enabled providers |
| Terminology glossary | Settings → Terminology; [guide](./docs/terminology.md) |
| History and favorites | Save and search translations; ⭐ in the panel |
| Text-to-speech | Read source text or translations aloud; 🔊 in the panel |
| JavaScript plugins | Extend LLM and dictionary support; [development guide](./docs/plugin-development.md) |
| PopClip integration | Install `examples/Parrot.popclipext` |
| URL integration | `parrot://translate?text=` or `parrot://lookup?text=` |

## Engines and credentials

Built-in providers include Google Translation LLM, DeepL, OpenAI, OpenCode Go, Microsoft, Tencent, Baidu, Youdao, Caiyun, DeepSeek, Gemini, Groq, Ollama, Qwen, Doubao, Kimi, GLM, and SiliconFlow. See the [engine and API key guide](./docs/engines.md) for the full list and credential formats.

Enter API keys in Settings → Keys. Local credentials are stored in `~/Library/Application Support/Parrot/secrets.json` with file permissions `0600`. Environment variables such as `OPENAI_API_KEY` and `DEEPSEEK_API_KEY` take precedence over local configuration.

Google Translation LLM uses the official Cloud Translation API and the `general/translation-llm` model; configure `Project ID:API Key`. Cloud services require your own credentials and bill according to the provider’s terms. Parrot connects directly to providers and supplies no translation proxy or free cloud quota. Plugin network access is restricted by the manifest host allowlist.

## Build and test

Install full Xcode for the macOS GUI build and XcodeGen for iOS project generation. The macOS app uses Swift, SwiftUI, and AppKit; the iOS app uses SwiftUI.

```bash
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
swift build
swift test
bash scripts/build-app.sh

# iOS
xcodegen generate
open Parrot.xcodeproj
```

The build script produces `build/Parrot.app`. Run `swift build` and `swift test` before submitting changes.

## Architecture

Interaction (shortcuts, menus, PopClip, URLs) → application orchestration (`AppState`, `TranslationCoordinator`) → provider abstraction (`TranslationProvider`, registry) → platform services (Vision OCR, accessibility, credentials, speech).

- `ParrotCore`: provider protocols, concurrent aggregation, language detection, history, and local credentials.
- `ParrotEngines`: built-in translation providers and Vision OCR.
- `ParrotPlugins`: JavaScriptCore plugin runtime with host allowlists and `$http`, `$option`, and `$log` APIs. Plugins live in `~/Library/Application Support/Parrot/Plugins`.
- `ParrotApp`: macOS menu bar app, shortcuts, floating panel, settings, and speech.
- `ParrotSocial` / `ParrotPlatformiOS`: social assistant logic and iOS adapters.

See the [design document](./openspec/changes/macos-translator/design.md). Example plugins: `examples/echo.parrotplugin` and `examples/openai.parrotplugin`.

## Contributing and security

See [CONTRIBUTING.md](./CONTRIBUTING.md) and [SECURITY.md](./SECURITY.md). Supporting documentation may be in Chinese.

## License

[AGPL-3.0](./LICENSE)
