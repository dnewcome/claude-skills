#!/usr/bin/env bash
# claude-skills install script
# Installs personal Claude Code skills into ~/.claude/commands/
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

COMMANDS_DIR="$HOME/.claude/commands"
mkdir -p "$COMMANDS_DIR"

echo "Installing claude-skills@${TAG} into $COMMANDS_DIR..."

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

cp "$TMP/$SRC/commands/"*.md "$COMMANDS_DIR/"
echo "  Copied skills ✓"

echo ""
echo "✅ claude-skills@${TAG} installed."
echo "   Available in any Claude Code session:"
for f in "$TMP/$SRC/commands/"*.md; do
  skill=$(basename "$f" .md)
  echo "   /$skill"
done
