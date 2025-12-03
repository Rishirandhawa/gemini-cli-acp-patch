#!/bin/bash

# Revert ACP patch from gemini-cli
# Usage: ./revert-patch.sh [path-to-gemini-cli]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PATCH_FILE="$SCRIPT_DIR/gemini-acp.patch"

echo "Gemini CLI ACP Patch - Revert"
echo "=============================="
echo ""

# Find gemini-cli installation
find_gemini_cli() {
    local paths=(
        "$(npm root -g 2>/dev/null)/@google/gemini-cli"
        "$(pnpm root -g 2>/dev/null)/@google/gemini-cli"
        "$HOME/.nvm/versions/node/$(node -v)/lib/node_modules/@google/gemini-cli"
        "/usr/local/lib/node_modules/@google/gemini-cli"
        "$HOME/.npm-global/lib/node_modules/@google/gemini-cli"
    )

    for p in "${paths[@]}"; do
        if [[ -f "$p/dist/src/gemini.js" ]]; then
            echo "$p"
            return 0
        fi
    done
    return 1
}

# Get target path
if [[ -n "$1" ]]; then
    GEMINI_CLI_PATH="$1"
else
    echo "Searching for @google/gemini-cli installation..."
    GEMINI_CLI_PATH=$(find_gemini_cli) || {
        echo ""
        echo "Could not find @google/gemini-cli installation."
        echo ""
        echo "Please provide the path manually:"
        echo "  ./revert-patch.sh /path/to/@google/gemini-cli"
        exit 1
    }
fi

GEMINI_JS="$GEMINI_CLI_PATH/dist/src/gemini.js"
BACKUP_FILE="$GEMINI_JS.backup"

echo "Found gemini-cli at: $GEMINI_CLI_PATH"
echo ""

# Try backup file first
if [[ -f "$BACKUP_FILE" ]]; then
    echo "Restoring from backup..."
    cp "$BACKUP_FILE" "$GEMINI_JS"
    echo "Reverted successfully using backup file."
    exit 0
fi

# Otherwise use patch -R
if [[ -f "$GEMINI_JS" ]]; then
    echo "No backup found. Attempting reverse patch..."
    cd "$GEMINI_CLI_PATH"
    patch -p1 --reverse < "$PATCH_FILE" || {
        echo "Failed to reverse patch. File may not be patched."
        exit 1
    }
    echo "Reverted successfully using reverse patch."
    exit 0
fi

echo "Error: Could not find gemini.js to revert"
exit 1
