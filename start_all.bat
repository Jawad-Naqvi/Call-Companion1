@echo off
echo ========================================
echo   Call Companion - Starting All Services
echo ========================================
echo.

REM Kill any existing processes on ports 8001 and 8080
echo [1/4] Cleaning up existing processes...
for /f "tokens=5" %%a in ('netstat -aon ^| findstr :8001') do taskkill /F /PID %%a >nul 2>&1
for /f "tokens=5" %%a in ('netstat -aon ^| findstr :8080') do taskkill /F /PID %%a >nul 2>&1
timeout /t 2 >nul

echo [2/4] Starting Backend Server...
start "Backend Server" cmd /k "cd /d %~dp0server && venv\Scripts\python.exe -m uvicorn main:app --host 0.0.0.0 --port 8001 --reload"
echo Backend starting on http://0.0.0.0:8001
timeout /t 5 >nul

echo [3/4] Testing Backend Connection...
curl -s http://127.0.0.1:8001/api/health >nul 2>&1
if %errorlevel% equ 0 (
    echo Backend is UP and HEALTHY!
) else (
    echo Backend is starting... (may take a few more seconds)
)

echo [4/4] Starting Flutter Web App...
start "Flutter Web" cmd /k "cd /d %~dp0 && flutter run -d chrome --web-port 8080"
echo Flutter Web starting on http://localhost:8080

echo.
echo ========================================
echo   All Services Started!
echo ========================================
echo.
echo Backend:  http://127.0.0.1:8001
echo Frontend: http://localhost:8080
echo API Docs: http://127.0.0.1:8001/docs
echo.
echo Press any key to exit this window...
pause >nul
