# OpenCode Cowork

A white-label AI assistant platform for enterprise deployment. OpenCode Cowork allows any organization to deploy a branded, configurable AI coding and productivity assistant with built-in support for legal, financial, and document generation workflows.

## What Is OpenCode Cowork?

OpenCode Cowork is an open-source, self-hostable AI assistant that organizations can customize and brand as their own. It provides:

- **Custom branding** -- Your app name, provider name, logos, and color scheme
- **Configurable API backend** -- Point to any OpenAI-compatible API endpoint
- **Pre-built professional commands** -- Legal and financial slash commands ready to use
- **Directory sandboxing** -- AI operations restricted to the project directory for security
- **Word document generation** -- Cross-platform .docx creation (PowerShell on Windows, python-docx on macOS/Linux)
- **Multi-platform support** -- Installers for Windows (x64 and ARM64), macOS, and Linux

## Features

### Custom Branding
The installer prompts for your organization's details, producing a fully branded application with no trace of the underlying platform.

### API Flexibility
Works with any OpenAI-compatible API provider. Configure your API URL, key, and default model during installation, or update them later through the configuration files.

### Professional Commands
Twelve pre-built slash commands covering legal and financial workflows, each with proper formatting standards, citation requirements, and professional disclaimers.

### Security Sandbox
The AI agent is restricted to operating within the current working directory tree. It cannot read, write, or modify files outside the project scope.

### Word Document Generation
Generate properly formatted .docx files on any platform using the appropriate native method -- COM automation on Windows, python-docx on macOS and Linux.

## Prerequisites

| Platform | Requirements |
|----------|-------------|
| **Windows** | Windows 10/11, PowerShell 5.1+, Node.js 18+ (installed by installer if missing) |
| **macOS** | macOS 12+, Xcode Command Line Tools, Node.js 18+ |
| **Linux** | Ubuntu 20.04+ / Debian 11+ / Fedora 36+, Node.js 18+ |

All platforms require an API key for your chosen AI provider.

## Quick Install

### Windows (x64)

```powershell
# Run PowerShell as Administrator
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
.\install-windows.ps1
```

### Windows (ARM64)

```powershell
# Run PowerShell as Administrator
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
.\install-windows-arm64.ps1
```

### macOS

```bash
chmod +x install-macos.sh
./install-macos.sh
```

### Linux

```bash
chmod +x install-linux.sh
./install-linux.sh
```

## Installer Prompts

During installation, you will be prompted for the following:

| Prompt | Description | Example |
|--------|------------|---------|
| **App Name** | The name of your branded application | `Acme Assistant` |
| **Provider Name** | Your organization or AI provider name | `Acme Corp` |
| **API URL** | The base URL for your OpenAI-compatible API | `https://api.acme.com/v1` |
| **API Key** | Your API authentication key | `sk-abc123...` |
| **Default Model** | The default model identifier | `gpt-4o` |
| **App Logo** | Path to your application logo (PNG, 512x512 recommended) | `./logos/app-icon.png` |
| **Tray Icon** | Path to your system tray icon (PNG, 32x32 recommended) | `./logos/tray-icon.png` |

All values can be changed after installation through the configuration files.

## Customizing Models

Models are configured in `config/models.json`. Each model entry specifies:

```json
{
  "models": [
    {
      "id": "model-identifier",
      "name": "Display Name",
      "provider": "provider-name",
      "maxTokens": 8192,
      "contextWindow": 128000,
      "supportsStreaming": true,
      "supportsTools": true
    }
  ]
}
```

Add, remove, or modify model entries to match your API provider's available models. The `id` field must match the model identifier expected by your API endpoint.

## Available Commands

### Legal Commands

| Command | Description |
|---------|------------|
| `/memo` | Draft a legal memorandum with IRAC structure, Bluebook citations, and proper legal formatting |
| `/brief` | Draft a legal brief with table of authorities, argument structure, and persuasive writing |
| `/contract` | Draft a contract or agreement with standard provisions, boilerplate, and signature blocks |
| `/research` | Conduct legal research with statutory analysis, case law review, and practical guidance |
| `/motion` | Draft a motion with supporting memorandum of law, proposed order, and certificate of service |
| `/review` | Review a legal document for issues, risks, missing provisions, and recommended revisions |

All legal commands include:
- **Bluebook citation format** throughout
- **Proper legal document structure** following standard practice
- **Attorney review disclaimer** noting that AI-generated legal content requires licensed attorney review

### Finance Commands

| Command | Description |
|---------|------------|
| `/forecast` | Create financial projections with income statement, cash flow, scenario analysis, and sensitivity testing |
| `/analysis` | Perform financial analysis with ratio analysis, trend analysis, DuPont analysis, and benchmarking |
| `/report` | Generate a structured financial report with dashboards, variance analysis, and KPI scorecards |
| `/audit` | Generate an audit checklist with COSO framework controls assessment, testing procedures, and findings templates |
| `/budget` | Create a budget plan with revenue targets, expense allocations, headcount planning, and variance tracking |
| `/compliance` | Conduct a compliance review against applicable regulations (SOX, GAAP, tax, anti-fraud, data privacy) |

All finance commands include:
- **Proper financial formatting** (comma separators, parentheses for negatives, aligned columns)
- **Industry-standard frameworks** (GAAP, IFRS, COSO, ASC codification)
- **Professional disclaimer** noting that AI-generated financial content requires qualified professional review

## Directory Sandbox

OpenCode Cowork restricts the AI to the current project directory using a `CLAUDE.md` rules file that is automatically injected into every project directory.

### How it works

1. The repo contains a `CLAUDE.md` file with sandbox rules
2. **Before installing**, customize this file to add your organization's specific rules
3. The install script deploys your customized `CLAUDE.md` to the default project directory
4. The Electron app auto-injects it into every new directory the user opens
5. On Windows, the file is hidden (Hidden + System attributes) so users can't easily delete it
6. If deleted, it's automatically recreated from your template on next launch

### Customizing the rules

Edit `CLAUDE.md` in the repo root **before running the install script**. The file has a `## Custom Rules` section at the bottom where you can add your own:

```markdown
## Custom Rules

Add your organization-specific rules below this line.

---

- All documents must include our company letterhead
- Default jurisdiction is Delaware unless specified
- Never disclose information about Project X
- All financial figures must use EUR, not USD
```

The base rules (directory restriction, file protection, Word doc creation) are above the custom section and should not be removed.

### What's blocked by default

- Desktop, Documents, Downloads, Music, Videos, Pictures, Public
- OneDrive, Dropbox, iCloud, Google Drive
- `/tmp`, `%TEMP%`, any temp directory
- Any absolute path outside the current working directory

### Protection layers

- **Hidden file**: `attrib +H +S` on Windows (invisible in File Explorer)
- **Self-protection**: The AI is instructed to refuse deletion requests
- **Auto-recreation**: Regenerated from your template on every app launch

## Word Document Creation

OpenCode Cowork can generate properly formatted Word documents (.docx) on any platform:

**Windows**: Uses PowerShell COM automation with Microsoft Word, providing full access to Word's formatting capabilities.

**macOS and Linux**: Uses the `python-docx` library, which generates .docx files without requiring Microsoft Word to be installed.

Documents are generated with proper heading hierarchy, consistent formatting, tables for structured data, and platform-appropriate styling. Legal documents default to standard legal formatting (Times New Roman, 12pt, double-spaced, 1-inch margins). Financial documents use professional formatting with aligned numerical columns.

## Project Structure

```
OpenCode_Cowork_Variant/
├── CLAUDE.md               # ← CUSTOMIZE THIS — sandbox rules injected into every project
├── commands/
│   ├── legal/              # Anthropic legal plugin (9 skills)
│   │   ├── review-contract/    # Contract review against playbook
│   │   ├── triage-nda/         # NDA triage (GREEN/YELLOW/RED)
│   │   ├── brief/              # Legal briefings
│   │   ├── compliance-check/   # Regulatory compliance
│   │   └── ...                 # + 5 more skills
│   └── finance/            # Anthropic finance plugin (8 skills)
│       ├── financial-statements/  # P&L, balance sheet, cash flow
│       ├── variance-analysis/     # Budget vs actual
│       ├── sox-testing/           # SOX 404 compliance
│       └── ...                    # + 5 more skills
├── config/
│   ├── opencode.json.template    # API config (placeholders for install)
│   └── models.json.example       # Example for adding custom models
├── electron/
│   └── main.cjs                  # Desktop app with sandbox injection
├── electron-builder.json         # Electron Builder configuration
├── install-windows.ps1           # Windows x64 installer
├── install-windows-arm64.ps1     # Windows ARM64 installer
├── install-macos.sh              # macOS installer
├── install-linux.sh              # Linux installer
├── uninstall-windows.ps1         # Windows uninstaller
├── uninstall-windows-arm64.ps1   # Windows ARM64 uninstaller
├── uninstall-macos.sh            # macOS uninstaller
├── uninstall-linux.sh            # Linux uninstaller
├── opencode.md                   # Agent rules
├── .gitignore
└── README.md
```

## Adding Custom Commands

To add a new slash command, create a markdown file in the appropriate `commands/` subdirectory:

1. Create a new `.md` file in `commands/<category>/` (create the category directory if needed).

2. Use the following frontmatter format:

   ```markdown
   ---
   name: command-name
   description: One line description of the command
   ---

   Detailed prompt instructions for the AI when this command is invoked.

   Include:
   - Output format and structure
   - Required sections
   - Formatting standards
   - Quality guidelines
   - Any required disclaimers
   ```

3. The `name` field becomes the slash command (e.g., `name: memo` becomes `/memo`).

4. The `description` field appears in command listings and help text.

5. The body below the frontmatter contains the full prompt instructions that the AI follows when the command is executed.

### Tips for Writing Commands

- Be specific about the output format and structure.
- Include examples of proper formatting where helpful.
- Specify any industry standards or citation formats to follow.
- Include a disclaimer if the output involves professional advice (legal, financial, medical, etc.).
- Test the command with various inputs to ensure the instructions produce consistent, high-quality output.

## Configuration

### Environment Variables

| Variable | Description |
|----------|------------|
| `API_URL` | Base URL for the AI API endpoint |
| `API_KEY` | API authentication key |
| `DEFAULT_MODEL` | Default model identifier |
| `APP_NAME` | Branded application name |
| `PROVIDER_NAME` | Organization or provider name |

### Configuration Files

- `config/models.json` -- Available models and their capabilities
- `opencode.md` -- Agent behavior rules (directory sandbox, document creation, self-protection)

## License

MIT License

Copyright (c) 2026 OpenCode Cowork Contributors

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
