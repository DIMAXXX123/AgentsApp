#!/usr/bin/env node

/**
 * Development script with automatic preload script patching
 * This sets up the environment for Claude Code OAuth credential interception
 */

import { spawn } from 'child_process';
import { join } from 'path';
import { fileURLToPath } from 'url';
import { dirname } from 'path';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

// Set up environment variables for preload script patching
const env = {
  ...process.env,
  NODE_OPTIONS: '--require ./auth/preload-script.cjs',
  CLAUDE_CREDENTIALS_PATH: join(process.env.HOME || process.env.USERPROFILE || process.cwd(), '.claude-credentials.json'),
  DEBUG_PRELOAD_SCRIPT: '1'
};

// Allow overriding Claude CLI path via env (helps on Windows where auto-detect can fail)
const claudePathFromEnv = process.env.CLAUDE_PATH;
const extraArgs = claudePathFromEnv ? ['--claude-path', claudePathFromEnv] : [];

console.log('🔧 Starting backend with Claude OAuth preload script patching...');
console.log('📁 Preload script:', './auth/preload-script.cjs');
console.log('🗄️ Credentials path:', env.CLAUDE_CREDENTIALS_PATH);
console.log('🐛 Debug logging: enabled');
console.log('');

// Start the development server with dotenvx and tsx
const child = spawn('npx', [
  'dotenvx',
  'run',
  '--env-file=../.env',
  '--',
  'tsx',
  'watch',
  'cli/node.ts',
  '--debug',
  ...extraArgs
], {
  env,
  stdio: 'inherit',
  shell: true
});

child.on('error', (error) => {
  console.error('❌ Failed to start development server:', error);
  process.exit(1);
});

child.on('close', (code) => {
  console.log(`\n🛑 Development server exited with code ${code}`);
  process.exit(code);
});

// Handle process termination
process.on('SIGINT', () => {
  console.log('\n🛑 Shutting down development server...');
  child.kill('SIGINT');
});

process.on('SIGTERM', () => {
  console.log('\n🛑 Shutting down development server...');
  child.kill('SIGTERM');
});