#!/usr/bin/env python3
"""
Call Companion API Server Startup Script
This script starts the FastAPI server with proper configuration for production.
"""

import os
import sys
import logging
import uvicorn
from pathlib import Path

# Add the backend directory to Python path
backend_dir = Path(__file__).parent
sys.path.insert(0, str(backend_dir))

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)

logger = logging.getLogger(__name__)

def check_environment():
    """Check if all required environment variables are set."""
    required_vars = [
        'NEON_CONNECTION_STRING',
        'FIREBASE_CREDENTIALS_PATH', 
        'FIREBASE_STORAGE_BUCKET',
        'WHISPER_API_KEY',
        'GEMINI_API_KEY'
    ]
    
    missing_vars = []
    for var in required_vars:
        if not os.getenv(var):
            missing_vars.append(var)
    
    if missing_vars:
        logger.error(f"Missing required environment variables: {missing_vars}")
        logger.error("Please check your .env file and ensure all required variables are set.")
        return False
    
    return True

def check_firebase_credentials():
    """Check if Firebase credentials file exists."""
    cred_path = os.getenv('FIREBASE_CREDENTIALS_PATH', 'call-companion.json')
    if not os.path.exists(cred_path):
        logger.error(f"Firebase credentials file not found: {cred_path}")
        logger.error("Please ensure you have a valid Firebase service account key file.")
        return False
    
    return True

def main():
    """Main entry point for the server."""
    logger.info("Starting Call Companion API Server...")
    
    # Load environment variables from .env file
    try:
        from dotenv import load_dotenv
        # Load backend/.env first
        load_dotenv()
        # Also load project root .env as fallback
        root_env = Path(__file__).parent.parent / '.env'
        if root_env.exists():
            load_dotenv(dotenv_path=str(root_env), override=True)
        logger.info("Environment variables loaded from .env files")
    except ImportError:
        logger.warning("python-dotenv not installed, using system environment variables")
    except Exception as e:
        logger.warning(f"Could not load .env file(s): {e}")
    
    # Check environment
    if not check_environment():
        sys.exit(1)
    
    if not check_firebase_credentials():
        sys.exit(1)
    
    # Get configuration from environment
    host = os.getenv('HOST', '0.0.0.0')
    port = int(os.getenv('PORT', 8001))
    log_level = os.getenv('LOG_LEVEL', 'INFO').lower()
    
    # Import the FastAPI app
    try:
        from main import app
        logger.info("FastAPI app imported successfully")
    except Exception as e:
        logger.error(f"Failed to import FastAPI app: {e}")
        sys.exit(1)
    
    logger.info(f"Starting server on {host}:{port}")
    logger.info(f"Log level: {log_level}")
    logger.info("Server is ready to accept connections!")
    
    # Start the server
    uvicorn.run(
        app, 
        host=host, 
        port=port, 
        log_level=log_level,
        access_log=True
    )

if __name__ == "__main__":
    main()