## Summary

End-to-end fixes for the Windows installer. Released as `installer-v0.1.11`. Verified by running `install-windows.ps1` 14 times on a real Windows 11 machine until it reached `Installation Complete` and the branded Electron app launched cleanly with the right title bar, model, and UI. The branded `ChatFortAI Cowork` chat send was also verified working against the real OpenRouter API after swapping the placeholder key for a real one.

The first commit cleans up the `INSTALLER_FAILURE_DETAILS_BEGIN/END` markers so the rest of the iteration was driven by real error messages instead of PowerShell `NativeCommandError` boilerplate. Subsequent commits each fix one concrete failure exposed by the now-readable diagnostics.

## Bugs fixed (in the order each one surfaced)

1. **Diagnostic noise** — PS 5.1's `2> $tempfile` wraps the first stderr line of every native command in `NativeCommandError` boilerplate (`+ At line:N char:N`, `+ CategoryInfo`, `+ FullyQualifiedErrorId`), burying the actual error inside the failure-details block. Switch to `2>&1` pipeline merge with per-line stream classification.

2. **`cloning-application-source` failed when re-running** — partial bun installs left `~/.opencode-cowork-build` populated with broken symlinks and no `.git`. PowerShell's `Remove-Item -Recurse -Force` aborts mid-walk on broken symlinks, and `-ErrorAction SilentlyContinue` silently swallowed the failure; the next `git clone` died with the opaque "destination path … already exists and is not an empty directory". Add a `Remove-DirectoryHard` helper that falls back to `cmd /c rmdir /s /q` (handles broken symlinks) and verifies the directory was actually removed.

3. **`bun add electron@latest`** — the script's `bun add --dev electron@latest electron-builder@24.13.3 …` step pulled `electron@41.3.0` whose `install.js` requires `@electron/get`, which isn't in `electron-builder@24`'s dependency tree. Postinstall failed with `MODULE_NOT_FOUND`. The line was redundant — `package.json` already pins all four packages — so just drop it and let `npm install` resolve from `package.json`.

4. **`packaging-desktop-app` symlink failure** — electron-builder unconditionally extracts `winCodeSign.7z`, which contains macOS dylib symlinks (`libcrypto`, `libssl`). Creating those on Windows requires `SeCreateSymbolicLinkPrivilege` (admin OR Developer Mode), which most end users have neither. Pre-extracting with `-xr!*.dylib` got overwritten on every internal retry; multi-attempt loops never converged because each attempt downloaded *more* signing-tool archives. Surgical fix: install a tiny inline-compiled C# wrapper at `node_modules/.../win/x64/7za.exe` that forwards args verbatim but always exits 0. The two missing files are macOS dylibs unused on `--win --x64` builds. Compiled via `Add-Type -OutputType ConsoleApplication`, no external toolchain needed.

5. **bun install layout broken on Windows** — verified by reproduction: bun's default backend leaves most `node_modules/<pkg>/` directories empty, so `node_modules/.bin/` is empty, so root `package.json`'s postinstall (`patch-package`) fails with `command not found`. `--linker hoisted --backend copyfile` causes ENOENT on lifecycle script enqueueing. Switch to `npm install` (slower but reliable). Falls back to `bun install` if npm isn't on PATH.

6. **npm `EOVERRIDE`** — `package.json` declares `@codemirror/language@^6.12.1` as a dep AND `6.12.2` as an override. npm rejects this and `--force` does NOT bypass the check (verified). Strip the `overrides` block when patching `package.json` for branding.

7. **npm `EUNSUPPORTEDPROTOCOL`** — `packages/vscode/package.json` declares `"@openchamber/ui": "workspace:*"`, which only bun/yarn/pnpm support. Rewrite to `"*"` in all `packages/*/package.json` files; npm resolves the local sibling workspace.

8. **`Write-InstallerLine` rejected blank lines** — its `[Parameter(Mandatory=$true)][string]$Message` validator rejects empty strings, which killed the script *after* npm install had successfully completed. Use `IsNullOrWhiteSpace` as the filter instead of `$null -ne $_`.

9. **PostCSS choked on UTF-8 BOM** — PowerShell 5.1's `Set-Content -Encoding UTF8` prepends a BOM. Vite/PostCSS's JSON loader chokes during `bun run build:web` with `Unexpected token ﻿, … is not valid JSON`. The script already had a `Write-Utf8NoBom` helper for exactly this — use it for the patched `package.json` and `useWindowTitle.ts`.

10. **`HTTP-Referer` pointed at the old repo** — `config/opencode.json.template` still referenced `OpenCode_Cowork_Variant`. OpenRouter uses the Referer for per-app rate-limit attribution, so this was misattributing usage. Updated to the renamed `ChatFortAI-Cowork`.

11. **Silent model-fetch failure** — `python3` was hardcoded and stderr was redirected to `$null`, so when Python wasn't installed (or the OpenRouter call failed) the user got only Claude Sonnet 4.6 in the model picker with no warning. Probe `python3` / `python` / `py`, capture stderr, and warn loudly when only the static default is loaded.

## Test plan

End-to-end repro on Windows 11 (PS 5.1.26100.8115, bun 1.3.13, node v24.15.0, npm 11.12.1, no admin, no Dev Mode):

```powershell
$env:COWORK_APP_NAME = "ChatFortAI Cowork Test"
$env:COWORK_API_KEY = "sk-or-v1-..."
$env:COWORK_GIT_BRANCH = "installer-v0.1.11"
powershell.exe -ExecutionPolicy Bypass -File .\install-windows.ps1
```

Verified outcomes:
- Reaches `STAGE: done` in ~7 minutes (clone + npm install ~2 min + vite build + electron-builder).
- `%LOCALAPPDATA%\<APP_NAME>\<APP_NAME>.exe` produced (~210 MB unpacked).
- NSIS setup at `~\.opencode-cowork-build\electron-dist\<APP_NAME> Setup 1.0.0.exe`.
- Start Menu + Desktop shortcuts created.
- Launching the .exe opens a window titled `<APP_NAME> Projects | <APP_NAME>` with the branded UI, default model "Claude Sonnet 4.6", and the bun web-server backend running.
- Diagnostic log at `%USERPROFILE%\.opencode-cowork-install\install-windows.log` is now readable on failure — each native-command line is tagged `[stdout]` / `[stderr]`, and the `INSTALLER_FAILURE_DETAILS` block surfaces the real error message instead of PowerShell stack noise.
- After replacing the placeholder API key in `~\.config\opencode\opencode.json` with a real OpenRouter key, the chat round-trip works (verified by sending a message from the UI and getting a streaming Claude Sonnet 4.6 reply).

## Known limitation (not fixed in this PR)

The packaged Electron app's bun backend points at `~/.opencode-cowork-build/packages/web/server/index.js` rather than a bundled copy. If a user manually deletes that directory the app shows a clear "installation not found" error and won't start until the installer is re-run. Fixing this properly means restructuring `electron-builder.json` to bundle `packages/web/dist` + a curated subset of `node_modules`, which is a larger change deserving its own PR. Filed as a follow-up.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
