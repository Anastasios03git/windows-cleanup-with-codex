@echo off
if not exist "%~dp0scripts\Show-Setup.ps1" (
    echo Windows Cleanup is incomplete. Extract the entire ZIP before running it.
    pause
    exit /b 1
)
powershell.exe -NoProfile -STA -ExecutionPolicy RemoteSigned -File "%~dp0scripts\Show-Setup.ps1"
if errorlevel 1 (
    echo.
    echo Windows Cleanup could not start. Read the error above.
    echo If downloaded files are blocked, see START-HERE.md for the ZIP Unblock step.
    echo Right-click the trusted ZIP, select Properties, check Unblock, then Apply.
    echo Extract the ZIP into a new folder and try again.
    echo No Windows security settings have been changed.
    pause
    exit /b 1
)
