# Fix Learning Selection Card Clarity

## Summary
Make the selected-word learning card in the macOS result panel clearly answer “what does this selected word mean here?” before showing learning metadata.

## Root Cause
The inline learning card reused a vocabulary detail layout with multiple nested sections: meaning, source chunk, collocations, mastery progress, frequency, and actions. In the result panel this made the selected-word translation visually secondary. Generic selected words also fell back to an instructional placeholder instead of a useful gloss.

## Motivation
When a user selects a word inside the translation workspace, their immediate goal is lookup: understand the selected word in this sentence. Vocabulary tracking is secondary and should not obscure the answer.

## Goals
- Put selected term and sentence-specific meaning in the first visual row.
- Reduce inline metadata density and remove nested detail cards.
- Keep “认识” and “加入词库” available without dominating the card.
- Add local glosses for common technical words that appear in the reported flow.

## Non-Goals
- Build a full dictionary service.
- Change review scheduling or vocabulary persistence.
- Redesign the standalone personal vocabulary window.

## Approach
Retune `LearningContextCard` into a compact lookup-first card and expand the small local learning lexicon with common technical expressions such as `proprietary`, `observability`, `tracing`, `evals`, and `hosted`.
