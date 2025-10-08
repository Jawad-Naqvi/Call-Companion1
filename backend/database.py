import os
import psycopg2
from psycopg2.extras import RealDictCursor
from dotenv import load_dotenv
from typing import Optional, Dict, Any, List
import logging

# Load environment variables
load_dotenv()

# Database connection configuration
NEON_CONNECTION_STRING = os.getenv(
    "NEON_CONNECTION_STRING", 
    "postgresql://neondb_owner:npg_6JZlrqGP1OCx@ep-super-bird-advyb94d-pooler.c-2.us-east-1.aws.neon.tech/neondb?sslmode=require&channel_binding=require"
)

class Database:
    def __init__(self):
        self.connection_string = NEON_CONNECTION_STRING
        self.conn = None
        self.connect()
        self.init_tables()
    
    def connect(self):
        """Establish connection to PostgreSQL database"""
        try:
            self.conn = psycopg2.connect(
                self.connection_string,
                cursor_factory=RealDictCursor
            )
            logging.info("Connected to PostgreSQL database successfully")
        except Exception as e:
            logging.error(f"Failed to connect to database: {e}")
            raise
    
    def init_tables(self):
        """Initialize database tables if they don't exist"""
        try:
            with self.conn.cursor() as cur:
                # Users table
                cur.execute("""
                    CREATE TABLE IF NOT EXISTS users (
                        id VARCHAR(255) PRIMARY KEY,
                        email VARCHAR(255) UNIQUE NOT NULL,
                        name VARCHAR(255) NOT NULL,
                        role VARCHAR(50) NOT NULL DEFAULT 'employee',
                        company_id VARCHAR(255),
                        phone_number VARCHAR(50),
                        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                    )
                """)
                
                # Customers table
                cur.execute("""
                    CREATE TABLE IF NOT EXISTS customers (
                        id VARCHAR(255) PRIMARY KEY,
                        phone_number VARCHAR(50) NOT NULL,
                        alias VARCHAR(255),
                        name VARCHAR(255),
                        company VARCHAR(255),
                        email VARCHAR(255),
                        employee_id VARCHAR(255) NOT NULL,
                        last_call_at TIMESTAMP,
                        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                        FOREIGN KEY (employee_id) REFERENCES users(id) ON DELETE CASCADE
                    )
                """)
                
                # Calls table
                cur.execute("""
                    CREATE TABLE IF NOT EXISTS calls (
                        id VARCHAR(255) PRIMARY KEY,
                        employee_id VARCHAR(255) NOT NULL,
                        customer_id VARCHAR(255) NOT NULL,
                        customer_phone_number VARCHAR(50) NOT NULL,
                        type VARCHAR(20) NOT NULL,
                        status VARCHAR(20) NOT NULL DEFAULT 'recorded',
                        audio_url TEXT,
                        audio_file_name VARCHAR(255),
                        audio_file_size BIGINT,
                        duration INTEGER,
                        start_time TIMESTAMP,
                        end_time TIMESTAMP,
                        transcript_id VARCHAR(255),
                        summary_id VARCHAR(255),
                        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                        FOREIGN KEY (employee_id) REFERENCES users(id) ON DELETE CASCADE,
                        FOREIGN KEY (customer_id) REFERENCES customers(id) ON DELETE CASCADE
                    )
                """)
                
                # Transcripts table
                cur.execute("""
                    CREATE TABLE IF NOT EXISTS transcripts (
                        id VARCHAR(255) PRIMARY KEY,
                        call_id VARCHAR(255) NOT NULL,
                        full_text TEXT NOT NULL,
                        provider VARCHAR(50),
                        language VARCHAR(20),
                        confidence_score FLOAT,
                        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                        FOREIGN KEY (call_id) REFERENCES calls(id) ON DELETE CASCADE
                    )
                """)
                
                # AI Summaries table
                cur.execute("""
                    CREATE TABLE IF NOT EXISTS ai_summaries (
                        id VARCHAR(255) PRIMARY KEY,
                        call_id VARCHAR(255) NOT NULL,
                        transcript_id VARCHAR(255) NOT NULL,
                        highlights JSONB,
                        sentiment VARCHAR(20),
                        next_steps JSONB,
                        raw_response TEXT,
                        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                        FOREIGN KEY (call_id) REFERENCES calls(id) ON DELETE CASCADE,
                        FOREIGN KEY (transcript_id) REFERENCES transcripts(id) ON DELETE CASCADE
                    )
                """)
                
                # Chat Messages table
                cur.execute("""
                    CREATE TABLE IF NOT EXISTS chat_messages (
                        id VARCHAR(255) PRIMARY KEY,
                        customer_id VARCHAR(255) NOT NULL,
                        employee_id VARCHAR(255) NOT NULL,
                        content TEXT NOT NULL,
                        is_from_user BOOLEAN NOT NULL DEFAULT TRUE,
                        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                        FOREIGN KEY (customer_id) REFERENCES customers(id) ON DELETE CASCADE,
                        FOREIGN KEY (employee_id) REFERENCES users(id) ON DELETE CASCADE
                    )
                """)
                
                # Create indexes for better performance
                cur.execute("CREATE INDEX IF NOT EXISTS idx_customers_employee_id ON customers(employee_id)")
                cur.execute("CREATE INDEX IF NOT EXISTS idx_calls_employee_id ON calls(employee_id)")
                cur.execute("CREATE INDEX IF NOT EXISTS idx_calls_customer_id ON calls(customer_id)")
                cur.execute("CREATE INDEX IF NOT EXISTS idx_chat_messages_customer_employee ON chat_messages(customer_id, employee_id)")
                
                self.conn.commit()
                logging.info("Database tables initialized successfully")
                
        except Exception as e:
            logging.error(f"Failed to initialize tables: {e}")
            self.conn.rollback()
            raise
    
    def execute_query(self, query: str, params: Optional[tuple] = None) -> List[Dict[str, Any]]:
        """Execute a SELECT query and return results"""
        try:
            with self.conn.cursor() as cur:
                cur.execute(query, params)
                return cur.fetchall()
        except Exception as e:
            logging.error(f"Query execution failed: {e}")
            raise
    
    def execute_command(self, query: str, params: Optional[tuple] = None) -> int:
        """Execute an INSERT, UPDATE, or DELETE command"""
        try:
            with self.conn.cursor() as cur:
                cur.execute(query, params)
                self.conn.commit()
                return cur.rowcount
        except Exception as e:
            logging.error(f"Command execution failed: {e}")
            self.conn.rollback()
            raise
    
    def close(self):
        """Close database connection"""
        if self.conn:
            self.conn.close()
            logging.info("Database connection closed")

# Global database instance
db = Database()