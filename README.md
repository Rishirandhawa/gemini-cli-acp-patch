# gemini-cli-acp-patch

Patch for `@google/gemini-cli` to fix ACP mode hanging when running as a subprocess with piped stdio.

## The Problem

When running `gemini --experimental-acp` as a subprocess with piped stdio, the CLI produces no output and hangs indefinitely without responding to JSON-RPC initialize messages.

```javascript
const { spawn } = require('child_process');

const gemini = spawn('gemini', ['--experimental-acp'], {
  stdio: ['pipe', 'pipe', 'pipe']
});

// Send ACP initialize message
const msg = JSON.stringify({
  jsonrpc: '2.0',
  id: 1,
  method: 'initialize',
  params: { protocolVersion: 1, clientCapabilities: {} }
}) + '\n';

gemini.stdin.write(msg);
// Expected: JSON-RPC response on stdout
// Actual: No output, process hangs
```

## Root Cause

The CLI's stdin is consumed by `readStdin()` in the sandbox initialization path before `runZedIntegration()` can use it for JSON-RPC communication.

## The Fix

This patch adds an early exit for ACP mode before any sandbox/relaunch logic runs, ensuring stdin remains available for the ACP JSON-RPC protocol.

## Installation

```bash
# First install gemini-cli
npm install -g @google/gemini-cli

# Then install the patch tool
npm install -g github:Rishirandhawa/gemini-cli-acp-patch

# Run the patch
gemini-cli-acp-patch
```

## Manual Path

If auto-detection doesn't find your installation:

```bash
# Find your gemini-cli installation
npm root -g

# Run patch with explicit path
gemini-cli-acp-patch /path/to/node_modules/@google/gemini-cli/dist/src/gemini.js
```

## Verification

After patching, the ACP mode should respond to JSON-RPC messages:

```javascript
const { spawn } = require('child_process');

const gemini = spawn('gemini', ['--experimental-acp'], {
  stdio: ['pipe', 'pipe', 'pipe']
});

gemini.stdout.on('data', d => console.log('[STDOUT]', d.toString()));
gemini.stderr.on('data', d => console.log('[STDERR]', d.toString()));

const msg = JSON.stringify({
  jsonrpc: '2.0',
  id: 1,
  method: 'initialize',
  params: { protocolVersion: 1, clientCapabilities: {} }
}) + '\n';

gemini.stdin.write(msg);
// Should now receive JSON-RPC response with auth methods and agent capabilities
```

## Reverting

The patch creates a backup file (`gemini.js.backup`). To revert:

```bash
# Find your installation
GEMINI_PATH=$(npm root -g)/@google/gemini-cli/dist/src

# Restore backup
cp "$GEMINI_PATH/gemini.js.backup" "$GEMINI_PATH/gemini.js"
```

## License

MIT
