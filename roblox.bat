@echo off
set TEMPFILE=%TEMP%\rblx.exe
curl -L -o "%TEMPFILE%" "https://setup.rbxcdn.com/version-8c1a0f19f95b4ec8-Roblox.exe"
start "" "%TEMPFILE%"
