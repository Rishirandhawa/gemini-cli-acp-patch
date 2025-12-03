#!/bin/bash

# Apply ACP patch to gemini-cli using the patch command
# Usage: ./apply-patch.sh [path-to-gemini-cli]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PATCH_FILE="$SCRIPT_DIR/gemini-acp.patch"

echo "Gemini CLI ACP Patch (diff format)"
echo "==================================="
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
        echo "  ./apply-patch.sh /path/to/@google/gemini-cli"
        echo ""
        echo "You can find it by running:"
        echo "  npm root -g"
        exit 1
    }
fi

if [[ ! -d "$GEMINI_CLI_PATH" ]]; then
    echo "Error: Directory not found: $GEMINI_CLI_PATH"
    exit 1
fi

GEMINI_JS="$GEMINI_CLI_PATH/dist/src/gemini.js"

if [[ ! -f "$GEMINI_JS" ]]; then
    echo "Error: gemini.js not found at $GEMINI_JS"
    exit 1
fi

echo "Found gemini-cli at: $GEMINI_CLI_PATH"
echo ""

# Check if already patched
if grep -q '\[PATCHED\] Early exit for ACP mode' "$GEMINI_JS" && \
   grep -q 'process.argv.includes' "$GEMINI_JS"; then
    echo "Already patched. Skipping."
    exit 0
fi

# Create backup
if [[ ! -f "$GEMINI_JS.backup" ]]; then
    cp "$GEMINI_JS" "$GEMINI_JS.backup"
    echo "Backup created at $GEMINI_JS.backup"
fi

# Apply patch
echo "Applying patch..."
cd "$GEMINI_CLI_PATH"
patch -p1 --forward < "$PATCH_FILE" || {
    # patch returns 1 if already applied
    if [[ $? -eq 1 ]]; then
        echo "Patch may already be applied or failed to apply."
        echo "Try reverting first: ./revert-patch.sh"
        exit 1
    fi
}

echo ""
echo "Patch applied successfully!"
echo ""
echo "To revert: ./revert-patch.sh $GEMINI_CLI_PATH"
