# Review: Contextual Translation Workflows

## Code Review

- Core request metadata is optional on `TranslateRequest`, so existing providers remain source-compatible.
- Privacy masking runs before terminology protection and restores after provider output, keeping mask maps transient.
- Quality recommendation is deterministic and leaves failed or lower-scored provider cards visible.
- OCR candidate defaulting now prefers the best scored body block when reliable geometry exists, while falling back to full text for fixture or low-quality geometry.
- Phase 9 closes HTML parity gaps: URL routes now honor explicit surface/profile parameters, `privateLocal` no longer falls back to cloud providers when no local engine is active, and native polish results can be sent back to the source app through a guarded paste action.
- Save-expression and save-research-excerpt actions reuse the existing learning vocabulary store instead of adding a parallel persistence path.
- Added tests cover context defaults, privacy masking, quality recommendation, Quick Peek routing, OCR candidate switching, unreliable OCR geometry fallback, profile persistence, LLM profile prompt instructions, URL route parsing, source-metadata rules, strict private-local empty-provider behavior, and save-action persistence.

## Architecture Review

- `TranslationContext` is owned by `ParrotCore`; UI state only chooses defaults and passes the context through.
- Entry-point routing lives in `AppState` / `AppDelegate`, keeping provider code free from UI concerns.
- Profile prompt behavior is centralized in `OpenAICompatEngine.systemPrompt`, while non-LLM providers continue to operate normally.
- OCR candidate preservation is implemented as view state derived from `OCRResult`, avoiding changes to OCR provider contracts. The macOS side mirrors the Quick Lens mental model with grouped text blocks and role labels such as body, reply sentence, and full text.
- Context rules are stored in `AppSettings`, surfaced in a dedicated rules-memory window, and applied during AppState default-profile resolution using source App/URL metadata.
- Provider routing now treats `allowedProviderIDs == nil` as unrestricted and an empty allowed list as intentionally no providers, preserving local-only semantics across AppState and `TranslationCoordinator`.

## UI Review

- Quick Peek is a compact first surface for short selection and lookup, with copy, speak, vocabulary, retry/configure recovery, and expand actions.
- The full workspace keeps the editable source composer, provider comparison, profile selector, bilingual paragraph view, and OCR candidate selector together.
- Provider cards now surface recommended, needs-review, terminology, and privacy-masking states without hiding competing outputs.
- OCR candidate cards now display user-facing roles (`正文`, `回复句`, `全文`, `文本块`) instead of a flat block list.
- Workspace and Quick Peek now expose rules memory, save-expression/save-excerpt, and native-polish replace actions as real controls with feedback states.
- Automated UI acceptance passed on 2026-07-02 via `.codex/skills/ui-acceptance-review/scripts/parrot-ui-acceptance.sh`, including Swift tests, release build, launch, AX menu fallback checks, input workspace, OCR fixture, URL smoke checks, result panel routing, and workspace resize stability.

## Verification

- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --filter AppStateContextTests` passed with 11 focused AppState workflow tests.
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test` passed with 125 tests.
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer .codex/skills/ui-acceptance-review/scripts/parrot-ui-acceptance.sh` passed, including its internal 125-test Swift run and release app smoke checks.
- `openspec validate optimize-contextual-translation-workflows` passed.
