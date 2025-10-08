#!/bin/bash
echo "Starting Call Companion API Server..."

# Check if virtual environment exists
if [ ! -d "venv" ]; then
    echo "Creating virtual environment..."
    python3 -m venv venv
fi

# Activate virtual environment
source venv/bin/activate

# Install dependencies
echo "Installing dependencies..."
pip install -r requirements.txt

# Load environment variables from .env file
if [ -f "../.env" ]; then
    echo "Loading environment variables..."
    export $(cat ../.env | grep -v '^#' | xargs)
fi

# Generate JWT secret if not provided
if [ -z "$JWT_SECRET" ]; then
    export JWT_SECRET="your-super-secret-jwt-key-change-this-in-production-12345"
fi

# Start the server
echo "Starting FastAPI server on http://127.0.0.1:8000"
uvicorn main:app --host 0.0.0.0 --port 8000 --reload
