# OpenCode Cowork — Windows Diagnostic Script
# Run this to check what's installed and find problems.

Write-Host ""
Write-Host "  OpenCode Cowork Diagnostic Report" -ForegroundColor Cyan
Write-Host "  ==================================" -ForegroundColor Cyan
Write-Host ""

# Read app name from branding
$brandingFile = "$env:USERPROFILE\.cowork-branding.json"
$APP_NAME = "OpenCode Cowork"
if (Test-Path $brandingFile) {
    try {
        $branding = Get-Content $brandingFile -Raw | ConvertFrom-Json
        if ($branding.appName) { $APP_NAME = $branding.appName }
    } catch {}
}
Write-Host "  App Name: $APP_NAME" -ForegroundColor Blue
Write-Host ""

# 1. Config file
$configPath = "$env:USERPROFILE\.config\opencode\opencode.json"
Write-Host "1. Config file: $configPath" -ForegroundColor Yellow
if (Test-Path $configPath) {
    $size = (Get-Item $configPath).Length
    Write-Host "   EXISTS ($size bytes)"
    # Check first 3 bytes for BOM
    $bytes = [System.IO.File]::ReadAllBytes($configPath)
    if ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) {
        Write-Host "   BOM: YES (UTF-8 BOM present)" -ForegroundColor Red
    } else {
        Write-Host "   BOM: No (clean)" -ForegroundColor Green
    }
    try {
        $cfg = Get-Content $configPath -Raw | ConvertFrom-Json
        Write-Host "   JSON parse: OK" -ForegroundColor Green
        Write-Host "   Top-level keys: $($cfg.PSObject.Properties.Name -join ', ')"
        if ($cfg.provider) {
            Write-Host "   Provider keys: $($cfg.provider.PSObject.Properties.Name -join ', ')" -ForegroundColor Green
        } else {
            Write-Host "   Provider: MISSING" -ForegroundColor Red
        }
        Write-Host "   Default model: $($cfg.model)"
    } catch {
        Write-Host "   JSON parse: FAILED -- $($_.Exception.Message)" -ForegroundColor Red
    }
} else {
    Write-Host "   MISSING" -ForegroundColor Red
}
Write-Host ""

# 2. OpenCode binary
Write-Host "2. OpenCode CLI" -ForegroundColor Yellow
$ocPath = (Get-Command opencode -ErrorAction SilentlyContinue)
if ($ocPath) {
    Write-Host "   Found: $($ocPath.Source)" -ForegroundColor Green
} else {
    Write-Host "   NOT FOUND in PATH" -ForegroundColor Red
}
Write-Host ""

# 3. npm provider SDK
Write-Host "3. npm Provider SDK" -ForegroundColor Yellow
$sdkPath = "$env:USERPROFILE\.config\opencode\node_modules\@ai-sdk\openai-compatible"
if (Test-Path $sdkPath) {
    Write-Host "   @ai-sdk/openai-compatible: INSTALLED" -ForegroundColor Green
} else {
    Write-Host "   @ai-sdk/openai-compatible: MISSING" -ForegroundColor Red
}
$pluginPath = "$env:USERPROFILE\.config\opencode\node_modules\@opencode-ai\plugin"
if (Test-Path $pluginPath) {
    Write-Host "   @opencode-ai/plugin: INSTALLED" -ForegroundColor Green
} else {
    Write-Host "   @opencode-ai/plugin: MISSING" -ForegroundColor Red
}
Write-Host ""

# 4. Agent Rules
Write-Host "4. Agent Rules" -ForegroundColor Yellow
$rulesPath = "$env:USERPROFILE\.config\opencode\opencode.md"
if (Test-Path $rulesPath) {
    $lines = (Get-Content $rulesPath).Count
    Write-Host "   opencode.md: EXISTS ($lines lines)" -ForegroundColor Green
} else {
    Write-Host "   opencode.md: MISSING" -ForegroundColor Red
}
Write-Host ""

# 5. Desktop app
Write-Host "5. Desktop App" -ForegroundColor Yellow
$installDir = "$env:LOCALAPPDATA\$APP_NAME"
if (Test-Path $installDir) {
    Write-Host "   Install dir: EXISTS ($installDir)" -ForegroundColor Green
} else {
    Write-Host "   Install dir: MISSING ($installDir)" -ForegroundColor Red
}
Write-Host ""

# 6. Environment
Write-Host "6. Environment" -ForegroundColor Yellow
$apiKey = [System.Environment]::GetEnvironmentVariable("OPENROUTER_API_KEY", "User")
if ($apiKey) {
    Write-Host "   OPENROUTER_API_KEY: SET" -ForegroundColor Green
} else {
    $legacyKey = [System.Environment]::GetEnvironmentVariable("COWORK_API_KEY", "User")
    if ($legacyKey) {
        Write-Host "   OPENROUTER_API_KEY: NOT SET (found legacy COWORK_API_KEY — re-run installer)" -ForegroundColor Yellow
    } else {
        Write-Host "   OPENROUTER_API_KEY: NOT SET" -ForegroundColor Red
    }
}
Write-Host ""

Write-Host "  Done. Share this output for troubleshooting." -ForegroundColor Cyan
Write-Host ""
