#!/usr/bin/env bash
# Initialize a new LLM Wiki directory structure
# Usage: ./init-wiki.sh <wiki-name> [base-dir]

set -euo pipefail

WIKI_NAME="${1:?Usage: init-wiki.sh <wiki-name> [base-dir]}"
BASE_DIR="${2:-.}"
WIKI_DIR="${BASE_DIR}/${WIKI_NAME}"

if [ -d "$WIKI_DIR" ]; then
  echo "Error: Directory '$WIKI_DIR' already exists."
  exit 1
fi

echo "Creating wiki: $WIKI_DIR"

# Create directory structure
mkdir -p "$WIKI_DIR/raw/assets"
mkdir -p "$WIKI_DIR/wiki/sources"
mkdir -p "$WIKI_DIR/wiki/entities"
mkdir -p "$WIKI_DIR/wiki/concepts"
mkdir -p "$WIKI_DIR/wiki/synthesis"

# Create index.md
cat > "$WIKI_DIR/wiki/index.md" << 'EOF'
# Wiki Index

> Last updated: $(date +%Y-%m-%d) | Pages: 0 | Sources: 0

## Sources

_No sources ingested yet._

## Entities

_No entity pages yet._

## Concepts

_No concept pages yet._

## Synthesis

_No synthesis pages yet._
EOF

# Fix the date in index.md
sed -i '' "s/\$(date +%Y-%m-%d)/$(date +%Y-%m-%d)/" "$WIKI_DIR/wiki/index.md" 2>/dev/null || \
sed -i "s/\$(date +%Y-%m-%d)/$(date +%Y-%m-%d)/" "$WIKI_DIR/wiki/index.md"

# Create log.md
cat > "$WIKI_DIR/wiki/log.md" << EOF
# Wiki Log

## [$(date +%Y-%m-%d)] init | Wiki Created
Wiki "${WIKI_NAME}" initialized.
EOF

echo "Wiki initialized at: $WIKI_DIR"
echo ""
echo "Next steps:"
echo "  1. Add source documents to $WIKI_DIR/raw/"
echo "  2. Customize $WIKI_DIR/SCHEMA.md for your domain"
echo "  3. Tell the LLM to ingest your first source"
