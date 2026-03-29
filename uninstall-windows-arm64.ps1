# ============================================================
#  OpenCode Cowork — Windows ARM64 Uninstaller
#  Delegates to uninstall-windows.ps1
# ============================================================

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
& "$scriptDir\uninstall-windows.ps1"
