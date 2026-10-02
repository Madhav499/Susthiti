<#
.SYNOPSIS
  Starts the whole SUSTHITI stack in the right order and checks each part is healthy.

  1. Diabetes risk model     (diabetes_risk_api, port 8001) - the supplied API v4 and its .joblib model
  2. SUSTHITI backend        (backend,      port 8000)  - sign-in, records, AI, calls the model service
  3. Flutter app in Chrome   (app,          port 8080)  - optional; use -App none when running from Android Studio

  Each service runs in its own window titled "SUSTHITI ...". Closing a window stops that service.
  Anything missing (virtual environments, packages, backend .env) is set up on first run.
  Older copies of these services on the same ports are stopped first so you always run the latest code.

.EXAMPLE
  .\start-susthiti.bat                 # services + app in Chrome
  .\start-susthiti.bat -App none       # services only (run the app from Android Studio)
  .\start-susthiti.bat -Lan            # also reachable from a phone on the same Wi-Fi
#>
param(
    [ValidateSet('chrome', 'none')] [string] $App = 'chrome',
    [switch] $Lan,
    [switch] $SeedDemo
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$apiDir = Join-Path $root 'diabetes_risk_api'
$backendDir = Join-Path $root 'backend'
$appDir = Join-Path $root 'app'

function Say($text, $color = 'Gray') { Write-Host $text -ForegroundColor $color }
function Step($text) { Write-Host ''; Write-Host "==> $text" -ForegroundColor Cyan }
function Fail($text) { Write-Host ''; Write-Host "X  $text" -ForegroundColor Red; exit 1 }

# ---------- helpers ----------

function Find-Python([string[]] $preferred) {
    # Returns an argument list that runs a suitable Python, e.g. @('py', '-3.13') or @('python').
    $launcher = Get-Command py -ErrorAction SilentlyContinue
    if ($launcher) {
        foreach ($v in $preferred) {
            try { & py "-$v" --version *> $null } catch { continue }
            if ($LASTEXITCODE -eq 0) { return @('py', "-$v") }
        }
    }
    $python = Get-Command python -ErrorAction SilentlyContinue
    if ($python) { return @('python') }
    Fail "Python was not found. Install Python 3.12 or 3.13 from python.org, then run this again."
}

function Ensure-Venv($dir, $name, [string[]] $pythonVersions) {
    $venvPython = Join-Path $dir '.venv\Scripts\python.exe'
    if (-not (Test-Path $venvPython)) {
        $py = Find-Python $pythonVersions
        Say "   Creating the $name Python environment (first run only)..."
        $exe = $py[0]; $pyArgs = @(); if ($py.Count -gt 1) { $pyArgs = $py[1..($py.Count - 1)] }
        & $exe @pyArgs -m venv (Join-Path $dir '.venv')
        if ($LASTEXITCODE -ne 0) { Fail "Could not create the $name environment." }
    }
    # Install or update packages only when requirements.txt changed since the last install.
    $req = Join-Path $dir 'requirements.txt'
    $stamp = Join-Path $dir '.venv\.requirements.sha256'
    $hash = (Get-FileHash $req -Algorithm SHA256).Hash
    $installed = ''
    if (Test-Path $stamp) { $installed = (Get-Content $stamp -Raw).Trim() }
    if ($installed -ne $hash) {
        Say "   Installing $name packages (first run or requirements changed)..."
        & $venvPython -m pip install --disable-pip-version-check -q -r $req
        if ($LASTEXITCODE -ne 0) { Fail "Installing $name packages failed. Check your internet connection and try again." }
        Set-Content -Path $stamp -Value $hash -Encoding ascii
    }
    return $venvPython
}

function Get-Listener([int] $port) {
    $conn = Get-NetTCPConnection -State Listen -LocalPort $port -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $conn) { return $null }
    $proc = Get-CimInstance Win32_Process -Filter "ProcessId=$($conn.OwningProcess)" -ErrorAction SilentlyContinue
    return $proc
}

function Stop-OldService([int] $port, [string[]] $signatures, [string] $name) {
    # Stops a previous SUSTHITI service on $port. Never touches an unrelated program.
    $proc = Get-Listener $port
    if (-not $proc) { return }
    $cmd = "$($proc.Name) $($proc.CommandLine)"
    $ours = $false
    foreach ($s in $signatures) { if ($cmd -like "*$s*") { $ours = $true } }
    if (-not $ours) {
        Fail "Port $port is used by another program ($($proc.Name), PID $($proc.ProcessId)). Close it, then run this again."
    }
    Say "   Stopping the older $name on port $port (PID $($proc.ProcessId)) so the latest code runs..."
    Stop-Process -Id $proc.ProcessId -Force -ErrorAction SilentlyContinue
    for ($i = 0; $i -lt 20 -and (Get-Listener $port); $i++) { Start-Sleep -Milliseconds 250 }
}

function Start-ServiceWindow($title, $dir, $command) {
    $script = "`$host.UI.RawUI.WindowTitle = '$title'; Set-Location -LiteralPath '$dir'; Write-Host '$title' -ForegroundColor Cyan; Write-Host 'Keep this window open. Close it to stop the service.' -ForegroundColor DarkGray; $command"
    # Encoded so paths with spaces survive Windows PowerShell's argument passing.
    $encoded = [Convert]::ToBase64String([System.Text.Encoding]::Unicode.GetBytes($script))
    Start-Process powershell -ArgumentList "-NoProfile -NoExit -ExecutionPolicy Bypass -EncodedCommand $encoded" | Out-Null
}

function Wait-Healthy($url, $name, $seconds, $check) {
    $deadline = (Get-Date).AddSeconds($seconds)
    while ((Get-Date) -lt $deadline) {
        try {
            $r = Invoke-RestMethod -Uri $url -TimeoutSec 3
            if (& $check $r) { return $r }
        } catch { }
        Start-Sleep -Milliseconds 700
    }
    Fail "$name did not become ready within $seconds seconds. Look at its window for the error."
}

# ---------- 1. model service ----------

Step 'Diabetes risk model service (diabetes_risk_api, API v4, port 8001)'
if (-not (Test-Path (Join-Path $apiDir 'unified_future_diabetes_model.joblib'))) {
    Fail 'The model file diabetes_risk_api\unified_future_diabetes_model.joblib is missing.'
}
$apiPython = Ensure-Venv $apiDir 'model service' @('3.13', '3.12', '3.11')
Stop-OldService 8001 @('main:app') 'model service'
Start-ServiceWindow 'SUSTHITI model service :8001' $apiDir "& '$apiPython' -m uvicorn main:app --host 127.0.0.1 --port 8001"
$ml = Wait-Healthy 'http://127.0.0.1:8001/health' 'The model service' 90 { param($r) $r.status -eq 'ok' -and $r.model_loaded -eq $true }
Say "   Ready: SUSTHITI Future Diabetes Risk API, model $($ml.model_version)" 'Green'

# ---------- 2. backend ----------

Step 'SUSTHITI backend (port 8000)'
$envFile = Join-Path $backendDir '.env'
if (-not (Test-Path $envFile)) {
    Say '   Creating backend\.env from .env.example with a new random JWT secret...'
    $bytes = New-Object byte[] 48; [System.Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($bytes)
    $secret = [Convert]::ToBase64String($bytes).TrimEnd('=').Replace('+', '-').Replace('/', '_')
    $lines = (Get-Content (Join-Path $backendDir '.env.example')) -replace '^JWT_SECRET=.*', "JWT_SECRET=$secret"
    [System.IO.File]::WriteAllLines($envFile, [string[]]$lines, (New-Object System.Text.UTF8Encoding $false))  # no BOM
}
$mlUrl = (Select-String -Path $envFile -Pattern '^ML_SERVICE_URL=(.*)$' | Select-Object -First 1)
if ($mlUrl -and $mlUrl.Matches[0].Groups[1].Value.Trim() -notmatch '127\.0\.0\.1:8001|localhost:8001') {
    Say "   Note: backend\.env has ML_SERVICE_URL=$($mlUrl.Matches[0].Groups[1].Value). This script starts the model service on http://127.0.0.1:8001." 'Yellow'
}
$backendPython = Ensure-Venv $backendDir 'backend' @('3.14', '3.13', '3.12', '3.11')
Stop-OldService 8000 @('app.main:app') 'backend'
if ($SeedDemo) {
    Say '   Creating DEMO accounts (skipped if they already exist)...'
    Push-Location $backendDir; & $backendPython -m app.cli seed-demo; Pop-Location
}
$bindHost = '127.0.0.1'; if ($Lan) { $bindHost = '0.0.0.0' }
Start-ServiceWindow 'SUSTHITI backend :8000' $backendDir "& '$backendPython' -m uvicorn app.main:app --host $bindHost --port 8000"
$api = Wait-Healthy 'http://127.0.0.1:8000/health' 'The backend' 90 { param($r) $r.status -eq 'ok' }
if ($api.model_service -ne 'ok') { Fail "The backend is up but cannot reach the model service (model_service=$($api.model_service)). Check ML_SERVICE_URL in backend\.env." }
Say '   Ready, and connected to the model service.' 'Green'
if (-not $api.ai_configured) { Say '   AI summaries are off: set GEMINI_API_KEY in backend\.env to enable them (optional).' 'Yellow' }

# ---------- phones on USB ----------

Step 'Phones connected with USB'
& (Join-Path $PSScriptRoot 'phone-usb.ps1')

# ---------- 3. app ----------

if ($App -eq 'chrome') {
    Step 'Flutter app in Chrome (port 8080)'
    if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) { Fail 'Flutter was not found on PATH. Run the app from Android Studio instead, or add D:\Android\flutter\bin to PATH.' }
    Stop-OldService 8080 @('dart', 'flutter') 'app'
    Start-ServiceWindow 'SUSTHITI app :8080' $appDir 'flutter run -d chrome --web-port 8080'
    Say '   Starting. Chrome opens by itself when the build finishes (about a minute the first time).' 'Green'
}

# ---------- summary ----------

$lanNote = ''
if ($Lan) {
    # The address of the adapter that carries the default route (the network the PC is actually
    # on), not the first adapter found, which can be a virtual one.
    $route = Get-NetRoute -DestinationPrefix '0.0.0.0/0' -ErrorAction SilentlyContinue | Sort-Object { $_.RouteMetric + $_.InterfaceMetric } | Select-Object -First 1
    $ip = $null
    if ($route) { $ip = (Get-NetIPAddress -AddressFamily IPv4 -InterfaceIndex $route.InterfaceIndex -ErrorAction SilentlyContinue | Select-Object -First 1).IPAddress }
    if (-not $ip) { $ip = (Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue | Where-Object { $_.IPAddress -notlike '127.*' -and $_.IPAddress -notlike '169.254*' -and $_.PrefixOrigin -ne 'WellKnown' } | Select-Object -First 1).IPAddress }
    if ($ip) {
        # A physical phone is built with this file (run configuration "SUSTHITI phone (Wi-Fi)").
        # Rewritten on every start, so a new network never leaves the app pointing at an old address.
        $apiUrl = "http://${ip}:8000/api/v1"
        $defines = Join-Path $appDir 'config\dev_phone.json'
        New-Item -ItemType Directory -Force (Split-Path $defines) | Out-Null
        [System.IO.File]::WriteAllText($defines, "{ `"API_BASE_URL`": `"$apiUrl`" }`n", (New-Object System.Text.UTF8Encoding $false))
        $lanNote = "`n   Phone on the same Wi-Fi: $apiUrl (saved to app\config\dev_phone.json; press Run again in Android Studio after the PC changes network)"
        $netCategory = (Get-NetConnectionProfile -InterfaceIndex $route.InterfaceIndex -ErrorAction SilentlyContinue).NetworkCategory
        if ($netCategory -eq 'Public') { $lanNote += "`n   Note: Windows treats this network as Public. If the phone cannot connect, allow Python for Public networks in Windows Firewall." }
    } else {
        $lanNote = "`n   Could not find this PC's network address. Is Wi-Fi connected?"
    }
}
Write-Host ''
Write-Host 'SUSTHITI is running.' -ForegroundColor Green
Write-Host "   Model service  http://127.0.0.1:8001/docs"
Write-Host "   Backend        http://127.0.0.1:8000/docs"
if ($App -eq 'chrome') { Write-Host "   App            http://localhost:8080" } else { Write-Host '   App            run it from Android Studio (Chrome with --web-port 8080, or the Android emulator)' }
Write-Host "$lanNote"
Write-Host '   Demo sign-in   demo.patient@susthiti.test / demo.doctor@susthiti.test / demo.admin@susthiti.test (password in README.md)'
Write-Host '   To stop        run stop-susthiti.bat, or close the SUSTHITI windows'
