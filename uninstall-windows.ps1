# ============================================================
#  OpenCode Cowork — Windows Uninstaller
#  Removes the app, configuration, and shortcuts.
#  Does NOT remove Bun, Git, or project files.
# ============================================================

$ErrorActionPreference = "Continue"

function Write-Ok($m) { Write-Host "  ✓ $m" -ForegroundColor Green }
function Write-Skip($m) { Write-Host "  - $m (not found)" -ForegroundColor Gray }

# Read app name from branding
$APP_NAME = "OpenCode Cowork"
$brandingFile = "$env:USERPROFILE\.cowork-branding.json"
if (Test-Path $brandingFile) {
    try { $APP_NAME = (Get-Content $brandingFile -Raw | ConvertFrom-Json).appName } catch {}
}

Write-Host ""
Write-Host "  ╔══════════════════════════════════════════╗" -ForegroundColor Red
Write-Host "  ║     $APP_NAME — Uninstaller               ║" -ForegroundColor Red
Write-Host "  ╚══════════════════════════════════════════╝" -ForegroundColor Red
Write-Host ""
Write-Host "  This will remove $APP_NAME and its configuration." -ForegroundColor Yellow
Write-Host "  Your project files will NOT be touched." -ForegroundColor Yellow
Write-Host ""

$confirm = Read-Host "  Proceed? (y/n)"
if ($confirm -notmatch "^[Yy]") { Write-Host "  Cancelled."; exit 0 }
Write-Host ""

# Stop processes
Write-Host "Stopping processes..." -ForegroundColor White
foreach ($name in @($APP_NAME, "opencode", "bun", "node")) {
    Get-Process -Name $name -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
}
Start-Sleep -Seconds 3
Write-Ok "Processes stopped"

# Remove app
$INSTALL_DIR = "$env:LOCALAPPDATA\$APP_NAME"
if (Test-Path $INSTALL_DIR) {
    Remove-Item -Recurse -Force $INSTALL_DIR -ErrorAction SilentlyContinue
    Write-Ok "Removed $INSTALL_DIR"
} else { Write-Skip "App directory" }

# Remove shortcuts
$StartMenuLink = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\$APP_NAME.lnk"
if (Test-Path $StartMenuLink) { Remove-Item $StartMenuLink -Force -ErrorAction SilentlyContinue; Write-Ok "Start Menu shortcut" }

$DesktopCandidates = @(
    [System.Environment]::GetFolderPath("Desktop") + "\$APP_NAME.lnk",
    "$env:USERPROFILE\Desktop\$APP_NAME.lnk"
)
foreach ($link in $DesktopCandidates) {
    if (Test-Path $link) {
        try { $item = Get-Item $link -Force; if ($item.Attributes -band [System.IO.FileAttributes]::ReadOnly) { $item.Attributes = $item.Attributes -bxor [System.IO.FileAttributes]::ReadOnly }; Remove-Item $link -Force } catch {}
        Write-Ok "Desktop shortcut"
        break
    }
}

# Remove build directory
$BUILD_DIR = "$env:USERPROFILE\.opencode-cowork-build"
if (Test-Path $BUILD_DIR) {
    Remove-Item -Recurse -Force $BUILD_DIR -ErrorAction SilentlyContinue
    Write-Ok "Removed build directory"
} else { Write-Skip "Build directory" }

# Remove config
foreach ($dir in @("$env:USERPROFILE\.config\opencode", "$env:USERPROFILE\.config\sf-steward", "$env:USERPROFILE\.config\openchamber")) {
    if (Test-Path $dir) { Remove-Item -Recurse -Force $dir -ErrorAction SilentlyContinue; Write-Ok "Removed $dir" }
}

# Remove branding file
Remove-Item "$env:USERPROFILE\.cowork-branding.json" -Force -ErrorAction SilentlyContinue

# Remove env var
if ([System.Environment]::GetEnvironmentVariable("COWORK_API_KEY", "User")) {
    [System.Environment]::SetEnvironmentVariable("COWORK_API_KEY", $null, "User")
    Write-Ok "Removed COWORK_API_KEY"
}

# Clean PATH
$userPath = [System.Environment]::GetEnvironmentVariable("PATH", "User")
$cleanedParts = ($userPath -split ";" | Where-Object { $_ -notlike "*$APP_NAME*" -and $_ -notlike "*opencode-cowork*" })
[System.Environment]::SetEnvironmentVariable("PATH", ($cleanedParts -join ";"), "User")

Write-Host ""
Write-Host "  ✓ $APP_NAME has been removed." -ForegroundColor Green
Write-Host "  Your project files were not touched." -ForegroundColor White
Write-Host ""
