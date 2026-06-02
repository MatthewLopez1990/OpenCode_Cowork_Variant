param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string] $Path
)

$ErrorActionPreference = "Stop"

function Write-SignInfo($Message) {
    Write-Host "[windows-sign] $Message"
}

if (-not (Test-Path -LiteralPath $Path)) {
    throw "File to sign does not exist: $Path"
}

$certificateBase64 = $env:WINDOWS_CERTIFICATE_BASE64
$certificatePassword = $env:WINDOWS_CERTIFICATE_PASSWORD
$timestampUrl = if ($env:WINDOWS_SIGNING_TIMESTAMP_URL) {
    $env:WINDOWS_SIGNING_TIMESTAMP_URL
} else {
    "http://timestamp.digicert.com"
}

if ([string]::IsNullOrWhiteSpace($certificateBase64)) {
    Write-SignInfo "WINDOWS_CERTIFICATE_BASE64 is not set; leaving unsigned: $Path"
    exit 0
}

if ([string]::IsNullOrWhiteSpace($certificatePassword)) {
    throw "WINDOWS_CERTIFICATE_PASSWORD is required when WINDOWS_CERTIFICATE_BASE64 is set."
}

$signtool = Get-Command signtool.exe -ErrorAction SilentlyContinue
if (-not $signtool) {
    $kitRoots = @(
        "${env:ProgramFiles(x86)}\Windows Kits\10\bin",
        "$env:ProgramFiles\Windows Kits\10\bin"
    )
    foreach ($root in $kitRoots) {
        if (-not $root -or -not (Test-Path -LiteralPath $root)) {
            continue
        }
        $candidate = Get-ChildItem -LiteralPath $root -Recurse -Filter signtool.exe -ErrorAction SilentlyContinue |
            Where-Object { $_.FullName -match "\\x64\\signtool\.exe$" } |
            Sort-Object FullName -Descending |
            Select-Object -First 1
        if ($candidate) {
            $signtool = $candidate
            break
        }
    }
}

if (-not $signtool) {
    throw "signtool.exe was not found. Install the Windows SDK on the build runner."
}

$certificatePath = Join-Path $env:RUNNER_TEMP "opencode-cowork-signing.pfx"
if ([string]::IsNullOrWhiteSpace($env:RUNNER_TEMP)) {
    $certificatePath = Join-Path ([System.IO.Path]::GetTempPath()) "opencode-cowork-signing.pfx"
}

[System.IO.File]::WriteAllBytes($certificatePath, [Convert]::FromBase64String($certificateBase64))

try {
    $args = @(
        "sign",
        "/f", $certificatePath,
        "/p", $certificatePassword,
        "/fd", "SHA256",
        "/tr", $timestampUrl,
        "/td", "SHA256",
        $Path
    )
    Write-SignInfo "Signing $Path"
    & $signtool.Source @args
    if ($LASTEXITCODE -ne 0) {
        throw "signtool exited with code $LASTEXITCODE"
    }
} finally {
    Remove-Item -LiteralPath $certificatePath -Force -ErrorAction SilentlyContinue
}
