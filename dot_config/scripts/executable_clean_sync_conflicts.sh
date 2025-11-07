#!/usr/bin/env bash
#
# clean_sync_conflicts.sh — Recursively remove .stfolder.removed-* and .sync-conflict-* files
# Usage: clean_sync_conflicts.sh [TARGET_DIR]
# If TARGET_DIR is omitted, defaults to current directory.

set -euo pipefail

TARGET_DIR="${1:-.}"

echo "Scanning and deleting .stfolder.removed-* files in: $TARGET_DIR"
find "$TARGET_DIR" -type f -name '.stfolder.removed-*' -print -delete

echo "Scanning and deleting .sync-conflict-* files in: $TARGET_DIR"
find "$TARGET_DIR" -type f -name '.sync-conflict-*' -print -delete

echo "Done. All sync‑conflict and removed‑folder markers cleaned up."

