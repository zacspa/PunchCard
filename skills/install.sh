#!/usr/bin/env bash
# Symlink every skill in this directory into ~/.claude/commands/ so edits to
# skills/*.md take effect immediately (no re-copy step on each change).
set -euo pipefail

SKILLS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_DIR="$HOME/.claude/commands"

mkdir -p "$TARGET_DIR"

count=0
for skill in "$SKILLS_DIR"/*.md; do
  [ -e "$skill" ] || continue
  name=$(basename "$skill")
  target="$TARGET_DIR/$name"
  rm -f "$target"
  ln -s "$skill" "$target"
  echo "  linked $name"
  count=$((count + 1))
done

echo "Installed $count skill(s) to $TARGET_DIR"
