# ============================================================
#  OpenCode Cowork — Windows ARM64 Installer (Copilot+ PCs)
#  White-label AI assistant for any enterprise
#
#  Delegates to install-windows.ps1 which handles both x64 and
#  ARM64. The Electron app runs natively on ARM64.
# ============================================================

Write-Host ""
Write-Host "  OpenCode Cowork supports both x64 and ARM64 (Copilot+ PCs)." -ForegroundColor Blue
Write-Host "  Running the standard Windows installer..." -ForegroundColor Blue
Write-Host ""

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
& "$scriptDir\install-windows.ps1"
