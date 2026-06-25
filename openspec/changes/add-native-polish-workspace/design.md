# Design: Native Polish Workspace

## Architecture

Native Polish is represented as `SocialMode.polish`. The app keeps `ExpressResult` as the output container because the feature still produces writing candidates: one primary native rewrite and a few alternatives. This avoids a parallel result model until the product needs richer explanation metadata.

## Data Model

- `SocialMode.polish`: identifies sessions whose `sourceDraft` is the rough draft being rewritten.
- `ExpressResult.candidates`: stores the primary polish result and variants.
- `ReplyCandidate.title`: differentiates `Native polish`, `Warmer`, `Sharper`, and similar variants.

## Service Contract

`SocialExpressionService.generateReplies(session:)` remains the shared writing-generation API. When `session.mode == .polish`, providers receive a polish prompt and rule-based fallback rewrites `sourceDraft`; otherwise the existing reply-generation behavior remains unchanged.

Refinement continues to return a replacement `ReplyCandidate`. In polish mode, actions rewrite the candidate as draft variants instead of social reply variants.

## iOS UX

- Today includes a Native Polish quick tile.
- Workspace shows a compact mode selector for Understand, Reply, and Polish.
- Understand keeps the source translation flow.
- Reply keeps the existing intent composer and candidate cards.
- Polish uses the source editor, tone chips, primary result card, variant cards, copy, replace draft, and refinement actions.

## Decisions

- Native Polish uses `SocialMode.polish` with existing `ExpressResult` candidates.
- The first production version uses deterministic compare notes instead of a full token diff model.
- Switching between Reply and Polish clears stale writing candidates because both modes share `ExpressResult`.
