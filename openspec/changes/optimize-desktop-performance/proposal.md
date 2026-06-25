# Proposal: Optimize Desktop Performance

## Why

The macOS app shows visible stutter across common actions because several expensive operations run on high-frequency UI paths:

- Translation start and provider retry rebuild all providers and rescan plugins on the main actor.
- Result rendering recomputes the configured provider order during SwiftUI body updates.
- Learning occurrence statistics are recomputed from full history on the main actor after startup and saved translations.

These costs compound in the desktop workflow: selection capture opens the floating panel, translation starts immediately, result slots update incrementally, and learning/history metadata refreshes in the same interaction window.

## What Changes

- Cache provider display order and missing-configuration outcomes when providers/settings are refreshed.
- Remove provider/plugin reloads from translation start and single-provider retry; settings changes remain the reload boundary.
- Move learning history occurrence-count calculation off the main actor and guard stale refreshes.
- Reduce repeated history filtering work in the history browser by materializing filtered records from model state.
- Add focused tests for provider-order caching and history-store query slices used by responsive UI.

## Impact

- **Affected modules**: `ParrotApp`, `ParrotCore`, focused app/core tests.
- **User-visible impact**: faster translation startup, smoother incremental result rendering, less UI blocking after saving translations or opening learning surfaces.
- **Compatibility**: no provider protocol, plugin manifest, or persisted-history format changes.

## Non-Goals

- Replacing JSON history persistence with SQLite.
- Introducing third-party profiling or storage dependencies.
- Changing translation provider behavior or network concurrency.
- Redesigning UI surfaces.

## Risks

- Cached provider order can become stale if settings changes do not call the existing refresh boundary.
- Off-main learning refreshes can finish out of order without a generation guard.
- History filtering changes must keep current search/scope/language-pair behavior intact.

## Reviewers

- architect — cache boundaries and main-thread workload review.
- code-reviewer — regression review for translation and history behavior.
- lead — scope review against performance objective.
