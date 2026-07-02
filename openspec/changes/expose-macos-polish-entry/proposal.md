# Proposal: Expose macOS Polish Entry

## Summary

Fix the missing macOS entry point for text polishing by surfacing the existing `.polish` mode in the menu bar and result workspace.

## Root Cause

The shared translation layer and LLM providers already support `TranslateMode.polish`, and iOS has a first-class Native Polish workspace. The macOS app only exposed translate and lookup actions, so users could not discover or launch polish from the menu bar or floating result panel.

## Goals

- Add a visible macOS menu-bar entry for input polish.
- Add a visible polish action next to the existing translate action in the source editor.
- Keep existing translate, lookup, OCR, and iOS behavior unchanged.
- Keep Polish and Translate as persistent sibling actions in the source editor.
- Route polish through all active translation engines.
- Preserve the source language for polish; Translate remains the only cross-language action.

## Non-Goals

- No new provider integration.
- No shortcut settings expansion.
- No persistence schema changes.

## Verification

- Build the Swift package.
- Run focused tests that cover existing polish prompt/service behavior.
