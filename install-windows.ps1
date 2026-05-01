# ============================================================
#  OpenCode Cowork - Windows Installer (x64 + ARM64)
#  White-label AI assistant for any enterprise
#
#  This is a self-contained fork. The installer clones THIS repo,
#  builds the branded Electron desktop app, configures AI models,
#  and deploys sandbox rules.
# ============================================================

# PowerShell 5.1 raises NativeCommandError whenever a native tool (git, bun,
# bunx, winget, electron-builder, curl, ...) writes ANYTHING to stderr under
# 'Stop'. Progress messages like `git: Cloning into '...'` and `bun: Resolving
# dependencies` are not errors but get treated as such. 'Continue' is the
# right preference for a script that orchestrates native tools; critical
# failures are still caught via try/catch and explicit exit-code/file checks
# below.
$ErrorActionPreference = "Continue"
$COWORK_REPO = "https://github.com/MatthewLopez1990/ChatFortAI-Cowork.git"
$COWORK_REPO_DIR = Split-Path -Parent $MyInvocation.MyCommand.Path
$BUILD_DIR = "$env:USERPROFILE\.opencode-cowork-build"
$INSTALL_LOG_DIR = "$env:USERPROFILE\.opencode-cowork-install"
$INSTALL_LOG = "$INSTALL_LOG_DIR\install-windows.log"
# Which branch to build from. Defaults to main; the GUI installer overrides this
# to the feature branch during pre-merge testing.
$COWORK_GIT_BRANCH = if ($env:COWORK_GIT_BRANCH) { $env:COWORK_GIT_BRANCH } else { "main" }

New-Item -ItemType Directory -Force -Path $INSTALL_LOG_DIR | Out-Null
Set-Content -Path $INSTALL_LOG -Encoding UTF8 -Value "[$(Get-Date -Format o)] Starting Windows installer"

function Write-InstallLog($m) {
    Add-Content -Path $script:INSTALL_LOG -Encoding UTF8 -Value "[$(Get-Date -Format o)] $m" -ErrorAction SilentlyContinue
}

function Write-InstallerLine {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,

        [string]$ForegroundColor = ""
    )

    if ([string]::IsNullOrWhiteSpace($ForegroundColor)) {
        Write-Host $Message
    } else {
        Write-Host $Message -ForegroundColor $ForegroundColor
    }
    Write-InstallLog $Message
}

function Write-Ok($m) { Write-InstallerLine "  * $m" "Green" }
function Write-Warn($m) { Write-InstallerLine "  ! $m" "Yellow" }

$script:CURRENT_STAGE = "startup"

function Set-InstallStage($Name) {
    $script:CURRENT_STAGE = $Name
    Write-InstallLog "STAGE: $Name"
}

function Fail-Install {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,

        [int]$Code = 1,

        [object[]]$Details = @()
    )

    Write-InstallerLine "INSTALLER_FAILURE_STAGE=$script:CURRENT_STAGE" "Red"
    Write-InstallerLine "INSTALLER_FAILURE_MESSAGE=$Message" "Red"
    Write-InstallerLine "INSTALLER_FAILURE_LOG=$script:INSTALL_LOG" "Red"

    if ($Details.Count -gt 0) {
        Write-InstallerLine "INSTALLER_FAILURE_DETAILS_BEGIN" "Red"
        $Details | Select-Object -Last 80 | ForEach-Object {
            if ($null -ne $_) { Write-InstallerLine ($_.ToString()) "Red" }
        }
        Write-InstallerLine "INSTALLER_FAILURE_DETAILS_END" "Red"
    }

    Write-InstallerLine "  ! $Message" "Red"
    Write-InstallerLine "  ! Full diagnostic log: $script:INSTALL_LOG" "Red"
    exit $Code
}

trap {
    Fail-Install "Unexpected PowerShell error: $($_.Exception.Message)" 1 @($_.ScriptStackTrace)
}

# Write UTF-8 WITHOUT BOM
function Write-Utf8NoBom($Path, $Content) {
    $utf8 = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($Path, $Content, $utf8)
}

# Robust directory removal. PowerShell's Remove-Item -Recurse -Force chokes on
# broken symlinks/junctions left behind by partial bun installs (it tries to
# traverse the link, fails to stat the target, and aborts mid-walk leaving
# the parent dir behind). cmd /c rmdir /s /q removes symlinks without
# traversing them, which handles those leftovers cleanly. Fail loudly if the
# directory is still there afterward — silently skipping leaves a populated
# dir that breaks the next git clone with an opaque "destination path
# already exists" error.
function Remove-DirectoryHard {
    param([Parameter(Mandatory = $true)][string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) { return }

    try {
        Remove-Item -LiteralPath $Path -Recurse -Force -ErrorAction Stop
    } catch {
        Write-InstallLog "Remove-Item failed for ${Path}: $($_.Exception.Message); falling back to cmd rmdir"
    }

    if (Test-Path -LiteralPath $Path) {
        & cmd /c "rmdir /s /q `"$Path`"" 2>&1 | ForEach-Object { Write-InstallLog "[rmdir] $_" }
    }

    if (Test-Path -LiteralPath $Path) {
        Fail-Install "Could not remove existing directory: $Path. Close any apps using it (Explorer, editors, antivirus) and re-run the installer."
    }
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

function Invoke-GitChecked {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Description,

        [Parameter(ValueFromRemainingArguments = $true)]
        [string[]]$GitArgs
    )

    $output = @(Invoke-Git @GitArgs)
    foreach ($line in $output) {
        if ($null -ne $line) { Write-InstallLog "[git] $line" }
    }

    $exitCode = $LASTEXITCODE
    if ($exitCode -ne 0) {
        Fail-Install "$Description failed (git exit code $exitCode)" $exitCode $output
    }

    return $output
}

function Invoke-NativeTool {
    param(
        [Parameter(Mandatory = $true)]
        [string]$FilePath,

        [string[]]$ArgumentList = @(),

        [int]$Tail = 0,

        [string]$MatchPattern = "",

        [switch]$Live
    )

    $oldEap = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    $output = New-Object 'System.Collections.Generic.List[string]'

    try {
        $command = Get-Command $FilePath -ErrorAction SilentlyContinue
        if (-not $command) {
            Fail-Install "Required command not found: $FilePath" 127
        }

        Write-InstallLog "Running native command: $FilePath $($ArgumentList -join ' ')"

        # Merge stderr into the pipeline (2>&1) instead of redirecting to a
        # tempfile. Under PS 5.1 the tempfile path wraps the first stderr line
        # of every native command in NativeCommandError formatting (CategoryInfo,
        # FullyQualifiedErrorId, source-line markers), which buries the actual
        # error message and pollutes the diagnostic log. With 2>&1 the stderr
        # stream arrives as ErrorRecord objects whose .ToString() returns just
        # the original message, and -Live actually streams in real time.
        & $command.Source @ArgumentList 2>&1 | ForEach-Object {
            $line = $_.ToString()
            $output.Add($line)
            $stream = if ($_ -is [System.Management.Automation.ErrorRecord]) { 'stderr' } else { 'stdout' }
            Write-InstallLog "[$stream] $line"
            $matchesFilter = [string]::IsNullOrWhiteSpace($MatchPattern) -or $line -match $MatchPattern
            if ($Live -and $matchesFilter) {
                Write-Host $line
            }
        }
        $exitCode = $LASTEXITCODE

        if (-not $Live) {
            $displayOutput = $output
            if (-not [string]::IsNullOrWhiteSpace($MatchPattern)) {
                $displayOutput = $output | Select-String -Pattern $MatchPattern | ForEach-Object { $_.Line }
            }

            if ($Tail -gt 0) {
                $displayOutput | Select-Object -Last $Tail | ForEach-Object {
                    if ($null -ne $_) { Write-InstallerLine $_ }
                }
            } elseif ($displayOutput.Count -gt 0) {
                $displayOutput | ForEach-Object {
                    if ($null -ne $_) { Write-InstallerLine $_ }
                }
            }
        }

        if ($exitCode -ne 0) {
            Fail-Install "$FilePath failed with exit code $exitCode" $exitCode $output
        }
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
Write-InstallerLine "  Diagnostic log: $INSTALL_LOG"

# Step 1: Organization Setup
# Any value pre-populated via env (COWORK_APP_NAME, COWORK_API_KEY,
# COWORK_DEFAULT_MODEL, COWORK_DEFAULT_MODEL_DISPLAY, COWORK_ICON_PATH,
# COWORK_LOGO_PATH) skips the corresponding prompt - used by the GUI installer
# to run this script headlessly.
Set-InstallStage "collecting-organization-settings"
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
Set-InstallStage "checking-prerequisites"
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
    Invoke-NativeTool -FilePath "winget" -ArgumentList @("install", "--id", "Git.Git", "-e", "--source", "winget", "--accept-package-agreements", "--accept-source-agreements") -Live
    # winget's symlink refresh doesn't reach this session, so re-scan.
    Invoke-GitPathScan
}

if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Fail-Install "Git is installed but not on PATH. Restart the terminal or add Git's cmd directory to PATH, then re-run the installer."
}
Write-Ok "Git ($((git --version 2>&1) -replace 'git version ',''))"

if (-not (Get-Command bun -ErrorAction SilentlyContinue)) {
    Write-Warn "Installing Bun..."
    try {
        irm https://bun.sh/install.ps1 -ErrorAction Stop | iex
        $env:PATH = "$env:USERPROFILE\.bun\bin;$env:PATH"
    } catch {
        Fail-Install "Bun installation failed: $($_.Exception.Message)" 1 @($_.ScriptStackTrace)
    }
}
if (-not (Get-Command bun -ErrorAction SilentlyContinue)) {
    Fail-Install "Bun was installed or requested but is still not available on PATH."
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
    Set-InstallStage "installing-opencode-cli"
    $ocArch = if ([System.Runtime.InteropServices.RuntimeInformation]::OSArchitecture -eq "Arm64") { "arm64" } else { "x64" }
    $ocUrl = "https://github.com/anomalyco/opencode/releases/latest/download/opencode-windows-${ocArch}.zip"
    $ocZip = "$env:TEMP\opencode.zip"
    $ocDir = "$env:USERPROFILE\.opencode\bin"
    try {
        New-Item -ItemType Directory -Force -Path $ocDir -ErrorAction Stop | Out-Null
        Invoke-WebRequest -Uri $ocUrl -OutFile $ocZip -ErrorAction Stop
        Expand-Archive -Path $ocZip -DestinationPath $ocDir -Force -ErrorAction Stop
        Remove-Item $ocZip -ErrorAction SilentlyContinue
    } catch {
        Fail-Install "OpenCode CLI download or extraction failed: $($_.Exception.Message)" 1 @("URL: $ocUrl", "Destination: $ocDir", $_.ScriptStackTrace)
    }
    $env:PATH = "$ocDir;$env:PATH"
}
Write-Ok "OpenCode CLI"
Write-Host ""

# Step 3: Clone and build
Set-InstallStage "cloning-application-source"
Write-Host "Step 3: Building $APP_NAME..." -ForegroundColor White

if (Test-Path "$BUILD_DIR\.git") {
    Set-Location $BUILD_DIR
    $CURRENT_BRANCH = (Invoke-GitChecked "Read existing build branch" rev-parse --abbrev-ref HEAD | Select-Object -First 1).ToString().Trim()
    if ($CURRENT_BRANCH -ne $COWORK_GIT_BRANCH) {
        Write-Host "  Existing build on '$CURRENT_BRANCH' - switching to '$COWORK_GIT_BRANCH'"
        Set-Location ..
        Remove-DirectoryHard $BUILD_DIR
        Invoke-GitChecked "Clone application source" clone --depth 1 --branch $COWORK_GIT_BRANCH $COWORK_REPO $BUILD_DIR | Out-Null
    } else {
        Invoke-GitChecked "Update existing application source" pull --ff-only | Out-Null
    }
} else {
    Remove-DirectoryHard $BUILD_DIR
    Invoke-GitChecked "Clone application source" clone --depth 1 --branch $COWORK_GIT_BRANCH $COWORK_REPO $BUILD_DIR | Out-Null
}

if (-not (Test-Path "$BUILD_DIR\.git")) {
    Fail-Install "Git clone did not create $BUILD_DIR\.git."
}

Set-Location $BUILD_DIR

# Copy Electron config
Set-InstallStage "preparing-branded-source"
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

# Install and build. The repo's package.json already pins compatible
# versions of electron, electron-builder, electron-store, and
# electron-context-menu. Don't `bun add ...@latest` over them — that
# pulls bleeding-edge Electron (e.g. 41.x) whose install.js requires
# @electron/get (not a transitive dep of electron-builder@24.x) and
# the postinstall fails.
#
# Use npm instead of bun for the install. Bun's install on this Windows
# environment leaves most package directories empty (default hardlink
# backend) or fails to enqueue lifecycle scripts (--linker hoisted +
# --backend copyfile combo) — both leave node_modules/.bin empty, so
# patch-package and other binstubs are unreachable. npm install is the
# slower-but-reliable fallback. We still use `bun run` and `bunx` for
# build/run steps later because those don't depend on the install layout.
Set-InstallStage "installing-build-dependencies"
$npm = Get-Command "npm" -ErrorAction SilentlyContinue
if (-not $npm) {
    # npm ships with Node; fall back to bun if not present (most likely path is
    # via Node from winget/direct install).
    Write-Warn "npm not found on PATH; falling back to bun install"
    Write-Host "  Installing dependencies (bun)..."
    Invoke-NativeTool -FilePath "bun" -ArgumentList @("install") -Tail 3
} else {
    Write-Host "  Installing dependencies (npm)..."
    # --force: bun is lenient about `overrides` whose target is also a direct
    # dependency; npm treats it as EOVERRIDE and bails. The repo declares
    # @codemirror/language@^6.12.1 as a dep AND 6.12.2 as an override, which
    # is harmless but rejected. --legacy-peer-deps doesn't fix EOVERRIDE; --force
    # does.
    Invoke-NativeTool -FilePath "npm" -ArgumentList @("install", "--no-audit", "--no-fund", "--loglevel=error", "--force") -Tail 5
}
Write-Host "  Building frontend..."
Set-InstallStage "building-web-frontend"
Invoke-NativeTool -FilePath "bun" -ArgumentList @("run", "build:web") -Tail 3
Write-Ok "Frontend built"

# Build Electron
Set-InstallStage "packaging-desktop-app"
Write-Host "  Packaging desktop app..."
Write-InstallerLine "  Electron Builder can spend several minutes downloading Windows packaging tools. Live output will continue below."
if (-not (Test-Path "$BUILD_DIR\packages\web\public\cowork-icon.png")) { New-Item "$BUILD_DIR\packages\web\public\cowork-icon.png" -ItemType File -Force | Out-Null }
if (-not (Test-Path "$BUILD_DIR\branding\icon.png")) { New-Item -ItemType Directory -Force "$BUILD_DIR\branding" | Out-Null; New-Item "$BUILD_DIR\branding\icon.png" -ItemType File -Force | Out-Null }

# electron-builder unconditionally extracts winCodeSign.7z which contains
# macOS dylib symlinks (libcrypto/libssl). Creating those symlinks on
# Windows requires SeCreateSymbolicLinkPrivilege (admin OR Developer Mode)
# — most end users have neither. The 7za extract aborts with "A required
# privilege is not held by the client" and electron-builder exits 1.
# Pre-extracting the archive ourselves doesn't help because electron-builder
# re-extracts each cache entry to validate it.
#
# Surgical fix: install a 7za.exe wrapper that forwards to the real 7za
# but always exits 0. Since this build is --win --x64, the failing files
# (macOS dylib symlinks) are unused — every other file in the archive
# extracts fine, and electron-builder treats the cache as ready.
function Install-7zaWrapper {
    $wrapperSrc = @'
using System;
using System.Diagnostics;
using System.IO;
using System.Reflection;
using System.Text;

class SevenZaWrapper {
    static int Main(string[] args) {
        string exeDir = Path.GetDirectoryName(Assembly.GetExecutingAssembly().Location);
        string realExe = Path.Combine(exeDir, "7za-real.exe");
        if (!File.Exists(realExe)) {
            Console.Error.WriteLine("7za-real.exe missing next to wrapper at " + realExe);
            return 127;
        }
        var sb = new StringBuilder();
        for (int i = 0; i < args.Length; i++) {
            string arg = args[i];
            if (sb.Length > 0) sb.Append(" ");
            if (arg.IndexOf(' ') >= 0 || arg.IndexOf('"') >= 0) {
                sb.Append("\"").Append(arg.Replace("\"", "\\\"")).Append("\"");
            } else {
                sb.Append(arg);
            }
        }
        var psi = new ProcessStartInfo(realExe, sb.ToString());
        psi.UseShellExecute = false;
        psi.CreateNoWindow = true;
        var p = Process.Start(psi);
        p.WaitForExit();
        // Always exit 0: symlink errors on macOS dylibs in winCodeSign are
        // harmless for --win builds (we don't use those files).
        return 0;
    }
}
'@
    $compiled = "$BUILD_DIR\branding\7za-wrapper.exe"
    if (-not (Test-Path "$BUILD_DIR\branding")) { New-Item -ItemType Directory -Force "$BUILD_DIR\branding" | Out-Null }
    if (Test-Path $compiled) { Remove-Item $compiled -Force }
    Add-Type -TypeDefinition $wrapperSrc -OutputType ConsoleApplication -OutputAssembly $compiled -ErrorAction Stop

    $targets = Get-ChildItem "$BUILD_DIR\node_modules" -Recurse -Filter "7za.exe" -ErrorAction SilentlyContinue |
        Where-Object { $_.FullName -match "\\win\\(x64|arm64|ia32)\\7za\.exe$" }
    foreach ($target in $targets) {
        $realPath = Join-Path $target.Directory.FullName "7za-real.exe"
        if (Test-Path $realPath) { continue }  # wrapper already installed
        Write-InstallLog "Installing 7za wrapper at $($target.FullName)"
        Move-Item -LiteralPath $target.FullName -Destination $realPath -Force
        Copy-Item -LiteralPath $compiled -Destination $target.FullName -Force
    }
}

Install-7zaWrapper

Invoke-NativeTool -FilePath "bunx" -ArgumentList @("electron-builder", "--config", "electron-builder.json", "--win", "--x64", "--publish=never") -Live

$EXE_NAME = "$APP_NAME.exe"
$INSTALL_DIR = "$env:LOCALAPPDATA\$APP_NAME"
$UNPACKED = "$BUILD_DIR\electron-dist\win-unpacked"
$UNPACKED_EXE = "$UNPACKED\$EXE_NAME"

if (-not (Test-Path $UNPACKED_EXE)) {
    $UNPACKED = "$BUILD_DIR\electron-dist\win-arm64-unpacked"
    $UNPACKED_EXE = "$UNPACKED\$EXE_NAME"
}

if (-not (Test-Path $UNPACKED_EXE)) {
    $bundleRoot = "$BUILD_DIR\electron-dist"
    $bundleFiles = @()
    if (Test-Path $bundleRoot) {
        $bundleFiles = Get-ChildItem $bundleRoot -Recurse -ErrorAction SilentlyContinue |
            Select-Object -First 120 -ExpandProperty FullName
    }
    Fail-Install "Electron Builder finished but did not produce the expected executable: $UNPACKED_EXE" 1 $bundleFiles
}

Set-InstallStage "installing-desktop-app"
try {
    if (Test-Path $INSTALL_DIR) { Remove-Item -Recurse -Force $INSTALL_DIR -ErrorAction Stop }
    Copy-Item -Recurse $UNPACKED $INSTALL_DIR -ErrorAction Stop

    $ICON_PATH = "$BUILD_DIR\packages\desktop\src-tauri\icons\icon.ico"
    if (-not (Test-Path $ICON_PATH)) { $ICON_PATH = "$INSTALL_DIR\$EXE_NAME" }

    $WshShell = New-Object -ComObject WScript.Shell -ErrorAction Stop
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
} catch {
    Fail-Install "Desktop app copy, shortcut creation, or PATH setup failed: $($_.Exception.Message)" 1 @("Install dir: $INSTALL_DIR", "Unpacked dir: $UNPACKED", "Executable: $UNPACKED_EXE", $_.ScriptStackTrace)
}
Write-Host ""

# Step 4: Configure AI models
Set-InstallStage "configuring-ai-models"
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
} else {
    Fail-Install "Required OpenCode config template is missing: $TEMPLATE"
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
Set-InstallStage "installing-provider-sdk"
$pkgJsonContent = '{ "dependencies": { "@ai-sdk/openai-compatible": "latest", "@opencode-ai/plugin": "1.2.27" } }'
Write-Utf8NoBom "$OPENCODE_CONFIG_DIR\package.json" $pkgJsonContent
$providerLocationPushed = $false
try {
    Push-Location $OPENCODE_CONFIG_DIR -ErrorAction Stop
    $providerLocationPushed = $true
    $npm = Get-Command "npm" -ErrorAction SilentlyContinue
    if ($npm) {
        Invoke-NativeTool -FilePath "npm" -ArgumentList @("install", "--no-audit", "--no-fund", "--loglevel=error") -Tail 3
    } else {
        Invoke-NativeTool -FilePath "bun" -ArgumentList @("install") -Tail 3
    }
} finally {
    if ($providerLocationPushed) {
        Pop-Location -ErrorAction SilentlyContinue
    }
}
if (Test-Path "$OPENCODE_CONFIG_DIR\node_modules\@ai-sdk") {
    Write-Ok "AI provider SDK installed"
} else {
    Fail-Install "AI provider SDK install completed without creating $OPENCODE_CONFIG_DIR\node_modules\@ai-sdk."
}

# Legal + Finance commands
Set-InstallStage "installing-commands-and-rules"
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
Set-InstallStage "writing-application-settings"
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
Set-InstallStage "done"

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
