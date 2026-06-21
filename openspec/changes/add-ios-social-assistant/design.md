# Design: Parrot iOS Social Assistant

This design translates the high-fidelity prototype in `docs/mockups/ios-social-assistant/index.html` into an implementation-ready iOS architecture.

## 1. Product Model

Parrot iOS has two primary jobs:

- **Understand**: explain what a post/comment actually means in context.
- **Express**: convert the user's rough thought into native, platform-appropriate English.

The central object is a social text session, not a one-off translation request.

```swift
enum SocialMode: String, Codable, Sendable {
    case understand
    case express
    case ocr
}

enum SourceOrigin: String, Codable, Sendable {
    case shareExtension
    case clipboard
    case screenshot
    case photoLibrary
    case manualInput
    case history
    case keyboard
    case shortcut
}

enum PlatformPreset: String, Codable, Sendable {
    case general
    case x
    case reddit
    case linkedin
    case email
}

enum TonePreset: String, Codable, Sendable {
    case natural
    case friendly
    case firm
    case redditStyle
    case xShort
    case politeDisagreement
}

struct SocialTextSession: Identifiable, Codable, Sendable {
    var id: UUID
    var mode: SocialMode
    var origin: SourceOrigin
    var platform: PlatformPreset
    var sourceDraft: String
    var contextText: String?
    var userIntentDraft: String
    var selectedTone: TonePreset
    var understand: UnderstandResult?
    var express: ExpressResult?
    var createdAt: Date
    var updatedAt: Date
}

struct UnderstandResult: Codable, Sendable {
    var meaningSummary: String
    var toneTags: [String]
    var phraseExplanations: [PhraseExplanation]
    var fullTranslation: String?
    var confidenceNote: String?
}

struct PhraseExplanation: Codable, Sendable {
    var phrase: String
    var explanation: String
}

struct ExpressResult: Codable, Sendable {
    var candidates: [ReplyCandidate]
}

struct ReplyCandidate: Identifiable, Codable, Sendable {
    var id: UUID
    var title: String
    var text: String
    var tone: TonePreset
}
```

Rules:

- `sourceDraft` is always editable.
- `userIntentDraft` is never cleared after generation.
- Understand sessions can open Express mode while preserving `sourceDraft` as reply context.
- History reopens into `SocialTextSession`, not a static read-only record.

## 2. Repository and Target Structure

### 2.1 Repository Decision

Use one repository for macOS and iOS. The correct boundary is target/module isolation, not repository separation.

Rationale:

- Shared translation and social-language capabilities need one versioned source of truth.
- Engine bug fixes and prompt/schema changes should be tested once and consumed by both apps.
- OpenSpec artifacts, UX docs, high-fidelity prototypes, and fixtures should stay together.
- Future history sync or cross-device features will be easier if data models do not diverge.

The repository structure MUST prevent platform bleed. "Same repo" does not mean shared UI or shared platform services.

The current package is macOS-only:

```swift
platforms: [.macOS(.v13)]
```

The change should evolve the codebase toward:

```text
parrot/
  Package.swift
  Parrot.xcworkspace              # created when app/extension signing is needed
  docs/
  openspec/
  Tests/

Sources/
  ParrotCore/                     # platform-neutral models, coordinator, registry
    Models.swift
    TranslationCoordinator.swift
    ProviderRegistry.swift
    LanguageDetector.swift
    HistoryModels.swift

  ParrotSocial/                   # social reading/writing session layer
    SocialTextSession.swift
    UnderstandResult.swift
    ExpressResult.swift
    SocialPromptBuilder.swift
    SocialResultParser.swift
    TonePreset.swift
    PlatformPreset.swift

  ParrotTextEngines/              # platform-safe text/LLM engines
    GoogleEngine.swift
    DeepLEngine.swift
    OpenAICompatEngine.swift
    GeminiEngine.swift
    MicrosoftEngine.swift

  ParrotPlatform/                 # protocols only, no AppKit/UIKit/SwiftUI
    SecretStoreProtocol.swift
    SessionStoreProtocol.swift
    OCRServiceProtocol.swift
    ClipboardServiceProtocol.swift
    SharedHandoffStore.swift

  ParrotPlatformMac/              # macOS adapters
    MacSecretStore.swift
    MacOCRService.swift
    SelectionCapture.swift
    HotKey.swift
    FloatingPanelPlacement.swift
    MacPermissions.swift

  ParrotPlatformiOS/              # iOS adapters
    IOSKeychainSecretStore.swift
    AppGroupSessionStore.swift
    AppGroupHandoffStore.swift
    IOSOCRService.swift
    IOSClipboardService.swift

  ParrotPlugins/                  # macOS plugin runtime; iOS MVP does not depend on it

Apps/
  macOS/
    ParrotMac/
      ParrotMacApp.swift
      AppDelegate.swift
      AppState.swift
      FloatingPanel.swift
      ResultView.swift
      SettingsWindow.swift
      HistoryWindow.swift
      MenuBarPopover.swift
      Resources/

  iOS/
    ParrotiOS/
      ParrotiOSApp.swift
      IOSAppState.swift
      TodayView.swift
      UnderstandWorkspaceView.swift
      ExpressWorkspaceView.swift
      OCRCleanupView.swift
      HistoryView.swift
      SettingsView.swift
      Resources/

    ParrotShareExtension/
      ShareViewController.swift
      ShareHandoffWriter.swift
      Info.plist

    ParrotKeyboardExtension/      # P2 optional
      KeyboardViewController.swift
      KeyboardCommandRow.swift
      Info.plist
```

Recommended SPM/platform update:

```swift
platforms: [
    .macOS(.v13),
    .iOS(.v17)
]
```

The iOS app may eventually need an `.xcodeproj` or generated Xcode project for app extensions, signing, entitlements, and App Groups. The package should still keep reusable logic testable through SPM.

### 2.2 Dependency Graph

Allowed dependencies:

```text
Apps/macOS/ParrotMac
  -> ParrotCore
  -> ParrotTextEngines
  -> ParrotPlatform
  -> ParrotPlatformMac
  -> ParrotPlugins

Apps/iOS/ParrotiOS
  -> ParrotCore
  -> ParrotSocial
  -> ParrotTextEngines
  -> ParrotPlatform
  -> ParrotPlatformiOS

Apps/iOS/ParrotShareExtension
  -> ParrotCore
  -> ParrotSocial
  -> ParrotPlatform
  -> ParrotPlatformiOS

Apps/iOS/ParrotKeyboardExtension
  -> ParrotCore
  -> ParrotSocial
  -> ParrotPlatform
  -> ParrotPlatformiOS
```

Forbidden dependencies:

```text
ParrotiOS -> ParrotApp / ParrotMac
ParrotShareExtension -> ParrotApp / ParrotPlatformMac / ParrotPlugins
ParrotCore -> AppKit / UIKit / SwiftUI
ParrotSocial -> AppKit / UIKit / SwiftUI
ParrotPlatform -> AppKit / UIKit / SwiftUI
ParrotApp / ParrotMac -> ParrotiOS / ParrotPlatformiOS
```

Compatibility rules:

- `ParrotApp` MUST remain macOS-only and MUST NOT import `ParrotiOS`, `ParrotShareExtension`, or `ParrotPlatformiOS`.
- `ParrotiOS` MUST NOT import `ParrotApp`, `FloatingPanel`, `SelectionCapture`, `HotKey`, `WindowPlacement`, or any AppKit/Carbon/Accessibility implementation.
- `ParrotPlatform` MUST contain protocols and platform-neutral models only.
- `ParrotPlatformMac` and `ParrotPlatformiOS` own platform APIs and can depend on `ParrotPlatform`, never the other way around.
- iOS app and extension bundle targets should be owned by an Xcode project/workspace because app extensions require signing, entitlements, and App Groups. SPM should remain the reusable library/test layer.

Current compatibility note:

- `ParrotCore` is close to reusable, but secret storage is currently file-backed and should be abstracted before iOS uses it.
- Current `ParrotEngines` contains AppKit-based OCR image encoding in several providers. iOS must not depend on that target directly until those files are split, gated with conditional compilation, or moved to `ParrotPlatformMac`/macOS-only engine targets.
- `ParrotPlugins` should remain out of iOS MVP. User-installed JavaScript plugins create App Store review, extension safety, and sandboxing questions that are unrelated to the social assistant MVP.

### 2.3 Migration Strategy

Do not start by moving the existing macOS app. The safe path is staged:

1. Add `ParrotSocial`, `ParrotPlatform`, and `ParrotPlatformiOS` as new targets.
2. Keep existing `Sources/ParrotApp` intact while iOS MVP is built.
3. Split platform-safe text engines from OCR/AppKit-dependent code before the iOS target imports translation engines.
4. Add `Apps/iOS/ParrotiOS` and `Apps/iOS/ParrotShareExtension`.
5. After iOS MVP is stable, optionally move `Sources/ParrotApp` into `Apps/macOS/ParrotMac` and move macOS platform adapters into `ParrotPlatformMac`.

This avoids turning a product expansion into a large macOS app relocation risk.

## 3. Module Responsibilities

### ParrotSocial

New cross-platform module.

Responsibilities:

- Own `SocialTextSession` and result models.
- Build social prompt requests.
- Parse model responses into structured `UnderstandResult` and `ExpressResult`.
- Provide deterministic fallback parsing for malformed LLM responses.
- Keep UI-independent business rules: tone presets, platform presets, refinement actions.

Key services:

```swift
protocol SocialUnderstandingService {
    func understand(session: SocialTextSession) async throws -> UnderstandResult
}

protocol SocialExpressionService {
    func generateReplies(session: SocialTextSession) async throws -> ExpressResult
    func refine(candidate: ReplyCandidate, action: RefinementAction, session: SocialTextSession) async throws -> ReplyCandidate
}
```

Implementation should call existing `TranslationProvider`/LLM providers through adapters instead of creating a parallel networking stack.

### ParrotPlatform

New cross-platform protocol module.

Responsibilities:

- Abstract secret storage.
- Abstract history/session persistence.
- Abstract platform OCR entry points.
- Provide App Group container resolution on iOS.

Protocols:

```swift
protocol SecretStoreProtocol: Sendable {
    func set(_ value: String, account: String) async throws
    func get(account: String) async throws -> String?
    func remove(account: String) async throws
}

protocol SocialSessionStore: Sendable {
    func save(_ session: SocialTextSession) async throws
    func recent(limit: Int) async throws -> [SocialTextSession]
    func search(_ query: String) async throws -> [SocialTextSession]
    func delete(_ id: UUID) async throws
}

protocol SharedHandoffStore: Sendable {
    func write(_ handoff: ShareHandoff) async throws
    func consumeLatest() async throws -> ShareHandoff?
}
```

iOS implementations:

- `IOSKeychainSecretStore`
- `AppGroupSocialSessionStore`
- `AppGroupHandoffStore`

macOS can keep existing file-backed history/secrets until separately migrated, but the existing macOS API surface should be wrapped behind adapters so future shared services do not call `SecretStore` directly.

### ParrotPlatformMac

New macOS platform implementation module, or a staged refactor inside existing `ParrotApp` if a separate target creates too much churn.

Responsibilities:

- Existing hotkey, Accessibility, pasteboard, NSPanel, AppKit window placement, and macOS permission flows.
- Existing file-backed `SecretStore` adapter.
- Existing macOS OCR capture path.

This module is optional for MVP if macOS code is not touched, but it is the long-term home for platform code currently mixed into `ParrotApp`.

### ParrotPlatformiOS

New iOS platform implementation module.

Responsibilities:

- iOS Keychain.
- App Group container access.
- Share Extension handoff.
- iOS clipboard foreground reads.
- iOS OCR/image import adapters.

This module MUST be extension-safe where used by `ParrotShareExtension`.

### ParrotiOS

New iOS app target.

Main screens:

- `TodayView`
- `UnderstandWorkspaceView`
- `ExpressWorkspaceView`
- `OCRCleanupView`
- `HistoryView`
- `EngineSettingsView`
- `PrivacySettingsView`

State object:

```swift
@MainActor
final class IOSAppState: ObservableObject {
    @Published var activeSession: SocialTextSession?
    @Published var recentSessions: [SocialTextSession] = []
    @Published var isProcessing: Bool = false
    @Published var errorNotice: SocialNotice?

    func open(_ handoff: ShareHandoff) async
    func understandActiveSession() async
    func generateReplies() async
    func refine(_ candidate: ReplyCandidate, action: RefinementAction) async
    func copy(_ text: String)
}
```

UI should follow the prototype:

- Quick Peek-style compact sheet for shared text.
- Understand/Express segmented mode.
- Meaning card before full translation.
- Tone chips and phrase cards.
- Reply candidate cards with Copy and Refine actions.
- OCR cleanup actions before analysis.

### ParrotShareExtension

MVP external entry point.

Responsibilities:

- Accept plain text.
- Accept URLs and best-effort title/body metadata when available.
- Accept image attachments and persist them for OCR handoff.
- Create `ShareHandoff` in App Group storage.
- Open the containing app when full processing is needed.

Extension-safe rule:

- Do minimal parsing/persistence in the extension.
- Avoid long-running provider calls inside the extension unless latency is proven safe.
- Never access app-only singletons or unavailable APIs from the extension.

### ParrotKeyboardExtension

P2 optional target, not MVP.

Responsibilities:

- Provide command-row writing actions: Native, Shorter, Kinder, Sharper, To English.
- Show a single best candidate plus swipe variants.
- Insert generated text only after explicit user action.

Keyboard implementation must not be a blocker for the MVP social assistant.

## 4. Entry Flows

### Share Text to Understand

```text
X/Reddit share
  -> ParrotShareExtension extracts text/URL/image
  -> AppGroupHandoffStore writes ShareHandoff
  -> ParrotiOS opens or foregrounds
  -> IOSAppState creates SocialTextSession(mode: .understand)
  -> UnderstandWorkspaceView shows sourceDraft
  -> SocialUnderstandingService produces structured result
```

### Understand to Reply

```text
User taps Reply
  -> same SocialTextSession switches to .express
  -> contextText = sourceDraft
  -> intent composer is focused
  -> generate candidates
  -> copy candidate
  -> user returns to original social app and pastes
```

### Screenshot OCR

```text
Screenshot shared/imported
  -> image stored in App Group temp directory
  -> OCR service recognizes text
  -> OCRCleanupView displays editable recognizedDraft
  -> user removes usernames/timestamps/broken lines
  -> Understand or Express continues from cleaned text
```

### Clipboard Foreground Action

```text
User opens Parrot
  -> app checks clipboard only while foregrounded
  -> if text exists, TodayView shows "Explain copied text"
  -> user taps
  -> SocialTextSession(origin: .clipboard)
```

No background clipboard monitoring is allowed.

## 5. Prompt Contracts

### Understand Prompt Output

The LLM response should be requested as JSON:

```json
{
  "meaningSummary": "string",
  "toneTags": ["string"],
  "phraseExplanations": [
    { "phrase": "string", "explanation": "string" }
  ],
  "fullTranslation": "string",
  "confidenceNote": "string"
}
```

Prompt guidance:

- Explain implied meaning before literal translation.
- Identify sarcasm, disagreement, jokes, hostility, formality, and platform-specific phrasing.
- Keep summary short and practical.
- Do not invent external context.

### Express Prompt Output

The LLM response should be requested as JSON:

```json
{
  "candidates": [
    { "title": "Natural reply", "text": "string", "tone": "natural" },
    { "title": "Short version", "text": "string", "tone": "xShort" },
    { "title": "Polite disagreement", "text": "string", "tone": "politeDisagreement" }
  ]
}
```

Prompt guidance:

- Preserve the user's stance.
- Do not over-polish into corporate or obviously AI language.
- Match the platform preset.
- Avoid adding facts the user did not provide.

## 6. Data and Privacy

Stored data:

- Session source text.
- Generated meaning/replies.
- Favorite state.
- Platform/origin metadata.
- Created/updated timestamps.

Sensitive data:

- API keys and provider tokens only in iOS Keychain.
- App Group storage may contain shared text and generated replies, but not secrets.

Privacy behavior:

- No background clipboard polling.
- No automatic posting.
- Keyboard extension sends text only after explicit user command.
- Settings must explain what content is sent to enabled providers.

## 7. UI Contract

Implementation should match `docs/mockups/ios-social-assistant/index.html` in behavior rather than pixel-perfect CSS values.

Required surfaces:

1. **Quick Peek**
   - Source preview.
   - Meaning summary card.
   - Tone tags.
   - Phrase explanation cards.
   - Collapsed full translation.
   - Reply/Copy/Save actions.

2. **Reply Composer**
   - Preserved context card.
   - Editable intent composer.
   - Tone preset chips.
   - Candidate reply cards.
   - Refinement actions.

3. **OCR Cleanup**
   - Screenshot thumbnail.
   - Editable OCR text.
   - Cleanup actions.
   - Understand and Reply actions.

4. **Keyboard Command Row** (P2)
   - Native, Shorter, Kinder, Sharper, To English.
   - Result strip.
   - Explicit Insert.

Interaction rules:

- One primary action per surface.
- Generated content updates in place.
- Copy/insert confirmations are inline.
- Errors appear inline and preserve drafts.

## 8. Testing Strategy

Unit tests:

- `SocialTextSession` state transitions.
- Understand/Express JSON parsing.
- Prompt builders.
- Refinement action mapping.
- App Group handoff encode/decode.
- Keychain adapter with injectable test storage.

Integration tests:

- Share handoff from fixture text to active session.
- OCR fixture text cleanup to Understand result.
- Provider timeout preserves session drafts.

UI tests:

- Share-handoff deep link opens Quick Peek.
- Reply button preserves context.
- Tone switch updates candidate cards without clearing draft.
- OCR cleanup actions mutate recognized text.
- History item reopens as editable session.

## 9. Rollout Plan

### MVP

- iOS app target.
- Share Extension.
- Understand/Express workspace.
- Social prompt services.
- History.
- Keychain/App Group storage.
- Screenshot OCR cleanup.

### P1

- App Shortcuts.
- Rich URL metadata extraction.
- Platform style presets.
- Provider configuration recovery flow.

### P2

- Parrot Keyboard.
- Safari Extension.
- User style memory.
- Cross-device sync.
