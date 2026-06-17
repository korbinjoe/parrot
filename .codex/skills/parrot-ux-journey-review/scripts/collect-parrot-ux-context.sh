#!/usr/bin/env bash
set -euo pipefail

ROOT="${1:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
OUT="${2:-$ROOT/build/ux-review-context.md}"
cd "$ROOT"
mkdir -p "$(dirname "$OUT")"

section() {
  printf '\n## %s\n\n' "$1" >> "$OUT"
}

: > "$OUT"
printf '# Parrot UX Review Context\n' >> "$OUT"
printf '\nGenerated: %s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" >> "$OUT"

section "Git Status"
git status --short >> "$OUT" || true

section "User-Facing Features From README"
sed -n '1,40p' README.md >> "$OUT" || true

section "Core Interaction Files"
for file in \
  Sources/ParrotApp/AppDelegate.swift \
  Sources/ParrotApp/InputPanel.swift \
  Sources/ParrotApp/FloatingPanel.swift \
  Sources/ParrotApp/ResultView.swift \
  Sources/ParrotApp/MenuBarPopover.swift \
  Sources/ParrotApp/OCRResultPanel.swift \
  Sources/ParrotApp/HistoryWindow.swift \
  Sources/ParrotApp/SettingsWindow.swift \
  Sources/ParrotApp/AppState.swift
do
  if [[ -f "$file" ]]; then
    printf '\n### %s\n\n' "$file" >> "$OUT"
    rg -n "func |var body|Option|⌥|onSubmit|show\\(|hide\\(|translate|retry|TextField|TextEditor|Button|onExitCommand|keyboardShortcut|focused|isPinned|orderOut|makeKey|WindowPlacement" "$file" >> "$OUT" || true
  fi
done

section "Existing UX Specs"
for file in openspec/specs/app-ui/spec.md openspec/changes/redesign-app-ui/taste-review.md openspec/changes/redesign-app-ui/tasks.md
do
  if [[ -f "$file" ]]; then
    printf '\n### %s\n\n' "$file" >> "$OUT"
    sed -n '1,180p' "$file" >> "$OUT"
  fi
done

printf 'Wrote %s\n' "$OUT"
