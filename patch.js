#!/usr/bin/env node

/**
 * Patch for @google/gemini-cli to fix ACP mode hanging when running as subprocess with piped stdio.
 * 
 * Issue: When running `gemini --experimental-acp` as a subprocess with piped stdio,
 * the CLI produces no output and hangs indefinitely because stdin is consumed by
 * readStdin() before the ACP connection can use it for JSON-RPC communication.
 * 
 * Fix: Add early exit for ACP mode before sandbox/relaunch logic.
 */

const fs = require('fs');
const path = require('path');

// Code to insert before the sandbox check
const PATCH_CODE = `
    // [PATCHED] Early exit for ACP mode - must happen before sandbox/relaunch logic
    // to preserve stdin for JSON-RPC communication. ACP mode uses stdin/stdout
    // for the JSON-RPC protocol, so we cannot let readStdin() consume it or
    // let relaunchAppInChildProcess interfere with the streams.
    if (argv.experimentalAcp) {
        const config = await loadCliConfig(settings.merged, sessionId, argv);
        return runZedIntegration(config, settings, argv);
    }
`;

// The marker to find where to insert the patch
const MARKER = `// hop into sandbox if we are outside and sandboxing is enabled`;
const PATCH_MARKER = `// [PATCHED] Early exit for ACP mode`;

function findGeminiCliPath() {
    // Try to find @google/gemini-cli in common locations
    const possiblePaths = [];
    
    // Check npm global
    const npmGlobalPrefix = process.env.npm_config_prefix || 
        (process.platform === 'win32' ? path.join(process.env.APPDATA || '', 'npm') : '/usr/local');
    possiblePaths.push(path.join(npmGlobalPrefix, 'lib', 'node_modules', '@google', 'gemini-cli'));
    
    // Check pnpm global
    const pnpmHome = process.env.PNPM_HOME || path.join(process.env.HOME || '', 'Library', 'pnpm');
    possiblePaths.push(path.join(pnpmHome, 'global', '5', 'node_modules', '@google', 'gemini-cli'));
    possiblePaths.push(path.join(pnpmHome, 'global', 'node_modules', '@google', 'gemini-cli'));
    
    // Check relative to this script (sibling install)
    possiblePaths.push(path.join(__dirname, '..', '@google', 'gemini-cli'));
    
    // Check npm root -g output style paths
    const homeDir = process.env.HOME || '';
    possiblePaths.push(path.join(homeDir, '.npm-global', 'lib', 'node_modules', '@google', 'gemini-cli'));
    possiblePaths.push(path.join(homeDir, '.nvm', 'versions', 'node', process.version, 'lib', 'node_modules', '@google', 'gemini-cli'));
    
    for (const p of possiblePaths) {
        const geminiJsPath = path.join(p, 'dist', 'src', 'gemini.js');
        if (fs.existsSync(geminiJsPath)) {
            return geminiJsPath;
        }
    }
    
    return null;
}

function applyPatch(filePath) {
    console.log(`Reading ${filePath}...`);
    let content = fs.readFileSync(filePath, 'utf8');
    
    // Check if already patched
    if (content.includes(PATCH_MARKER)) {
        console.log('File is already patched. Skipping.');
        return true;
    }
    
    // Find the marker
    const markerIndex = content.indexOf(MARKER);
    if (markerIndex === -1) {
        console.error('Could not find insertion point. The file structure may have changed.');
        return false;
    }
    
    // Insert patch before the marker
    const before = content.substring(0, markerIndex);
    const after = content.substring(markerIndex);
    const patchedContent = before + PATCH_CODE + '\n    ' + after;
    
    // Backup original
    const backupPath = filePath + '.backup';
    if (!fs.existsSync(backupPath)) {
        fs.writeFileSync(backupPath, content);
        console.log(`Backup created at ${backupPath}`);
    }
    
    // Write patched file
    fs.writeFileSync(filePath, patchedContent);
    console.log('Patch applied successfully!');
    return true;
}

function main() {
    console.log('Gemini CLI ACP Patch');
    console.log('====================');
    console.log('');
    
    // Allow passing path as argument
    let targetPath = process.argv[2];
    
    if (!targetPath) {
        console.log('Searching for @google/gemini-cli installation...');
        targetPath = findGeminiCliPath();
    }
    
    if (!targetPath) {
        console.error('');
        console.error('Could not find @google/gemini-cli installation.');
        console.error('');
        console.error('Please provide the path to gemini.js manually:');
        console.error('  gemini-cli-acp-patch /path/to/@google/gemini-cli/dist/src/gemini.js');
        console.error('');
        console.error('You can find it by running:');
        console.error('  npm root -g   # then look in @google/gemini-cli/dist/src/gemini.js');
        console.error('  pnpm root -g  # then look in @google/gemini-cli/dist/src/gemini.js');
        process.exit(1);
    }
    
    if (!fs.existsSync(targetPath)) {
        console.error(`File not found: ${targetPath}`);
        process.exit(1);
    }
    
    console.log(`Found gemini.js at: ${targetPath}`);
    console.log('');
    
    const success = applyPatch(targetPath);
    process.exit(success ? 0 : 1);
}

main();
