@echo off
setlocal EnableDelayedExpansion

REM ============================================================================
REM Manual-Refresh.bat - User-friendly manual refresh with visible progress
REM ============================================================================

echo.
echo ============================================
echo   Rob's Computer Manual - Refresh
echo ============================================
echo.
echo Checking for updates to your manual...
echo.

REM Change to the script directory
cd /d "%USERPROFILE%\rk-comp-wksp\code"

REM Check if the PowerShell script exists
if not exist "Update-Manual.ps1" (
    echo ERROR: Update script not found!
    echo Please contact your support person.
    echo.
    echo Press any key to close this window...
    pause >nul
    exit /b 1
)

echo Starting update process...
echo.

REM Run the PowerShell update script
powershell.exe -ExecutionPolicy Bypass -File ".\Update-Manual.ps1" -Force

REM Check the result
if errorlevel 1 (
    echo.
    echo ========================================
    echo   Update Problem
    echo ========================================
    echo.
    echo There was a problem updating your manual.
    echo The support team has been notified and will
    echo help resolve this issue.
    echo.
    echo You can continue using the current version
    echo of your manual while this is being fixed.
    echo.
) else (
    echo.
    echo ========================================
    echo   Update Successful!
    echo ========================================
    echo.
    echo Your manual has been refreshed successfully!
    echo The latest content is now available.
    echo.
    echo You can close this window and continue
    echo using your updated manual.
    echo.
)

echo Press any key to close this window...
pause >nul
exit /b 0