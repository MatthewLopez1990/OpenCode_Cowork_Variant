# ============================================================
#  OpenCode Cowork — Model Manager (Windows)
#
#  Discovers all models from your configured provider's API and
#  lets you pick which ones to load into the app. Works with any
#  OpenAI-compatible endpoint including Open WebUI, where custom
#  workspace models (with tools stripped, etc.) appear alongside
#  base models.
#
#  Usage:
#    .\manage-models.ps1          Normal mode
#    .\manage-models.ps1 -Debug   Dump raw API response and exit
# ============================================================

param(
    [switch]$Debug
)

$ErrorActionPreference = "Stop"

$CONFIG_FILE = "$env:USERPROFILE\.config\opencode\opencode.json"
$BUILD_CONFIG = "$env:USERPROFILE\.opencode-cowork-build\opencode.json"

if (-not (Test-Path $CONFIG_FILE)) {
    Write-Host "Error: No config found at $CONFIG_FILE" -ForegroundColor Red
    Write-Host "Run the installer first."
    exit 1
}

# Write UTF-8 WITHOUT BOM (same helper as installer)
function Write-Utf8NoBom($Path, $Content) {
    $utf8 = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($Path, $Content, $utf8)
}

# Load config
$config = Get-Content $CONFIG_FILE -Raw | ConvertFrom-Json

if (-not $config.provider -or $config.provider.PSObject.Properties.Count -eq 0) {
    Write-Host "Error: No provider configured in opencode.json" -ForegroundColor Red
    exit 1
}

# Use the first provider (Cowork variant has exactly one)
$providerProp = $config.provider.PSObject.Properties | Select-Object -First 1
$PROVIDER_KEY = $providerProp.Name
$provider = $providerProp.Value
$PROVIDER_NAME = if ($provider.name) { $provider.name } else { $PROVIDER_KEY }
$BASE_URL = ($provider.options.baseURL -as [string]).TrimEnd('/')
$API_KEY = $provider.options.apiKey

$currentModels = @()
if ($provider.models) {
    $currentModels = @($provider.models.PSObject.Properties.Name)
}

Write-Host ""
Write-Host "  +==========================================+" -ForegroundColor Blue
Write-Host "  |       Model Manager - Cowork             |" -ForegroundColor Blue
Write-Host "  +==========================================+" -ForegroundColor Blue
Write-Host ""
Write-Host "  Provider: $PROVIDER_NAME ($PROVIDER_KEY)"
Write-Host "  API URL:  $BASE_URL"
Write-Host ""
Write-Host "  Fetching available models..."

# Fetch from /models, fall back to /v1/models
$modelsResponse = $null
$triedPath = ""
foreach ($path in @("/models", "/v1/models")) {
    try {
        $modelsResponse = Invoke-RestMethod -Uri "$BASE_URL$path" `
            -Method Get `
            -Headers @{ Authorization = "Bearer $API_KEY" } `
            -ErrorAction Stop
        $triedPath = $path
        break
    } catch {
        $modelsResponse = $null
    }
}

if ($null -eq $modelsResponse) {
    Write-Host "Error: Could not fetch models from the API." -ForegroundColor Red
    Write-Host "  Tried: $BASE_URL/models and $BASE_URL/v1/models"
    Write-Host "  Check your API key and that the endpoint exposes GET /models."
    Write-Host ""
    Write-Host "  Tip: run with -Debug to see the raw API response" -ForegroundColor DarkGray
    exit 1
}

if ($Debug) {
    Write-Host ""
    Write-Host "=== DEBUG: raw response from $BASE_URL$triedPath ===" -ForegroundColor Yellow
    $modelsResponse | ConvertTo-Json -Depth 10
    Write-Host "=== end of raw response ===" -ForegroundColor Yellow
    Write-Host ""
    exit 0
}

# Extract id AND name from each model entry
$rawModels = if ($modelsResponse.data) { $modelsResponse.data } else { $modelsResponse }
$modelEntries = @()
$seen = @{}
foreach ($m in $rawModels) {
    $id = $null
    $name = $null
    if ($m -is [string]) {
        $id = $m
        $name = $m
    } elseif ($m.id) {
        $id = $m.id
        # Prefer name, then info.name, fall back to id
        if ($m.name) {
            $name = $m.name
        } elseif ($m.info -and $m.info.name) {
            $name = $m.info.name
        } else {
            $name = $m.id
        }
    } elseif ($m.model) {
        $id = $m.model
        $name = if ($m.name) { $m.name } else { $m.model }
    }
    if (-not $id -or $seen.ContainsKey($id)) { continue }
    $seen[$id] = $true
    $modelEntries += [PSCustomObject]@{
        Id = $id
        Name = $name
        State = if ($currentModels -contains $id) { 'on' } else { 'off' }
    }
}

$modelEntries = $modelEntries | Sort-Object Id

if ($modelEntries.Count -eq 0) {
    Write-Host "Error: API returned no models (or unexpected format)." -ForegroundColor Red
    Write-Host "  Tip: run with -Debug to see the raw API response" -ForegroundColor DarkGray
    exit 1
}

$loaded = @($modelEntries | Where-Object { $_.State -eq 'on' }).Count
Write-Host "  Found $($modelEntries.Count) model(s) - $loaded currently loaded"

# With huge catalogs (OpenRouter has 300+), ask for an optional filter
$Filter = ""
if ($modelEntries.Count -gt 30) {
    Write-Host ""
    $Filter = Read-Host "  Filter models (e.g. 'claude', 'gpt-5', or press Enter for all)"
}

function Get-FilteredView {
    param($entries, $filter)
    if ([string]::IsNullOrWhiteSpace($filter)) { return $entries }
    return $entries | Where-Object { $_.Id -match [regex]::Escape($filter) -or $_.Name -match [regex]::Escape($filter) }
}

function Show-Menu {
    param($allEntries, $view, $filter)
    Write-Host ""
    if ([string]::IsNullOrWhiteSpace($filter)) {
        Write-Host "  Available models:" -ForegroundColor White
    } else {
        Write-Host "  Available models (filter: '$filter', showing $($view.Count) of $($allEntries.Count)):" -ForegroundColor White
    }
    for ($i = 0; $i -lt $view.Count; $i++) {
        $num = $i + 1
        $entry = $view[$i]
        $label = if ($entry.Id -eq $entry.Name) { $entry.Id } else { "$($entry.Id)  ($($entry.Name))" }
        if ($entry.State -eq 'on') {
            Write-Host "    [" -NoNewline
            Write-Host "*" -ForegroundColor Green -NoNewline
            Write-Host "] $num) $label"
        } else {
            Write-Host "    [ ] $num) $label"
        }
    }
    Write-Host ""
    Write-Host "  Legend: [*] = loaded, [ ] = available" -ForegroundColor Yellow
}

# Interactive loop
while ($true) {
    $view = @(Get-FilteredView -entries $modelEntries -filter $Filter)
    Show-Menu -allEntries $modelEntries -view $view -filter $Filter
    Write-Host ""
    Write-Host "  Enter numbers to toggle (e.g. '2,3,5'), 'a' to select all (in view), 'n' to deselect all (in view),"
    Write-Host "  '/text' to change filter, or press Enter to save:"
    $userInput = Read-Host "  >"

    if ([string]::IsNullOrWhiteSpace($userInput)) { break }

    # Filter change
    if ($userInput.StartsWith('/')) {
        $Filter = $userInput.Substring(1)
        continue
    }

    if ($userInput -eq 'a' -or $userInput -eq 'A') {
        foreach ($e in $view) { $e.State = 'on' }
        continue
    }
    if ($userInput -eq 'n' -or $userInput -eq 'N') {
        foreach ($e in $view) { $e.State = 'off' }
        continue
    }

    $picks = $userInput -split ',' | ForEach-Object { $_.Trim() }
    foreach ($p in $picks) {
        if ($p -match '^\d+$') {
            $idx = [int]$p - 1
            if ($idx -ge 0 -and $idx -lt $view.Count) {
                $e = $view[$idx]
                if ($e.State -eq 'on') { $e.State = 'off' } else { $e.State = 'on' }
            }
        }
    }
}

# Build selected list
$selected = @($modelEntries | Where-Object { $_.State -eq 'on' })

if ($selected.Count -eq 0) {
    Write-Host "Warning: No models selected. At least one model must be loaded." -ForegroundColor Yellow
    Write-Host "No changes saved."
    exit 0
}

# Default template for new models
function New-ModelEntry($id, $name) {
    return @{
        name = $name
        tool_call = $true
        attachment = $true
        modalities = @{ input = @("text", "image"); output = @("text") }
        options = @{ temperature = 0.7; max_tokens = 16384 }
    }
}

function Update-ConfigFile($path) {
    if (-not (Test-Path $path)) { return }
    $cfg = Get-Content $path -Raw | ConvertFrom-Json

    if (-not $cfg.provider.$PROVIDER_KEY) { return }

    $existing = $cfg.provider.$PROVIDER_KEY.models
    $newModels = [ordered]@{}

    foreach ($e in $selected) {
        if ($existing -and $existing.PSObject.Properties[$e.Id]) {
            # Preserve existing config (temperature, max_tokens, custom name, etc.)
            $newModels[$e.Id] = $existing.($e.Id)
        } else {
            $newModels[$e.Id] = New-ModelEntry $e.Id $e.Name
        }
    }

    # Replace the models object
    $cfg.provider.$PROVIDER_KEY | Add-Member -MemberType NoteProperty -Name 'models' -Value $newModels -Force

    Write-Utf8NoBom $path ($cfg | ConvertTo-Json -Depth 10)
}

Update-ConfigFile $CONFIG_FILE
Update-ConfigFile $BUILD_CONFIG

Write-Host ""
Write-Host "  * Configuration updated ($($selected.Count) model(s))." -ForegroundColor Green
Write-Host ""
Write-Host "  Restart the app for changes to take effect:" -ForegroundColor Yellow
Write-Host "    1. Quit the app"
Write-Host "    2. Relaunch from Start Menu or Desktop shortcut"
Write-Host ""
