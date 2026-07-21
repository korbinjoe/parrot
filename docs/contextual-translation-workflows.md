# Contextual Translation Workflows

Parrot now routes translation sessions through a lightweight `TranslationContext`.
The context captures the entry origin, user-facing profile, paragraph hints, privacy policy, provider routing hints, and OCR candidate selection.

## User-facing surfaces

- Selected text, lookup, OCR, manual input, and polish actions open the full workspace.
- The workspace header includes a compact context profile selector.
- Long or multi-paragraph text shows a bilingual paragraph reading block before provider comparison cards.
- OCR results preserve candidate text blocks with confidence and bounding boxes; switching a candidate updates the source draft and reruns translation.

## Profiles

Profiles tune prompt behavior, privacy, and routing without exposing raw provider configuration:

- Quick Translate: fast direct translation.
- Understand: prioritizes meaning, nuance, and tone.
- Native Polish: rewrites text in the target/original language as appropriate.
- Strict Terminology: preserves configured terms exactly.
- Private Local: masks sensitive entities and prefers local providers when available.
- GitHub, Email, Social, Reply, Document: preserve domain-specific structure and wording.

Manual profile changes are remembered for future manual input sessions only; automatic entry-point defaults still win for selection, lookup, OCR, URL, and polish flows.

## Safety and quality

- Sensitive emails, URLs, API keys, phone-like strings, and long numeric IDs can be masked before provider calls and restored after results return.
- Mask maps are transient and are not persisted to translation history.
- Results are scored for empty output, wrong language, extreme length ratio, unchanged source, placeholder leaks, terminology miss, and timeout.
- One provider result is marked recommended, but all provider cards remain available for comparison and recovery.
