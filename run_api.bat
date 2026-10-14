@echo off
title IPL Match Outcome Prediction API Server
echo ====================================================================
echo      Starting IPL Match Outcome Prediction API (R Plumber)
echo ====================================================================
echo.

where Rscript >nul 2>nul
if %ERRORLEVEL% EQU 0 (
    Rscript api\start_server.R
) else if exist "D:\Program Files\R\R-4.6.1\bin\Rscript.exe" (
    "D:\Program Files\R\R-4.6.1\bin\Rscript.exe" api\start_server.R
) else if exist "C:\Program Files\R\R-4.6.1\bin\Rscript.exe" (
    "C:\Program Files\R\R-4.6.1\bin\Rscript.exe" api\start_server.R
) else (
    "C:\Users\HP\R\bin\Rscript.exe" api\start_server.R
)

pause
