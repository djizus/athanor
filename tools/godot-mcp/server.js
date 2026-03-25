/**
 * Godot MCP Server — Exposes Godot engine operations as MCP tools.
 * Run on a machine with GPU + Godot installed.
 * Connect via SSH tunnel or direct HTTP.
 *
 * Usage:
 *   GODOT_PATH=/path/to/godot PROJECT_PATH=/path/to/client node server.js
 *
 * Environment:
 *   GODOT_PATH  — Path to Godot binary (default: "godot")
 *   PROJECT_PATH — Path to Godot project directory (default: "./client")
 *   PORT — Server port (default: 8080)
 *   SCREENSHOT_DIR — Where screenshots go (default: PROJECT_PATH/screenshots/mcp)
 */

import { createServer } from "node:http";
import { randomUUID } from "node:crypto";
import { spawn, execSync } from "node:child_process";
import { existsSync, mkdirSync, readFileSync, writeFileSync, readdirSync, unlinkSync } from "node:fs";
import { join, resolve } from "node:path";
import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StreamableHTTPServerTransport } from "@modelcontextprotocol/sdk/server/streamableHttp.js";
import { z } from "zod";

// --- Config ---
const GODOT = process.env.GODOT_PATH || "godot";
const PROJECT = resolve(process.env.PROJECT_PATH || "./client");
const PORT = parseInt(process.env.PORT || "8080");
const SCREENSHOT_DIR = resolve(process.env.SCREENSHOT_DIR || join(PROJECT, "screenshots", "mcp"));

// Ensure screenshot dir exists
mkdirSync(SCREENSHOT_DIR, { recursive: true });

// --- Godot process management ---
let activeProcess = null;
let processLogs = "";

function killActive() {
  if (activeProcess && !activeProcess.killed) {
    activeProcess.kill("SIGTERM");
    setTimeout(() => {
      if (activeProcess && !activeProcess.killed) activeProcess.kill("SIGKILL");
    }, 2000);
  }
  activeProcess = null;
}

function runGodot(args, { timeout = 30000, captureOutput = true } = {}) {
  return new Promise((resolve, reject) => {
    let stdout = "";
    let stderr = "";
    const proc = spawn(GODOT, args, { cwd: PROJECT, timeout });

    if (captureOutput) {
      proc.stdout.on("data", (d) => { stdout += d.toString(); });
      proc.stderr.on("data", (d) => { stderr += d.toString(); });
    }

    proc.on("close", (code) => {
      resolve({ code, stdout, stderr });
    });

    proc.on("error", (err) => {
      reject(err);
    });
  });
}

function runGodotInteractive(args) {
  killActive();
  processLogs = "";

  activeProcess = spawn(GODOT, args, { cwd: PROJECT });

  activeProcess.stdout.on("data", (d) => {
    processLogs += d.toString();
  });
  activeProcess.stderr.on("data", (d) => {
    processLogs += d.toString();
  });

  activeProcess.on("close", () => {
    activeProcess = null;
  });

  return activeProcess.pid;
}

// --- Platform-specific screenshot ---
function takeScreenshot(filename) {
  const filepath = join(SCREENSHOT_DIR, filename);
  const platform = process.platform;

  try {
    if (platform === "win32") {
      // PowerShell screenshot on Windows
      const ps = `
        Add-Type -AssemblyName System.Windows.Forms
        Add-Type -AssemblyName System.Drawing
        $screen = [System.Windows.Forms.Screen]::PrimaryScreen
        $bitmap = New-Object System.Drawing.Bitmap($screen.Bounds.Width, $screen.Bounds.Height)
        $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
        $graphics.CopyFromScreen($screen.Bounds.Location, [System.Drawing.Point]::Empty, $screen.Bounds.Size)
        $bitmap.Save('${filepath.replace(/\\/g, "\\\\")}')
        $graphics.Dispose()
        $bitmap.Dispose()
      `;
      execSync(`powershell -Command "${ps.replace(/\n/g, " ")}"`, { timeout: 5000 });
    } else if (platform === "linux") {
      // Try scrot, then import (ImageMagick), then xdotool+xwd
      try {
        execSync(`scrot "${filepath}"`, { timeout: 5000 });
      } catch {
        try {
          execSync(`import -window root "${filepath}"`, { timeout: 5000 });
        } catch {
          return { success: false, error: "No screenshot tool found (tried scrot, import)" };
        }
      }
    } else if (platform === "darwin") {
      execSync(`screencapture "${filepath}"`, { timeout: 5000 });
    }

    if (existsSync(filepath)) {
      const data = readFileSync(filepath);
      return { success: true, path: filepath, base64: data.toString("base64"), size: data.length };
    }
    return { success: false, error: "Screenshot file not created" };
  } catch (err) {
    return { success: false, error: err.message };
  }
}

// --- Input simulation ---
function sendMouseClick(x, y, button = "left") {
  const platform = process.platform;
  try {
    if (platform === "win32") {
      const ps = `
        Add-Type -AssemblyName System.Windows.Forms
        [System.Windows.Forms.Cursor]::Position = New-Object System.Drawing.Point(${x}, ${y})
        Add-Type @'
        using System;
        using System.Runtime.InteropServices;
        public class Mouse {
          [DllImport("user32.dll")] public static extern void mouse_event(int dwFlags, int dx, int dy, int dwData, int dwExtraInfo);
        }
'@
        [Mouse]::mouse_event(0x0002, 0, 0, 0, 0)
        Start-Sleep -Milliseconds 50
        [Mouse]::mouse_event(0x0004, 0, 0, 0, 0)
      `;
      execSync(`powershell -Command "${ps.replace(/\n/g, " ")}"`, { timeout: 3000 });
    } else if (platform === "linux") {
      execSync(`xdotool mousemove ${x} ${y} click ${button === "right" ? 3 : 1}`, { timeout: 3000 });
    } else if (platform === "darwin") {
      execSync(`cliclick c:${x},${y}`, { timeout: 3000 });
    }
    return { success: true };
  } catch (err) {
    return { success: false, error: err.message };
  }
}

function sendKeyPress(key) {
  const platform = process.platform;
  try {
    if (platform === "win32") {
      const keyMap = { w: "87", a: "65", s: "83", d: "68", space: "32", escape: "27", enter: "13" };
      const vk = keyMap[key.toLowerCase()] || key;
      const ps = `
        Add-Type @'
        using System;
        using System.Runtime.InteropServices;
        public class Kbd {
          [DllImport("user32.dll")] public static extern void keybd_event(byte bVk, byte bScan, int dwFlags, int dwExtraInfo);
        }
'@
        [Kbd]::keybd_event(${vk}, 0, 0, 0)
        Start-Sleep -Milliseconds 50
        [Kbd]::keybd_event(${vk}, 0, 2, 0)
      `;
      execSync(`powershell -Command "${ps.replace(/\n/g, " ")}"`, { timeout: 3000 });
    } else if (platform === "linux") {
      execSync(`xdotool key ${key}`, { timeout: 3000 });
    } else if (platform === "darwin") {
      execSync(`cliclick kp:${key}`, { timeout: 3000 });
    }
    return { success: true };
  } catch (err) {
    return { success: false, error: err.message };
  }
}

// --- MCP Server ---
function createGodotMcpServer() {
  const server = new McpServer({
    name: "godot-mcp",
    version: "1.0.0",
  });

  // Tool: Parse check
  server.registerTool(
    "godot_parse_check",
    {
      title: "Godot Parse Check",
      description: "Run godot --headless --quit to validate all scripts parse correctly. Returns errors if any.",
      inputSchema: z.object({}),
    },
    async () => {
      const result = await runGodot(["--headless", "--quit"], { timeout: 60000 });
      const errors = (result.stdout + result.stderr)
        .split("\n")
        .filter((l) => /error|FAIL|Parser Error/i.test(l) && !/ext_resource.*invalid UID/i.test(l));
      return {
        content: [{
          type: "text",
          text: `Exit code: ${result.code}\nErrors (${errors.length}):\n${errors.join("\n") || "(none)"}`,
        }],
      };
    }
  );

  // Tool: Run tests
  server.registerTool(
    "godot_run_tests",
    {
      title: "Run All Tests",
      description: "Run all test_*.gd scripts in the tests/ directory. Returns pass/fail summary.",
      inputSchema: z.object({}),
    },
    async () => {
      const testsDir = join(PROJECT, "tests");
      if (!existsSync(testsDir)) {
        return { content: [{ type: "text", text: "No tests/ directory found" }] };
      }
      const testFiles = readdirSync(testsDir).filter((f) => f.startsWith("test_") && f.endsWith(".gd"));
      const results = [];

      for (const file of testFiles) {
        const r = await runGodot(["--headless", "--script", `res://tests/${file}`], { timeout: 30000 });
        const output = r.stdout + r.stderr;
        const passMatch = output.match(/(\d+) passed/);
        const failMatch = output.match(/(\d+) failed/);
        results.push({
          file,
          passed: passMatch ? parseInt(passMatch[1]) : 0,
          failed: failMatch ? parseInt(failMatch[1]) : 0,
          output: output.split("\n").filter((l) => /pass|fail|error/i.test(l)).join("\n"),
        });
      }

      const totalPassed = results.reduce((s, r) => s + r.passed, 0);
      const totalFailed = results.reduce((s, r) => s + r.failed, 0);
      const summary = results.map((r) => `  ${r.file}: ${r.passed} passed, ${r.failed} failed`).join("\n");

      return {
        content: [{
          type: "text",
          text: `${totalPassed} passed, ${totalFailed} failed across ${results.length} suites\n\n${summary}`,
        }],
      };
    }
  );

  // Tool: Capture scene screenshots
  server.registerTool(
    "godot_capture_scene",
    {
      title: "Capture Scene Screenshots",
      description: "Run a scene or test script with --write-movie to capture PNG frames. Returns frame file paths. Uses GPU rendering.",
      inputSchema: z.object({
        scene_or_script: z.string().describe("Scene path (res://...) or script path for --script flag"),
        fps: z.number().default(10).describe("Frames per second (default 10)"),
        frame_count: z.number().default(30).describe("Total frames to capture (default 30)"),
        use_script: z.boolean().default(false).describe("If true, use --script flag instead of loading as main scene"),
      }),
    },
    async ({ scene_or_script, fps, frame_count, use_script }) => {
      const folder = `capture_${Date.now()}`;
      const outDir = join(SCREENSHOT_DIR, folder);
      mkdirSync(outDir, { recursive: true });

      const args = [
        "--write-movie", join(outDir, "frame.png"),
        "--fixed-fps", String(fps),
        "--quit-after", String(frame_count),
      ];

      if (use_script) {
        args.push("--script", scene_or_script);
      } else {
        args.push("--main-pack", scene_or_script);
      }

      const result = await runGodot(args, { timeout: frame_count * 1000 + 10000 });

      const frames = existsSync(outDir)
        ? readdirSync(outDir).filter((f) => f.endsWith(".png")).sort()
        : [];

      return {
        content: [{
          type: "text",
          text: `Captured ${frames.length} frames to ${outDir}\nExit: ${result.code}\nFrames: ${frames.join(", ")}`,
        }],
      };
    }
  );

  // Tool: Read a captured frame as base64 image
  server.registerTool(
    "godot_read_frame",
    {
      title: "Read Captured Frame",
      description: "Read a captured screenshot frame and return it as base64-encoded PNG.",
      inputSchema: z.object({
        path: z.string().describe("Absolute path to the PNG file"),
      }),
    },
    async ({ path: filePath }) => {
      if (!existsSync(filePath)) {
        return { content: [{ type: "text", text: `File not found: ${filePath}` }] };
      }
      const data = readFileSync(filePath);
      return {
        content: [{
          type: "image",
          data: data.toString("base64"),
          mimeType: "image/png",
        }],
      };
    }
  );

  // Tool: Launch Godot interactively
  server.registerTool(
    "godot_launch",
    {
      title: "Launch Godot",
      description: "Launch Godot with GPU rendering for interactive testing. Returns PID. Use godot_screenshot and godot_click to interact.",
      inputSchema: z.object({
        scene: z.string().optional().describe("Scene to run (res://...). Omit for project default."),
        extra_args: z.array(z.string()).default([]).describe("Extra CLI arguments"),
      }),
    },
    async ({ scene, extra_args }) => {
      const args = [...extra_args];
      if (scene) args.push(scene);
      const pid = runGodotInteractive(args);
      return {
        content: [{ type: "text", text: `Godot launched with PID ${pid}` }],
      };
    }
  );

  // Tool: Stop Godot
  server.registerTool(
    "godot_stop",
    {
      title: "Stop Godot",
      description: "Kill the running Godot process.",
      inputSchema: z.object({}),
    },
    async () => {
      killActive();
      return { content: [{ type: "text", text: "Godot process stopped" }] };
    }
  );

  // Tool: Screenshot of running Godot
  server.registerTool(
    "godot_screenshot",
    {
      title: "Screenshot",
      description: "Take a screenshot of the current screen (captures the Godot window). Returns base64 PNG.",
      inputSchema: z.object({
        filename: z.string().default("screenshot.png").describe("Filename for the screenshot"),
      }),
    },
    async ({ filename }) => {
      const result = takeScreenshot(filename);
      if (result.success) {
        return {
          content: [{
            type: "image",
            data: result.base64,
            mimeType: "image/png",
          }],
        };
      }
      return { content: [{ type: "text", text: `Screenshot failed: ${result.error}` }] };
    }
  );

  // Tool: Click
  server.registerTool(
    "godot_click",
    {
      title: "Mouse Click",
      description: "Send a mouse click at screen coordinates (x, y). Use after godot_launch.",
      inputSchema: z.object({
        x: z.number().describe("X screen coordinate"),
        y: z.number().describe("Y screen coordinate"),
        button: z.enum(["left", "right"]).default("left"),
      }),
    },
    async ({ x, y, button }) => {
      const result = sendMouseClick(x, y, button);
      return {
        content: [{ type: "text", text: result.success ? `Clicked (${x}, ${y}) ${button}` : `Click failed: ${result.error}` }],
      };
    }
  );

  // Tool: Key press
  server.registerTool(
    "godot_press_key",
    {
      title: "Press Key",
      description: "Send a keyboard key press. Common keys: w, a, s, d, space, escape, enter, 1, 2, 3.",
      inputSchema: z.object({
        key: z.string().describe("Key to press (e.g. 'w', 'space', 'escape')"),
      }),
    },
    async ({ key }) => {
      const result = sendKeyPress(key);
      return {
        content: [{ type: "text", text: result.success ? `Pressed '${key}'` : `Key press failed: ${result.error}` }],
      };
    }
  );

  // Tool: Read logs
  server.registerTool(
    "godot_logs",
    {
      title: "Read Godot Logs",
      description: "Read stdout/stderr from the currently running (or last run) Godot process.",
      inputSchema: z.object({
        tail: z.number().default(50).describe("Number of lines from the end"),
      }),
    },
    async ({ tail }) => {
      const lines = processLogs.split("\n");
      const output = lines.slice(-tail).join("\n");
      return {
        content: [{ type: "text", text: output || "(no logs)" }],
      };
    }
  );

  // Tool: Wait
  server.registerTool(
    "godot_wait",
    {
      title: "Wait",
      description: "Wait for a number of milliseconds. Useful between click and screenshot.",
      inputSchema: z.object({
        ms: z.number().default(1000).describe("Milliseconds to wait"),
      }),
    },
    async ({ ms }) => {
      await new Promise((r) => setTimeout(r, ms));
      return { content: [{ type: "text", text: `Waited ${ms}ms` }] };
    }
  );

  return server;
}

// --- HTTP Transport ---
const transports = {};

const httpServer = createServer(async (req, res) => {
  // CORS
  res.setHeader("Access-Control-Allow-Origin", "*");
  res.setHeader("Access-Control-Allow-Methods", "GET, POST, OPTIONS, DELETE");
  res.setHeader("Access-Control-Allow-Headers", "Content-Type, mcp-session-id");

  if (req.method === "OPTIONS") {
    res.writeHead(204);
    res.end();
    return;
  }

  // Health check
  if (req.url === "/health") {
    res.writeHead(200, { "Content-Type": "application/json" });
    res.end(JSON.stringify({
      status: "ok",
      godot: GODOT,
      project: PROJECT,
      activeProcess: activeProcess ? activeProcess.pid : null,
    }));
    return;
  }

  // MCP endpoint
  if (req.url === "/mcp") {
    let body = "";
    req.on("data", (chunk) => { body += chunk; });
    req.on("end", async () => {
      try {
        const parsed = body ? JSON.parse(body) : undefined;
        const sessionId = req.headers["mcp-session-id"];

        if (req.method === "GET" && sessionId && transports[sessionId]) {
          await transports[sessionId].handleRequest(req, res);
          return;
        }

        if (req.method === "POST") {
          if (sessionId && transports[sessionId]) {
            await transports[sessionId].handleRequest(req, res, parsed);
            return;
          }

          // New session
          const transport = new StreamableHTTPServerTransport({
            sessionIdGenerator: () => randomUUID(),
            onsessioninitialized: (id) => {
              transports[id] = transport;
              console.log(`[MCP] Session: ${id}`);
            },
          });

          transport.onclose = () => {
            if (transport.sessionId) delete transports[transport.sessionId];
          };

          const server = createGodotMcpServer();
          await server.connect(transport);
          await transport.handleRequest(req, res, parsed);
          return;
        }

        if (req.method === "DELETE" && sessionId && transports[sessionId]) {
          await transports[sessionId].handleRequest(req, res, parsed);
          return;
        }

        res.writeHead(400, { "Content-Type": "application/json" });
        res.end(JSON.stringify({ error: "Bad request" }));
      } catch (err) {
        console.error("[MCP] Error:", err);
        res.writeHead(500, { "Content-Type": "application/json" });
        res.end(JSON.stringify({ error: err.message }));
      }
    });
    return;
  }

  res.writeHead(404);
  res.end("Not found");
});

httpServer.listen(PORT, "0.0.0.0", () => {
  console.log(`
╔══════════════════════════════════════════════╗
║         Godot MCP Server v1.0.0             ║
╠══════════════════════════════════════════════╣
║  Endpoint: http://0.0.0.0:${String(PORT).padEnd(5)}             ║
║  Godot:    ${GODOT.padEnd(33)}║
║  Project:  ${PROJECT.slice(-33).padEnd(33)}║
╠══════════════════════════════════════════════╣
║  Tools:                                     ║
║    godot_parse_check  — Validate scripts    ║
║    godot_run_tests    — Run test suites     ║
║    godot_capture_scene— Movie frames        ║
║    godot_read_frame   — Read PNG as base64  ║
║    godot_launch       — Interactive Godot   ║
║    godot_stop         — Kill Godot          ║
║    godot_screenshot   — Screen capture      ║
║    godot_click        — Mouse click at x,y  ║
║    godot_press_key    — Keyboard input      ║
║    godot_logs         — Read process output ║
║    godot_wait         — Pause between ops   ║
╠══════════════════════════════════════════════╣
║  Connect via SSH tunnel:                    ║
║  ssh -R ${PORT}:localhost:${PORT} user@server         ║
╚══════════════════════════════════════════════╝
  `);
});
