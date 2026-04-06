#!/usr/bin/env bash
# Validate that all blueprint files follow the TEMPLATE.md structure.
# Checks: required sections, metadata comment, and index.md link integrity.
#
# Usage: ./scripts/validate-blueprints.sh
# Exit code: 0 = all valid, 1 = errors found

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ERRORS=0
WARNINGS=0
CHECKED=0

# Colors
RED='\033[0;31m'
YELLOW='\033[0;33m'
GREEN='\033[0;32m'
NC='\033[0m'

error() { echo -e "${RED}ERROR${NC}: $1"; ERRORS=$((ERRORS + 1)); }
warn()  { echo -e "${YELLOW}WARN${NC}:  $1"; WARNINGS=$((WARNINGS + 1)); }
ok()    { echo -e "${GREEN}OK${NC}:    $1"; }

# ---------------------------------------------------------------------------
# 1. Blueprint format validation
# ---------------------------------------------------------------------------

# Required sections every blueprint MUST have
REQUIRED_SECTIONS=(
  "## TL;DR"
  "## When to Use"
  "## Prerequisites"
  "## Gotchas"
  "## Checklist"
)

# Sections where at least one of the group must exist
CONTENT_SECTIONS=(
  "## Steps"
  "## Overview"
)

# Directories containing blueprints (not root-level files)
BLUEPRINT_DIRS=("project-setup" "ci-cd" "architecture" "workflow" "patterns")

echo "=== Blueprint Format Validation ==="
echo ""

for dir in "${BLUEPRINT_DIRS[@]}"; do
  dirpath="$ROOT/$dir"
  [ -d "$dirpath" ] || continue

  for file in "$dirpath"/*.md; do
    [ -f "$file" ] || continue
    CHECKED=$((CHECKED + 1))
    relpath="${file#$ROOT/}"
    file_ok=true
    # Read first 20 lines for metadata checks (avoids SIGPIPE with large files + pipefail)
    header="$(head -20 "$file")"

    # Check metadata comment
    if ! echo "$header" | grep -q "^<!--"; then
      error "$relpath — missing metadata comment (<!-- tags, category, ... -->)"
      file_ok=false
    else
      for field in "tags:" "category:" "difficulty:" "time:"; do
        if ! echo "$header" | grep -q "$field"; then
          error "$relpath — metadata missing '$field'"
          file_ok=false
        fi
      done
    fi

    # Check required sections
    for section in "${REQUIRED_SECTIONS[@]}"; do
      if ! grep -q "^${section}" "$file"; then
        error "$relpath — missing required section: $section"
        file_ok=false
      fi
    done

    # Check at least one content section exists
    has_content=false
    for section in "${CONTENT_SECTIONS[@]}"; do
      if grep -q "^${section}" "$file"; then
        has_content=true
        break
      fi
    done
    if [ "$has_content" = false ]; then
      error "$relpath — missing content section (need at least one of: ${CONTENT_SECTIONS[*]})"
      file_ok=false
    fi

    # Check for TL;DR content (not just the heading)
    tldr_line=$(grep -n "^## TL;DR" "$file" | head -1 | cut -d: -f1)
    if [ -n "$tldr_line" ]; then
      next_line=$((tldr_line + 2))
      tldr_content=$(sed -n "${next_line}p" "$file")
      if [ -z "$tldr_content" ]; then
        warn "$relpath — TL;DR section appears empty"
      fi
    fi

    if [ "$file_ok" = true ]; then
      ok "$relpath"
    fi
  done
done

# ---------------------------------------------------------------------------
# 2. Index link validation
# ---------------------------------------------------------------------------

echo ""
echo "=== Index Link Validation ==="
echo ""

INDEX="$ROOT/index.md"
if [ -f "$INDEX" ]; then
  # Extract all markdown links to .md files
  links=$(grep -oE '\([^)]+\.md\)' "$INDEX" | tr -d '()')

  for link in $links; do
    target="$ROOT/$link"
    if [ -f "$target" ]; then
      ok "index.md → $link"
    else
      error "index.md → $link (file not found)"
    fi
  done
else
  error "index.md not found"
fi

# ---------------------------------------------------------------------------
# 3. Summary
# ---------------------------------------------------------------------------

echo ""
echo "=== Summary ==="
echo "Blueprints checked: $CHECKED"
echo -e "Errors:   ${RED}${ERRORS}${NC}"
echo -e "Warnings: ${YELLOW}${WARNINGS}${NC}"

if [ "$ERRORS" -gt 0 ]; then
  echo ""
  echo -e "${RED}Validation failed with $ERRORS error(s).${NC}"
  exit 1
else
  echo ""
  echo -e "${GREEN}All blueprints valid.${NC}"
  exit 0
fi
