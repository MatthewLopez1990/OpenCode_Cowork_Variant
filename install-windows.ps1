# ============================================================
#  OpenCode Cowork — Windows Installer (x64 + ARM64)
#  White-label AI assistant for any enterprise
#
#  Prompts for: App name, API URL, API key, logos
#  Installs: Git, Bun, OpenCode CLI, branded desktop app
#  Configures: AI models, oh-my-opencode plugin,
#              legal + finance commands, directory sandbox
# ============================================================

$ErrorActionPreference = "Stop"
$OPENCHAMBER_REPO = "https://github.com/openchamber/openchamber.git"
$COWORK_REPO_DIR = Split-Path -Parent $MyInvocation.MyCommand.Path
$BUILD_DIR = "$env:USERPROFILE\.opencode-cowork-build"

function Write-Ok($m) { Write-Host "  ✓ $m" -ForegroundColor Green }
function Write-Warn($m) { Write-Host "  ! $m" -ForegroundColor Yellow }

function Write-Utf8NoBom($Path, $Content) {
    $utf8 = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($Path, $Content, $utf8)
}

Write-Host ""
Write-Host "  ╔══════════════════════════════════════════╗" -ForegroundColor Blue
Write-Host "  ║    OpenCode Cowork — Enterprise Installer  ║" -ForegroundColor Blue
Write-Host "  ║    White-label AI for your organization     ║" -ForegroundColor Blue
Write-Host "  ╚══════════════════════════════════════════╝" -ForegroundColor Blue
Write-Host ""

# ── Step 1: Branding ─────────────────────────────────────────
Write-Host "Step 1: Organization Setup" -ForegroundColor White
Write-Host ""

$APP_NAME = ""
while ([string]::IsNullOrWhiteSpace($APP_NAME)) {
    $APP_NAME = Read-Host "  App name (e.g., 'Acme AI Assistant')"
    if ([string]::IsNullOrWhiteSpace($APP_NAME)) { Write-Host "  Required." -ForegroundColor Red }
}

$PROVIDER_DISPLAY = ""
while ([string]::IsNullOrWhiteSpace($PROVIDER_DISPLAY)) {
    $PROVIDER_DISPLAY = Read-Host "  Provider display name (e.g., 'Acme AI')"
    if ([string]::IsNullOrWhiteSpace($PROVIDER_DISPLAY)) { Write-Host "  Required." -ForegroundColor Red }
}
# Create a safe provider ID from the display name
$PROVIDER_NAME = ($PROVIDER_DISPLAY -replace '[^a-zA-Z0-9]', '-').ToLower().Trim('-')

$API_URL = ""
while ([string]::IsNullOrWhiteSpace($API_URL)) {
    $API_URL = Read-Host "  API base URL (e.g., 'https://api.yourcompany.com/v1')"
    if ([string]::IsNullOrWhiteSpace($API_URL)) { Write-Host "  Required." -ForegroundColor Red }
}

$API_KEY = ""
while ([string]::IsNullOrWhiteSpace($API_KEY)) {
    $API_KEY = Read-Host "  API key"
    if ([string]::IsNullOrWhiteSpace($API_KEY)) { Write-Host "  Required." -ForegroundColor Red }
}

$DEFAULT_MODEL = Read-Host "  Default model ID (Enter for 'gpt-4o')"
if ([string]::IsNullOrWhiteSpace($DEFAULT_MODEL)) { $DEFAULT_MODEL = "gpt-4o" }
$DEFAULT_MODEL_DISPLAY = Read-Host "  Default model display name (Enter for '$DEFAULT_MODEL')"
if ([string]::IsNullOrWhiteSpace($DEFAULT_MODEL_DISPLAY)) { $DEFAULT_MODEL_DISPLAY = $DEFAULT_MODEL }

Write-Host ""
Write-Host "  Logo URLs (optional — press Enter to skip):" -ForegroundColor Gray
$SMALL_LOGO_URL = Read-Host "  Small logo URL (favicon/icon, PNG or ICO)"
$LARGE_LOGO_URL = Read-Host "  Large logo URL (landing page, PNG or WebP)"

Write-Ok "Organization: $APP_NAME"
Write-Ok "Provider: $PROVIDER_DISPLAY ($API_URL)"
Write-Ok "Model: $DEFAULT_MODEL"
Write-Host ""

# ── Step 2: Prerequisites ──────────────────────────────────
Write-Host "Step 2: Installing prerequisites..." -ForegroundColor White

if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Write-Warn "Installing Git..."
    winget install --id Git.Git -e --source winget --accept-package-agreements --accept-source-agreements
    $env:PATH = "$env:ProgramFiles\Git\cmd;$env:PATH"
}
Write-Ok "Git"

if (-not (Get-Command bun -ErrorAction SilentlyContinue)) {
    Write-Warn "Installing Bun..."
    irm https://bun.sh/install.ps1 | iex
    $env:PATH = "$env:USERPROFILE\.bun\bin;$env:PATH"
}
Write-Ok "Bun $(bun --version 2>&1)"

if (-not (Get-Command opencode -ErrorAction SilentlyContinue)) {
    Write-Host "  Installing OpenCode CLI..."
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

# ── Step 3: Clone and build ──────────────────────────────
Write-Host "Step 3: Building $APP_NAME..." -ForegroundColor White

if (Test-Path $BUILD_DIR) {
    Set-Location $BUILD_DIR
    git pull 2>&1 | Out-Null
} else {
    git clone --depth 1 $OPENCHAMBER_REPO $BUILD_DIR 2>&1 | Out-Null
}
Set-Location $BUILD_DIR

# Copy electron config from Cowork repo
New-Item -ItemType Directory -Force -Path "$BUILD_DIR\electron" | Out-Null
if (Test-Path "$COWORK_REPO_DIR\electron\main.cjs") {
    Copy-Item "$COWORK_REPO_DIR\electron\main.cjs" "$BUILD_DIR\electron\main.cjs" -Force
}
if (Test-Path "$COWORK_REPO_DIR\electron-builder.json") {
    Copy-Item "$COWORK_REPO_DIR\electron-builder.json" "$BUILD_DIR\electron-builder.json" -Force
}

# Set app name in package.json
$pkgPath = "$BUILD_DIR\package.json"
if (Test-Path $pkgPath) {
    $pkg = Get-Content $pkgPath -Raw | ConvertFrom-Json
    $pkg.name = ($APP_NAME -replace '[^a-zA-Z0-9]', '-').ToLower()
    $pkg.productName = $APP_NAME
    if (-not $pkg.main) { $pkg | Add-Member -NotePropertyName "main" -NotePropertyValue "electron/main.cjs" -Force }
    $pkg | ConvertTo-Json -Depth 10 | Set-Content $pkgPath -Encoding UTF8
}

# Save branding config for the Electron app to read
$brandingJson = @{ appName = $APP_NAME; provider = $PROVIDER_DISPLAY } | ConvertTo-Json
Write-Utf8NoBom "$env:USERPROFILE\.cowork-branding.json" $brandingJson

# Download logos if provided
if ($SMALL_LOGO_URL) {
    Write-Host "  Downloading small logo..."
    New-Item -ItemType Directory -Force -Path "$BUILD_DIR\branding" | Out-Null
    try {
        $ext = if ($SMALL_LOGO_URL -match '\.ico') { "ico" } else { "png" }
        Invoke-WebRequest -Uri $SMALL_LOGO_URL -OutFile "$BUILD_DIR\branding\icon.$ext" -TimeoutSec 15
        # Copy to standard locations
        $iconDirs = @("$BUILD_DIR\packages\desktop\src-tauri\icons", "$BUILD_DIR\packages\web\public")
        foreach ($dir in $iconDirs) {
            if (Test-Path $dir) {
                Copy-Item "$BUILD_DIR\branding\icon.$ext" "$dir\favicon.png" -Force -ErrorAction SilentlyContinue
                Copy-Item "$BUILD_DIR\branding\icon.$ext" "$dir\icon.png" -Force -ErrorAction SilentlyContinue
            }
        }
        Write-Ok "Small logo applied"
    } catch {
        Write-Warn "Could not download small logo — using default"
    }
}

if ($LARGE_LOGO_URL) {
    Write-Host "  Downloading large logo..."
    try {
        $ext = if ($LARGE_LOGO_URL -match '\.webp') { "webp" } elseif ($LARGE_LOGO_URL -match '\.svg') { "svg" } else { "png" }
        Invoke-WebRequest -Uri $LARGE_LOGO_URL -OutFile "$BUILD_DIR\packages\web\public\logo.$ext" -TimeoutSec 15
        Write-Ok "Large logo applied"
    } catch {
        Write-Warn "Could not download large logo — using default"
    }
}

# Update HTML title
$indexHtml = "$BUILD_DIR\packages\web\index.html"
if (Test-Path $indexHtml) {
    $html = Get-Content $indexHtml -Raw
    $html = $html -replace '<title>[^<]*</title>', "<title>$APP_NAME</title>"
    Set-Content $indexHtml $html -Encoding UTF8
}

Write-Host "  Installing dependencies..."
bun install 2>&1 | Select-Object -Last 1
Write-Host "  Building branded frontend..."
bun run build:web 2>&1 | Select-Object -Last 3
Write-Ok "Frontend built"

# Build Electron app
Write-Host "  Packaging desktop app (this may take a few minutes)..."
$EXE_NAME = "$APP_NAME.exe"
$INSTALL_DIR = "$env:LOCALAPPDATA\$APP_NAME"

# Update electron-builder config with app name
$ebConfig = "$BUILD_DIR\electron-builder.json"
if (Test-Path $ebConfig) {
    $eb = Get-Content $ebConfig -Raw | ConvertFrom-Json
    $eb.appId = "com.cowork.$PROVIDER_NAME"
    $eb.productName = $APP_NAME
    $eb | ConvertTo-Json -Depth 5 | Set-Content $ebConfig -Encoding UTF8
}

bunx electron-builder --config electron-builder.json --win --x64 2>&1 | Select-String -Pattern "(building|packaging|target=)" | Select-Object -Last 5

$UNPACKED = "$BUILD_DIR\electron-dist\win-unpacked"
$UNPACKED_EXE = "$UNPACKED\$EXE_NAME"
if (-not (Test-Path $UNPACKED_EXE)) {
    $UNPACKED = "$BUILD_DIR\electron-dist\win-arm64-unpacked"
    $UNPACKED_EXE = "$UNPACKED\$EXE_NAME"
}

if (Test-Path $UNPACKED_EXE) {
    Write-Host "  Installing to $INSTALL_DIR..."
    if (Test-Path $INSTALL_DIR) { Remove-Item -Recurse -Force $INSTALL_DIR }
    Copy-Item -Recurse $UNPACKED $INSTALL_DIR

    $WshShell = New-Object -ComObject WScript.Shell
    $ICON_PATH = "$INSTALL_DIR\$EXE_NAME"
    if (Test-Path "$BUILD_DIR\branding\icon.ico") { $ICON_PATH = "$BUILD_DIR\branding\icon.ico" }

    # Start Menu shortcut
    $StartMenu = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs"
    $Shortcut = $WshShell.CreateShortcut("$StartMenu\$APP_NAME.lnk")
    $Shortcut.TargetPath = "$INSTALL_DIR\$EXE_NAME"
    $Shortcut.WorkingDirectory = $INSTALL_DIR
    $Shortcut.Description = $APP_NAME
    $Shortcut.IconLocation = $ICON_PATH
    $Shortcut.Save()
    Write-Ok "Start Menu shortcut created"

    # Desktop shortcut
    $DesktopPath = [System.Environment]::GetFolderPath("Desktop")
    if ([string]::IsNullOrWhiteSpace($DesktopPath)) { $DesktopPath = "$env:USERPROFILE\Desktop" }
    $DesktopShortcut = $WshShell.CreateShortcut("$DesktopPath\$APP_NAME.lnk")
    $DesktopShortcut.TargetPath = "$INSTALL_DIR\$EXE_NAME"
    $DesktopShortcut.WorkingDirectory = $INSTALL_DIR
    $DesktopShortcut.Description = $APP_NAME
    $DesktopShortcut.IconLocation = $ICON_PATH
    $DesktopShortcut.Save()
    Write-Ok "Desktop shortcut created"

    # Copy icon to install directory
    foreach ($iconFile in @("icon.ico", "icon.png")) {
        $src = "$BUILD_DIR\branding\$iconFile"
        if (Test-Path $src) { Copy-Item $src "$INSTALL_DIR\$iconFile" -Force }
    }

    $currentPath = [System.Environment]::GetEnvironmentVariable("PATH", "User")
    if ($currentPath -notlike "*$INSTALL_DIR*") {
        [System.Environment]::SetEnvironmentVariable("PATH", "$INSTALL_DIR;$currentPath", "User")
        $env:PATH = "$INSTALL_DIR;$env:PATH"
    }
    Write-Ok "$APP_NAME desktop app installed"
} else {
    Write-Warn "Desktop build failed. You can still run: opencode web"
}
Write-Host ""

# ── Step 4: Configure ────────────────────────────────────────
Write-Host "Step 4: Configuring AI models..." -ForegroundColor White

$OPENCODE_CONFIG_DIR = "$env:USERPROFILE\.config\opencode"
New-Item -ItemType Directory -Force -Path $OPENCODE_CONFIG_DIR | Out-Null

$TEMPLATE = "$COWORK_REPO_DIR\config\opencode.json.template"
if (Test-Path $TEMPLATE) {
    $content = Get-Content $TEMPLATE -Raw
    $content = $content -replace '__API_KEY__', $API_KEY
    $content = $content -replace '__API_URL__', $API_URL
    $content = $content -replace '__PROVIDER_NAME__', $PROVIDER_NAME
    $content = $content -replace '__DISPLAY_NAME__', $PROVIDER_DISPLAY
    $content = $content -replace '__DEFAULT_MODEL__', $DEFAULT_MODEL
    $content = $content -replace '__DEFAULT_MODEL_DISPLAY__', $DEFAULT_MODEL_DISPLAY
    Write-Utf8NoBom "$OPENCODE_CONFIG_DIR\opencode.json" $content
    Write-Ok "AI models configured (default: $DEFAULT_MODEL)"
}

# Add extra models from models.json if it exists
$modelsFile = "$COWORK_REPO_DIR\config\models.json"
if (Test-Path $modelsFile) {
    try {
        $configPath = "$OPENCODE_CONFIG_DIR\opencode.json"
        $config = Get-Content $configPath -Raw | ConvertFrom-Json
        $models = Get-Content $modelsFile -Raw | ConvertFrom-Json
        foreach ($prop in $models.models.PSObject.Properties) {
            $config.provider.$PROVIDER_NAME.models | Add-Member -NotePropertyName $prop.Name -NotePropertyValue $prop.Value -Force
        }
        $config | ConvertTo-Json -Depth 20 | Set-Content $configPath -Encoding UTF8
        Write-Ok "Additional models loaded from models.json"
    } catch {
        Write-Warn "Could not load models.json — using default model only"
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
    Write-Warn "SDK install may have failed — will retry on first launch"
}

# Deploy commands (legal + finance) — Anthropic plugins use SKILL.md in subdirectories
foreach ($cmdType in @("legal", "finance")) {
    $CMDS_SRC = "$COWORK_REPO_DIR\commands\$cmdType"
    if (Test-Path $CMDS_SRC) {
        $CMDS_DEST = "$OPENCODE_CONFIG_DIR\commands\$cmdType"
        Copy-Item -Recurse -Force $CMDS_SRC "$OPENCODE_CONFIG_DIR\commands\" -ErrorAction SilentlyContinue
        $skillCount = (Get-ChildItem -Recurse "$CMDS_DEST" -Filter "SKILL.md" -ErrorAction SilentlyContinue).Count
        Write-Ok "$skillCount $cmdType skills installed"
    }
}

# Deploy agent rules
$RULES_SRC = "$COWORK_REPO_DIR\opencode.md"
if (Test-Path $RULES_SRC) {
    Copy-Item $RULES_SRC "$OPENCODE_CONFIG_DIR\opencode.md" -Force
    Write-Ok "Agent rules deployed"
}

# Create default project directory with CLAUDE.md from the repo
$DEFAULT_PROJECT = "$env:USERPROFILE\$APP_NAME Projects"
New-Item -ItemType Directory -Force -Path $DEFAULT_PROJECT | Out-Null
$CLAUDE_SRC = "$COWORK_REPO_DIR\CLAUDE.md"
if (Test-Path $CLAUDE_SRC) {
    attrib -H -S "$DEFAULT_PROJECT\CLAUDE.md" 2>$null
    Copy-Item $CLAUDE_SRC "$DEFAULT_PROJECT\CLAUDE.md" -Force
    attrib +H +S "$DEFAULT_PROJECT\CLAUDE.md" 2>$null
    Write-Ok "Sandbox rules deployed from CLAUDE.md"
}
# Also save a copy as the template for the web server to inject into new directories
New-Item -ItemType Directory -Force -Path "$OPENCODE_CONFIG_DIR\sandbox" | Out-Null
Copy-Item $CLAUDE_SRC "$OPENCODE_CONFIG_DIR\sandbox\CLAUDE.md.template" -Force
Write-Ok "Default project directory: $DEFAULT_PROJECT"

# Settings
foreach ($dir in @("$env:USERPROFILE\.config\sf-steward", "$env:USERPROFILE\.config\openchamber")) {
    New-Item -ItemType Directory -Force -Path $dir | Out-Null
    Write-Utf8NoBom "$dir\settings.json" "{`"defaultModel`":`"${PROVIDER_NAME}:${DEFAULT_MODEL}`"}"
}

[System.Environment]::SetEnvironmentVariable("COWORK_API_KEY", $API_KEY, "User")
$env:COWORK_API_KEY = $API_KEY
Write-Ok "API key saved"

Write-Host ""
Write-Host "  ╔══════════════════════════════════════════╗" -ForegroundColor Blue
Write-Host "  ║         Installation Complete!            ║" -ForegroundColor Blue
Write-Host "  ╚══════════════════════════════════════════╝" -ForegroundColor Blue
Write-Host ""
Write-Host "  ✓ $APP_NAME desktop app installed" -ForegroundColor Green
Write-Host "  ✓ AI models configured (default: $DEFAULT_MODEL)" -ForegroundColor Green
Write-Host "  ✓ oh-my-opencode plugin enabled" -ForegroundColor Green
Write-Host "  ✓ Legal + Finance commands" -ForegroundColor Green
Write-Host "  ✓ Directory sandbox active" -ForegroundColor Green
Write-Host ""
Write-Host "  Default project: $DEFAULT_PROJECT"
Write-Host "  Launch from: Start Menu, Desktop shortcut, or type '$APP_NAME' in Run."
Write-Host ""

$launch = Read-Host "  Launch now? (y/n)"
if ($launch -match "^[Yy]") {
    Start-Process -FilePath "$INSTALL_DIR\$EXE_NAME" -WorkingDirectory $INSTALL_DIR -WindowStyle Normal
    Write-Host "  $APP_NAME is running. You can close this terminal." -ForegroundColor Green
}
