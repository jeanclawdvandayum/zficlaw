#!/bin/bash
# zficlaw installer — copies all skills to your OpenClaw skills directory
set -e

SKILLS_DIR="${OPENCLAW_SKILLS:-$HOME/.openclaw/skills}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE="$SCRIPT_DIR/skills"

echo "🔒 zficlaw — Smart Contract Security Audit Pack"
echo "================================================"
echo ""
echo "Installing 79 skills to: $SKILLS_DIR"
echo ""

if [ ! -d "$SOURCE" ]; then
  echo "❌ Skills directory not found at $SOURCE"
  echo "   Run this script from the zficlaw repo root."
  exit 1
fi

mkdir -p "$SKILLS_DIR"

INSTALLED=0
UPDATED=0
SKIPPED=0

for skill_dir in "$SOURCE"/*/; do
  skill_name=$(basename "$skill_dir")
  
  if [ ! -f "$skill_dir/SKILL.md" ]; then
    continue
  fi
  
  target="$SKILLS_DIR/$skill_name"
  
  if [ -d "$target" ]; then
    # Check if content differs
    if diff -rq "$skill_dir" "$target" > /dev/null 2>&1; then
      ((SKIPPED++))
    else
      cp -r "$skill_dir" "$SKILLS_DIR/"
      ((UPDATED++))
      echo "  ↻ Updated: $skill_name"
    fi
  else
    cp -r "$skill_dir" "$SKILLS_DIR/"
    ((INSTALLED++))
    echo "  + Installed: $skill_name"
  fi
done

echo ""
echo "✅ Done!"
echo "   Installed: $INSTALLED new"
echo "   Updated:   $UPDATED"
echo "   Unchanged: $SKIPPED"
echo ""
echo "Skills are now available to your OpenClaw agent."
echo "Start an audit: 'Use the e2e-audit-process skill to audit [contract].'"
