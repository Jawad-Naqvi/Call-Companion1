@echo off
echo Starting Call Companion API Server...

REM Check if virtual environment exists
if not exist "venv" (
    echo Creating virtual environment...
    python -m venv venv
)

REM Activate virtual environment
call venv\Scripts\activate

REM Install dependencies
echo Installing dependencies...
pip install -r requirements.txt

REM Set environment variables from .env file
echo Loading environment variables...
for /f "tokens=1,2 delims==" %%a in (..\.env) do (
    if not "%%a"=="" if not "%%a:~0,1%"=="#" (
        set "%%a=%%b"
    )
)

REM Generate JWT secret if not provided
if not defined JWT_SECRET (
    set JWT_SECRET=your-super-secret-jwt-key-change-this-in-production-12345
)

REM Start the server
echo Starting FastAPI server on http://127.0.0.1:8001
uvicorn main:app --host 0.0.0.0 --port 8001 --reload --log-level debug --access-log

pause
