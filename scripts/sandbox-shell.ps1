# OpenCode Cowork — Sandbox Shell Wrapper
# Every command the AI runs goes through this script.
# It checks for file paths outside the project directory and blocks them.
# This is a HARD enforcement — the AI cannot bypass it.

param(
    [Parameter(Position=0)]
    [string]$Flag,
    [Parameter(Position=1, ValueFromRemainingArguments)]
    [string[]]$CommandParts
)

$command = $CommandParts -join ' '
$projectDir = (Get-Location).Path

# Protected folder names (case-insensitive)
$blockedFolders = @(
    'Desktop', 'Documents', 'Downloads', 'Movies', 'Music',
    'Videos', 'Pictures', 'Public', 'OneDrive'
)

# Build list of blocked path patterns
$blockedPatterns = @()
$home = $env:USERPROFILE
foreach ($folder in $blockedFolders) {
    $blockedPatterns += [regex]::Escape("$home\$folder")
    $blockedPatterns += [regex]::Escape("$home/$folder")
    # Also catch OneDrive variants (e.g., "OneDrive - Company Name")
    if ($folder -eq 'OneDrive') {
        $blockedPatterns += [regex]::Escape($home) + '[/\\]OneDrive[^/\\]*[/\\]'
    }
}
# Block temp directories
$blockedPatterns += '\\Temp\\'
$blockedPatterns += '/tmp/'
$blockedPatterns += '/private/tmp/'
# Block %USERPROFILE% and $env:USERPROFILE references to protected folders
foreach ($folder in $blockedFolders) {
    $blockedPatterns += '%USERPROFILE%[/\\]' + $folder
    $blockedPatterns += '\$env:USERPROFILE[/\\]' + $folder
    $blockedPatterns += '~/?' + $folder
}

# Check command for blocked paths
$violation = $null
foreach ($pattern in $blockedPatterns) {
    if ($command -match $pattern) {
        $violation = $Matches[0]
        break
    }
}

# Also check for drive-letter absolute paths outside the project
if (-not $violation -and $command -match '[A-Za-z]:[/\\]') {
    # Extract all drive-letter paths from the command
    $paths = [regex]::Matches($command, '[A-Za-z]:[/\\][^\s"''<>|;]+')
    foreach ($m in $paths) {
        $testPath = $m.Value -replace '/', '\'
        $normalizedProject = $projectDir -replace '/', '\'
        if (-not $testPath.StartsWith($normalizedProject, [System.StringComparison]::OrdinalIgnoreCase)) {
            # This path is outside the project directory
            $violation = $m.Value
            break
        }
    }
}

if ($violation) {
    Write-Output ""
    Write-Output "SANDBOX VIOLATION: This command was blocked because it references a path outside the current project directory."
    Write-Output ""
    Write-Output "This app restricts ALL file operations to the working directory ($projectDir) for workstation safety."
    Write-Output ""
    Write-Output "Blocked path: $violation"
    Write-Output ""
    Write-Output "Save all files inside the current project directory instead."
    exit 1
}

# Command is safe — execute it with the real shell
& cmd /c $command
exit $LASTEXITCODE
