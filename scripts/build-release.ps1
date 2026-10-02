<#
.SYNOPSIS
  Builds SUSTHITI for your internet server: Android APKs to share with any phone, and the web
  app (for iPhones and computers) into deploy\web for the server.

.EXAMPLE
  .\build-release.bat https://203-0-113-10.sslip.io
#>
param(
    [Parameter(Mandatory = $true)] [string] $Server
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$appDir = Join-Path $root 'app'
$outDir = Join-Path $root 'release'
$webOut = Join-Path $root 'deploy\web'

function Fail($text) { Write-Host ''; Write-Host "X  $text" -ForegroundColor Red; exit 1 }

# Release builds only talk HTTPS (Android blocks plain HTTP outside debug builds, and health
# data must be encrypted in transit), so refuse anything else up front.
$Server = $Server.Trim().TrimEnd('/') -replace '/api/v1$', ''
if ($Server -notmatch '^https://[A-Za-z0-9.-]+(:\d+)?$') {
    Fail "Give the server as https://your-domain (for example https://203-0-113-10.sslip.io). Got: $Server"
}
$api = "$Server/api/v1"
if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) { Fail 'Flutter was not found on PATH.' }

Write-Host "Building SUSTHITI for $api" -ForegroundColor Cyan
try {
    $health = Invoke-RestMethod -Uri "$Server/health" -TimeoutSec 10
    Write-Host "   Server is up: status=$($health.status), model service=$($health.model_service)" -ForegroundColor Green
} catch {
    Write-Host "   Note: $Server/health did not answer yet. Building anyway; the app will work once the server is up." -ForegroundColor Yellow
}

Push-Location $appDir
try {
    Write-Host ''; Write-Host '==> Android APKs (release)' -ForegroundColor Cyan
    & flutter build apk --release --split-per-abi "--dart-define=API_BASE_URL=$api"
    if ($LASTEXITCODE -ne 0) { Fail 'The Android build failed. See the messages above.' }

    Write-Host ''; Write-Host '==> Web app (release)' -ForegroundColor Cyan
    & flutter build web --release "--dart-define=API_BASE_URL=$api"
    if ($LASTEXITCODE -ne 0) { Fail 'The web build failed. See the messages above.' }
} finally {
    Pop-Location
}

New-Item -ItemType Directory -Force $outDir | Out-Null
$apkDir = Join-Path $appDir 'build\app\outputs\flutter-apk'
$names = @{ 'app-arm64-v8a-release.apk' = 'SUSTHITI.apk'; 'app-armeabi-v7a-release.apk' = 'SUSTHITI-older-phones.apk'; 'app-x86_64-release.apk' = 'SUSTHITI-x86_64.apk' }
foreach ($name in $names.Keys) {
    $source = Join-Path $apkDir $name
    if (Test-Path $source) { Copy-Item $source (Join-Path $outDir $names[$name]) -Force }
}

# Replace the previous web build on the deploy side, keeping the folder's README.
Get-ChildItem $webOut -Force | Where-Object { $_.Name -ne 'README.txt' } | Remove-Item -Recurse -Force
Copy-Item (Join-Path $appDir 'build\web\*') $webOut -Recurse -Force

Write-Host ''
Write-Host 'Done.' -ForegroundColor Green
Write-Host "   Android:  release\SUSTHITI.apk  (almost all phones; share it by WhatsApp, Drive or USB)"
Write-Host "             release\SUSTHITI-older-phones.apk  (only for very old 32-bit phones)"
Write-Host "   Web app:  deploy\web  (upload with the server package; opens at $Server)"
Write-Host "   Next:     scripts\package-server.bat, then upload it to the server (DEPLOY.md, step 5)"
