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

```bash
# 1. Install gemini-cli globally (if not already installed)
npm install -g @google/gemini-cli

# 2. Clone and run the patch
git clone https://github.com/Rishirandhawa/gemini-cli-acp-patch.git
cd gemini-cli-acp-patch
node patch.js
```

### Manual Path

If auto-detection doesn't find your installation:

```bash
# Find your gemini-cli installation
npm root -g
# Output example: /Users/you/.nvm/versions/node/v22.18.0/lib/node_modules

# Run patch with explicit path
node patch.js /path/to/node_modules/@google/gemini-cli/dist/src/gemini.js
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

## Using with Zed

After applying the patch:

1. Restart Zed
2. Open the Agent panel (Cmd+?)
3. Click + to start a new Gemini CLI thread
4. Gemini should now initialize correctly

## Reverting

The patch creates a backup file. To revert:

```bash
# Find your installation
GEMINI_PATH=$(npm root -g)/@google/gemini-cli/dist/src

# Restore backup
cp "$GEMINI_PATH/gemini.js.backup" "$GEMINI_PATH/gemini.js"
```

## Note

This patch needs to be re-applied after updating `@google/gemini-cli`. Hopefully this fix will be merged upstream.

## License

MIT
