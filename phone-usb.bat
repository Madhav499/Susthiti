@echo off
rem Lets a phone connected with USB reach the SUSTHITI backend through the cable (adb reverse).
rem Run after plugging the phone in; start-susthiti.bat does this too.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\phone-usb.ps1"
pause
