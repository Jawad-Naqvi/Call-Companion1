from sqlalchemy import create_engine, MetaData
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker
from config import settings
import logging

logger = logging.getLogger(__name__)

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

def ensure_users_table():
    """Ensure critical columns exist on the 'users' table.
    This reconciles older databases that may miss new columns like 'hashed_password'.
    Safe to run repeatedly.
    """
    try:
        from sqlalchemy import text
        with engine.begin() as conn:
            # Ensure table exists
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
            # Fetch existing column names
            cols = conn.execute(text(
                """
                SELECT column_name
                FROM information_schema.columns
                WHERE table_schema = 'public' AND table_name = 'users'
                """
            )).fetchall()
            existing = {row[0] for row in cols}

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

            # Inspect id column type/default
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

            # Create case-insensitive unique index on email
            conn.execute(text(
                """
                CREATE UNIQUE INDEX IF NOT EXISTS users_email_unique_ci
                ON public.users (lower(trim(email)));
                """
            ))
        logger.info("✅ Schema reconciliation complete for 'users' table")
    except Exception as e:
        logger.error(f"❌ Schema reconciliation failed: {e}")

# Dependency to get database session
def get_db():
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
    try:
        with engine.connect() as connection:
            from sqlalchemy import text
            result = connection.execute(text("SELECT 1"))
            logger.info("✅ Database connection successful")
            return True
    except Exception as e:
        logger.error(f"❌ Database connection failed: {e}")
        return False
