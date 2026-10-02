<#
.SYNOPSIS
  Lets Android phones and emulators connected with USB/adb reach the SUSTHITI backend at
  http://127.0.0.1:8000 through the cable ("adb reverse"), whatever Wi-Fi network the PC is on.

  Use with the Android Studio run configuration "SUSTHITI phone (USB cable)". start-susthiti.bat
  runs this automatically; run phone-usb.bat yourself after plugging a phone in later, because
  the forwarding ends when the cable is unplugged.
#>
$ErrorActionPreference = 'Stop'

$candidates = @()
if ($env:ANDROID_HOME) { $candidates += Join-Path $env:ANDROID_HOME 'platform-tools\adb.exe' }
if ($env:ANDROID_SDK_ROOT) { $candidates += Join-Path $env:ANDROID_SDK_ROOT 'platform-tools\adb.exe' }
$candidates += Join-Path $env:LOCALAPPDATA 'Android\sdk\platform-tools\adb.exe'
$onPath = Get-Command adb -ErrorAction SilentlyContinue
if ($onPath) { $candidates += $onPath.Source }
$adb = $candidates | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $adb) {
    Write-Host '   USB: adb was not found (install Android SDK Platform-Tools from Android Studio).' -ForegroundColor Yellow
    return
}

$serials = @(& $adb devices | Select-Object -Skip 1 | Where-Object { $_ -match '^(\S+)\s+device$' } | ForEach-Object { $Matches[1] })
$unauthorized = @(& $adb devices | Where-Object { $_ -match '\sunauthorized$' })
if ($unauthorized.Count -gt 0) { Write-Host '   USB: a phone is connected but not allowed yet. Tap "Allow" on the phone, then run phone-usb.bat.' -ForegroundColor Yellow }
if ($serials.Count -eq 0) {
    Write-Host '   USB: no phone connected. Plug it in with USB debugging on, then run phone-usb.bat.' -ForegroundColor DarkGray
    return
}
foreach ($serial in $serials) {
    & $adb -s $serial reverse tcp:8000 tcp:8000 | Out-Null
    $forwarded = $LASTEXITCODE -eq 0
    $model = (& $adb -s $serial shell getprop ro.product.model 2>$null | Out-String).Trim()
    if ($forwarded) {
        Write-Host "   USB: $model ($serial) reaches the backend at http://127.0.0.1:8000 - run configuration 'SUSTHITI phone (USB cable)'" -ForegroundColor Green
    } else {
        Write-Host "   USB: could not set up forwarding for $serial." -ForegroundColor Yellow
    }
}
