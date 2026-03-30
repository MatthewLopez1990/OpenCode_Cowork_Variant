# ============================================================
#  OpenCode Cowork — Windows Installer (x64 + ARM64)
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

function Write-Ok($m) { Write-Host "  * $m" -ForegroundColor Green }
function Write-Warn($m) { Write-Host "  ! $m" -ForegroundColor Yellow }

# Write UTF-8 WITHOUT BOM
function Write-Utf8NoBom($Path, $Content) {
    $utf8 = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($Path, $Content, $utf8)
}

Write-Host ""
Write-Host "  +==========================================+" -ForegroundColor Blue
Write-Host "  |  OpenCode Cowork - Enterprise Installer   |" -ForegroundColor Blue
Write-Host "  |  White-label AI for your organization      |" -ForegroundColor Blue
Write-Host "  +==========================================+" -ForegroundColor Blue
Write-Host ""

# Step 1: Organization Setup
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
$PROVIDER_NAME = ($PROVIDER_DISPLAY.ToLower() -replace '[^a-z0-9]','-' -replace '-+','-').Trim('-')

$API_URL = ""
while ([string]::IsNullOrWhiteSpace($API_URL)) {
    $API_URL = Read-Host "  API base URL (e.g., 'https://api.yourcompany.com/api')"
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
Write-Ok "Organization: $APP_NAME"
Write-Ok "Provider: $PROVIDER_DISPLAY ($API_URL)"
Write-Ok "Model: $DEFAULT_MODEL"

# Check for branding assets
$ICON_ASSET = Get-ChildItem "$COWORK_REPO_DIR\assets\icon.png" -ErrorAction SilentlyContinue | Select-Object -First 1
$LOGO_ASSET = Get-ChildItem "$COWORK_REPO_DIR\assets\logo.png" -ErrorAction SilentlyContinue | Select-Object -First 1
if ($ICON_ASSET) { Write-Ok "Icon: $($ICON_ASSET.Name)" } else { Write-Host "  - No custom icon -- using defaults" }
if ($LOGO_ASSET) { Write-Ok "Logo: $($LOGO_ASSET.Name)" } else { Write-Host "  - No custom logo -- using defaults" }
Write-Host ""

# Step 2: Prerequisites
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

if (Test-Path $BUILD_DIR) {
    Set-Location $BUILD_DIR
    git pull 2>&1 | Out-Null
} else {
    git clone --depth 1 $COWORK_REPO $BUILD_DIR 2>&1 | Out-Null
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
$ebContent.appId = "com.cowork.$PROVIDER_NAME"
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
    # Also copy to build directory (OpenCode reads config from CWD)
    Copy-Item "$OPENCODE_CONFIG_DIR\opencode.json" "$BUILD_DIR\opencode.json" -Force -ErrorAction SilentlyContinue
    Write-Ok "AI models configured (default: $DEFAULT_MODEL)"
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

# Settings — must include a project entry or the app can't create sessions
$PROJECT_UUID = [guid]::NewGuid().ToString()
$PROJECT_TS = [long]([datetime]::UtcNow - [datetime]'1970-01-01').TotalMilliseconds
$PROJECT_PATH_JSON = ($DEFAULT_PROJECT -replace '\\', '\\')
foreach ($dir in @("$env:USERPROFILE\.config\sf-steward", "$env:USERPROFILE\.config\openchamber")) {
    New-Item -ItemType Directory -Force -Path $dir | Out-Null
    $settingsJson = @"
{
  "defaultModel": "${PROVIDER_NAME}:${DEFAULT_MODEL}",
  "projects": [
    {
      "id": "$PROJECT_UUID",
      "path": "$PROJECT_PATH_JSON",
      "addedAt": $PROJECT_TS,
      "lastOpenedAt": $PROJECT_TS
    }
  ],
  "activeProjectId": "$PROJECT_UUID"
}
"@
    Write-Utf8NoBom "$dir\settings.json" $settingsJson
}
Write-Ok "Default project registered in settings"

[System.Environment]::SetEnvironmentVariable("COWORK_API_KEY", $API_KEY, "User")
$env:COWORK_API_KEY = $API_KEY
Write-Ok "API key set"

Write-Host ""
Write-Host "  +==========================================+" -ForegroundColor Blue
Write-Host "  |         Installation Complete!            |" -ForegroundColor Blue
Write-Host "  +==========================================+" -ForegroundColor Blue
Write-Host ""
Write-Host "  * $APP_NAME desktop app" -ForegroundColor Green
Write-Host "  * AI models (default: $DEFAULT_MODEL)" -ForegroundColor Green
Write-Host "  * oh-my-opencode plugin" -ForegroundColor Green
Write-Host "  * Legal + Finance commands" -ForegroundColor Green
Write-Host "  * Directory sandbox (hidden CLAUDE.md)" -ForegroundColor Green
Write-Host ""

$launch = Read-Host "  Launch now? (y/n)"
if ($launch -match "^[Yy]") {
    if (Test-Path "$INSTALL_DIR\$EXE_NAME") {
        Start-Process -FilePath "$INSTALL_DIR\$EXE_NAME" -WorkingDirectory $INSTALL_DIR -WindowStyle Normal
        Write-Host "  $APP_NAME is running. You can close this terminal." -ForegroundColor Green
    }
}
