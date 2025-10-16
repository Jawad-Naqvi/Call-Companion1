@echo off
echo Starting Call Companion API Server...

REM Check if Python is installed
python --version >nul 2>&1
if errorlevel 1 (
    echo Python is not installed or not in PATH
    echo Please install Python 3.8+ and add it to your PATH
    pause
    exit /b 1
)

REM Check if virtual environment exists
if not exist "venv" (
    echo Creating virtual environment...
    python -m venv venv
)

REM Activate virtual environment
echo Activating virtual environment...
call venv\Scripts\activate.bat

REM Install dependencies
echo Installing dependencies...
pip install -r requirements.txt

REM Check if .env file exists
if not exist ".env" (
    echo .env file not found!
    echo Please copy .env.example to .env and configure your environment variables
    pause
    exit /b 1
)

REM Start the server
echo Starting FastAPI server...
python start_server.py

REM Keep the window open if there's an error
if errorlevel 1 (
    echo.
    echo Server exited with error code %errorlevel%
    pause
)