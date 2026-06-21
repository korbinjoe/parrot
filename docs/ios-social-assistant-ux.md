# Parrot iOS Social Assistant UX

## North Star

Parrot iOS is a social reading and expression assistant: when users browse X, Reddit, or similar communities, Parrot helps them understand multilingual content in context and turn rough thoughts into native speaker-style replies without losing the original app context.

## Product Positioning

The macOS product is a fast translation utility. The iOS product should not simply be a smaller translation app. Its primary job is to support two high-frequency social behaviors:

- **Understand**: make foreign-language posts, comments, slang, sarcasm, and argument tone immediately understandable.
- **Express**: convert Chinese, mixed-language notes, or awkward English into natural platform-appropriate English.

The product should optimize for confidence and speed, not for exposing every translation control first.

## Design Principles

1. **Context before translation**
   - Social text often depends on tone, implied meaning, memes, abbreviations, or platform culture.
   - The first result should answer: "What does this actually mean here?"
   - Full literal translation is useful, but it is secondary.

2. **User intent before generated copy**
   - In writing scenarios, the user is not asking for a direct translation.
   - The user is asking: "How would a native speaker say what I mean?"
   - Parrot should preserve the user's stance while improving fluency.

3. **One editable workspace**
   - Shared text, copied text, OCR text, history items, and typed drafts all enter an editable composer.
   - No captured source should become a read-only dead end.
   - Every result can be refined without restarting the task.

4. **Return to the original app**
   - X, Reddit, and other social apps remain the user's main environment.
   - Parrot appears as a temporary assistant surface unless the user explicitly opens the full workspace.

5. **Fast path first, power path second**
   - Default action: understand or rewrite.
   - Advanced controls: engine selection, language pair, model, and prompt settings are deferred.

## Primary User Journeys

| Journey | User Goal | Entry Point | Target Flow | P-Level |
| --- | --- | --- | --- | --- |
| Understand a post | Quickly understand an English or multilingual post while browsing | Share Extension, copied text, screenshot OCR | Source preview -> meaning summary -> tone tags -> optional full translation -> return | P0 |
| Understand comments | Decode slang, sarcasm, disagreement, or community-specific phrasing | Share Extension, copy, screenshot OCR | Comment text -> "what they mean" -> phrase explanations -> reply option | P0 |
| Reply naturally | Turn rough thoughts into native English | Reply Composer, Parrot Keyboard, clipboard rewrite | User intent -> tone presets -> candidate replies -> copy/insert | P0 |
| Polish awkward English | Make a draft sound natural without changing intent | Keyboard, main app, clipboard | Draft -> native rewrite -> shorter/kinder/sharper variants -> insert/copy | P0 |
| OCR screenshot | Understand text that cannot be selected or shared | Screenshot import/share | OCR -> editable source cleanup -> understand/reply | P1 |
| Reuse history | Reopen prior explanations or replies | History | Search -> reopen editable workspace -> refine -> copy | P1 |
| Configure recovery | Fix missing key, timeout, unsupported language | Inline error card | Preserve source/draft -> configure -> retry in place | P1 |

## Entry Strategy

### MVP Entrypoints

1. **Share Extension**
   - Highest-value entry for posts, comments, links, and selected text.
   - Opens Quick Peek as a compact bottom-sheet style surface.

2. **Quick Lens**
   - Fast path for X, Reddit, image posts, and other surfaces where text cannot be selected or shared cleanly.
   - The user takes a screenshot, invokes `Translate Latest Screenshot`, and Parrot reads only the most recent user-initiated screenshot.
   - Parrot OCRs the screenshot, clusters text into tappable blocks, auto-selects the most likely post/comment body, and starts Understand immediately.
   - Manual block selection, crop, and source editing are correction paths, not the default path.

3. **Clipboard Launch**
   - If the clipboard contains recent text, opening Parrot shows a contextual "Explain copied text" action.
   - Avoid background clipboard polling. Ask only when the app is foregrounded.

4. **Main App Workspace**
   - Persistent destination for composing, reviewing history, managing engines, and longer writing tasks.

5. **Screenshot OCR**
   - Accept screenshot import/share.
   - Recognized text enters an editable source composer before or alongside first analysis.

### Post-MVP Entrypoints

1. **Parrot Keyboard**
   - Fastest writing surface once enabled.
   - Focused on rewrite commands, not full keyboard replacement.
   - Actions: Native, Shorter, Kinder, Sharper, Translate to English.

2. **App Shortcuts**
   - Explain Clipboard.
   - Rewrite Clipboard.
   - Translate Screenshot.
   - Open Reply Composer.

3. **Safari Extension**
   - Useful for web reading, less important than social app share flows for MVP.

## Information Architecture

### Top-Level App Structure

- **Today**
  - Clipboard suggestion.
  - Recent social explanations.
  - Continue draft.

- **Understand**
  - Source composer.
  - Meaning summary.
  - Tone/intent tags.
  - Phrase explanations.
  - Full translation.
  - Reply handoff.

- **Express**
  - Context card.
  - Intent composer.
  - Tone presets.
  - Candidate reply cards.
  - Refinement actions.

- **History**
  - Explanations.
  - Replies.
  - Favorites.
  - Search.

- **Settings**
  - Engines.
  - Writing style defaults.
  - Languages.
  - Keyboard setup.
  - Privacy.

## Screen Designs

### 1. Quick Peek

**Purpose**: Understand social text without leaving the original app mentally.

**Layout**

- Header:
  - Source app label: X, Reddit, Clipboard, Screenshot.
  - Close button.
  - Open Workspace button.

- Source preview:
  - Compact quoted source.
  - Author/context if available.

- Meaning card:
  - One sentence in the user's preferred language.
  - Prioritize implied meaning over literal translation.

- Tone row:
  - Tags such as sarcastic, supportive, skeptical, joke, heated, formal.

- Phrase cards:
  - Slang, idiom, abbreviation, community reference.
  - Each phrase explains meaning and usage.

- Collapsed full translation:
  - Available but secondary.

- Bottom action row:
  - Reply.
  - Copy meaning.
  - Save.

**Behavior**

- Default height: roughly 62% of screen.
- Reply opens a taller composer sheet, preserving the source context above it.
- Open Workspace expands to the full Parrot app.
- Copy gives inline confirmation, not a detached toast.

### 2. Reply Composer

**Purpose**: Convert the user's rough thought into native speaker-style English.

**Layout**

- Context card:
  - Shows the original post/comment being replied to.
  - Collapsible after the user starts typing.

- Intent composer:
  - Placeholder: "Say what you mean..."
  - Accepts Chinese, mixed language, bullet points, or rough English.

- Tone presets:
  - Natural.
  - Friendly.
  - Firm.
  - Reddit-style.
  - X-short.

- Candidate cards:
  - Each card has a clear usage label.
  - Example: "Natural reply", "Polite disagreement", "Short version".
  - Each card has Copy, Insert, and Refine.

- Refinement tray:
  - Shorter.
  - More casual.
  - More polite.
  - Keep my attitude.
  - Add context.

**Behavior**

- The composer never clears itself after generation.
- Generated cards update in place.
- The selected tone stays visible.
- Copying a reply confirms inline and keeps the original draft.

### 3. OCR Cleanup

**Purpose**: Handle screenshots and unselectable text.

**Layout**

- Screenshot thumbnail.
- OCR source editor.
- Noise cleanup actions:
  - Remove usernames.
  - Remove timestamps.
  - Join broken lines.
  - Delete empty lines.

- Primary action:
  - Understand.

- Secondary action:
  - Write reply.

**Behavior**

- OCR text is always editable.
- OCR confidence and suspected noise are visible but not alarming.
- If recognition fails, the user sees retry and import-photo actions in the same surface.

### 4. Quick Lens

**Purpose**: Make unselectable social text feel selectable with the lowest possible user effort.

**Layout**

- Screenshot preview with highlighted candidate text blocks.
- Selected text summary.
- Meaning result area.
- Actions:
  - Reply.
  - Edit source.
  - Crop.
  - Copy meaning.

**Behavior**

- Default path is screenshot -> invoke Parrot -> translated result.
- Quick Lens reads only a recent screenshot after explicit user action.
- The best candidate block is selected automatically and Understand starts without an extra translate tap.
- Tapping another highlighted block updates the source and reruns Understand in place.
- Editing source keeps the screenshot context visible and rerunnable.
- Crop is a correction path for dense or incorrect OCR block detection.
- Translation providers receive only selected or edited text, not the full screenshot.

### 5. Parrot Keyboard

**Purpose**: Improve text inside the user's current social app composer.

**Layout**

- Compact command row:
  - Native.
  - Shorter.
  - Kinder.
  - Sharper.
  - Translate.

- Draft preview:
  - Shows current selected or typed text when available.

- Result strip:
  - One best candidate first.
  - Swipe for variants.

**Behavior**

- It should feel like a writing command pad, not a full keyboard replacement.
- The keyboard should preserve user input until insertion succeeds.
- Privacy copy should be concrete: what is sent, when, and to which provider.

## Interaction Model

### Modes

```text
understand
  sourceText
  sourceOrigin
  meaning
  toneTags
  phraseExplanations
  fullTranslation
  canReply

express
  contextText?
  userIntentDraft
  tonePreset
  generatedReplies
  selectedReply?

ocr
  imageRef
  recognizedDraft
  confidence
  cleanupActions

quickLens
  imageRef
  candidates
  selectedCandidate
  sourceDraft
  meaning
```

### Shared Session Rules

- Every source has an editable draft.
- Every generated output keeps a link to the source/context.
- Every failure keeps the source and draft intact.
- Reply generation can start from any understand session.
- History reopens into the same editable workspace, not a static record.
- Quick Lens selected blocks always become editable source drafts before or while translation runs.

## Visual Direction

### Product Feel

- Native iOS utility with social-app awareness.
- Dense enough for repeated use, but warmer than a settings-heavy utility.
- Calm neutral base, with sharp color accents for source app, tone, and action state.

### Palette

- Base: off-white / graphite.
- Primary action: vivid green.
- Social source accent: blue-black for X, orange-red for Reddit.
- Writing accent: warm coral.
- Analysis accent: clear cyan.

### Typography

- Use the iOS system font stack.
- Prioritize readable body text over oversized marketing typography.
- Meaning summaries use medium weight.
- Candidate replies use larger line-height and generous spacing.

### Motion

- Quick Peek slides up from the current app context.
- Reply Composer grows from Quick Peek, preserving the source card.
- Tone changes crossfade only the generated cards, not the whole page.
- Copy and insert confirmations are inline.

## Implementation Plan

### P0 - MVP

1. Add iOS app target.
   - Reuse `ParrotCore` and compatible engine code.
   - Add iOS-specific `ParrotiOSApp`, `IOSAppState`, and `TranslationSession`.

2. Build shared session model.
   - `SocialTextSession`
   - `UnderstandResult`
   - `ExpressResult`
   - `SourceOrigin`
   - `TonePreset`

3. Build main workspace.
   - `TodayView`
   - `UnderstandWorkspaceView`
   - `ExpressWorkspaceView`
   - `ResultCandidateCard`

4. Build Share Extension.
   - Parse text, URL metadata where available, and image attachments.
   - Open Quick Peek for text.
   - Route images to OCR cleanup.

5. Build native expression pipeline.
   - Prompt templates for social explanation.
   - Prompt templates for native speaker replies.
   - Platform presets for X and Reddit.

6. Add persistence.
   - History records for understand and express sessions.
   - Favorite replies.
   - Keychain-backed secrets.

### P1

1. Quick Lens latest screenshot translation.
2. Screenshot OCR import and cleanup.
3. Inline engine errors with retry/configure.
4. Platform style presets.
5. App Shortcuts.
6. Share Extension polish for URLs and rich snippets.

### P2

1. Parrot Keyboard.
2. Safari Extension.
3. On-device phrase memory and user style profile.
4. Cross-device history sync.

## Acceptance Criteria

### User-Facing Checks

- Sharing a Reddit comment to Parrot opens Quick Peek with meaning, tone, phrase explanation, and full translation.
- Tapping Reply preserves the original comment and opens an editable intent composer.
- A Chinese or mixed-language draft generates at least three native English reply candidates.
- Copying a candidate never clears the draft or hides the context.
- OCR screenshot text enters an editable source editor before analysis.
- Quick Lens opens from a recent screenshot, auto-selects a likely text block, and shows an Understand result without requiring manual crop.
- Tapping a different Quick Lens block updates the translated source in place.
- History records can be reopened, edited, and regenerated.
- Missing API key or timeout does not lose source text or draft.

### Design Checks

- The first visible result in Understand mode is a meaning summary, not a literal translation dump.
- Express mode makes one primary action obvious.
- Source context remains visible until the user intentionally collapses it.
- No screen has more than one equally dominant primary button.
- Error recovery appears inline.

### Technical Checks

- Core translation/session tests run on both macOS and iOS-compatible targets.
- Share Extension can pass text to the shared session without relying on unavailable app-only APIs.
- Secrets use Keychain on iOS.
- App Group storage is used only for extension-safe shared data.

## Open Risks

- Social apps differ in what they expose through the share sheet.
- Some flows may require copy/paste because iOS does not expose arbitrary selected text globally.
- Keyboard extension setup has user friction and privacy sensitivity.
- LLM latency must be masked with partial, useful intermediate states.
- Platform-style generation must avoid sounding fake, overly polished, or unsafe for public posting.
