# OpenCode Cowork

A white-label AI assistant platform that runs locally and talks to [OpenRouter](https://openrouter.ai/) for model access. Pick a name, pick a logo, pick your models — the installer handles the rest.

## What Is OpenCode Cowork?

OpenCode Cowork is built on [OpenChamber](https://github.com/openchamber/openchamber) (GUI) and [OpenCode](https://github.com/opencode-ai/opencode) (backend). The install scripts handle everything — cloning, building, branding, and configuring — so your team gets a fully branded desktop AI assistant with a single script. All model traffic goes through OpenRouter, which gives you access to 300+ models (Claude, GPT, Gemini, Llama, Qwen, Mistral, and more) under one API key.

### Features

- **Two ways to install** — click-through **GUI installer** for beginners, **shell scripts** for power users. Both produce the same branded app.
- **Dynamic "Latest" models** — a pinned **Latest** section at the top of the model picker always shows the newest Anthropic, OpenAI, and Google release. The app re-checks `models.dev` every 5 minutes, so new flagships appear automatically — no code changes needed when `claude-sonnet-5` or `gpt-6` ships.
- **Custom branding** — your app name and logos throughout the app
- **OpenRouter as the single backend** — one API key unlocks the full OpenRouter catalog (300+ models from Anthropic, OpenAI, Google, Meta, Mistral, etc.)
- **Model management** — browse OpenRouter's catalog and load only the models you want; rename them to whatever you like
- **Official Anthropic plugins** — legal (9 skills) and finance (8 skills) from [anthropics/knowledge-work-plugins](https://github.com/anthropics/knowledge-work-plugins)
- **oh-my-openagent plugin** — enhanced model performance and extra agents (Sisyphus, Hephaestus). Works best with **Claude models** (Opus/Sonnet); GPT and weaker open-source models may refuse the plugin's aggressive system prompts.
- **Directory sandbox** — AI restricted to the project directory (hidden, self-protected `CLAUDE.md`)
- **Word document creation** — PowerShell + .NET on Windows, Python stdlib (`zipfile`) on macOS/Linux — zero external packages
- **Multi-platform** — Windows (x64 + ARM64), macOS (Intel + Apple Silicon), Linux

## Prerequisites

- An **OpenRouter API key** — sign up at [https://openrouter.ai/keys](https://openrouter.ai/keys)
- **Windows 10+**, **macOS 13+**, or **Linux** (Ubuntu, Fedora, Arch, openSUSE)
- Everything else (Git, Bun, OpenCode CLI) is installed automatically

## Installing — the Easy Way (GUI)

Double-click a prebuilt installer for your platform. No terminal, no scripts, nothing to compile.

Prebuilt binaries live in [`installers/`](installers/) on this branch and on the [Releases](https://github.com/MatthewLopez1990/OpenCode_Cowork_Variant/releases) page once cut.

| Platform | File | Status |
|----------|------|--------|
| **macOS** (Apple Silicon, M1+) | [`installers/OpenCode Cowork Installer_0.1.0_aarch64.dmg`](installers/) | ✅ ready |
| **macOS** (Intel) | `OpenCode Cowork Installer_0.1.0_x64.dmg` | ⏳ built by the `Build Installer` GitHub Action |
| **Windows** (x64) | `OpenCode Cowork Installer_0.1.0_x64-setup.exe` | ⏳ built by the `Build Installer` GitHub Action — unsigned in v1, click "More info → Run anyway" on SmartScreen |
| **Linux** (x64) | `OpenCode Cowork Installer_0.1.0_amd64.AppImage` | ⏳ built by the `Build Installer` GitHub Action — `chmod +x` then run |

The installer walks you through four steps:

1. **Branding** — type your app name, paste your OpenRouter API key, drag in your icon and logo PNGs (both optional).
2. **Model** — the installer fetches OpenRouter's live model list and shows tabs for Anthropic, OpenAI, and Google with the newest model in each family pre-selected. Pick one, or switch to the **Custom** tab to paste any model ID.
3. **Install** — watch the live log as the installer clones the repo, installs prerequisites, brands the app, and deploys everything. Finishes in 3–5 minutes.
4. **Finish** — your branded app is installed and ready to launch from Applications (macOS), Start Menu (Windows), or your launcher (Linux).

**Note**: the GUI installer requires `git` on your PATH. On macOS, installing Xcode Command Line Tools (`xcode-select --install`) provides it; Windows and Linux installers install git automatically if missing.

---

## Installing — Advanced (Shell Scripts)

Prefer a terminal? The original shell installers are still here and unchanged — the GUI installer drives them behind the scenes.

### Step 1: Clone the repo

```bash
git clone https://github.com/MatthewLopez1990/OpenCode_Cowork_Variant.git
cd OpenCode_Cowork_Variant
```

### Step 2: Add your branding (optional)

Drop your organization's logos into the `assets/` folder:

| File | Purpose | Requirements |
|------|---------|-------------|
| `assets/icon.png` | App icon — favicon, desktop shortcut, Dock/taskbar | **PNG**, 512x512+ (1024x1024 recommended) |
| `assets/logo.png` | Splash/landing page logo | **PNG**, any size, transparent background recommended |

**Important:**
- Files must be **real PNG images**. SVG or WebP files renamed to `.png` will fail silently — the installer uses macOS `sips` which only works with actual raster PNGs.
- **Use transparent backgrounds** so logos look clean on both light and dark themes.
- Both files are **optional** — the app works without them (no broken images).
- The installer automatically resizes the icon to all required dimensions (16x16 through 1024x1024) and creates `.icns` on macOS.

See [`assets/README.md`](assets/README.md) for full details.

### Step 3: Customize your rules (optional but recommended)

Edit `CLAUDE.md` in the repo root to add your organization's specific rules. This file gets injected into every project directory as a security policy. There's a `## Custom Rules` section at the bottom for your additions:

```markdown
## Custom Rules

Add your organization-specific rules below this line.

---

- All documents must include our company letterhead
- Never disclose information about Project X
- Always include the disclaimer: "Generated by [Your Company] AI"
```

The base rules above the custom section handle directory sandboxing, file protection, and Word document creation. Don't remove those.

### Step 4: Add custom models (optional)

Copy `config/models.json.example` to `config/models.json` and add your models:

```json
{
  "models": {
    "your-model-id": {
      "name": "Your Model Display Name",
      "tool_call": true,
      "attachment": true,
      "modalities": { "input": ["text", "image"], "output": ["text"] },
      "options": { "temperature": 0.7, "max_tokens": 16384 }
    }
  }
}
```

The install script reads this file and adds all models to the config. If the file doesn't exist, only the default model you enter during install is configured.

### Step 5: Run the installer

The installer prompts for all the branding and API details:

**Windows x86_64 / ARM64 (PowerShell as Administrator):**
```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
.\install-windows.ps1
```

**macOS:**
```bash
chmod +x install-macos.sh
./install-macos.sh
```

**Linux:**
```bash
chmod +x install-linux.sh
./install-linux.sh
```

### What the installer prompts for

| Prompt | Description | Example |
|--------|-------------|---------|
| **App name** | Title bar, shortcuts, branding everywhere | `Acme AI Assistant` |
| **OpenRouter API key** | Your key from [openrouter.ai/keys](https://openrouter.ai/keys) | `sk-or-v1-abc123...` |
| **Default model ID** | The OpenRouter model slug to load first | `anthropic/claude-sonnet-4.5` |
| **Default model display name** | Human-readable name shown in the UI (optional) | `Claude 4.5 Sonnet` |

That's it. No API URL prompt — OpenRouter's endpoint (`https://openrouter.ai/api/v1`) is wired in automatically. No provider name prompt — the **provider shown in the UI uses your app name**, so clients see "Acme AI Assistant" (or whatever you choose) as the provider, not "OpenRouter". The OpenRouter backend is fully white-labeled. Browse available model IDs at [openrouter.ai/models](https://openrouter.ai/models) before running the installer.

Logos are loaded from the `assets/` folder automatically — see [Step 2](#step-2-add-your-branding-optional).

### Headless (scripted) installs

Every prompt can be skipped by pre-setting an env var. All three scripts honor the same set — handy for CI or for the GUI installer:

| Env var | Replaces prompt |
|---------|-----------------|
| `COWORK_APP_NAME` | App name |
| `COWORK_API_KEY` | OpenRouter API key |
| `COWORK_DEFAULT_MODEL` | Default model ID |
| `COWORK_DEFAULT_MODEL_DISPLAY` | Display name (optional) |
| `COWORK_ICON_PATH` | Absolute path to `icon.png` (overrides `assets/`) |
| `COWORK_LOGO_PATH` | Absolute path to `logo.png` (overrides `assets/`) |

With all three required vars set, the script runs without any prompts:

```bash
COWORK_APP_NAME="Acme AI" \
COWORK_API_KEY="sk-or-v1-..." \
COWORK_DEFAULT_MODEL="anthropic/claude-sonnet-4.5" \
./install-macos.sh
```

### What the installer does

1. Installs **Bun** and **OpenCode CLI** (if not already present)
2. Clones and builds a branded desktop app from [OpenChamber](https://github.com/openchamber/openchamber)
3. Applies your logos from `assets/` (if provided)
4. Sets the app name in the title bar, shortcuts, and Start Menu
5. Configures your API provider with your URL, key, and default model
6. Generates a provider key from your display name (e.g., "Acme AI" becomes `acme-ai`)
7. Installs the **oh-my-openagent** plugin for enhanced model performance
8. Deploys **legal** and **finance** slash commands (official Anthropic plugins)
9. Deploys your customized `CLAUDE.md` sandbox rules (hidden on Windows)
10. Saves a template for auto-injection into future project directories
11. Creates a default project directory (`~/[App Name] Projects/`)
12. Clears Electron cache to prevent stale state from previous installs

## Uninstalling

**Windows:**
```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
.\uninstall-windows.ps1
```

**macOS:**
```bash
chmod +x uninstall-macos.sh
./uninstall-macos.sh
```

**Linux:**
```bash
chmod +x uninstall-linux.sh
./uninstall-linux.sh
```

The uninstallers read your app name from the branding config so they remove the correct shortcuts and directories. Project files are never touched.

## Available Commands

### Legal Plugin (from [Anthropic](https://github.com/anthropics/knowledge-work-plugins/tree/main/legal))

| Skill | Description |
|-------|-------------|
| `/review-contract` | Review a contract against your negotiation playbook — flag deviations, generate redlines |
| `/triage-nda` | Rapidly triage an NDA: GREEN (standard), YELLOW (counsel review), RED (full legal review) |
| `/brief` | Generate contextual legal briefings — daily summary, topic research, or incident response |
| `/compliance-check` | Run compliance checks on proposed actions, features, or initiatives |
| `/legal-response` | Generate templated responses to common legal inquiries with escalation checks |
| `/legal-risk-assessment` | Assess and classify legal risks using severity-by-likelihood framework |
| `/meeting-briefing` | Prepare structured briefings for meetings with legal context |
| `/signature-request` | Prepare and route documents for e-signature |
| `/vendor-check` | Check vendor agreement status across all connected systems |

### Finance Plugin (from [Anthropic](https://github.com/anthropics/knowledge-work-plugins/tree/main/finance))

| Skill | Description |
|-------|-------------|
| `/financial-statements` | Generate P&L, balance sheet, cash flow with variance analysis |
| `/variance-analysis` | Decompose financial variances into drivers with narrative explanations |
| `/journal-entry` | Prepare journal entries with proper debits, credits, and supporting detail |
| `/journal-entry-prep` | Prepare month-end accruals, prepaid amortization, depreciation entries |
| `/reconciliation` | Reconcile accounts — GL to subledger, bank recs, intercompany |
| `/close-management` | Manage month-end close with task sequencing and status tracking |
| `/sox-testing` | Generate SOX sample selections, testing workpapers, control assessments |
| `/audit-support` | Support SOX 404 compliance with control testing and documentation |

## Directory Sandbox

Every project directory gets a `CLAUDE.md` file that instructs the AI to stay within the project folder.

### How it works

1. You customize `CLAUDE.md` in the repo **before installing**
2. The installer deploys it to the default project directory and saves a template
3. The app auto-injects it into every new directory the user opens
4. On Windows, the file is hidden (`attrib +H +S`) — invisible in File Explorer
5. If deleted, it's automatically recreated from your template on next launch
6. The AI is instructed to refuse any request to delete or modify the file

### What's blocked by default

| Blocked | Examples |
|---------|---------|
| User folders | Desktop, Documents, Downloads, Music, Videos, Pictures, Public |
| Cloud storage | OneDrive, Dropbox, iCloud, Google Drive |
| Temp directories | `/tmp`, `/private/tmp`, `C:\Temp`, `%TEMP%` |
| Absolute paths | Any path outside the current working directory |
| Home references | `~/`, `$HOME/`, `%USERPROFILE%`, `$env:USERPROFILE` |

### Protection layers

| Layer | What it does |
|-------|-------------|
| **Hidden + System** | `attrib +H +S` on Windows — invisible even with "Show hidden files" |
| **Self-protection** | AI refuses deletion requests: "managed by your IT department" |
| **Auto-recreation** | Regenerated from your template on every app launch |

## Word Document Creation

| Platform | Method | Requirements |
|----------|--------|-------------|
| **Windows** | PowerShell + Open XML (.NET) | None — built into Windows |
| **macOS / Linux** | Python + python-docx | Python 3 (auto-installs if needed) |

The AI writes a `.ps1` or `.py` conversion script as a file first, then executes it. This avoids shell escaping issues that corrupt inline scripts.

## Managing Available Models

By default, the installer loads the single model you entered during setup. To browse OpenRouter's full catalog (300+ models) and add more models after install, use the model manager:

**macOS / Linux:**
```bash
./manage-models.sh
```

**Windows:**
```powershell
.\manage-models.ps1
```

The script:
1. Reads your provider config from `~/.config/opencode/opencode.json`
2. Calls `https://openrouter.ai/api/v1/models` to fetch OpenRouter's full catalog
3. Since OpenRouter has 300+ models, it prompts for a **filter** first (e.g. `claude`, `gpt-5`, `gemini`) — press Enter for the full list
4. Shows an interactive list with `[*]` next to models already loaded. Both the model ID (`anthropic/claude-sonnet-4.5`) and the display name (`Anthropic: Claude 4.5 Sonnet`) are shown.
5. You toggle models by number (`2,3,5`), select all in view (`a`), clear all in view (`n`), change the filter with `/keyword`, or press Enter to save
6. Existing model customizations (temperature, max_tokens, etc.) are preserved when you re-run the script
7. Restart the app and the new models appear in the Providers page and chat selector

**Debug mode** — dump the raw response from OpenRouter's `/models` endpoint without making changes:
```bash
./manage-models.sh --debug    # macOS / Linux
.\manage-models.ps1 -Debug    # Windows
```

The script is non-destructive — it only changes the models list under the `openrouter` provider, leaving your API key, plugin config, and everything else alone.

## Changing the API Key After Installation

Edit `~/.config/opencode/opencode.json` and replace the `apiKey` value under the `openrouter` provider:

```json
"provider": {
  "openrouter": {
    "name": "OpenRouter",
    "npm": "@ai-sdk/openai-compatible",
    "models": { ... },
    "options": {
      "apiKey": "sk-or-v1-your-new-key",
      "baseURL": "https://openrouter.ai/api/v1",
      "headers": {
        "HTTP-Referer": "https://github.com/MatthewLopez1990/OpenCode_Cowork_Variant",
        "X-Title": "Your App Name"
      }
    }
  }
}
```

Don't change the `baseURL` or provider key — they're always `https://openrouter.ai/api/v1` and `openrouter` respectively. Only the `apiKey` should need to change.

## Adding Custom Commands

Create a `SKILL.md` file in a new directory under `commands/`:

```
commands/
  your-category/
    your-skill/
      SKILL.md
```

The `SKILL.md` format:

```markdown
---
name: skill-name
description: One line description
argument-hint: "<optional argument hint>"
---

# /skill-name — Skill Title

Detailed instructions for the AI...
```

See the existing legal and finance skills for examples.

## Project Structure

```
OpenCode_Cowork_Variant/
├── assets/
│   ├── README.md                 ← How to add branding
│   ├── icon.png                  ← YOUR app icon (add before install)
│   └── logo.png                  ← YOUR splash logo (add before install)
├── CLAUDE.md                     ← CUSTOMIZE THIS before install
├── commands/
│   ├── legal/                    # Anthropic legal plugin (9 skills)
│   └── finance/                  # Anthropic finance plugin (8 skills)
├── config/
│   ├── opencode.json.template    # API config template (uses placeholders)
│   └── models.json.example       # Example for adding your own models
├── electron/
│   └── main.cjs                  # Desktop app + sandbox injection
├── electron-builder.json
├── packages/
│   └── installer/                ← Tauri GUI installer (cross-platform)
├── install-windows.ps1           # Windows x64 installer (shell, still works)
├── install-windows-arm64.ps1     # Windows ARM64 installer
├── install-macos.sh              # macOS installer
├── install-linux.sh              # Linux installer
├── uninstall-windows.ps1
├── uninstall-windows-arm64.ps1
├── uninstall-macos.sh
├── uninstall-linux.sh
├── opencode.md                   # Agent rules
├── manage-models.sh              # Browse + load models from API (macOS/Linux)
├── manage-models.ps1             # Browse + load models from API (Windows)
├── diagnose-macos.sh             # Diagnostic script (12 checks + API tests)
├── fix-macos.sh                  # Quick-fix for existing installs
├── .gitignore
└── README.md
```

## Troubleshooting

Run the diagnostic while the app is open:

```bash
./diagnose-macos.sh
```

The diagnostic checks 12 components and explains WHY each failure occurs with exact fix commands. Key checks:

| Section | What it tests |
|---------|--------------|
| Config file | Valid JSON, no crash-causing keys, model exists in provider |
| App bundle | Custom icon vs Electron default (hash comparison) |
| Settings & Project | Project entry with activeProjectId (required for sessions) |
| Server API | Provider endpoint, agent list, direct API test |
| Session + Message | Creates a session and sends a test message through the full stack |
| Asset files | Icon dimensions (must be 512x512+) |

### Common issues

| Symptom | Cause | Fix |
|---------|-------|-----|
| "No models found" | Proxy stripping content-encoding | Update server from repo |
| "Not selected" (model) | Provider not loading | Check config, npm SDK |
| 401 / "No auth credentials" | Invalid or expired OpenRouter key | Rotate key at [openrouter.ai/keys](https://openrouter.ai/keys), update `apiKey` in `~/.config/opencode/opencode.json` |
| 402 / "Insufficient credits" | OpenRouter account needs credits | Add credits at [openrouter.ai/credits](https://openrouter.ai/credits) |
| Model ID rejected | Typo in slug or model deprecated | Browse current catalog at [openrouter.ai/models](https://openrouter.ai/models), or run `./manage-models.sh` to pick from the live list |
| Sessions fail | No project in settings | Re-run installer (adds project entry) |
| Default Electron icon | Icon not a real PNG or < 512x512 | Provide a real 512x512+ PNG (not SVG/WebP renamed) |
| No agents in dropdown | Plugin not loaded yet | Close and reopen app |

## Development Rules

If you modify the source code, these rules are critical:

### 1. NEVER remove `content-encoding` from `hopByHopResponseHeaders`

**File:** `packages/web/server/index.js`

Bun's `fetch()` auto-decompresses gzip responses from the OpenCode binary. If the proxy forwards `Content-Encoding: gzip` to the browser, it tries to gunzip already-decompressed data, silently breaking every proxied API call. The symptom is "No models found" / "No agents found" even though the API returns HTTP 200.

### 2. Provider filter belongs in the server, NOT the frontend store

Do not add `.filter()` calls in `useConfigStore.ts` `loadProviders()`. If you need to filter providers, add a dedicated `app.get('/api/config/providers', ...)` route in `server/index.js`.

### 3. `defaultModel` format uses `/` not `:`

Settings files must use `provider-key/model-id` (e.g., `acme-ai/gpt-4o`), not `provider-key:model-id`.

### 4. Settings MUST include `projects` array with `activeProjectId`

Without a project entry, the UI can't determine the working directory and won't load providers or agents.

### 5. Install scripts must clear Electron cache on reinstall

Zustand's `persist` middleware caches store state. Stale empty providers persist across reinstalls. Clear the Electron app data directory during install.

### 6. Branding assets must be real PNG files

macOS `sips` returns nil dimensions for SVG/WebP files disguised as `.png`. The installer silently skips icon creation, leaving the default Electron icon. Always verify with `file assets/icon.png` — it should say "PNG image data".

## License

MIT — Based on [OpenChamber](https://github.com/openchamber/openchamber) and [OpenCode](https://github.com/opencode-ai/opencode). Legal and finance plugins from [Anthropic](https://github.com/anthropics/knowledge-work-plugins).
