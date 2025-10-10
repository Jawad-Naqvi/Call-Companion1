@echo off
echo Starting Call Companion API Server...
echo.

REM Check if virtual environment exists
if not exist "venv" (
    echo Creating virtual environment...
    python -m venv venv
)

REM Activate virtual environment
call venv\Scripts\activate

REM Install dependencies
echo Installing dependencies...
pip install -r requirements.txt >nul 2>&1
if errorlevel 1 (
    echo ERROR: Failed to install dependencies
    echo Please check requirements.txt and try again
    pause
    exit /b 1
)

REM Set environment variables from .env file
echo Loading environment variables...
if exist "..\.env" (
    for /f "tokens=1,2 delims==" %%a in (..\.env) do (
        if not "%%a"=="" if not "%%a:~0,1%"=="#" (
            set "%%a=%%b"
        )
    )
    echo Environment loaded from .env
) else (
    echo WARNING: .env file not found in parent directory
)

REM Generate JWT secret if not provided
if not defined JWT_SECRET (
    set JWT_SECRET=your-super-secret-jwt-key-change-this-in-production-12345
)

REM Set working directory to server folder for proper imports
cd /d %~dp0

REM Start the server with proper host binding and logging
echo.
echo Starting FastAPI server...
echo Server will be available at:
echo   - Local: http://127.0.0.1:8001
echo   - Network: http://192.168.1.17:8001
echo   - Health check: http://127.0.0.1:8001/api/health
echo.

uvicorn main:app --host 0.0.0.0 --port 8001 --reload --log-level info

REM If server stops unexpectedly, keep console open for debugging
echo.
echo Server stopped. Press any key to exit.
pause
