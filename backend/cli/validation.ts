/**
 * Shared CLI validation utilities
 *
 * Common validation functions used across different runtime CLI entry points.
 */

import { createRequire } from "node:module";
import type { Runtime } from "../runtime/types.ts";

// Path to the SDK's bundled cli.js. The SDK spawns `node <path>` to run it,
// so the path MUST be a JS file readable by Node — not the system `claude`
// binary (e.g. on Windows it's a Bun-compiled .exe).
const requireFromHere = createRequire(import.meta.url);
const SDK_BUNDLED_CLI = requireFromHere.resolve("@anthropic-ai/claude-code/cli.js");

/**
 * Detects if a file is an asdf shim by checking for the asdf exec pattern
 * @param runtime - Runtime abstraction for system operations
 * @param filePath - Path to the file to check
 * @returns boolean - True if file is an asdf shim
 */
async function isAsdfShim(
  runtime: Runtime,
  filePath: string,
): Promise<boolean> {
  try {
    const content = await runtime.readTextFile(filePath);
    return content.includes("asdf exec");
  } catch {
    return false;
  }
}

/**
 * Resolves the actual executable path for asdf shims
 * @param runtime - Runtime abstraction for system operations
 * @param command - The command name (e.g., "claude")
 * @returns Promise<string> - The resolved path to the actual executable
 */
async function resolveAsdfExecutablePath(
  runtime: Runtime,
  command: string,
): Promise<string> {
  const asdfWhichResult = await runtime.runCommand("asdf", ["which", command]);

  if (!asdfWhichResult.success || !asdfWhichResult.stdout.trim()) {
    throw new Error(`Failed to resolve asdf executable for ${command}`);
  }

  return asdfWhichResult.stdout.trim();
}

/**
 * Extracts actual executable path from bash script
 * Parses 'exec "path"' pattern from migrate-installer wrapper scripts
 * @param runtime - Runtime abstraction for system operations
 * @param scriptPath - Path to the script file
 * @returns string - The extracted executable path or original path if no match
 */
async function resolveWrapperScript(
  runtime: Runtime,
  scriptPath: string,
): Promise<string> {
  // Skip binary executables — readTextFile on a binary lets random byte
  // sequences match the `exec "..."` regex (e.g. .exe contains 'echo hi')
  // and the SDK then tries to spawn that garbage instead of Claude.
  if (/\.(exe|cmd|bat|com|dll)$/i.test(scriptPath)) {
    return scriptPath;
  }
  try {
    const content = await runtime.readTextFile(scriptPath);
    const match = content.match(/exec\s+"([^"]+)"/);
    return match ? match[1] : scriptPath;
  } catch {
    return scriptPath;
  }
}

/**
 * Resolves symlinks and wrapper scripts to actual executable paths
 * @param runtime - Runtime abstraction for system operations
 * @param claudePath - Initial path to resolve
 * @returns string - The resolved actual executable path
 */
async function resolveExecutablePath(
  runtime: Runtime,
  claudePath: string,
): Promise<string> {
  // Handle symlinks (typical npm install: /usr/local/bin/claude -> node_modules/.bin/claude)
  try {
    const stat = runtime.lstatSync(claudePath);
    if (stat.isSymlink) {
      // Node.js resolves symlinks automatically when executing, so we can use the symlink path
      return claudePath;
    }
  } catch {
    // Silently continue if stat check fails
  }

  // Handle shell scripts (migrate-installer: extract actual executable path)
  return await resolveWrapperScript(runtime, claudePath);
}

/**
 * Validates that the Claude CLI is available and working
 * Uses platform-specific command (`which` on Unix, `where` on Windows) for PATH detection
 * Resolves asdf shims to actual executable paths for SDK compatibility
 * Exits process if Claude CLI is not found or not working
 * @param runtime - Runtime abstraction for system operations
 * @param customPath - Optional custom path to claude executable to validate
 * @returns Promise<string> - The validated path to claude executable (resolved from shims)
 */
export async function validateClaudeCli(
  runtime: Runtime,
  customPath?: string,
): Promise<string> {
  try {
    let claudePath = "";
    const platform = runtime.getPlatform();

    if (customPath) {
      // Use custom path if provided
      claudePath = customPath;
      console.log(`🔍 Validating custom Claude path: ${customPath}`);
    } else {
      // Auto-detect using runtime's findExecutable method
      console.log("🔍 Searching for Claude CLI in PATH...");
      const candidates = await runtime.findExecutable("claude");

      if (candidates.length === 0) {
        console.error("❌ Claude CLI not found in PATH");
        console.error("   Please install claude-code globally:");
        console.error(
          "   Visit: https://claude.ai/code for installation instructions",
        );
        runtime.exit(1);
      }

      // Try each candidate until one works
      let validPath = "";
      for (const candidate of candidates) {
        const testResult = await runtime.runCommand(candidate, ["--version"]);

        if (testResult.success) {
          validPath = candidate;
          break;
        }
      }

      if (!validPath) {
        console.error("❌ Claude CLI found but none are working properly");
        console.error("   Found candidates:", candidates);
        console.error(
          "   Please reinstall claude-code or check your installation",
        );
        runtime.exit(1);
      }

      claudePath = validPath;
    }

    // Resolve all types of wrappers to actual executable paths
    if (platform !== "windows") {
      // Check if the path is an asdf shim and resolve to actual executable (Unix-like systems only)
      if (await isAsdfShim(runtime, claudePath)) {
        console.log(`🔍 Detected asdf shim: ${claudePath}`);
        try {
          const resolvedPath = await resolveAsdfExecutablePath(
            runtime,
            "claude",
          );
          console.log(`📍 Resolved to actual executable: ${resolvedPath}`);
          claudePath = resolvedPath;
        } catch (error) {
          console.error("❌ Failed to resolve asdf executable path");
          console.error(
            `   Error: ${error instanceof Error ? error.message : String(error)}`,
          );
          console.error(
            "   Make sure claude is installed through asdf and properly configured",
          );
          runtime.exit(1);
        }
      } else {
        // Resolve symlinks and wrapper scripts
        claudePath = await resolveExecutablePath(runtime, claudePath);
      }
    } else {
      // Windows: resolve symlinks and wrapper scripts
      claudePath = await resolveExecutablePath(runtime, claudePath);
    }

    // Final validation: verify the resolved path works
    // For custom paths: needed because original path wasn't tested
    // For auto-detected paths: needed because path may have been resolved/changed
    const versionResult = await runtime.runCommand(claudePath, ["--version"]);
    if (versionResult.success) {
      console.log(`✅ Claude CLI found: ${versionResult.stdout.trim()}`);
      console.log(`   Path: ${claudePath}`);
      // The SDK spawns `node <path>` and CAN'T run a native .exe / Bun binary.
      // If the system Claude is one of those, return the SDK's bundled cli.js
      // instead so downstream `pathToClaudeCodeExecutable` works.
      if (/\.(exe|cmd|bat|com)$/i.test(claudePath)) {
        console.log(`   Using SDK bundled cli.js for Node SDK calls: ${SDK_BUNDLED_CLI}`);
        return SDK_BUNDLED_CLI;
      }
      return claudePath;
    } else {
      const pathType = customPath ? "Custom" : "Auto-detected";
      console.error(`❌ ${pathType} Claude path not working after resolution`);
      console.error(
        "   Please check your installation or try a different path",
      );
      runtime.exit(1);
    }
  } catch (error) {
    console.error("❌ Failed to validate Claude CLI");
    console.error(
      `   Error: ${error instanceof Error ? error.message : String(error)}`,
    );
    runtime.exit(1);
  }
}
