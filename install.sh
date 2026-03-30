#!/usr/bin/env bash
# claude-skills install script
# Installs personal Claude Code skills into ~/.claude/skills/
#
# Usage:
#   bash <(curl -fsSL https://raw.githubusercontent.com/dnewcome/claude-skills/main/install.sh)
#
# Or locally:
#   bash path/to/claude-skills/install.sh [--tag v1.0]

set -euo pipefail

REPO="https://github.com/dnewcome/claude-skills"
TAG="main"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --tag) TAG="$2"; shift 2 ;;
    *) echo "Unknown argument: $1"; exit 1 ;;
  esac
done

SKILLS_DIR="$HOME/.claude/skills"
mkdir -p "$SKILLS_DIR"

echo "Installing claude-skills@${TAG} into $SKILLS_DIR..."

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

if [[ "$TAG" == "main" ]]; then
  TARBALL_URL="$REPO/archive/refs/heads/main.tar.gz"
else
  TARBALL_URL="$REPO/archive/refs/tags/${TAG}.tar.gz"
fi

echo "  Fetching $TARBALL_URL..."
curl -fsSL "$TARBALL_URL" | tar xz -C "$TMP"
SRC=$(ls "$TMP")

for f in "$TMP/$SRC/skills/"*.md; do
  skill=$(basename "$f" .md)
  mkdir -p "$SKILLS_DIR/$skill"
  cp "$f" "$SKILLS_DIR/$skill/SKILL.md"
  echo "  ✓ $skill"
done

echo ""
echo "✅ claude-skills@${TAG} installed."
