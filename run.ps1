# Elio — run on connected device (prod flavor, debug mode)
# Usage: .\run.ps1
#        .\run.ps1 -device emulator    (to use emulator instead)

param(
    [string]$device = ""
)

# Read API key from .env.local
$envFile = Join-Path $PSScriptRoot ".env.local"
if (-not (Test-Path $envFile)) {
    Write-Host "ERROR: .env.local not found. Create it with: GEMINI_API_KEY=your_key" -ForegroundColor Red
    exit 1
}

$apiKey = (Get-Content $envFile | Select-String "GEMINI_API_KEY=(.+)" | ForEach-Object { $_.Matches[0].Groups[1].Value }).Trim()
if (-not $apiKey) {
    Write-Host "ERROR: GEMINI_API_KEY not found in .env.local" -ForegroundColor Red
    exit 1
}

$cmd = "flutter run --flavor prod -t lib/main.dart --dart-define=GEMINI_API_KEY=$apiKey"
if ($device) {
    $cmd += " -d $device"
}

Write-Host "Starting Elio (prod debug)..." -ForegroundColor Cyan
Invoke-Expression $cmd
