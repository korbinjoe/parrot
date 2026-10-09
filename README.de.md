# Parrot

[English](./README.md) · [简体中文](./README.zh-CN.md) · [日本語](./README.ja.md) · [Deutsch](./README.de.md) · [Français](./README.fr.md)

Open-Source-Übersetzung und OCR für macOS und iOS: markierten Text übersetzen, Text aus Screenshots erkennen, Wörter nachschlagen, Übersetzungsdienste vergleichen und LLMs über Plugins anbinden.

[Neueste Version herunterladen](https://github.com/korbinjoe/parrot/releases/latest)

<p align="center">
  <img src="docs/screenshots/app-icon.png" alt="Parrot" width="128">
  <img src="docs/screenshots/menubar-icon.png" alt="Parrot" width="64">
</p>

## Plattformen

- **macOS 13 oder neuer**: Menüleisten-App mit globalen Tastenkürzeln und schwebendem Übersetzungsfenster. DMG oder ZIP für Apple silicon unter Releases herunterladen oder `build/Parrot.app` lokal erstellen.
- **iOS 17 oder neuer**: Assistent zum Lesen und Schreiben in sozialen Medien mit Quick Lens OCR. Xcode-Projekt erzeugen und das Schema `ParrotiOS` ausführen. Siehe [interaktiven Prototyp](./docs/mockups/ios-social-assistant/index.html).

## Funktionen

| Funktion | Bedienung |
| --- | --- |
| Markierten Text übersetzen | `⌥D`, Menü oder PopClip |
| Wörter nachschlagen | `⌥E`, Menü oder PopClip |
| Screenshot-OCR und Übersetzung | `⌥S` oder Menü |
| Eingegebenen Text übersetzen | `⌥A` oder Menü |
| Mehrere Dienste vergleichen | Ergebnisse aktivierter Anbieter automatisch zusammenführen |
| Terminologieglossar | Einstellungen → Terminologie; [Anleitung](./docs/terminology.md) |
| Verlauf und Favoriten | Übersetzungen speichern und durchsuchen; ⭐ im Fenster |
| Sprachausgabe | Ausgangstext oder Übersetzung vorlesen; 🔊 im Fenster |
| JavaScript-Plugins | LLMs und Wörterbücher ergänzen; [Entwicklungsanleitung](./docs/plugin-development.md) |
| PopClip-Anbindung | `examples/Parrot.popclipext` installieren |
| URL-Anbindung | `parrot://translate?text=` oder `parrot://lookup?text=` |

## Dienste und Zugangsdaten

Integriert sind unter anderem Google Translation LLM, DeepL, OpenAI, OpenCode Go, Microsoft, Tencent, Baidu, Youdao, Caiyun, DeepSeek, Gemini, Groq, Ollama, Qwen, Doubao, Kimi, GLM und SiliconFlow. Die vollständige Liste und Formate der Zugangsdaten stehen in der [Anleitung zu Diensten und API-Schlüsseln](./docs/engines.md).

API-Schlüssel unter Einstellungen → Schlüssel eingeben. Lokale Zugangsdaten werden in `~/Library/Application Support/Parrot/secrets.json` mit Dateirechten `0600` gespeichert. Umgebungsvariablen wie `OPENAI_API_KEY` und `DEEPSEEK_API_KEY` haben Vorrang vor der lokalen Konfiguration.

Google Translation LLM nutzt die offizielle Cloud Translation API mit dem Modell `general/translation-llm`; als Zugangsdaten dient `Project ID:API Key`. Für Cloud-Dienste sind eigene Zugangsdaten erforderlich; Abrechnung und Nutzungsbedingungen richten sich nach dem Anbieter. Parrot verbindet sich direkt mit den Anbietern und stellt weder einen Übersetzungsproxy noch ein kostenloses Cloud-Kontingent bereit. Netzwerkzugriffe von Plugins sind auf die im Manifest erlaubten Hosts beschränkt.

## Build und Tests

Für den macOS-GUI-Build wird die vollständige Xcode-Installation benötigt, für die iOS-Projekterzeugung XcodeGen. Die macOS-App verwendet Swift, SwiftUI und AppKit; die iOS-App SwiftUI.

```bash
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
swift build
swift test
bash scripts/build-app.sh

# iOS
xcodegen generate
open Parrot.xcodeproj
```

Das Build-Skript erzeugt `build/Parrot.app`. Vor dem Einreichen von Änderungen `swift build` und `swift test` ausführen.

## Architektur

Interaktion (Tastenkürzel, Menüs, PopClip, URLs) → Anwendungssteuerung (`AppState`, `TranslationCoordinator`) → Anbieterabstraktion (`TranslationProvider`, Registry) → Plattformdienste (Vision OCR, Bedienungshilfen, Zugangsdaten, Sprache).

- `ParrotCore`: Anbieterprotokolle, parallele Ergebnisaggregation, Spracherkennung, Verlauf und lokale Zugangsdaten.
- `ParrotEngines`: integrierte Übersetzungsanbieter und Vision OCR.
- `ParrotPlugins`: JavaScriptCore-Laufzeit mit erlaubten Hosts sowie `$http`, `$option` und `$log`. Plugins liegen in `~/Library/Application Support/Parrot/Plugins`.
- `ParrotApp`: macOS-Menüleisten-App, Tastenkürzel, Übersetzungsfenster, Einstellungen und Sprachausgabe.
- `ParrotSocial` / `ParrotPlatformiOS`: Logik des Social-Media-Assistenten und iOS-Adapter.

Siehe [Entwurfsdokument](./openspec/changes/macos-translator/design.md). Beispiel-Plugins: `examples/echo.parrotplugin` und `examples/openai.parrotplugin`.

## Mitwirken und Sicherheit

Siehe [CONTRIBUTING.md](./CONTRIBUTING.md) und [SECURITY.md](./SECURITY.md). Weiterführende Dokumentation ist teilweise auf Chinesisch.

## Lizenz

[AGPL-3.0](./LICENSE)
