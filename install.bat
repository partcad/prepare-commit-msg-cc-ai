@echo off
setlocal enabledelayedexpansion

:: Check if running with administrator privileges
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo Please run this script as Administrator
    exit /b 1
)

:: Set up directories
set "INSTALL_DIR=%USERPROFILE%\git-commit-ai"
set "CONFIG_DIR=%USERPROFILE%\.config\git-commit-ai"

:: Create directories
mkdir "%INSTALL_DIR%" 2>nul
mkdir "%CONFIG_DIR%" 2>nul

:: Copy script
copy /Y "git-commit.sh" "%INSTALL_DIR%\cmai.sh"

:: Add to PATH if not already present
echo Checking PATH...
echo %PATH% | findstr /I /C:"%INSTALL_DIR%" >nul
if %errorLevel% neq 0 (
    setx PATH "%PATH%;%INSTALL_DIR%"
    echo Added to PATH
) else (
    echo Already in PATH
)

echo Installation complete!
echo.
echo To set up your OpenRouter API key, run:
echo cmai your_openrouter_api_key
echo.
echo Please restart your terminal for the changes to take effect. 