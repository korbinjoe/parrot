# Design: iOS Quick Lens

## 1. North Star

Quick Lens should make unselectable social text feel selectable: the user takes a screenshot, invokes Parrot, and sees the most likely post/comment translated before doing any cleanup.

## 2. User Flow

### 2.1 Primary Flow

```text
External app
  -> user takes screenshot
  -> user invokes Translate Latest Screenshot
  -> Parrot opens Quick Lens
  -> latest screenshot is fetched
  -> OCR runs
  -> OCR lines are clustered into candidate text blocks
  -> best candidate becomes sourceDraft
  -> Understand runs automatically
  -> user reads result or taps another block
```

The default path MUST NOT require share sheet, manual crop, or source editing.

### 2.2 Fallback Flow

```text
Quick Lens
  -> no recent screenshot / permission missing / OCR failed
  -> inline recovery
  -> share screenshot, import image, manual input, or open settings
```

Fallback actions preserve continuity: the user remains in the same Quick Lens surface or moves into the same editable Understand workspace.

## 3. Data Model

Add Quick Lens metadata without creating a separate translation model.

```swift
public enum SourceOrigin: String, Codable, Sendable, CaseIterable {
    case shareExtension
    case clipboard
    case screenshot
    case latestScreenshot
    case photoLibrary
    case manualInput
    case history
    case keyboard
    case shortcut
}

public struct QuickLensCandidate: Identifiable, Codable, Sendable, Equatable {
    public var id: UUID
    public var text: String
    public var boundingBox: CGRectCodable
    public var lineBoxes: [CGRectCodable]
    public var confidence: Float
    public var score: Double
    public var roleHint: QuickLensRoleHint
    public var isNoise: Bool
}

public enum QuickLensRoleHint: String, Codable, Sendable {
    case primaryBody
    case comment
    case quote
    case username
    case timestamp
    case navigation
    case unknown
}

public struct QuickLensState: Codable, Sendable, Equatable {
    public var imageFileName: String
    public var imagePixelSize: CGSizeCodable
    public var screenshotCreatedAt: Date
    public var candidates: [QuickLensCandidate]
    public var selectedCandidateID: UUID?
    public var ocrConfidence: Float
}
```

`SocialTextSession` should gain optional Quick Lens fields:

```swift
public var quickLens: QuickLensState?
```

Rules:

- `sourceDraft` is always the selected candidate text or the manually edited text.
- `quickLens.selectedCandidateID` points to the block that produced the current `sourceDraft`.
- Editing source text clears only the "selected block is exact source" assumption; it does not discard the screenshot.
- History can reopen the session with the selected source and, if retained, the screenshot overlay.

If adding `QuickLensState` directly to `SocialTextSession` creates too much coupling, store it as a sidecar keyed by session ID in the iOS app layer for MVP. The user-facing requirement is that source/result/history remain editable and rerunnable through `SocialTextSession`.

## 4. Platform Services

### 4.1 LatestScreenshotProvider

Add `LatestScreenshotProvider` to `ParrotPlatformiOS`.

```swift
public protocol LatestScreenshotProviding: Sendable {
    func authorizationStatus() -> PhotoAccessStatus
    func requestAuthorization() async -> PhotoAccessStatus
    func latestScreenshot(maxAge: TimeInterval) async throws -> LatestScreenshotAsset?
}

public struct LatestScreenshotAsset: Sendable, Equatable {
    public var localIdentifier: String
    public var createdAt: Date
    public var pixelWidth: Int
    public var pixelHeight: Int
    public var imageData: Data
    public var uniformTypeIdentifier: String?
}
```

Implementation notes:

- Use PhotoKit in the containing app, not the Share Extension.
- Query screenshots only after explicit user action.
- Prefer `PHAssetCollectionSubtype.smartAlbumScreenshots` when available.
- Filter to assets with `creationDate >= now - maxAge`; default `maxAge = 60`.
- Sort newest first.
- Reject screenshots already consumed in the current Quick Lens launch unless the user retries.
- Copy the selected image into the existing App Group image directory for the active session.
- Add `NSPhotoLibraryUsageDescription` to the iOS app `Info.plist`.

### 4.2 App Shortcuts and Deep Link

Add an App Intent:

```swift
struct TranslateLatestScreenshotIntent: AppIntent {
    static var title: LocalizedStringResource = "Translate Latest Screenshot"
    static var openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult {
        // Write a lightweight launch request if needed, then open app.
        return .result()
    }
}
```

Add a URL route:

```text
parrot://quick-lens
```

`ParrotiOSApp` / `IOSAppState.handle(url:)` should route this URL to `openQuickLensFromLatestScreenshot()`.

Expected external invocation options:

- Shortcuts app action
- Action Button configured to run the shortcut
- Back Tap configured to run the shortcut
- Siri phrase
- Spotlight shortcut suggestion

Do not require those surfaces for automated tests; tests can call the URL route or direct app state method.

## 5. OCR and Block Clustering

### 5.1 OCR Service Changes

Current `IOSOCRService.recognize` returns `OCRResult` with normalized Vision bounding boxes. Quick Lens needs enough geometry to render overlays consistently.

Add or derive:

- source image pixel size,
- normalized candidate bounding boxes,
- display-space conversion helpers,
- line confidence.

Keep Vision OCR in `ParrotPlatformiOS`; keep clustering logic in a platform-neutral module if it only depends on `OCRBlock` and geometry helpers.

### 5.2 OCRTextBlockClusterer

Add `OCRTextBlockClusterer` to `ParrotSocial` or a platform-neutral OCR utility target.

Input:

```swift
struct OCRLine {
    var text: String
    var boundingBox: CGRect
    var confidence: Float
}
```

Output:

```swift
[QuickLensCandidate]
```

Grouping heuristics:

- Sort lines top-to-bottom, left-to-right after converting Vision coordinates into image coordinates.
- Merge lines with similar x-range, close vertical distance, and compatible width.
- Keep quote/repost/comment blocks separate when vertical gaps or indentation change sharply.
- Filter obvious UI noise:
  - status bar time/battery,
  - tab bar labels,
  - isolated counts such as likes/replies when detached from text,
  - usernames/handles/timestamps when they are not followed by body text,
  - one-word buttons.
- Preserve low-confidence text as editable source if it belongs to a high-scoring block.

Ranking heuristics:

- Prefer blocks with more natural-language tokens.
- Prefer central content areas over top status bar and bottom tab bar.
- Prefer multi-line or paragraph-like text over isolated metadata.
- Prefer larger area and higher confidence, capped so giant full-screen noisy blocks do not win.
- Use platform hints when available:
  - X: body text near author row, quoted-tweet body below quote container.
  - Reddit: comment/post text below subreddit/user metadata, ignore vote/sidebar controls.

The ranking does not need to be perfect; it must make correction cheap.

## 6. Quick Lens UI

Add `QuickLensView` under `Apps/iOS/ParrotiOS`.

Recommended layout:

```text
Navigation title / close
Screenshot preview with overlayed candidate blocks
Selected source summary row
Meaning result area
Actions: Reply, Copy meaning, Edit source, Crop
```

States:

- `idle`
- `requestingPhotoPermission`
- `loadingScreenshot`
- `recognizingText`
- `translating`
- `ready`
- `needsPermission`
- `noRecentScreenshot`
- `ocrFailed`

Interaction rules:

- Show screenshot as soon as it is available.
- Show candidate overlays as soon as OCR clustering completes.
- Auto-select the top candidate and start Understand immediately.
- Tapping another candidate updates `sourceDraft`, updates selected overlay, and reruns Understand in place.
- "Edit source" opens the existing editable source composer with the selected text.
- "Crop" opens manual region selection and reruns OCR only for that region.
- Copy/reply/history behavior should reuse existing iOS Understand/Express flows.

Do not make OCR cleanup the first screen. OCR cleanup is a fallback detail.

## 7. App State Integration

Add methods to `IOSAppState`:

```swift
func openQuickLensFromLatestScreenshot() async
func selectQuickLensCandidate(_ candidateID: UUID) async
func retryQuickLensOCR() async
func openQuickLensManualCrop() async
func editQuickLensSource()
```

State handling:

- `selectedTab` may route to a new `quickLens` tab/sheet, or Quick Lens can be a modal route over Understand. Prefer a modal route or full-screen route instead of adding a permanent tab.
- `activeSession` remains the current session used by Understand/Express.
- `isProcessing` should distinguish OCR and translation if UI needs separate progress.
- Errors should be inline and recoverable.

## 8. Privacy and Storage

Rules:

- Quick Lens runs only after explicit invocation.
- No background photo scanning.
- Default screenshot age window: 60 seconds.
- Do not upload the full screenshot to translation providers.
- Send only selected/edited text to language providers.
- Store transient screenshot copies in App Group image storage only for active sessions/history needs.
- Purge unreferenced Quick Lens images older than 24 hours.
- Never store provider secrets in App Group storage.

First-run permission copy should be concrete: Parrot needs access to find the screenshot the user just took. If access is denied, the share-extension flow remains available.

## 9. Testing Strategy

Unit tests:

- `LatestScreenshotProvider` with fake PhotoKit adapter:
  - picks newest screenshot within age window,
  - rejects non-screenshot assets,
  - handles denied/limited/no-assets states.
- `OCRTextBlockClusterer`:
  - clusters X post body,
  - clusters Reddit comment,
  - filters tab/status/user metadata,
  - ranks central content above metadata,
  - preserves low-confidence body lines.
- `QuickLensState` encode/decode and session integration.

UI tests:

- Launch app with injected Quick Lens fixture screenshot and OCR blocks.
- Verify top candidate auto-translates.
- Tap a second block and verify source/result update in place.
- Open edit source, change text, rerun, and verify screenshot overlay remains.
- Verify no-recent-screenshot and permission-denied recovery states.

Manual checks:

- iPhone SE, standard, and large iPhone sizes.
- Light/dark mode and dynamic type.
- X screenshot, Reddit screenshot, image meme/text screenshot.
- Action Button and Back Tap via Shortcuts on a physical device.

## 10. Rollout

Phase 1:

- In-app Lens button and URL route with fixture-friendly Quick Lens pipeline.
- OCR clustering and result surface.

Phase 2:

- PhotoKit latest screenshot provider and permission flow.
- App Intent / Shortcuts action.

Phase 3:

- Manual crop fallback.
- Platform-specific ranking refinements.
- Telemetry-free local debug diagnostics for candidate scoring during development.
