# Parrot

[English](./README.md) · [简体中文](./README.zh-CN.md) · [日本語](./README.ja.md) · [Deutsch](./README.de.md) · [Français](./README.fr.md)

Outil libre de traduction et d’OCR pour macOS et iOS : traduction du texte sélectionné, reconnaissance de texte dans les captures d’écran, recherche de mots, comparaison de moteurs et intégration de LLM via des plugins.

[Télécharger la dernière version](https://github.com/korbinjoe/parrot/releases/latest)

<p align="center">
  <img src="docs/screenshots/app-icon.png" alt="Parrot" width="128">
  <img src="docs/screenshots/menubar-icon.png" alt="Parrot" width="64">
</p>

## Plateformes

- **macOS 13 et versions ultérieures** : application dans la barre de menus, raccourcis globaux et panneau de traduction flottant. Téléchargez le DMG ou le ZIP pour Apple silicon depuis Releases, ou compilez `build/Parrot.app` localement.
- **iOS 17 et versions ultérieures** : assistant de lecture et de rédaction pour les réseaux sociaux, avec Quick Lens OCR. Générez le projet Xcode et exécutez le schéma `ParrotiOS`. Consultez le [prototype interactif](./docs/mockups/ios-social-assistant/index.html).

## Fonctionnalités

| Fonctionnalité | Utilisation |
| --- | --- |
| Traduction du texte sélectionné | `⌥D`, menu ou PopClip |
| Recherche dans le dictionnaire | `⌥E`, menu ou PopClip |
| OCR et traduction de captures d’écran | `⌥S` ou menu |
| Traduction du texte saisi | `⌥A` ou menu |
| Comparaison de plusieurs moteurs | Agrégation automatique des résultats des fournisseurs activés |
| Glossaire terminologique | Réglages → Terminologie ; [guide](./docs/terminology.md) |
| Historique et favoris | Enregistrer et rechercher des traductions ; ⭐ dans le panneau |
| Synthèse vocale | Lire le texte source ou la traduction ; 🔊 dans le panneau |
| Plugins JavaScript | Ajouter des LLM et dictionnaires ; [guide de développement](./docs/plugin-development.md) |
| Intégration PopClip | Installer `examples/Parrot.popclipext` |
| Intégration par URL | `parrot://translate?text=` ou `parrot://lookup?text=` |

## Moteurs et identifiants

Les fournisseurs intégrés comprennent Google Translation LLM, DeepL, OpenAI, OpenCode Go, Microsoft, Tencent, Baidu, Youdao, Caiyun, DeepSeek, Gemini, Groq, Ollama, Qwen, Doubao, Kimi, GLM et SiliconFlow. Consultez le [guide des moteurs et des clés API](./docs/engines.md) pour la liste complète et les formats des identifiants.

Saisissez les clés API dans Réglages → Clés. Les identifiants locaux sont stockés dans `~/Library/Application Support/Parrot/secrets.json` avec les permissions `0600`. Les variables d’environnement telles que `OPENAI_API_KEY` et `DEEPSEEK_API_KEY` sont prioritaires sur la configuration locale.

Google Translation LLM utilise l’API officielle Cloud Translation et le modèle `general/translation-llm` ; configurez `Project ID:API Key`. Les services cloud nécessitent vos propres identifiants et appliquent leurs conditions et tarifs. Parrot se connecte directement aux fournisseurs et ne fournit ni proxy de traduction ni quota cloud gratuit. Les accès réseau des plugins sont limités aux hôtes autorisés dans leur manifeste.

## Compilation et tests

Installez la version complète de Xcode pour compiler l’interface macOS et XcodeGen pour générer le projet iOS. L’application macOS utilise Swift, SwiftUI et AppKit ; l’application iOS utilise SwiftUI.

```bash
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
swift build
swift test
bash scripts/build-app.sh

# iOS
xcodegen generate
open Parrot.xcodeproj
```

Le script produit `build/Parrot.app`. Exécutez `swift build` et `swift test` avant de soumettre des modifications.

## Architecture

Interaction (raccourcis, menus, PopClip, URL) → orchestration de l’application (`AppState`, `TranslationCoordinator`) → abstraction des fournisseurs (`TranslationProvider`, registre) → services de plateforme (Vision OCR, accessibilité, identifiants, voix).

- `ParrotCore` : protocoles des fournisseurs, agrégation concurrente, détection de langue, historique et identifiants locaux.
- `ParrotEngines` : fournisseurs de traduction intégrés et Vision OCR.
- `ParrotPlugins` : environnement JavaScriptCore avec liste d’hôtes autorisés et API `$http`, `$option` et `$log`. Les plugins se trouvent dans `~/Library/Application Support/Parrot/Plugins`.
- `ParrotApp` : application macOS dans la barre de menus, raccourcis, panneau flottant, réglages et synthèse vocale.
- `ParrotSocial` / `ParrotPlatformiOS` : logique de l’assistant pour les réseaux sociaux et adaptateurs iOS.

Consultez le [document de conception](./openspec/changes/macos-translator/design.md). Exemples de plugins : `examples/echo.parrotplugin` et `examples/openai.parrotplugin`.

## Contribution et sécurité

Consultez [CONTRIBUTING.md](./CONTRIBUTING.md) et [SECURITY.md](./SECURITY.md). Certains documents complémentaires sont en chinois.

## Licence

[AGPL-3.0](./LICENSE)
