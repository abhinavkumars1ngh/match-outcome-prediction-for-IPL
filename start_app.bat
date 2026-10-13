@echo off
echo ============================================================
echo  IPL Oracle - Starting Development Environment
echo ============================================================
echo.

REM Start R Plumber API in background
echo [1/2] Starting R Plumber API on port 8000...
start "IPL Oracle API" cmd /k "cd /d "%~dp0" && Rscript api/start_server.R"

REM Wait a moment for R to initialize
timeout /t 5 /nobreak > nul

REM Start Vite frontend
echo [2/2] Starting React frontend on port 5173...
echo.
echo  API:      http://127.0.0.1:8000/api/health
echo  Frontend: http://localhost:5173
echo.
cd /d "%~dp0frontend"
set PATH=C:\Program Files\nodejs;%PATH%
call npx --yes vite --open

pause
