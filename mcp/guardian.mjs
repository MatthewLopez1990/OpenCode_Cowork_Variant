#!/usr/bin/env node
// ============================================================
//  OpenCode Cowork Guardian — MCP Directory Sandbox Server
//  ZERO DEPENDENCIES — implements MCP JSON-RPC over stdio directly.
//  No npm packages needed. Works with bun, node, or deno.
// ============================================================

import path from "node:path";
import fs from "node:fs";
import os from "node:os";
import { createInterface } from "node:readline";

const PROJECT_DIR = process.cwd();
const HOME_DIR = os.homedir();
const SERVER_NAME = "opencode-cowork-guardian";
const SERVER_VERSION = "1.0.0";

// ── Path Validation ─────────────────────────────────────────

function resolvePath(inputPath) {
  let p = inputPath;
  if (p.startsWith("~/") || p.startsWith("~\\")) p = path.join(HOME_DIR, p.slice(2));
  if (p.startsWith("$HOME/") || p.startsWith("$HOME\\")) p = path.join(HOME_DIR, p.slice(6));
  if (p.includes("%USERPROFILE%")) p = p.replace(/%USERPROFILE%/gi, HOME_DIR);
  if (p.includes("$env:USERPROFILE")) p = p.replace(/\$env:USERPROFILE/gi, HOME_DIR);
  if (p.includes("%APPDATA%")) p = p.replace(/%APPDATA%/gi, process.env.APPDATA || path.join(HOME_DIR, "AppData", "Roaming"));
  if (p.includes("%LOCALAPPDATA%")) p = p.replace(/%LOCALAPPDATA%/gi, process.env.LOCALAPPDATA || path.join(HOME_DIR, "AppData", "Local"));
  if (p.includes("%TEMP%")) p = p.replace(/%TEMP%/gi, os.tmpdir());
  if (!path.isAbsolute(p)) p = path.resolve(PROJECT_DIR, p);
  p = path.normalize(p);
  try { p = fs.realpathSync(p); } catch {
    try { p = path.join(fs.realpathSync(path.dirname(p)), path.basename(p)); } catch {}
  }
  return p;
}

function isInsideProject(resolvedPath) {
  let realProject = PROJECT_DIR;
  try { realProject = fs.realpathSync(PROJECT_DIR); } catch {}
  const n = path.normalize(resolvedPath);
  const np = path.normalize(realProject);
  return n === np || n.startsWith(np + path.sep);
}

const BLOCKED_FOLDERS = ["desktop", "documents", "downloads", "movies", "music", "pictures", "public", "onedrive", "dropbox", "icloud"];

function containsBlockedFolder(resolvedPath) {
  const lower = resolvedPath.toLowerCase();
  const homeLower = HOME_DIR.toLowerCase();
  if (!lower.startsWith(homeLower)) return null;
  const parts = resolvedPath.slice(HOME_DIR.length).split(path.sep).filter(Boolean);
  for (const part of parts) {
    if (BLOCKED_FOLDERS.includes(part.toLowerCase())) return part;
    if (part.toLowerCase().startsWith("onedrive")) return part;
  }
  return null;
}

// ── Tool Handlers ───────────────────────────────────────────

function handleValidatePath(args) {
  const filePath = args.file_path;
  if (!filePath) return { content: [{ type: "text", text: JSON.stringify({ allowed: false, reason: "file_path is required" }) }], isError: true };

  const resolved = resolvePath(filePath);
  const inside = isInsideProject(resolved);
  const blocked = containsBlockedFolder(resolved);

  if (!inside) {
    return {
      content: [{ type: "text", text: JSON.stringify({
        allowed: false, path: filePath, resolved_path: resolved, project_directory: PROJECT_DIR,
        reason: `BLOCKED: "${filePath}" resolves outside the project directory "${PROJECT_DIR}". Save inside the project instead.`
      }, null, 2) }],
      isError: true
    };
  }
  if (blocked) {
    return {
      content: [{ type: "text", text: JSON.stringify({
        allowed: false, path: filePath, resolved_path: resolved, project_directory: PROJECT_DIR,
        reason: `BLOCKED: references protected folder "${blocked}". Save inside the project instead.`
      }, null, 2) }],
      isError: true
    };
  }
  return {
    content: [{ type: "text", text: JSON.stringify({
      allowed: true, path: filePath, resolved_path: resolved, project_directory: PROJECT_DIR,
      reason: "Path is inside the project directory. Proceed."
    }, null, 2) }]
  };
}

function handleGetStatus() {
  return {
    content: [{ type: "text", text: JSON.stringify({
      project_directory: PROJECT_DIR, home_directory: HOME_DIR, platform: process.platform, status: "active",
      rules: [
        "All file writes must be inside: " + PROJECT_DIR,
        "Blocked folders: Desktop, Documents, Downloads, OneDrive, etc.",
        "Call validate_path before every file write operation"
      ]
    }, null, 2) }]
  };
}

// ── Tool Definitions ────────────────────────────────────────

const TOOLS = [
  {
    name: "validate_path",
    description: "REQUIRED: Call this BEFORE any file write, edit, move, copy, or delete. Returns whether the path is allowed.",
    inputSchema: {
      type: "object",
      properties: {
        file_path: { type: "string", description: "The file path to validate" },
        operation: { type: "string", description: "The operation: write, edit, delete, move, copy" }
      },
      required: ["file_path"]
    }
  },
  {
    name: "get_sandbox_status",
    description: "Returns the current sandbox configuration and rules.",
    inputSchema: { type: "object", properties: {} }
  }
];

// ── MCP JSON-RPC Protocol (stdio) ───────────────────────────

function sendResponse(id, result) {
  const msg = JSON.stringify({ jsonrpc: "2.0", id, result });
  process.stdout.write(`Content-Length: ${Buffer.byteLength(msg)}\r\n\r\n${msg}`);
}

function sendError(id, code, message) {
  const msg = JSON.stringify({ jsonrpc: "2.0", id, error: { code, message } });
  process.stdout.write(`Content-Length: ${Buffer.byteLength(msg)}\r\n\r\n${msg}`);
}

function sendNotification(method, params) {
  const msg = JSON.stringify({ jsonrpc: "2.0", method, params });
  process.stdout.write(`Content-Length: ${Buffer.byteLength(msg)}\r\n\r\n${msg}`);
}

function handleRequest(request) {
  const { id, method, params } = request;

  switch (method) {
    case "initialize":
      sendResponse(id, {
        protocolVersion: "2024-11-05",
        capabilities: { tools: {} },
        serverInfo: { name: SERVER_NAME, version: SERVER_VERSION }
      });
      break;

    case "notifications/initialized":
      // Client is ready — no response needed
      break;

    case "tools/list":
      sendResponse(id, { tools: TOOLS });
      break;

    case "tools/call": {
      const toolName = params?.name;
      const toolArgs = params?.arguments || {};
      let result;
      if (toolName === "validate_path") {
        result = handleValidatePath(toolArgs);
      } else if (toolName === "get_sandbox_status") {
        result = handleGetStatus();
      } else {
        sendError(id, -32601, `Unknown tool: ${toolName}`);
        return;
      }
      sendResponse(id, result);
      break;
    }

    case "ping":
      sendResponse(id, {});
      break;

    default:
      if (id !== undefined) {
        sendError(id, -32601, `Method not found: ${method}`);
      }
  }
}

// ── Message Parser (Content-Length framing) ──────────────────

let buffer = "";
let contentLength = -1;

process.stdin.on("data", (chunk) => {
  buffer += chunk.toString();

  while (true) {
    if (contentLength === -1) {
      const headerEnd = buffer.indexOf("\r\n\r\n");
      if (headerEnd === -1) break;
      const header = buffer.slice(0, headerEnd);
      const match = header.match(/Content-Length:\s*(\d+)/i);
      if (!match) { buffer = buffer.slice(headerEnd + 4); continue; }
      contentLength = parseInt(match[1], 10);
      buffer = buffer.slice(headerEnd + 4);
    }

    if (buffer.length < contentLength) break;

    const body = buffer.slice(0, contentLength);
    buffer = buffer.slice(contentLength);
    contentLength = -1;

    try {
      const request = JSON.parse(body);
      handleRequest(request);
    } catch (e) {
      process.stderr.write(`Guardian parse error: ${e.message}\n`);
    }
  }
});

process.stdin.resume();
process.stderr.write(`Guardian MCP server started (project: ${PROJECT_DIR})\n`);
