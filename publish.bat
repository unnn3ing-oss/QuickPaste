@echo off
rem Build a portable (no-install) QuickPaste: dist\QuickPaste\ and dist\QuickPaste-portable.zip
rem Requires the .NET 8 SDK. Double-click this file or run it from a terminal.
setlocal
cd /d "%~dp0"

where dotnet >nul 2>nul
if errorlevel 1 (
    echo [ERROR] .NET 8 SDK not found. Install it from https://dotnet.microsoft.com/download
    pause
    exit /b 1
)

set "OUT=dist\QuickPaste"
if exist dist rmdir /s /q dist

echo Publishing...
dotnet publish CopyTool\CopyTool.csproj -c Release -r win-x64 --self-contained true ^
    -p:PublishSingleFile=true -p:IncludeNativeLibrariesForSelfExtract=true ^
    -p:DebugType=None -p:DebugSymbols=false -o "%OUT%"
if errorlevel 1 (
    echo [ERROR] publish failed.
    pause
    exit /b 1
)

rem Data files sit next to the exe. Copy yours in if they exist in the repo root.
if exist "copy-tool-buttons.json" copy /y "copy-tool-buttons.json" "%OUT%\" >nul
if exist "copy-tool-settings.json" copy /y "copy-tool-settings.json" "%OUT%\" >nul
del /q "%OUT%\*.pdb" 2>nul

echo Zipping...
powershell -NoProfile -Command "Compress-Archive -Path '%OUT%\*' -DestinationPath 'dist\QuickPaste-portable.zip' -Force"

echo.
echo Done:
echo   Folder: %CD%\%OUT%
echo   Zip:    %CD%\dist\QuickPaste-portable.zip
pause
