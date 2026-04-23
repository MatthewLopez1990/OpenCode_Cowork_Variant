# ============================================================
#  OpenCode Cowork - Windows Installer (x64 + ARM64)
#  White-label AI assistant for any enterprise
#
#  This is a self-contained fork. The installer clones THIS repo,
#  builds the branded Electron desktop app, configures AI models,
#  and deploys sandbox rules.
# ============================================================

$ErrorActionPreference = "Stop"
$COWORK_REPO = "https://github.com/MatthewLopez1990/OpenCode_Cowork_Variant.git"
$COWORK_REPO_DIR = Split-Path -Parent $MyInvocation.MyCommand.Path
$BUILD_DIR = "$env:USERPROFILE\.opencode-cowork-build"
# Which branch to build from. Defaults to main; the GUI installer overrides this
# to the feature branch during pre-merge testing.
$COWORK_GIT_BRANCH = if ($env:COWORK_GIT_BRANCH) { $env:COWORK_GIT_BRANCH } else { "main" }

function Write-Ok($m) { Write-Host "  * $m" -ForegroundColor Green }
function Write-Warn($m) { Write-Host "  ! $m" -ForegroundColor Yellow }

# Write UTF-8 WITHOUT BOM
function Write-Utf8NoBom($Path, $Content) {
    $utf8 = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($Path, $Content, $utf8)
}

# PowerShell 5.1 raises NativeCommandError when a native tool writes ANYTHING
# to stderr under $ErrorActionPreference = 'Stop' - even harmless progress
# messages like git's "Cloning into '...'". This helper runs git with the
# preference temporarily relaxed so progress chatter doesn't kill the script,
# and emits combined stdout+stderr so the caller can capture or ignore it.
function Invoke-Git {
    $oldEap = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        & git @args 2>&1
    } finally {
        $ErrorActionPreference = $oldEap
    }
}

Write-Host ""
Write-Host "  +==========================================+" -ForegroundColor Blue
Write-Host "  |  OpenCode Cowork - Enterprise Installer   |" -ForegroundColor Blue
Write-Host "  |  White-label AI for your organization      |" -ForegroundColor Blue
Write-Host "  +==========================================+" -ForegroundColor Blue
Write-Host ""

# Step 1: Organization Setup
# Any value pre-populated via env (COWORK_APP_NAME, COWORK_API_KEY,
# COWORK_DEFAULT_MODEL, COWORK_DEFAULT_MODEL_DISPLAY, COWORK_ICON_PATH,
# COWORK_LOGO_PATH) skips the corresponding prompt - used by the GUI installer
# to run this script headlessly.
Write-Host "Step 1: Organization Setup" -ForegroundColor White
Write-Host ""

$APP_NAME = if ($env:COWORK_APP_NAME) { $env:COWORK_APP_NAME } else { "" }
while ([string]::IsNullOrWhiteSpace($APP_NAME)) {
    $APP_NAME = Read-Host "  App name (e.g., 'Acme AI Assistant')"
    if ([string]::IsNullOrWhiteSpace($APP_NAME)) { Write-Host "  Required." -ForegroundColor Red }
}

$API_KEY = if ($env:COWORK_API_KEY) { $env:COWORK_API_KEY } else { "" }
while ([string]::IsNullOrWhiteSpace($API_KEY)) {
    $API_KEY = Read-Host "  OpenRouter API key (starts with 'sk-or-v1-')"
    if ([string]::IsNullOrWhiteSpace($API_KEY)) { Write-Host "  Required." -ForegroundColor Red }
}

# Default model is NEVER prompted - it's statically Claude Sonnet 4.6. Power
# users can override by setting $env:COWORK_DEFAULT_MODEL before running this
# script, or by editing %USERPROFILE%\.config\opencode\opencode.json after install.
$DEFAULT_MODEL = if ($env:COWORK_DEFAULT_MODEL) { $env:COWORK_DEFAULT_MODEL } else { "anthropic/claude-sonnet-4.6" }
$DEFAULT_MODEL_DISPLAY = if ($env:COWORK_DEFAULT_MODEL_DISPLAY) { $env:COWORK_DEFAULT_MODEL_DISPLAY } else { "Claude Sonnet 4.6" }

# Backend is OpenRouter (hidden from the client). The provider is surfaced
# in the UI using the APP_NAME so the end user sees the white-label brand,
# not "OpenRouter". The provider key is a slug of the app name.
$PROVIDER_NAME = ($APP_NAME.ToLower() -replace '[^a-z0-9]', '-' -replace '-+', '-').Trim('-')
if ([string]::IsNullOrWhiteSpace($PROVIDER_NAME)) { $PROVIDER_NAME = "provider" }
$PROVIDER_DISPLAY = $APP_NAME
$API_URL = "https://openrouter.ai/api/v1"

Write-Host ""
Write-Ok "Organization: $APP_NAME"
Write-Ok "Provider (shown to users): $APP_NAME"
Write-Ok "Model: $DEFAULT_MODEL"

# Check for branding assets - env-var paths take precedence over \assets\
$ICON_ASSET = $null
$LOGO_ASSET = $null
if ($env:COWORK_ICON_PATH -and (Test-Path $env:COWORK_ICON_PATH)) {
    $ICON_ASSET = Get-Item $env:COWORK_ICON_PATH
} else {
    $ICON_ASSET = Get-ChildItem "$COWORK_REPO_DIR\assets\icon.png" -ErrorAction SilentlyContinue | Select-Object -First 1
}
if ($env:COWORK_LOGO_PATH -and (Test-Path $env:COWORK_LOGO_PATH)) {
    $LOGO_ASSET = Get-Item $env:COWORK_LOGO_PATH
} else {
    $LOGO_ASSET = Get-ChildItem "$COWORK_REPO_DIR\assets\logo.png" -ErrorAction SilentlyContinue | Select-Object -First 1
}
if ($ICON_ASSET) { Write-Ok "Icon: $($ICON_ASSET.Name)" } else { Write-Host "  - No custom icon -- using defaults" }
if ($LOGO_ASSET) { Write-Ok "Logo: $($LOGO_ASSET.Name)" } else { Write-Host "  - No custom logo -- using defaults" }
Write-Host ""

# Step 2: Prerequisites
Write-Host "Step 2: Installing prerequisites..." -ForegroundColor White

# Git discovery: scan every common install location, add to $env:PATH if found.
# Covers: system-wide Git for Windows (winget/installer), WOW64 32-bit install,
# per-user install to %LOCALAPPDATA%\Programs\Git, and scoop.
$gitCandidateDirs = @(
    "$env:ProgramFiles\Git\cmd",
    "$env:ProgramFiles\Git\bin",
    "${env:ProgramFiles(x86)}\Git\cmd",
    "$env:LOCALAPPDATA\Programs\Git\cmd",
    "$env:USERPROFILE\scoop\apps\git\current\cmd"
)
function Invoke-GitPathScan {
    foreach ($p in $script:gitCandidateDirs) {
        if ($p -and (Test-Path (Join-Path $p 'git.exe')) -and ($env:PATH -notlike "*$p*")) {
            $env:PATH = "$p;$env:PATH"
        }
    }
}
Invoke-GitPathScan

if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Write-Warn "Installing Git..."
    winget install --id Git.Git -e --source winget --accept-package-agreements --accept-source-agreements
    # winget's symlink refresh doesn't reach this session, so re-scan.
    Invoke-GitPathScan
}

if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Write-Host "  ! Git is installed but not on PATH. Please restart your terminal or add Git's cmd directory to PATH, then re-run the installer." -ForegroundColor Red
    exit 1
}
Write-Ok "Git ($((git --version 2>&1) -replace 'git version ',''))"

if (-not (Get-Command bun -ErrorAction SilentlyContinue)) {
    Write-Warn "Installing Bun..."
    irm https://bun.sh/install.ps1 | iex
    $env:PATH = "$env:USERPROFILE\.bun\bin;$env:PATH"
}
Write-Ok "Bun $(bun --version 2>&1)"

# Always install/update OpenCode CLI to latest version
# Remove any old wrapper scripts that might override the real binary
Remove-Item "$env:USERPROFILE\.local\bin\opencode.exe" -Force -ErrorAction SilentlyContinue
Remove-Item "$env:USERPROFILE\.local\bin\opencode" -Force -ErrorAction SilentlyContinue
Remove-Item "$env:USERPROFILE\.opencode\bin\opencode.cmd" -Force -ErrorAction SilentlyContinue
Remove-Item "$env:USERPROFILE\.opencode\bin\opencode.real.exe" -Force -ErrorAction SilentlyContinue
Write-Host "  Installing OpenCode CLI (latest)..."
if ($true) {
    $ocArch = if ([System.Runtime.InteropServices.RuntimeInformation]::OSArchitecture -eq "Arm64") { "arm64" } else { "x64" }
    $ocUrl = "https://github.com/anomalyco/opencode/releases/latest/download/opencode-windows-${ocArch}.zip"
    $ocZip = "$env:TEMP\opencode.zip"
    $ocDir = "$env:USERPROFILE\.opencode\bin"
    New-Item -ItemType Directory -Force -Path $ocDir | Out-Null
    Invoke-WebRequest -Uri $ocUrl -OutFile $ocZip
    Expand-Archive -Path $ocZip -DestinationPath $ocDir -Force
    Remove-Item $ocZip -ErrorAction SilentlyContinue
    $env:PATH = "$ocDir;$env:PATH"
}
Write-Ok "OpenCode CLI"
Write-Host ""

# Step 3: Clone and build
Write-Host "Step 3: Building $APP_NAME..." -ForegroundColor White

if (Test-Path "$BUILD_DIR\.git") {
    Set-Location $BUILD_DIR
    $CURRENT_BRANCH = (Invoke-Git rev-parse --abbrev-ref HEAD | Select-Object -First 1).ToString().Trim()
    if ($CURRENT_BRANCH -ne $COWORK_GIT_BRANCH) {
        Write-Host "  Existing build on '$CURRENT_BRANCH' - switching to '$COWORK_GIT_BRANCH'"
        Set-Location ..
        Remove-Item -Recurse -Force $BUILD_DIR -ErrorAction SilentlyContinue
        Invoke-Git clone --depth 1 --branch $COWORK_GIT_BRANCH $COWORK_REPO $BUILD_DIR | Out-Null
    } else {
        Invoke-Git pull --ff-only | Out-Null
    }
} else {
    Remove-Item -Recurse -Force $BUILD_DIR -ErrorAction SilentlyContinue
    Invoke-Git clone --depth 1 --branch $COWORK_GIT_BRANCH $COWORK_REPO $BUILD_DIR | Out-Null
}

if (-not (Test-Path "$BUILD_DIR\.git")) {
    Write-Host "  ! git clone failed - $BUILD_DIR has no .git directory. Aborting." -ForegroundColor Red
    exit 1
}

Set-Location $BUILD_DIR

# Copy Electron config
Write-Host "  Applying Electron configuration..."
if (-not (Test-Path "$BUILD_DIR\electron")) { New-Item -ItemType Directory -Force -Path "$BUILD_DIR\electron" | Out-Null }
Copy-Item "$COWORK_REPO_DIR\electron\main.cjs" "$BUILD_DIR\electron\main.cjs" -Force
Copy-Item "$COWORK_REPO_DIR\electron-builder.json" "$BUILD_DIR\electron-builder.json" -Force

# Patch package.json
Write-Host "  Setting app name..."
$pkgContent = Get-Content "$BUILD_DIR\package.json" -Raw | ConvertFrom-Json
$pkgContent.name = ($APP_NAME.ToLower() -replace '[^a-z0-9]','-')
$pkgContent | Add-Member -MemberType NoteProperty -Name "productName" -Value $APP_NAME -Force
$pkgContent.main = "electron/main.cjs"
$pkgContent | ConvertTo-Json -Depth 10 | Set-Content "$BUILD_DIR\package.json" -Encoding UTF8

# Patch index.html
$INDEX_HTML = "$BUILD_DIR\packages\web\index.html"
if (Test-Path $INDEX_HTML) {
    $htmlContent = Get-Content $INDEX_HTML -Raw
    $htmlContent = $htmlContent -replace '<title>[^<]*</title>', "<title>$APP_NAME</title>"
    $htmlContent = $htmlContent -replace 'content="OpenCode Cowork"', "content=`"$APP_NAME`""
    $htmlContent = $htmlContent -replace 'content="OpenChamber[^"]*"', "content=`"$APP_NAME`""
    $htmlContent = $htmlContent -replace 'alt="Loading"', "alt=`"$APP_NAME`""
    $htmlContent = $htmlContent -replace "const defaultAppName = '[^']*'", "const defaultAppName = '$APP_NAME'"
    $htmlContent = $htmlContent -replace "const defaultShortName = '[^']*'", "const defaultShortName = '$APP_NAME'"
    # Patch React useWindowTitle hook
    $windowTitleTs = "$BUILD_DIR\packages\ui\src\hooks\useWindowTitle.ts"
    if (Test-Path $windowTitleTs) {
        $tsContent = Get-Content $windowTitleTs -Raw
        $tsContent = $tsContent -replace "const APP_TITLE = '[^']*'", "const APP_TITLE = '$APP_NAME'"
        Set-Content $windowTitleTs $tsContent -Encoding UTF8
        Write-Ok "Window title patched"
    }
    if ($LOGO_ASSET) {
        Copy-Item $LOGO_ASSET.FullName "$BUILD_DIR\packages\web\public\cowork-logo.png" -Force
        $htmlContent = $htmlContent -replace 'src="[^"]*logo[^"]*\.svg"', 'src="/cowork-logo.png"'
        Write-Ok "Custom logo applied"
    }
    Write-Utf8NoBom $INDEX_HTML $htmlContent
}

# Apply icon
if ($ICON_ASSET) {
    $iconDir = "$BUILD_DIR\packages\desktop\src-tauri\icons"
    New-Item -ItemType Directory -Force -Path $iconDir | Out-Null
    Copy-Item $ICON_ASSET.FullName "$iconDir\icon.png" -Force
    Copy-Item $ICON_ASSET.FullName "$BUILD_DIR\packages\web\public\cowork-icon.png" -Force
    Copy-Item $ICON_ASSET.FullName "$BUILD_DIR\packages\web\public\favicon.png" -Force
    New-Item -ItemType Directory -Force -Path "$BUILD_DIR\branding" | Out-Null
    Copy-Item $ICON_ASSET.FullName "$BUILD_DIR\branding\icon.png" -Force
    Write-Ok "Custom icon applied"
}

# Update electron-builder
$ebContent = Get-Content "$BUILD_DIR\electron-builder.json" -Raw | ConvertFrom-Json
$ebContent.appId = "com.cowork." + ($APP_NAME.ToLower() -replace '[^a-z0-9]','-')
$ebContent.productName = $APP_NAME
Write-Utf8NoBom "$BUILD_DIR\electron-builder.json" ($ebContent | ConvertTo-Json -Depth 10)

# Deploy sandbox rules
$SERVER_JS = "$BUILD_DIR\packages\web\server\index.js"
# ALWAYS copy the template
Copy-Item "$COWORK_REPO_DIR\CLAUDE.md" "$BUILD_DIR\packages\web\server\CLAUDE_TEMPLATE.md" -Force -ErrorAction SilentlyContinue
Write-Ok "CLAUDE_TEMPLATE.md deployed"

if ((Test-Path $SERVER_JS) -and -not (Select-String -Path $SERVER_JS -Pattern "ensureSandboxRules" -Quiet)) {
    $sandboxCode = @"

// OpenCode Cowork: Auto-inject CLAUDE.md sandbox rules
const __cowork_path = require('path');
const __cowork_fs = require('fs');
function ensureSandboxRules(directory) {
  if (!directory) return;
  const claudePath = __cowork_path.join(directory, 'CLAUDE.md');
  try {
    const templatePath = __cowork_path.join(__dirname, 'CLAUDE_TEMPLATE.md');
    let rules = '';
    if (__cowork_fs.existsSync(templatePath)) { rules = __cowork_fs.readFileSync(templatePath, 'utf8'); }
    if (!rules) return;
    __cowork_fs.writeFileSync(claudePath, rules, 'utf8');
    if (process.platform === 'win32') { try { require('child_process').execSync('attrib +H +S "' + claudePath + '"', { stdio: 'ignore', timeout: 5000 }); } catch (e) {} }
  } catch (e) {}
}
"@
    Add-Content -Path $SERVER_JS -Value $sandboxCode -Encoding UTF8
    Write-Ok "Sandbox injection ready"
}

# Save branding
Write-Utf8NoBom "$env:USERPROFILE\.cowork-branding.json" "{`"appName`":`"$APP_NAME`",`"provider`":`"$PROVIDER_DISPLAY`"}"

# Install and build
Write-Host "  Adding Electron dependencies..."
bun add --dev electron@latest electron-builder@24.13.3 electron-store@latest electron-context-menu@latest 2>&1 | Select-Object -Last 1
Write-Host "  Installing all dependencies..."
bun install 2>&1 | Select-Object -Last 1
Write-Host "  Building frontend..."
bun run build:web 2>&1 | Select-Object -Last 3
Write-Ok "Frontend built"

# Build Electron
Write-Host "  Packaging desktop app..."
if (-not (Test-Path "$BUILD_DIR\packages\web\public\cowork-icon.png")) { New-Item "$BUILD_DIR\packages\web\public\cowork-icon.png" -ItemType File -Force | Out-Null }
if (-not (Test-Path "$BUILD_DIR\branding\icon.png")) { New-Item -ItemType Directory -Force "$BUILD_DIR\branding" | Out-Null; New-Item "$BUILD_DIR\branding\icon.png" -ItemType File -Force | Out-Null }
bunx electron-builder --config electron-builder.json --win --x64 2>&1 | Select-String -Pattern "(building|packaging|target=)" | Select-Object -Last 5

$EXE_NAME = "$APP_NAME.exe"
$INSTALL_DIR = "$env:LOCALAPPDATA\$APP_NAME"
$UNPACKED = "$BUILD_DIR\electron-dist\win-unpacked"
$UNPACKED_EXE = "$UNPACKED\$EXE_NAME"

if (-not (Test-Path $UNPACKED_EXE)) {
    $UNPACKED = "$BUILD_DIR\electron-dist\win-arm64-unpacked"
    $UNPACKED_EXE = "$UNPACKED\$EXE_NAME"
}

if (Test-Path $UNPACKED_EXE) {
    if (Test-Path $INSTALL_DIR) { Remove-Item -Recurse -Force $INSTALL_DIR }
    Copy-Item -Recurse $UNPACKED $INSTALL_DIR

    $ICON_PATH = "$BUILD_DIR\packages\desktop\src-tauri\icons\icon.ico"
    if (-not (Test-Path $ICON_PATH)) { $ICON_PATH = "$INSTALL_DIR\$EXE_NAME" }

    $WshShell = New-Object -ComObject WScript.Shell
    $StartMenu = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs"
    $Shortcut = $WshShell.CreateShortcut("$StartMenu\$APP_NAME.lnk")
    $Shortcut.TargetPath = "$INSTALL_DIR\$EXE_NAME"
    $Shortcut.WorkingDirectory = $INSTALL_DIR
    $Shortcut.Description = "$APP_NAME - AI Assistant"
    $Shortcut.IconLocation = $ICON_PATH
    $Shortcut.Save()
    Write-Ok "Start Menu shortcut created"

    $DesktopPath = [System.Environment]::GetFolderPath("Desktop")
    if ([string]::IsNullOrWhiteSpace($DesktopPath)) { $DesktopPath = "$env:USERPROFILE\Desktop" }
    $DesktopShortcut = $WshShell.CreateShortcut("$DesktopPath\$APP_NAME.lnk")
    $DesktopShortcut.TargetPath = "$INSTALL_DIR\$EXE_NAME"
    $DesktopShortcut.WorkingDirectory = $INSTALL_DIR
    $DesktopShortcut.Description = "$APP_NAME - AI Assistant"
    $DesktopShortcut.IconLocation = $ICON_PATH
    $DesktopShortcut.Save()
    Write-Ok "Desktop shortcut created"

    $currentPath = [System.Environment]::GetEnvironmentVariable("PATH", "User")
    if ($currentPath -notlike "*$INSTALL_DIR*") {
        [System.Environment]::SetEnvironmentVariable("PATH", "$INSTALL_DIR;$currentPath", "User")
        $env:PATH = "$INSTALL_DIR;$env:PATH"
    }
    Write-Ok "$APP_NAME installed to $INSTALL_DIR"
} else {
    Write-Warn "Build produced no executable. You can still run: opencode web"
}
Write-Host ""

# Step 4: Configure AI models
Write-Host "Step 4: Configuring AI models..." -ForegroundColor White

$OPENCODE_CONFIG_DIR = "$env:USERPROFILE\.config\opencode"
New-Item -ItemType Directory -Force -Path $OPENCODE_CONFIG_DIR | Out-Null

# Auto-select the 5 newest models from Anthropic, OpenAI, and Google from
# OpenRouter. Default = newest Claude Sonnet unless COWORK_DEFAULT_MODEL pins it.
$FETCHED_MODELS_FILE = [System.IO.Path]::GetTempFileName() + '.json'
Write-Host "  Fetching newest Anthropic / OpenAI / Google models from OpenRouter..."
try {
    $fetchOutput = python3 "$COWORK_REPO_DIR\scripts\fetch-top-models.py" $FETCHED_MODELS_FILE 2>$null
    if ($LASTEXITCODE -eq 0 -and $fetchOutput) {
        $fetchedDefault = ($fetchOutput | Select-String -Pattern '^DEFAULT_MODEL=(.*)$' | ForEach-Object { $_.Matches.Groups[1].Value } | Select-Object -First 1)
        $fetchedDisplay = ($fetchOutput | Select-String -Pattern '^DEFAULT_MODEL_DISPLAY=(.*)$' | ForEach-Object { $_.Matches.Groups[1].Value } | Select-Object -First 1)
        if (-not $env:COWORK_DEFAULT_MODEL -and $fetchedDefault) {
            $DEFAULT_MODEL = $fetchedDefault
            $DEFAULT_MODEL_DISPLAY = $fetchedDisplay
        }
    }
} catch {
    Write-Warn "Could not auto-fetch models: $_"
}

# Final safety net - force the static default if somehow still empty.
if ([string]::IsNullOrWhiteSpace($DEFAULT_MODEL)) {
    $DEFAULT_MODEL = "anthropic/claude-sonnet-4.6"
    $DEFAULT_MODEL_DISPLAY = "Claude Sonnet 4.6"
}
if ([string]::IsNullOrWhiteSpace($DEFAULT_MODEL_DISPLAY)) { $DEFAULT_MODEL_DISPLAY = $DEFAULT_MODEL }

$TEMPLATE = "$COWORK_REPO_DIR\config\opencode.json.template"
if (Test-Path $TEMPLATE) {
    $content = Get-Content $TEMPLATE -Raw
    $content = $content -replace '__PROVIDER_KEY__', $PROVIDER_NAME
    $content = $content -replace '__API_KEY__', $API_KEY
    $content = $content -replace '__APP_NAME__', $APP_NAME
    $content = $content -replace '__DEFAULT_MODEL__', $DEFAULT_MODEL
    $content = $content -replace '__DEFAULT_MODEL_DISPLAY__', $DEFAULT_MODEL_DISPLAY
    Write-Utf8NoBom "$OPENCODE_CONFIG_DIR\opencode.json" $content
    # Also copy to build directory (OpenCode reads config from CWD)
    Copy-Item "$OPENCODE_CONFIG_DIR\opencode.json" "$BUILD_DIR\opencode.json" -Force -ErrorAction SilentlyContinue
    Write-Ok "AI models configured (default: $DEFAULT_MODEL)"
}

# Merge the 15 fetched models (top 5 per family) into the config.
if (Test-Path $FETCHED_MODELS_FILE) {
    try {
        $config = Get-Content "$OPENCODE_CONFIG_DIR\opencode.json" -Raw | ConvertFrom-Json
        $extra = Get-Content $FETCHED_MODELS_FILE -Raw | ConvertFrom-Json
        $providerKey = $PROVIDER_NAME
        if ($config.provider.PSObject.Properties[$providerKey]) {
            $added = 0
            foreach ($m in $extra.models.PSObject.Properties) {
                $config.provider.$providerKey.models | Add-Member -MemberType NoteProperty -Name $m.Name -Value $m.Value -Force
                $added++
            }
            Write-Utf8NoBom "$OPENCODE_CONFIG_DIR\opencode.json" ($config | ConvertTo-Json -Depth 10)
            Copy-Item "$OPENCODE_CONFIG_DIR\opencode.json" "$BUILD_DIR\opencode.json" -Force -ErrorAction SilentlyContinue
            Write-Ok "Loaded $added latest models from Anthropic / OpenAI / Google"
        }
    } catch {
        Write-Warn "Could not load fetched models: $_"
    }
    Remove-Item -Path $FETCHED_MODELS_FILE -Force -ErrorAction SilentlyContinue
}

# Merge extra models from config/models.json
$MODELS_FILE = "$COWORK_REPO_DIR\config\models.json"
if (Test-Path $MODELS_FILE) {
    try {
        $config = Get-Content "$OPENCODE_CONFIG_DIR\opencode.json" -Raw | ConvertFrom-Json
        $extra = Get-Content $MODELS_FILE -Raw | ConvertFrom-Json
        $providerKey = $PROVIDER_NAME
        if ($config.provider.PSObject.Properties[$providerKey]) {
            $extraModels = $extra.models.PSObject.Properties
            $added = 0
            foreach ($m in $extraModels) {
                $config.provider.$providerKey.models | Add-Member -MemberType NoteProperty -Name $m.Name -Value $m.Value -Force
                $added++
            }
            Write-Utf8NoBom "$OPENCODE_CONFIG_DIR\opencode.json" ($config | ConvertTo-Json -Depth 10)
            Copy-Item "$OPENCODE_CONFIG_DIR\opencode.json" "$BUILD_DIR\opencode.json" -Force -ErrorAction SilentlyContinue
            Write-Ok "Added $added extra models from models.json"
        }
    } catch {
        Write-Warn "Could not merge extra models: $_"
    }
}

# Install npm provider SDK
$pkgJsonContent = '{ "dependencies": { "@ai-sdk/openai-compatible": "latest", "@opencode-ai/plugin": "1.2.27" } }'
Write-Utf8NoBom "$OPENCODE_CONFIG_DIR\package.json" $pkgJsonContent
Push-Location $OPENCODE_CONFIG_DIR
bun install 2>&1 | Out-Null
Pop-Location
if (Test-Path "$OPENCODE_CONFIG_DIR\node_modules\@ai-sdk") {
    Write-Ok "AI provider SDK installed"
} else {
    Write-Warn "SDK install may have failed -- will retry on first launch"
}

# Legal + Finance commands
foreach ($CMD_TYPE in @("legal", "finance")) {
    $CMDS_SRC = "$COWORK_REPO_DIR\commands\$CMD_TYPE"
    if (Test-Path $CMDS_SRC) {
        $CMDS_DEST = "$OPENCODE_CONFIG_DIR\commands\$CMD_TYPE"
        if (Test-Path $CMDS_DEST) { Remove-Item -Recurse -Force $CMDS_DEST }
        Copy-Item -Recurse $CMDS_SRC $CMDS_DEST
        $skillCount = (Get-ChildItem "$CMDS_DEST" -Recurse -Filter "SKILL.md").Count
        Write-Ok "$skillCount $CMD_TYPE skills installed"
    }
}

# Deploy agent rules
$RULES_SRC = "$COWORK_REPO_DIR\opencode.md"
if (Test-Path $RULES_SRC) {
    Copy-Item $RULES_SRC "$OPENCODE_CONFIG_DIR\opencode.md" -Force
    Write-Ok "Agent rules deployed"
}

# Default project with sandbox rules
$DEFAULT_PROJECT = "$env:USERPROFILE\$APP_NAME Projects"
New-Item -ItemType Directory -Force -Path $DEFAULT_PROJECT | Out-Null
$CLAUDE_SRC = "$COWORK_REPO_DIR\CLAUDE.md"
if (Test-Path $CLAUDE_SRC) {
    attrib -H -S "$DEFAULT_PROJECT\CLAUDE.md" 2>$null
    Copy-Item $CLAUDE_SRC "$DEFAULT_PROJECT\CLAUDE.md" -Force
    attrib +H +S "$DEFAULT_PROJECT\CLAUDE.md" 2>$null
    Write-Ok "Sandbox rules deployed (hidden)"
}
# Save template for auto-injection
$sandboxDir = "$OPENCODE_CONFIG_DIR\sandbox"
New-Item -ItemType Directory -Force -Path $sandboxDir | Out-Null
Copy-Item $CLAUDE_SRC "$sandboxDir\CLAUDE.md.template" -Force

Write-Ok "Default project: $DEFAULT_PROJECT"

# Settings - MERGE with existing (don't destroy other app settings)
$PROJECT_UUID = [guid]::NewGuid().ToString()
$PROJECT_TS = [long]([datetime]::UtcNow - [datetime]'1970-01-01').TotalMilliseconds
foreach ($dir in @("$env:USERPROFILE\.config\sf-steward", "$env:USERPROFILE\.config\openchamber")) {
    New-Item -ItemType Directory -Force -Path $dir | Out-Null
    $settingsPath = "$dir\settings.json"
    $existing = @{}
    if (Test-Path $settingsPath) {
        try { $existing = Get-Content $settingsPath -Raw | ConvertFrom-Json } catch {}
    }
    # Merge: keep existing projects, add new one
    $existingProjects = @()
    if ($existing.PSObject -and $existing.PSObject.Properties['projects']) {
        $existingProjects = @($existing.projects)
    }
    $newPath = $DEFAULT_PROJECT
    $alreadyExists = $false
    foreach ($p in $existingProjects) {
        if ($p.path -eq $newPath) { $alreadyExists = $true; break }
    }
    if (-not $alreadyExists) {
        $existingProjects += @{ id = $PROJECT_UUID; path = $newPath; addedAt = $PROJECT_TS; lastOpenedAt = $PROJECT_TS }
    }
    $merged = @{
        defaultModel = "${PROVIDER_NAME}/${DEFAULT_MODEL}"
        projects = $existingProjects
        activeProjectId = $PROJECT_UUID
    }
    # Preserve other existing settings (theme, etc.)
    if ($existing.PSObject) {
        foreach ($prop in $existing.PSObject.Properties) {
            if ($prop.Name -notin @('defaultModel','projects','activeProjectId')) {
                $merged[$prop.Name] = $prop.Value
            }
        }
    }
    Write-Utf8NoBom $settingsPath ($merged | ConvertTo-Json -Depth 10)
}
Write-Ok "Settings configured (merged with existing)"

# Clear Electron app data (stale Zustand state from previous installs)
$electronCache = "$env:APPDATA\$APP_NAME"
if (Test-Path $electronCache) { Remove-Item -Recurse -Force $electronCache -ErrorAction SilentlyContinue }

[System.Environment]::SetEnvironmentVariable("OPENROUTER_API_KEY", $API_KEY, "User")
$env:OPENROUTER_API_KEY = $API_KEY
Write-Ok "API key set"

Write-Host ""
Write-Host "  +==========================================+" -ForegroundColor Blue
Write-Host "  |         Installation Complete!            |" -ForegroundColor Blue
Write-Host "  +==========================================+" -ForegroundColor Blue
Write-Host ""
Write-Host "  * $APP_NAME desktop app" -ForegroundColor Green
Write-Host "  * AI models (default: $DEFAULT_MODEL)" -ForegroundColor Green
Write-Host "  * oh-my-openagent plugin" -ForegroundColor Green
Write-Host "  * Legal + Finance commands" -ForegroundColor Green
Write-Host "  * Directory sandbox (hidden CLAUDE.md)" -ForegroundColor Green
Write-Host ""

Write-Host "Done. Launch $APP_NAME from your Start Menu." -ForegroundColor Green
