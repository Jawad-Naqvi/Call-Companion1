from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from contextlib import asynccontextmanager
import logging
import uvicorn

# Import with error handling to prevent startup crashes
try:
    from config import settings, DB_AVAILABLE
    CONFIG_LOADED = True
except Exception as e:
    print(f"❌ Config import failed: {e}")
    CONFIG_LOADED = False
    settings = None
    DB_AVAILABLE = False

try:
    from database import Base, engine, test_connection, ensure_users_table, DB_ENGINE_AVAILABLE
    DATABASE_LOADED = True
except Exception as e:
    print(f"❌ Database import failed: {e}")
    DATABASE_LOADED = False
    Base = None
    engine = None
    test_connection = lambda: False
    ensure_users_table = lambda: None
    DB_ENGINE_AVAILABLE = False

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s - %(name)s - %(levelname)s - %(message)s"
)
logger = logging.getLogger(__name__)

# Global flag for database availability
db_connected = False

@asynccontextmanager
async def lifespan(app: FastAPI):
    """Application lifespan events."""
    global db_connected

    # Startup
    logger.info("🚀 Starting Call Companion API Server...")

    # Test database connection only if everything loaded properly
    if CONFIG_LOADED and DATABASE_LOADED and DB_AVAILABLE and DB_ENGINE_AVAILABLE:
        try:
            logger.info("Testing database connection...")
            if test_connection():
                db_connected = True
                logger.info("✅ Database connection successful")

                # Reconcile schema (idempotent) before creating tables
                try:
                    logger.info("Reconciling database schema...")
                    ensure_users_table()
                    logger.info("✅ Schema reconciliation complete")
                except Exception as e:
                    logger.error(f"❌ Schema reconciliation raised an error: {e}")
                    # Don't crash the server for schema issues

                # Create database tables
                try:
                    logger.info("Creating/verifying database tables...")
                    if Base and engine:
                        Base.metadata.create_all(bind=engine)
                    logger.info("✅ Database tables created/verified")
                except Exception as e:
                    logger.error(f"❌ Database table creation failed: {e}")
                    # Don't crash the server for table creation issues
            else:
                logger.warning("⚠️ Database connection failed - server will run but auth may not work")
                db_connected = False
        except Exception as e:
            logger.error(f"❌ Database initialization error: {e}")
            logger.warning("⚠️ Server will run but database-dependent features may not work")
            db_connected = False
    else:
        logger.warning("⚠️ Database or config not properly loaded - server will run in limited mode")
        db_connected = False

    logger.info("✅ Server startup complete")

    yield

    # Shutdown
    logger.info("🛑 Shutting down Call Companion API Server...")

# Create FastAPI app
app = FastAPI(
    title="Call Companion API",
    description="Backend API for Call Companion - AI-powered sales call management",
    version="1.0.0",
    lifespan=lifespan
)

# Add CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Allow all origins for development
    allow_credentials=False,  # Set to False when using allow_origins=["*"]
    allow_methods=["GET", "POST", "PUT", "DELETE", "OPTIONS"],
    allow_headers=["*"],
)

# Include routers with error handling
try:
    from routes import auth
    app.include_router(auth.router, prefix="/api")
    logger.info("✅ Auth routes loaded")
except Exception as e:
    logger.error(f"❌ Auth routes failed to load: {e}")

try:
    from routes import ai
    app.include_router(ai.router, prefix="/api")
    logger.info("✅ AI routes loaded")
except Exception as e:
    logger.error(f"❌ AI routes failed to load: {e}")

# Health check endpoint
@app.get("/health")
async def health_check():
    """Health check endpoint."""
    return {
        "status": "healthy",
        "service": "call-companion-api",
        "version": "1.0.0",
        "database_connected": db_connected,
        "config_loaded": CONFIG_LOADED,
        "database_loaded": DATABASE_LOADED
    }

# API health check endpoint
@app.get("/api/health")
async def api_health_check():
    """API health check with detailed status."""
    gemini_configured = False
    api_host = "0.0.0.0:8001"

    if CONFIG_LOADED and settings:
        gemini_configured = bool(settings.gemini_api_key)
        api_host = f"{settings.api_host}:{settings.api_port}"

    return {
        "status": "ok",
        "database_connected": db_connected,
        "database_url_configured": DB_AVAILABLE if CONFIG_LOADED else False,
        "gemini_api_configured": gemini_configured,
        "api_host": api_host,
        "auth_mode": "api_auth" if not db_connected else "full_auth",
        "config_loaded": CONFIG_LOADED,
        "database_loaded": DATABASE_LOADED
    }

# Root endpoint
@app.get("/")
async def root():
    """Root endpoint with API information."""
    return {
        "message": "Call Companion API",
        "version": "1.0.0",
        "docs": "/docs",
        "health": "/health",
        "api_health": "/api/health"
    }

# Global exception handler
@app.exception_handler(Exception)
async def global_exception_handler(request, exc):
    """Global exception handler."""
    logger.error(f"Unhandled exception: {exc}")
    return JSONResponse(
        status_code=500,
        content={"error": "Internal server error", "detail": str(exc)}
    )

if __name__ == "__main__":
    # Use default settings if config failed to load
    host = "0.0.0.0"
    port = 8001

    if CONFIG_LOADED and settings:
        host = settings.api_host
        port = settings.api_port

    uvicorn.run(
        "main:app",
        host=host,
        port=port,
        reload=True,
        log_level="info"
    )
