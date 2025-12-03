# gemini-cli-acp-patch

Patch for `@google/gemini-cli` to fix ACP (Agent Communication Protocol) mode when running as a subprocess with piped stdio - required for Zed editor integration.

## The Problem

When running `gemini --experimental-acp` as a subprocess (as Zed does), the CLI produces no output and hangs indefinitely.

**Root cause:** The CLI's `patchStdio()` function runs at the very start of `main()` and redirects stdout/stderr to internal event handlers. This breaks ACP mode which needs raw stdout for JSON-RPC communication.

```javascript
// This hangs with no output:
const gemini = spawn('gemini', ['--experimental-acp'], {
  stdio: ['pipe', 'pipe', 'pipe']
});

gemini.stdin.write(JSON.stringify({
  jsonrpc: '2.0',
  id: 1,
  method: 'initialize',
  params: { protocolVersion: 1, clientCapabilities: { fs: { readTextFile: true, writeTextFile: true } } }
}) + '\n');
// Expected: JSON-RPC response on stdout
// Actual: No output, process hangs
```

## The Fix

This patch inserts an early check for `--experimental-acp` at the very beginning of `main()`, **before** `patchStdio()` runs. When ACP mode is detected, it skips the stdio patching and goes directly to the Zed integration handler.

## Installation

Two methods are available:

### Method 1: Shell script with `patch` command

```bash
git clone https://github.com/Rishirandhawa/gemini-cli-acp-patch.git
cd gemini-cli-acp-patch

# Auto-detect gemini-cli location
./apply-patch.sh

# Or specify path manually
./apply-patch.sh /path/to/@google/gemini-cli
```

### Method 2: Node.js script

```bash
git clone https://github.com/Rishirandhawa/gemini-cli-acp-patch.git
cd gemini-cli-acp-patch

# Auto-detect gemini-cli location
node patch.js

# Or specify path to gemini.js manually
node patch.js /path/to/@google/gemini-cli/dist/src/gemini.js
```

### Manual patch application

If you prefer to apply the patch manually:

```bash
# Find your gemini-cli installation
GEMINI_CLI=$(npm root -g)/@google/gemini-cli

# Apply the patch
cd $GEMINI_CLI
patch -p1 < /path/to/gemini-acp.patch
```

## Verification

After patching, test that ACP mode responds to JSON-RPC:

```javascript
const { spawn } = require('child_process');

const gemini = spawn('gemini', ['--experimental-acp'], {
  stdio: ['pipe', 'pipe', 'pipe']
});

gemini.stdout.on('data', d => console.log('Response:', d.toString()));

const msg = JSON.stringify({
  jsonrpc: '2.0',
  id: 1,
  method: 'initialize',
  params: { 
    protocolVersion: 1, 
    clientCapabilities: { 
      fs: { readTextFile: true, writeTextFile: true } 
    } 
  }
}) + '\n';

gemini.stdin.write(msg);
// Should output: {"jsonrpc":"2.0","id":1,"result":{"protocolVersion":1,"authMethods":[...],...}}
```

## Reverting

### Using shell script

```bash
./revert-patch.sh

# Or with explicit path
./revert-patch.sh /path/to/@google/gemini-cli
```

### Manual revert

```bash
# Find your installation
GEMINI_PATH=$(npm root -g)/@google/gemini-cli/dist/src

# Option 1: Restore from backup (if available)
cp "$GEMINI_PATH/gemini.js.backup" "$GEMINI_PATH/gemini.js"

# Option 2: Reverse patch
cd $(npm root -g)/@google/gemini-cli
patch -R -p1 < /path/to/gemini-acp.patch
```

## Files

| File | Description |
|------|-------------|
| `gemini-acp.patch` | Unified diff format patch for use with `patch` command |
| `apply-patch.sh` | Shell script to apply the patch |
| `revert-patch.sh` | Shell script to revert the patch |
| `patch.js` | Node.js script that applies the patch programmatically |

## Note

This patch needs to be re-applied after updating `@google/gemini-cli`. Hopefully this fix will be merged upstream.

## License

MIT
