@echo off
echo ============================================================
echo  IPL info - Cricket Analytics ^& Prediction Platform
echo ============================================================
echo.

set RSCRIPT=Rscript
where Rscript >nul 2>nul
if %ERRORLEVEL% NEQ 0 (
    if exist "D:\Program Files\R\R-4.6.1\bin\Rscript.exe" (
        set RSCRIPT="D:\Program Files\R\R-4.6.1\bin\Rscript.exe"
    ) else if exist "C:\Program Files\R\R-4.6.1\bin\Rscript.exe" (
        set RSCRIPT="C:\Program Files\R\R-4.6.1\bin\Rscript.exe"
    ) else (
        set RSCRIPT="C:\Users\HP\R\bin\Rscript.exe"
    )
)

REM Start R Plumber API in background
echo [1/2] Starting R Plumber API on port 8000...
start "IPL Oracle API" cmd /k "cd /d "%~dp0" && %RSCRIPT% api/start_server.R"

REM Wait a moment for R to initialize
timeout /t 5 /nobreak > nul

REM Start Vite frontend
echo [2/2] Starting React frontend on port 5173...
echo.
echo  API:      http://127.0.0.1:8000/api/health
echo  Frontend: http://localhost:5173
echo.
cd /d "%~dp0frontend"
call npm run dev -- --open

pause
