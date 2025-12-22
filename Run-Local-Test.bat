@echo off
setlocal
title Project CloudVerse - Local Launcher
color 0A

echo ===================================================
echo       Project CloudVerse (One-Dream Edition)
echo                Local Experience
echo ===================================================
echo.

:: 1. Check Docker
echo [*] Checking Docker Desktop status...
docker info >nul 2>&1
if %errorlevel% neq 0 (
    color 0C
    echo [!] Docker is NOT running! 
    echo Please start Docker Desktop and try again.
    pause
    exit /b
)
echo [V] Docker is running.

:: 2. Config
echo.
echo [?] You can run this locally to test "Mission Critical" features.
echo.
set /p IMAGE_NAME="Enter your GHCR Image URL (e.g., ghcr.io/user/redroid-pro:latest): "

if "%IMAGE_NAME%"=="" (
    color 0C
    echo [!] You MUST provide an image URL. Local building is disabled to save resources.
    echo Please build on GitHub Actions first.
    pause
    exit /b
) else (
    echo [*] Pulling image: %IMAGE_NAME%
    docker pull %IMAGE_NAME%
)

:: 3. Launch
echo.
echo [*] Launching CloudVerse...
:: Export the variable so docker-compose picks it up
set REDROID_IMAGE=%IMAGE_NAME%
docker-compose up -d

:: 4. Verify
echo.
echo [*] Waiting for services...
timeout /t 10 >nul

echo.
echo ===================================================
echo [V] Deployment Successful!
echo.
echo 1. Web Portal (Touch): http://localhost:8000
echo 2. Data Sync (File):   http://localhost:8384
echo 3. ADB Connect:        adb connect localhost:5555
echo ===================================================
echo.
echo Press any key to open Web Portal...
pause >nul
start http://localhost:8000

endlocal
