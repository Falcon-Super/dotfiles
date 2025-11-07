#!/usr/bin/env bash
#
# clean_mac_junk.sh — Recursively remove .DS_Store and ._* files
# Usage: clean_mac_junk.sh [TARGET_DIR]
# If TARGET_DIR is omitted, defaults to current directory.
#
# Works on GNU find (Linux) and BSD find (macOS, *BSD, CachyOS).

set -euo pipefail

TARGET_DIR="${1:-.}"

echo "Scanning and deleting .DS_Store files in: $TARGET_DIR"
find "$TARGET_DIR" -type f -name '.DS_Store' -print -delete   # removes .DS_Store files :contentReference[oaicite:0]{index=0}

echo "Scanning and deleting ._* files in: $TARGET_DIR"
find "$TARGET_DIR" -type f -name '._*'       -print -delete   # removes AppleDouble resource forks :contentReference[oaicite:1]{index=1}

echo "Done. All junk files removed."

