# ============================================================
#  OpenCode Cowork — Windows Uninstaller
#  Removes the app, configuration, shortcuts, and all artifacts.
#  Does NOT remove Bun, Git, or your project files.
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
Write-Host "  ║          $APP_NAME — Uninstaller           ║" -ForegroundColor Red
Write-Host "  ╚══════════════════════════════════════════╝" -ForegroundColor Red
Write-Host ""

Write-Host "  This will remove:" -ForegroundColor Yellow
Write-Host "    - $APP_NAME desktop app"
Write-Host "    - Build directory (~\.opencode-cowork-build)"
Write-Host "    - OpenCode CLI (~\.opencode)"
Write-Host "    - OpenCode configuration (~\.config\opencode)"
Write-Host "    - App settings (~\.config\sf-steward, ~\.config\openchamber)"
Write-Host "    - Desktop and Start Menu shortcuts"
Write-Host "    - COWORK_API_KEY environment variable"
Write-Host ""
Write-Host "  This will NOT remove:" -ForegroundColor Yellow
Write-Host "    - Bun or Git"
Write-Host "    - Your project files"
Write-Host ""

$confirm = Read-Host "  Proceed with uninstall? (y/n)"
if ($confirm -notmatch "^[Yy]") { Write-Host "  Cancelled."; exit 0 }
Write-Host ""

# Step 1: Stop processes
Write-Host "Step 1: Stopping processes..." -ForegroundColor White
foreach ($name in @($APP_NAME, "opencode", "opencode.real", "bun", "node")) {
    Get-Process -Name $name -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
}
Get-Process | ForEach-Object {
    try {
        if ($_.Path -and ($_.Path -like "*opencode*" -or $_.Path -like "*cowork*")) {
            Stop-Process -Id $_.Id -Force -ErrorAction SilentlyContinue
        }
    } catch {}
}
Start-Sleep -Seconds 3
Write-Ok "Processes stopped"

# Step 2: Remove desktop app
Write-Host "Step 2: Removing desktop app..." -ForegroundColor White
$INSTALL_DIR = "$env:LOCALAPPDATA\$APP_NAME"
if (Test-Path $INSTALL_DIR) {
    Remove-Item -Recurse -Force $INSTALL_DIR -ErrorAction SilentlyContinue
    Write-Ok "Removed $INSTALL_DIR"
} else { Write-Skip "App directory" }

# Step 3: Remove shortcuts
Write-Host "Step 3: Removing shortcuts..." -ForegroundColor White
$StartMenuLink = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\$APP_NAME.lnk"
if (Test-Path $StartMenuLink) {
    Remove-Item $StartMenuLink -Force -ErrorAction SilentlyContinue
    Write-Ok "Start Menu shortcut"
} else { Write-Skip "Start Menu shortcut" }

$DesktopCandidates = @(
    [System.Environment]::GetFolderPath("Desktop") + "\$APP_NAME.lnk",
    "$env:USERPROFILE\Desktop\$APP_NAME.lnk",
    "$env:USERPROFILE\OneDrive\Desktop\$APP_NAME.lnk"
)
# Also check OneDrive variants
Get-ChildItem "$env:USERPROFILE\OneDrive*" -Directory -ErrorAction SilentlyContinue | ForEach-Object {
    $DesktopCandidates += "$($_.FullName)\Desktop\$APP_NAME.lnk"
}
$desktopDone = $false
foreach ($link in $DesktopCandidates) {
    if (Test-Path $link) {
        try {
            $item = Get-Item $link -Force
            if ($item.Attributes -band [System.IO.FileAttributes]::ReadOnly) {
                $item.Attributes = $item.Attributes -bxor [System.IO.FileAttributes]::ReadOnly
            }
            Remove-Item $link -Force -ErrorAction Stop
            Write-Ok "Desktop shortcut"
        } catch {
            try { cmd /c "del /f /q `"$link`"" 2>$null } catch {}
            if (-not (Test-Path $link)) { Write-Ok "Desktop shortcut" }
            else { Write-Host "  ! Could not remove — delete manually: $link" -ForegroundColor Yellow }
        }
        $desktopDone = $true
        break
    }
}
if (-not $desktopDone) { Write-Skip "Desktop shortcut" }

# Step 4: Remove OpenCode CLI
Write-Host "Step 4: Removing OpenCode CLI..." -ForegroundColor White
$ocDir = "$env:USERPROFILE\.opencode"
if (Test-Path $ocDir) {
    Remove-Item -Recurse -Force $ocDir -ErrorAction SilentlyContinue
    Write-Ok "Removed $ocDir"
} else { Write-Skip "OpenCode CLI" }

# Step 5: Remove build directory
Write-Host "Step 5: Removing build directory..." -ForegroundColor White
$BUILD_DIR = "$env:USERPROFILE\.opencode-cowork-build"
if (Test-Path $BUILD_DIR) {
    for ($i = 1; $i -le 3; $i++) {
        try {
            Remove-Item -Recurse -Force $BUILD_DIR -ErrorAction Stop
            Write-Ok "Removed $BUILD_DIR"
            break
        } catch {
            if ($i -lt 3) { Start-Sleep -Seconds 2 }
            else { Write-Host "  ! Could not remove — restart and run: Remove-Item -Recurse -Force '$BUILD_DIR'" -ForegroundColor Yellow }
        }
    }
} else { Write-Skip "Build directory" }

# Step 6: Remove configuration
Write-Host "Step 6: Removing configuration..." -ForegroundColor White
foreach ($dir in @(
    "$env:USERPROFILE\.config\opencode",
    "$env:USERPROFILE\.config\sf-steward",
    "$env:USERPROFILE\.config\sf-steward-code",
    "$env:USERPROFILE\.config\openchamber"
)) {
    if (Test-Path $dir) {
        Remove-Item -Recurse -Force $dir -ErrorAction SilentlyContinue
        Write-Ok "Removed $dir"
    }
}

# Remove branding file
Remove-Item "$env:USERPROFILE\.cowork-branding.json" -Force -ErrorAction SilentlyContinue

# Remove any .opencode.json in home
Remove-Item "$env:USERPROFILE\.opencode.json" -Force -ErrorAction SilentlyContinue

# Step 7: Remove environment variable
Write-Host "Step 7: Removing environment variable..." -ForegroundColor White
if ([System.Environment]::GetEnvironmentVariable("COWORK_API_KEY", "User")) {
    [System.Environment]::SetEnvironmentVariable("COWORK_API_KEY", $null, "User")
    Write-Ok "Removed COWORK_API_KEY"
} else { Write-Skip "COWORK_API_KEY" }

# Step 8: Clean PATH
Write-Host "Step 8: Cleaning PATH..." -ForegroundColor White
$userPath = [System.Environment]::GetEnvironmentVariable("PATH", "User")
$pathChanged = $false
$cleanedParts = @()
foreach ($part in ($userPath -split ";")) {
    if ($part -like "*$APP_NAME*" -or $part -like "*opencode-cowork*" -or $part -like "*\.opencode*") {
        $pathChanged = $true
    } else {
        $cleanedParts += $part
    }
}
if ($pathChanged) {
    [System.Environment]::SetEnvironmentVariable("PATH", ($cleanedParts -join ";"), "User")
    Write-Ok "Cleaned PATH"
} else { Write-Skip "PATH entries" }

Write-Host ""
Write-Host "  ╔══════════════════════════════════════════╗" -ForegroundColor Green
Write-Host "  ║          Uninstall Complete                ║" -ForegroundColor Green
Write-Host "  ╚══════════════════════════════════════════╝" -ForegroundColor Green
Write-Host ""
Write-Host "  $APP_NAME has been removed from this machine." -ForegroundColor White
Write-Host "  Your project files were not touched." -ForegroundColor White
Write-Host ""
