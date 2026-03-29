# ============================================================
#  OpenCode Cowork — Windows ARM64 Installer (Copilot+ PCs)
#
#  Delegates to install-windows.ps1 which handles both x64 and
#  ARM64 architectures automatically.
# ============================================================

Write-Host ""
Write-Host "  OpenCode Cowork supports both x64 and ARM64 (Copilot+ PCs)." -ForegroundColor Blue
Write-Host "  Running the standard Windows installer..." -ForegroundColor Blue
Write-Host ""

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
& "$scriptDir\install-windows.ps1"
