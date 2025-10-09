import os
from pydantic_settings import BaseSettings
from dotenv import load_dotenv

# Load environment variables from parent directory .env file
load_dotenv(dotenv_path="../.env")

class Settings(BaseSettings):
    # Database
    neon_connection_string: str = os.getenv("NEON_CONNECTION_STRING", "")
    
    # JWT
    jwt_secret: str = os.getenv("JWT_SECRET", "your-super-secret-jwt-key-change-this-in-production")
    jwt_algorithm: str = "HS256"
    jwt_expires_minutes: int = int(os.getenv("JWT_EXPIRES_MINUTES", "1440"))  # 24 hours
    
    # API
    api_host: str = os.getenv("HOST", "0.0.0.0")
    api_port: int = int(os.getenv("PORT", "8001"))  # Changed default to 8001
    
    # CORS
    cors_origins: list = [
        "http://localhost:3000",
        "http://127.0.0.1:3000",
        "http://localhost:8080",
        "http://127.0.0.1:8080",
        "http://localhost:60935",  # Flutter web dev server
        "http://127.0.0.1:60935",
        "http://localhost:61006",  # Browser preview
        "http://127.0.0.1:61006",
        "http://localhost:50569",  # Current Flutter dev server
        "http://127.0.0.1:50569",
        "http://localhost:55338",  # Current Flutter web dev server
        "http://127.0.0.1:55338",
        "*"  # Allow all origins for development
    ]

    # External APIs
    gemini_api_key: str = os.getenv("GEMINI_API_KEY", "")
    # Debug flags
    debug_ai: bool = os.getenv("DEBUG_AI", "true").lower() in ("1", "true", "yes", "on")

    class Config:
        env_file = "../.env"
        extra = "ignore"

settings = Settings()
