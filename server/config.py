import os
from pydantic_settings import BaseSettings
from dotenv import load_dotenv, find_dotenv
import logging

logger = logging.getLogger(__name__)

# Load environment variables from .env file
# Use find_dotenv() to search for .env file in parent directories
env_file = find_dotenv()
if env_file:
    load_dotenv(env_file)
    logger.info(f"Loaded environment from: {env_file}")
else:
    logger.warning("No .env file found - using environment variables only")

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
    # Admin allowlist raw string (comma-separated). We'll normalize after instantiation.
    admin_emails: str = os.getenv(
        "ADMIN_EMAILS",
        "naqvimohammedjawad@gmail.com"
    )

    class Config:
        env_file = "../.env"
        extra = "ignore"

# After instantiation, normalize admin_emails to a list for downstream usage
settings = Settings()
try:
    if isinstance(settings.admin_emails, str):
        parsed = [e.strip().lower() for e in settings.admin_emails.split(',') if e.strip()]
        object.__setattr__(settings, 'admin_emails', parsed)
except Exception as _e:
    logger.warning(f"Failed to normalize ADMIN_EMAILS: {_e}")

# Log configuration status
logger.info("=== Configuration Status ===")
logger.info(f"Database URL configured: {bool(settings.neon_connection_string)}")
logger.info(f"Gemini API Key configured: {bool(settings.gemini_api_key)}")
logger.info(f"API Host: {settings.api_host}:{settings.api_port}")
logger.info(f"JWT configured: {bool(settings.jwt_secret != 'your-super-secret-jwt-key-change-this-in-production')}")
logger.info(f"Admin allowlist size: {len(settings.admin_emails) if isinstance(settings.admin_emails, (list, tuple)) else 0}")
logger.info("=============================")

# Export a flag for database availability
DB_AVAILABLE = bool(settings.neon_connection_string)
