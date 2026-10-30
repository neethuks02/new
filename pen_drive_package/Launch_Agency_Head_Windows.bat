@echo off
title Student Agency Manager - Launcher
setlocal EnableDelayedExpansion

echo ===================================================
echo     STUDENT AGENCY MANAGER - PORTABLE WEB APP
echo ===================================================
echo.
echo Starting Agency Head portable server...
echo.

set "SCRIPT_DIR=%~dp0"
set "WEB_DIR=%SCRIPT_DIR%Agency_Head_Web"
set "PORT=8080"

:: Check if Python is installed
python --version >nul 2>&1
if %ERRORLEVEL% EQU 0 (
    echo [OK] Using Python HTTP server...
    start /B python -m http.server %PORT% --directory "%WEB_DIR%" >nul 2>&1
    goto OPEN_BROWSER
)

python3 --version >nul 2>&1
if %ERRORLEVEL% EQU 0 (
    echo [OK] Using Python3 HTTP server...
    start /B python3 -m http.server %PORT% --directory "%WEB_DIR%" >nul 2>&1
    goto OPEN_BROWSER
)

:: Use PowerShell (built into every Windows 7, 8, 10, 11 PC)
echo [OK] Using Windows PowerShell HTTP server...
start /B powershell -NoProfile -ExecutionPolicy Bypass -Command "& { $listener = New-Object System.Net.HttpListener; $listener.Prefixes.Add('http://localhost:%PORT%/'); $listener.Start(); Write-Host 'Running on port %PORT%...'; while ($listener.IsListening) { $context = $listener.GetContext(); $request = $context.Request; $response = $context.Response; $relPath = $request.Url.LocalPath.TrimStart('/'); if ([string]::IsNullOrEmpty($relPath) -or $relPath -eq '/') { $relPath = 'index.html' }; $filePath = Join-Path '%WEB_DIR%' $relPath; if (-not (Test-Path $filePath)) { $filePath = Join-Path '%WEB_DIR%' 'index.html' }; $bytes = [System.IO.File]::ReadAllBytes($filePath); $ext = [System.IO.Path]::GetExtension($filePath).ToLower(); switch ($ext) { '.html' { $response.ContentType = 'text/html' } '.js' { $response.ContentType = 'application/javascript' } '.json' { $response.ContentType = 'application/json' } '.css' { $response.ContentType = 'text/css' } '.png' { $response.ContentType = 'image/png' } '.wasm' { $response.ContentType = 'application/wasm' } default { $response.ContentType = 'application/octet-stream' } }; $response.ContentLength64 = $bytes.Length; $response.OutputStream.Write($bytes, 0, $bytes.Length); $response.OutputStream.Close() } }" >nul 2>&1

:OPEN_BROWSER
timeout /t 2 /nobreak >nul

echo [OK] Launching Agency Head standalone Web App window...

:: Check Edge first (built into all Windows 10 & 11)
if exist "%ProgramFiles(x86)%\Microsoft\Edge\Application\msedge.exe" (
    start "" "%ProgramFiles(x86)%\Microsoft\Edge\Application\msedge.exe" --app="http://localhost:%PORT%/"
    goto DONE
)

if exist "%ProgramFiles%\Microsoft\Edge\Application\msedge.exe" (
    start "" "%ProgramFiles%\Microsoft\Edge\Application\msedge.exe" --app="http://localhost:%PORT%/"
    goto DONE
)

:: Check Google Chrome
if exist "%ProgramFiles%\Google\Chrome\Application\chrome.exe" (
    start "" "%ProgramFiles%\Google\Chrome\Application\chrome.exe" --app="http://localhost:%PORT%/"
    goto DONE
)

if exist "%ProgramFiles(x86)%\Google\Chrome\Application\chrome.exe" (
    start "" "%ProgramFiles(x86)%\Google\Chrome\Application\chrome.exe" --app="http://localhost:%PORT%/"
    goto DONE
)

:: Fallback to default browser
start http://localhost:%PORT%/

:DONE
echo.
echo ===================================================
echo   Agency Head is now open!
echo   To install it as a desktop icon on this PC:
echo   Click the 'Install' icon in the top right.
echo ===================================================
echo Keep this window minimized while using the app.
pause
