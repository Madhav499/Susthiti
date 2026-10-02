<#
.SYNOPSIS
  Packs exactly what the server needs into release\susthiti-server.tar.gz: the backend and model
  service source with their Dockerfiles, and the deploy folder (compose file, Caddyfile, web app).
  Never includes local databases, uploaded reports, virtual environments or .env files.
#>
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$outDir = Join-Path $root 'release'
$stage = Join-Path ([System.IO.Path]::GetTempPath()) ("susthiti-server-" + [guid]::NewGuid().ToString('N'))
$exclude = @('__pycache__', '*.pyc', '.venv', '.env', '*.db', '*.db-journal', 'storage', '.pytest_cache', 'tests', 'training_dataset_used.csv')

function Copy-Clean($from, $to) {
    New-Item -ItemType Directory -Force $to | Out-Null
    Get-ChildItem $from -Force | Where-Object {
        $name = $_.Name
        -not ($exclude | Where-Object { $name -like $_ })
    } | ForEach-Object {
        if ($_.PSIsContainer) { Copy-Clean $_.FullName (Join-Path $to $_.Name) }
        else { Copy-Item $_.FullName (Join-Path $to $_.Name) -Force }
    }
}

try {
    foreach ($part in 'backend', 'diabetes_risk_api', 'deploy') { Copy-Clean (Join-Path $root $part) (Join-Path $stage "susthiti\$part") }
    if (-not (Get-ChildItem (Join-Path $stage 'susthiti\deploy\web') -Filter 'index.html' -ErrorAction SilentlyContinue)) {
        Write-Host '   Note: deploy\web has no web app yet. Run build-release.bat first if you want the browser version online.' -ForegroundColor Yellow
    }
    New-Item -ItemType Directory -Force $outDir | Out-Null
    $archive = Join-Path $outDir 'susthiti-server.tar.gz'
    # tar (built into Windows 10+) writes forward-slash paths that Linux extracts correctly.
    & tar.exe -czf $archive -C $stage susthiti
    if ($LASTEXITCODE -ne 0) { throw 'tar failed' }
    $size = [math]::Round((Get-Item $archive).Length / 1MB, 1)
    Write-Host "Created release\susthiti-server.tar.gz ($size MB)" -ForegroundColor Green
    Write-Host '   Upload it to the server:  scp release\susthiti-server.tar.gz USER@SERVER-IP:~'
} finally {
    Remove-Item $stage -Recurse -Force -ErrorAction SilentlyContinue
}
