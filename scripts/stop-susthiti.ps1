<#
.SYNOPSIS
  Stops the SUSTHITI services started by start-susthiti (ports 8002, 8001, 8000 and 8080).
  Only stops processes that are SUSTHITI's own (uvicorn / flutter); anything else is left alone.
#>
$ports = @{ 8002 = @('main:app'); 8001 = @('main:app'); 8000 = @('app.main:app'); 8080 = @('dart', 'flutter') }
foreach ($port in 8080, 8000, 8001, 8002) {
    $conn = Get-NetTCPConnection -State Listen -LocalPort $port -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $conn) { Write-Host "Port ${port}: nothing running"; continue }
    $proc = Get-CimInstance Win32_Process -Filter "ProcessId=$($conn.OwningProcess)"
    $cmd = "$($proc.Name) $($proc.CommandLine)"
    $ours = $false
    foreach ($s in $ports[$port]) { if ($cmd -like "*$s*") { $ours = $true } }
    if (-not $ours) { Write-Host "Port ${port}: used by $($proc.Name) (not SUSTHITI), left running" -ForegroundColor Yellow; continue }
    # Close the "SUSTHITI ..." window the service runs in, if there is one (its command is encoded).
    $parent = Get-CimInstance Win32_Process -Filter "ProcessId=$($proc.ParentProcessId)" -ErrorAction SilentlyContinue
    Stop-Process -Id $proc.ProcessId -Force -ErrorAction SilentlyContinue
    if ($parent -and $parent.Name -eq 'powershell.exe' -and $parent.CommandLine -like '*-EncodedCommand*') {
        Stop-Process -Id $parent.ProcessId -Force -ErrorAction SilentlyContinue
    }
    Write-Host "Port ${port}: stopped" -ForegroundColor Green
}
