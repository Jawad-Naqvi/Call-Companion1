from sqlalchemy import create_engine, MetaData, text
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker
from config import settings
import logging

logger = logging.getLogger(__name__)

# Only create engine if database URL is configured
if settings.neon_connection_string:
    try:
        logger.info("Creating database engine...")
        # Create database engine
        engine = create_engine(
            settings.neon_connection_string.replace("postgresql://", "postgresql+psycopg://"),
            pool_pre_ping=True,
            pool_recycle=300,
            echo=False  # Set to True for SQL debugging
        )

        # Create session factory
        SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

        # Create base class for models
        Base = declarative_base()

        # Flag to indicate database is available
        DB_ENGINE_AVAILABLE = True
        logger.info("✅ Database engine created successfully")

    except Exception as e:
        logger.error(f"Failed to create database engine: {e}")
        # Create a dummy engine that will fail gracefully
        engine = None
        SessionLocal = None
        Base = None
        DB_ENGINE_AVAILABLE = False
        logger.warning("⚠️ Database engine creation failed - server will run but database features may not work")
else:
    logger.warning("No database URL configured - database features will not work")
    engine = None
    SessionLocal = None
    Base = None
    DB_ENGINE_AVAILABLE = False

def ensure_users_table():
    """Ensure critical columns exist on the 'users' table.
    This reconciles older databases that may miss new columns like 'hashed_password'.
    Safe to run repeatedly.
    """
    if not DB_ENGINE_AVAILABLE or not engine:
        logger.warning("Database engine not available - skipping schema reconciliation")
        return

    try:
        logger.info("Starting schema reconciliation...")
        with engine.begin() as conn:
            # Ensure table exists
            logger.info("Creating users table if not exists...")
            conn.execute(text(
                """
                CREATE TABLE IF NOT EXISTS public.users (
                    id INTEGER PRIMARY KEY,
                    email VARCHAR(255) NOT NULL,
                    hashed_password VARCHAR(255) NOT NULL DEFAULT '',
                    name VARCHAR(255) NOT NULL,
                    role VARCHAR(50) NOT NULL DEFAULT 'employee',
                    company_id VARCHAR(255) NOT NULL DEFAULT 'default-company',
                    is_active BOOLEAN NOT NULL DEFAULT TRUE,
                    created_at TIMESTAMPTZ DEFAULT NOW(),
                    updated_at TIMESTAMPTZ DEFAULT NOW()
                );
                """
            ))
            logger.info("✅ Users table created/verified")

            # Fetch existing column names
            logger.info("Checking existing columns...")
            cols = conn.execute(text(
                """
                SELECT column_name
                FROM information_schema.columns
                WHERE table_schema = 'public' AND table_name = 'users'
                """
            )).fetchall()
            existing = {row[0] for row in cols}
            logger.info(f"Existing columns: {existing}")

            # Define required columns and their SQL definitions
            required = {
                "email": "VARCHAR(255) NOT NULL",
                "hashed_password": "VARCHAR(255) NOT NULL DEFAULT ''",
                "name": "VARCHAR(255) NOT NULL",
                "role": "VARCHAR(50) NOT NULL DEFAULT 'employee'",
                "company_id": "VARCHAR(255) NOT NULL DEFAULT 'default-company'",
                "is_active": "BOOLEAN NOT NULL DEFAULT TRUE",
                "created_at": "TIMESTAMPTZ DEFAULT NOW()",
                "updated_at": "TIMESTAMPTZ DEFAULT NOW()",
            }

            # Add any missing columns
            for col, ddl in required.items():
                if col not in existing:
                    logger.warning(f"[schema] Adding missing column 'users.{col}'")
                    conn.execute(text(f"ALTER TABLE public.users ADD COLUMN {col} {ddl}"))

            # Ensure updated_at auto-update trigger (optional, idempotent)
            if "updated_at" in required:
                logger.info("Creating updated_at trigger...")
                conn.execute(text(
                    """
                    CREATE OR REPLACE FUNCTION set_updated_at()
                    RETURNS TRIGGER AS $$
                    BEGIN
                        NEW.updated_at = NOW();
                        RETURN NEW;
                    END;
                    $$ LANGUAGE plpgsql;

                    DO $$ BEGIN
                    IF NOT EXISTS (
                        SELECT 1 FROM pg_trigger WHERE tgname = 'users_set_updated_at'
                    ) THEN
                        CREATE TRIGGER users_set_updated_at
                        BEFORE UPDATE ON public.users
                        FOR EACH ROW EXECUTE FUNCTION set_updated_at();
                    END IF;
                    END $$;
                    """
                ))
                logger.info("✅ Updated_at trigger created")

            # Inspect id column type/default
            logger.info("Checking id column configuration...")
            id_col_info = conn.execute(text(
                """
                SELECT data_type, column_default
                FROM information_schema.columns
                WHERE table_schema='public' AND table_name='users' AND column_name='id'
                """
            )).fetchone()

            # If id is integer-like, ensure it auto-increments via a sequence; otherwise leave as-is
            if id_col_info and id_col_info[0] in ('integer','bigint','smallint'):
                # Ensure id column exists
                if 'id' not in existing:
                    conn.execute(text("ALTER TABLE public.users ADD COLUMN id INTEGER"))

                # Create sequence and attach as default
                logger.info("Creating id sequence...")
                conn.execute(text("CREATE SEQUENCE IF NOT EXISTS public.users_id_seq"))
                conn.execute(text("ALTER TABLE public.users ALTER COLUMN id SET DEFAULT nextval('public.users_id_seq')"))
                # Sync sequence to current max(id)
                conn.execute(text(
                    "SELECT setval('public.users_id_seq', COALESCE((SELECT MAX(id) FROM public.users), 0))"
                ))
                # Ensure primary key constraint exists
                conn.execute(text(
                    """
                    DO $$ BEGIN
                    IF NOT EXISTS (
                        SELECT 1 FROM pg_constraint
                        WHERE conrelid = 'public.users'::regclass AND contype = 'p'
                    ) THEN
                        ALTER TABLE public.users ADD CONSTRAINT users_pkey PRIMARY KEY (id);
                    END IF;
                    END $$;
                    """
                ))
                logger.info("✅ ID sequence and primary key configured")

            # Create case-insensitive unique index on email
            logger.info("Creating email unique index...")
            conn.execute(text(
                """
                CREATE UNIQUE INDEX IF NOT EXISTS users_email_unique_ci
                ON public.users (lower(trim(email)));
                """
            ))
            logger.info("✅ Email unique index created")

        logger.info("✅ Schema reconciliation complete for 'users' table")
    except Exception as e:
        logger.error(f"❌ Schema reconciliation failed: {e}")
        raise

# Dependency to get database session
def get_db():
    if not DB_ENGINE_AVAILABLE or not SessionLocal:
        logger.warning("Database not available - returning 503 error")
        from fastapi import HTTPException
        raise HTTPException(
            status_code=503,
            detail="Database not available"
        )

    logger.debug("Creating database session...")
    db = SessionLocal()
    try:
        yield db
    except Exception as e:
        logger.error(f"Database session error: {e}")
        db.rollback()
        raise
    finally:
        db.close()

# Test database connection
def test_connection():
    if not DB_ENGINE_AVAILABLE or not engine:
        logger.warning("Database engine not available for connection test")
        return False

    try:
        logger.info("Testing database connection...")
        with engine.connect() as connection:
            result = connection.execute(text("SELECT 1"))
            logger.info("✅ Database connection successful")
            return True
    except Exception as e:
        logger.error(f"❌ Database connection failed: {e}")
        return False
