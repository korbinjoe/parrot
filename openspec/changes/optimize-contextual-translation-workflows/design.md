# Design: Contextual Translation Workflows

## North Star

Parrot should make cross-language work feel native to the user's current task: short text gets a low-friction answer, long text becomes bilingual reading, OCR stays connected to screenshot context, and every result remains editable, retryable, and recoverable in the same workspace.

## Current State

Parrot already has the key workspace foundations:

- `AppState.sourceDraft`, `sourceText`, `isSourceDirty`, and `translateDraft()` preserve editable source state.
- `ResultView` contains an editable source composer and provider result cards.
- macOS entry points include selection, lookup, manual input, screenshot OCR, URL Scheme, menu, history, and PopClip.
- iOS has `ParrotSocial`, Understand/Express/Polish, Share Extension, OCR cleanup, and Quick Lens design.
- Terminology design already introduces request-time terminology snapshots.

The gap is contextual behavior. The current model still treats most tasks as one source text and many provider outputs. It does not yet:

- choose lightweight vs full surfaces by task size,
- render long text as paragraph-level bilingual reading,
- expose task profiles in the workspace,
- carry OCR block candidate metadata through macOS flows,
- locally mask sensitive entities before cloud requests,
- evaluate obvious provider result failures before recommending a result.

## User Experience

### Quick Peek

Quick Peek is a compact transient surface for short selected text and lookup-like requests.

Entry rules:

- `Option+D` with short source text opens Quick Peek first.
- `Option+E` lookup opens Quick Peek when the request is a word or short phrase.
- Menu/PopClip URL calls may request Quick Peek with `surface=peek`.
- Any dirty, long, OCR, history, or manual input session opens the full workspace.

Default behavior:

- Show source, primary meaning/translation, pronunciation when available, and quick actions.
- Actions: copy result, speak, save/vocabulary, expand workspace, retry, configure on error.
- Quick Peek may auto-close only after a successful copy/use action or explicit close.
- Expanding preserves the same source draft and existing outcomes.

Quick Peek is not a second translation model. It reads from and writes to the same `AppState` session fields.

### Paragraph Bilingual Workspace

When source text is long enough or contains multiple paragraphs, the workspace offers a bilingual reading layout:

```text
Source paragraph 1
Translated paragraph 1

Source paragraph 2
Translated paragraph 2
```

Rules:

- The original source composer remains editable at the top.
- Paragraph view is a result presentation, not a separate source editor.
- Editing the source and rerunning updates the paragraph view.
- Users can copy one paragraph, copy all translations, or fall back to provider cards.
- Provider cards remain available for comparison and errors.

Segmentation is deterministic and local:

- Split by blank lines first.
- Fall back to sentence/line grouping for OCR and pasted text.
- Preserve code fences, markdown tables, and list markers as protected blocks.
- Do not translate code blocks in `github` / `document` profiles unless the user explicitly switches mode.

### Context Profiles

Profiles turn provider/prompt complexity into task-oriented controls.

```swift
public enum TranslationContextProfile: String, Codable, Sendable, CaseIterable {
    case quickTranslate
    case understand
    case nativePolish
    case reply
    case strictTerminology
    case privateLocal
    case github
    case social
    case email
    case document
}
```

Profile behavior:

| Profile | Default result shape | Routing intent | Terminology | Privacy |
| --- | --- | --- | --- | --- |
| `quickTranslate` | concise translation | fastest configured provider first | normal | standard |
| `understand` | meaning + nuance + translation | LLM-capable provider preferred | normal | standard |
| `nativePolish` | rewrite + alternatives | polish-capable provider | normal | standard |
| `reply` | candidate replies | social expression service / LLM | normal | standard |
| `strictTerminology` | translation with term status | terminology-aware or placeholder strategy | strict | standard |
| `privateLocal` | local/on-device result when possible | Apple/local/BYO-only provider | normal | strict |
| `github` | markdown/code-safe translation | code-safe prompt | normal | mask secrets |
| `social` | implied meaning + tone | social Understand prompt | normal | standard |
| `email` | polished business output | LLM/DeepL preferred | normal | mask contact info |
| `document` | paragraph bilingual | quality provider + segmentation | normal | standard |

The UI should expose a compact profile menu with user-facing names. It should not expose raw prompt names.

### Translation Context

`TranslateRequest` should carry optional context that is safe for providers to ignore.

```swift
public struct TranslationContext: Codable, Equatable, Sendable {
    public var profile: TranslationContextProfile
    public var origin: TranslationOrigin
    public var sourceApp: String?
    public var windowTitle: String?
    public var sourceURL: String?
    public var selectedOCRBlockID: UUID?
    public var paragraphHints: [ParagraphHint]
    public var privacyPolicy: PrivacyPolicy
    public var routingHints: ProviderRoutingHints
}
```

Do not collect background metadata. Only include metadata attached to an explicit user action, such as URL Scheme parameters, share payloads, active app/window title during selection capture when already available, or OCR block metadata created by Parrot.

### Sensitive Entity Masking

Before sending content to cloud providers, Parrot can locally mask sensitive entities.

Entity types for MVP:

- email address
- phone number
- URL with tokens/query secrets
- API keys and common token patterns
- long numeric IDs
- addresses only when detected with high confidence

Data model:

```swift
public struct PrivacyMaskingReport: Codable, Equatable, Sendable {
    public var applied: Bool
    public var policy: PrivacyPolicy
    public var entityCounts: [SensitiveEntityType: Int]
}
```

Rules:

- Masking runs before terminology placeholder protection.
- Provider receives masked text.
- Result unmasking happens before display.
- Result cards show a compact "masked N sensitive items" status.
- Users can disable masking per request from the profile/status menu.
- `privateLocal` profile must not send masked or unmasked content to cloud providers unless the user explicitly overrides.

### Quality Evaluation and Fallback

Coordinator should evaluate each result before marking it recommended.

Checks:

- empty or whitespace-only translation,
- output language appears wrong,
- length ratio is extreme for normal translation,
- provider returned the unchanged source unexpectedly,
- terminology placeholders leaked,
- strict terminology misses,
- provider soft timeout,
- plugin malformed response.

Data model:

```swift
public enum ResultQualityIssue: String, Codable, Sendable {
    case emptyOutput
    case wrongLanguage
    case extremeLengthRatio
    case unchangedSource
    case placeholderLeak
    case terminologyMiss
    case softTimeout
    case malformedResponse
}

public struct ResultQualitySummary: Codable, Equatable, Sendable {
    public var score: Double
    public var issues: [ResultQualityIssue]
    public var isRecommended: Bool
}
```

Rules:

- Provider cards remain visible even when they have quality issues.
- The recommended result is the best passing result by user order, profile preference, and quality score.
- If no result passes, show the best available result with "needs review" status and visible retry/fallback actions.

### OCR Candidate Integration

macOS screenshot OCR should preserve block geometry when available and present candidate blocks for correction, borrowing the Quick Lens mental model.

Flow:

```text
Option+S
  -> user selects screenshot region
  -> OCR returns blocks
  -> candidate scorer selects likely body text
  -> sourceDraft receives selected candidate
  -> workspace opens with screenshot context + editable source
  -> user taps another block or edits source
  -> translation reruns in place
```

For MVP, macOS can show a compact candidate list rather than full screenshot overlay if rendering the screenshot overlay is too large. The user-facing requirement is block switching without leaving the workspace.

## Decisions

1. **One session model remains mandatory.** Quick Peek, paragraph bilingual view, and OCR block switching are surfaces over the same editable source draft.
2. **Profiles are additive.** Existing provider settings and ordering remain valid; profiles only supply defaults and routing hints.
3. **Quality recommendation is additive.** Parrot does not hide provider outputs; it only labels the recommended result.
4. **Privacy masking is local.** The mask/unmask mapping must not be sent to providers or logged.
5. **Full webpage translation is deferred.** Parrot should integrate with browser/context entry points later, but this change focuses on the native workspace.

## Implementation Notes

- Keep UI controls dense and tool-like. Use icons, menus, and segmented controls; avoid marketing-style text inside the app.
- Keep `ResultView` readable at current minimum widths. Paragraph view may replace provider cards only in the scroll body, not in the header.
- Add tests for local pure functions first: segmentation, masking, profile mapping, quality checks, candidate scoring.
- Use existing terminology snapshot when implementing strict terminology profile.
- Make new request fields optional and defaultable so existing providers/plugins continue to compile.

