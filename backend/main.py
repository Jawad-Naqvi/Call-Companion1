from fastapi import FastAPI, Depends, HTTPException, status, UploadFile, File, Form, Header
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from typing import Optional, Dict, Any, List
import firebase_admin
from firebase_admin import credentials, auth, storage
import os
import uuid
import httpx
import json
from datetime import datetime
import tempfile
from dotenv import load_dotenv
import logging
from pydantic import BaseModel
import psycopg2
from psycopg2.extras import RealDictCursor
from contextlib import asynccontextmanager

# Load environment variables
load_dotenv()

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Database connection
NEON_CONNECTION_STRING = os.getenv("NEON_CONNECTION_STRING")

class Database:
    def __init__(self):
        self.connection_string = NEON_CONNECTION_STRING
        self.conn = None
        self._connect()
        self._init_tables()
    
    def _connect(self):
        """Establish connection to PostgreSQL database with retry logic"""
        max_retries = 3
        for attempt in range(max_retries):
            try:
                self.conn = psycopg2.connect(
                    self.connection_string,
                    cursor_factory=RealDictCursor
                )
                logger.info("Connected to PostgreSQL database successfully")
                return
            except Exception as e:
                logger.error(f"Failed to connect to database (attempt {attempt + 1}/{max_retries}): {e}")
                if attempt == max_retries - 1:
                    raise
    
    def reconnect_if_needed(self):
        """Reconnect to database if connection is lost"""
        try:
            if self.conn.closed:
                logger.info("Database connection closed, reconnecting...")
                self._connect()
        except Exception as e:
            logger.error(f"Failed to check/reconnect database: {e}")
            self._connect()
    
    def _init_tables(self):
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
                        recording_enabled BOOLEAN DEFAULT FALSE,
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
                        CONSTRAINT fk_customers_employee FOREIGN KEY (employee_id) REFERENCES users(id) ON DELETE CASCADE
                    )
                """)
                
                # Calls table
                cur.execute("""
                    CREATE TABLE IF NOT EXISTS calls (
                        id VARCHAR(255) PRIMARY KEY,
                        employee_id VARCHAR(255) NOT NULL,
                        customer_id VARCHAR(255),
                        customer_phone_number VARCHAR(50) NOT NULL,
                        type VARCHAR(20) NOT NULL DEFAULT 'outgoing',
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
                        CONSTRAINT fk_calls_employee FOREIGN KEY (employee_id) REFERENCES users(id) ON DELETE CASCADE
                    )
                """)
                
                # Transcripts table
                cur.execute("""
                    CREATE TABLE IF NOT EXISTS transcripts (
                        id VARCHAR(255) PRIMARY KEY,
                        call_id VARCHAR(255) NOT NULL,
                        full_text TEXT NOT NULL,
                        provider VARCHAR(50) DEFAULT 'whisper',
                        language VARCHAR(20) DEFAULT 'en',
                        confidence_score FLOAT DEFAULT 0.95,
                        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                        CONSTRAINT fk_transcripts_call FOREIGN KEY (call_id) REFERENCES calls(id) ON DELETE CASCADE
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
                        CONSTRAINT fk_summaries_call FOREIGN KEY (call_id) REFERENCES calls(id) ON DELETE CASCADE,
                        CONSTRAINT fk_summaries_transcript FOREIGN KEY (transcript_id) REFERENCES transcripts(id) ON DELETE CASCADE
                    )
                """)
                
                # Chat Messages table
                cur.execute("""
                    CREATE TABLE IF NOT EXISTS chat_messages (
                        id VARCHAR(255) PRIMARY KEY,
                        customer_id VARCHAR(255),
                        customer_phone VARCHAR(50),
                        employee_id VARCHAR(255) NOT NULL,
                        content TEXT NOT NULL,
                        is_from_user BOOLEAN NOT NULL DEFAULT TRUE,
                        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                        CONSTRAINT fk_chat_employee FOREIGN KEY (employee_id) REFERENCES users(id) ON DELETE CASCADE
                    )
                """)

                # Backfill/migrate columns for existing deployments
                cur.execute("ALTER TABLE chat_messages ADD COLUMN IF NOT EXISTS customer_phone VARCHAR(50)")
                cur.execute("ALTER TABLE calls ADD COLUMN IF NOT EXISTS audio_file_name VARCHAR(255)")
                cur.execute("ALTER TABLE calls ADD COLUMN IF NOT EXISTS audio_file_size BIGINT")
                cur.execute("ALTER TABLE users ADD COLUMN IF NOT EXISTS recording_enabled BOOLEAN DEFAULT FALSE")

                # Create indexes for better performance
                cur.execute("CREATE INDEX IF NOT EXISTS idx_customers_employee_id ON customers(employee_id)")
                cur.execute("CREATE INDEX IF NOT EXISTS idx_customers_phone ON customers(phone_number)")
                cur.execute("CREATE INDEX IF NOT EXISTS idx_calls_employee_id ON calls(employee_id)")
                cur.execute("CREATE INDEX IF NOT EXISTS idx_calls_customer_phone ON calls(customer_phone_number)")
                cur.execute("CREATE INDEX IF NOT EXISTS idx_calls_start_time ON calls(start_time)")
                cur.execute("CREATE INDEX IF NOT EXISTS idx_chat_messages_customer_employee ON chat_messages(customer_phone, employee_id)")
                
                self.conn.commit()
                logger.info("Database tables initialized successfully")
                
        except Exception as e:
            logger.error(f"Failed to initialize tables: {e}")
            if self.conn:
                self.conn.rollback()
            raise
    
    def execute_query(self, query: str, params: Optional[tuple] = None) -> List[Dict[str, Any]]:
        """Execute a SELECT query and return results"""
        self.reconnect_if_needed()
        try:
            with self.conn.cursor() as cur:
                cur.execute(query, params)
                return cur.fetchall()
        except Exception as e:
            logger.error(f"Query execution failed: {e}")
            raise
    
    def execute_command(self, query: str, params: Optional[tuple] = None) -> int:
        """Execute an INSERT, UPDATE, or DELETE command"""
        self.reconnect_if_needed()
        try:
            with self.conn.cursor() as cur:
                cur.execute(query, params)
                self.conn.commit()
                return cur.rowcount
        except Exception as e:
            logger.error(f"Command execution failed: {e}")
            if self.conn:
                self.conn.rollback()
            raise

# Initialize database
db = Database()

@asynccontextmanager
async def lifespan(app: FastAPI):
    logger.info("Starting up Call Companion API")
    yield
    logger.info("Shutting down Call Companion API")
    if db.conn:
        db.conn.close()

# Initialize FastAPI app
app = FastAPI(title="Call Companion API", lifespan=lifespan)

# Add CORS middleware - Allow all origins for development
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # In production, replace with specific origins
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Initialize Firebase
firebase_cred_path = os.getenv("FIREBASE_CREDENTIALS_PATH", "call-companion.json")
storage_bucket = os.getenv("FIREBASE_STORAGE_BUCKET", "call-companion-ff585.appspot.com")

try:
    cred = credentials.Certificate(firebase_cred_path)
    firebase_admin.initialize_app(cred, {
        'storageBucket': storage_bucket
    })
    bucket = storage.bucket()
    logger.info("Firebase initialized successfully")
except Exception as e:
    logger.error(f"Firebase initialization failed: {e}")
    bucket = None

# API Configuration
WHISPER_API_URL = "https://api.openai.com/v1/audio/transcriptions"
GEMINI_API_URL = "https://generativelanguage.googleapis.com/v1beta/models/gemini-pro:generateContent"
WHISPER_API_KEY = os.getenv("WHISPER_API_KEY")
GEMINI_API_KEY = os.getenv("GEMINI_API_KEY")

# Pydantic models
class UserSignup(BaseModel):
    email: str
    name: str
    role: str = "employee"
    company_id: Optional[str] = None
    phone_number: Optional[str] = None

class UserLogin(BaseModel):
    email: str
    password: str

class CallRecord(BaseModel):
    customer_phone_number: str
    duration: int
    call_type: str = "outgoing"
    employee_id: str

# Firebase auth middleware
async def verify_firebase_token(authorization: Optional[str] = Header(None)):
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid authentication credentials",
        )
    
    token = authorization.split("Bearer ")[1]
    try:
        decoded_token = auth.verify_id_token(token)
        # Ensure user exists in our database
        user_id = decoded_token['uid']
        query = "SELECT * FROM users WHERE id = %s"
        user_result = db.execute_query(query, (user_id,))
        
        if not user_result:
            # Create user in database if not exists
            user_email = decoded_token.get('email', '')
            user_name = decoded_token.get('name', user_email.split('@')[0])
            
            insert_query = """
                INSERT INTO users (id, email, name, role) 
                VALUES (%s, %s, %s, %s)
                ON CONFLICT (id) DO NOTHING
            """
            db.execute_command(insert_query, (user_id, user_email, user_name, 'employee'))
            
        return decoded_token
    except Exception as e:
        logger.error(f"Token verification failed: {e}")
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=f"Invalid token: {str(e)}",
        )

# Helper function to get or create customer
def get_or_create_customer(phone_number: str, employee_id: str, alias: str = None) -> str:
    """Get existing customer or create new one"""
    # Check if customer exists
    query = "SELECT id FROM customers WHERE phone_number = %s AND employee_id = %s"
    result = db.execute_query(query, (phone_number, employee_id))
    
    if result:
        return result[0]['id']
    
    # Create new customer
    customer_id = str(uuid.uuid4())
    insert_query = """
        INSERT INTO customers (id, phone_number, employee_id, alias, last_call_at)
        VALUES (%s, %s, %s, %s, %s)
    """
    db.execute_command(
        insert_query, 
        (customer_id, phone_number, employee_id, alias or phone_number, datetime.now())
    )
    
    return customer_id

# Routes
@app.get("/")
async def root():
    return {"message": "Call Companion API is running with PostgreSQL"}

@app.get("/api/health")
async def health_check():
    try:
        # Test database connection
        db.execute_query("SELECT 1")
        return {
            "status": "healthy", 
            "database": "connected",
            "timestamp": datetime.now().isoformat()
        }
    except Exception as e:
        logger.error(f"Health check failed: {e}")
        raise HTTPException(status_code=500, detail=f"Database connection failed: {e}")

@app.post("/api/auth/signup")
async def signup(user_data: UserSignup):
    """Handle user signup - works with both API and Firebase auth"""
    try:
        user_id = str(uuid.uuid4())
        
        # Check if user already exists
        query = "SELECT id FROM users WHERE email = %s"
        existing_user = db.execute_query(query, (user_data.email,))
        
        if existing_user:
            raise HTTPException(status_code=400, detail="User already exists")
        
        # Insert new user
        insert_query = """
            INSERT INTO users (id, email, name, role, company_id, phone_number, recording_enabled) 
            VALUES (%s, %s, %s, %s, %s, %s, %s)
        """
        
        db.execute_command(
            insert_query,
            (user_id, user_data.email, user_data.name, user_data.role,
             user_data.company_id, user_data.phone_number, False)
        )
        
        logger.info(f"User created successfully: {user_data.email}")
        return {
            "success": True,
            "message": "User created successfully",
            "user_id": user_id
        }
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Signup failed: {e}")
        raise HTTPException(status_code=500, detail=f"Internal server error: {str(e)}")

@app.post("/api/auth/login")
async def login(login_data: UserLogin):
    """Handle user login - for API auth mode"""
    try:
        query = "SELECT * FROM users WHERE email = %s"
        user_result = db.execute_query(query, (login_data.email,))
        
        if not user_result:
            raise HTTPException(status_code=401, detail="Invalid credentials")
        
        user = user_result[0]
        
        # In a real implementation, you would verify password hash here
        # For now, we'll accept any login for existing users
        
        return {
            "success": True,
            "user": {
                "id": user['id'],
                "email": user['email'],
                "name": user['name'],
                "role": user['role'],
                "recording_enabled": user.get('recording_enabled', False)
            }
        }
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Login failed: {e}")
        raise HTTPException(status_code=500, detail=f"Internal server error: {str(e)}")

@app.get("/api/users/me")
async def get_current_user(user_token = Depends(verify_firebase_token)):
    """Get current user information"""
    try:
        user_id = user_token['uid']
        query = "SELECT * FROM users WHERE id = %s"
        user_result = db.execute_query(query, (user_id,))
        
        if not user_result:
            raise HTTPException(status_code=404, detail="User not found")
        
        user = user_result[0]
        return {
            "id": user['id'],
            "email": user['email'],
            "name": user['name'],
            "role": user['role'],
            "recording_enabled": user.get('recording_enabled', False),
            "phone_number": user.get('phone_number'),
            "company_id": user.get('company_id')
        }
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Get user failed: {e}")
        raise HTTPException(status_code=500, detail=f"Internal server error: {str(e)}")

@app.put("/api/users/recording-toggle")
async def toggle_recording(enabled: bool = Form(...), user_token = Depends(verify_firebase_token)):
    """Toggle call recording for user"""
    try:
        user_id = user_token['uid']
        
        update_query = """
            UPDATE users 
            SET recording_enabled = %s, updated_at = %s 
            WHERE id = %s
        """
        
        db.execute_command(update_query, (enabled, datetime.now(), user_id))
        
        return {
            "success": True,
            "recording_enabled": enabled,
            "message": f"Recording {'enabled' if enabled else 'disabled'}"
        }
    except Exception as e:
        logger.error(f"Toggle recording failed: {e}")
        raise HTTPException(status_code=500, detail=f"Internal server error: {str(e)}")

@app.post("/api/calls/record")
async def record_call(
    customer_phone_number: str = Form(...),
    duration: int = Form(...),
    call_type: str = Form("outgoing"),
    audio_file: Optional[UploadFile] = File(None),
    customer_alias: Optional[str] = Form(None),
    user_token = Depends(verify_firebase_token)
):
    """Record a new call and upload audio"""
    try:
        user_id = user_token['uid']
        
        # Check if user has recording enabled
        user_query = "SELECT recording_enabled FROM users WHERE id = %s"
        user_result = db.execute_query(user_query, (user_id,))
        
        if not user_result or not user_result[0].get('recording_enabled', False):
            raise HTTPException(status_code=403, detail="Call recording not enabled")
        
        # Get or create customer
        customer_id = get_or_create_customer(customer_phone_number, user_id, customer_alias)
        
        # Generate call ID and filename
        call_id = str(uuid.uuid4())
        audio_url = None
        audio_file_name = None
        audio_file_size = None
        
        # Handle audio file upload if provided
        if audio_file and bucket:
            filename = f"{call_id}.m4a"
            audio_file_name = filename
            
            # Save file temporarily
            temp_file_path = tempfile.NamedTemporaryFile(delete=False).name
            with open(temp_file_path, "wb") as buffer:
                content = await audio_file.read()
                buffer.write(content)
                audio_file_size = len(content)
            
            try:
                # Upload to Firebase Storage
                blob = bucket.blob(f"call_recordings/{user_id}/{filename}")
                blob.upload_from_filename(temp_file_path)
                blob.make_public()
                audio_url = blob.public_url
                
                logger.info(f"Audio file uploaded: {audio_url}")
            except Exception as e:
                logger.error(f"Failed to upload audio file: {e}")
                audio_url = f"local://{temp_file_path}"  # Fallback to local storage
            finally:
                # Clean up temp file if upload succeeded
                if audio_url and audio_url.startswith('http'):
                    try:
                        os.unlink(temp_file_path)
                    except:
                        pass
        
        # Create call record in PostgreSQL
        insert_query = """
            INSERT INTO calls (id, employee_id, customer_id, customer_phone_number, 
                             type, status, audio_url, audio_file_name, audio_file_size,
                             duration, start_time, end_time)
            VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
        """
        
        start_time = datetime.now()
        end_time = start_time if duration == 0 else None
        
        db.execute_command(
            insert_query,
            (call_id, user_id, customer_id, customer_phone_number,
             call_type, "recorded", audio_url, audio_file_name, audio_file_size,
             duration, start_time, end_time)
        )
        
        # Update customer's last call time
        update_customer_query = """
            UPDATE customers 
            SET last_call_at = %s, updated_at = %s 
            WHERE id = %s
        """
        db.execute_command(update_customer_query, (start_time, start_time, customer_id))
        
        logger.info(f"Call recorded successfully: {call_id}")
        
        return {
            "success": True,
            "call_id": call_id,
            "customer_id": customer_id,
            "audio_url": audio_url,
            "message": "Call recorded successfully"
        }
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Call recording failed: {e}")
        raise HTTPException(status_code=500, detail=f"Internal server error: {str(e)}")

@app.post("/api/calls/{call_id}/transcribe")
async def transcribe_call(
    call_id: str,
    user_token = Depends(verify_firebase_token)
):
    """Transcribe a call using Whisper API"""
    try:
        user_id = user_token['uid']
        
        # Get call data from PostgreSQL
        query = "SELECT * FROM calls WHERE id = %s AND employee_id = %s"
        call_result = db.execute_query(query, (call_id, user_id))
        
        if not call_result:
            raise HTTPException(status_code=404, detail="Call not found")
        
        call_data = call_result[0]
        audio_url = call_data.get("audio_url")
        
        if not audio_url:
            raise HTTPException(status_code=400, detail="Call has no audio URL")
        
        # Check if already transcribed
        if call_data.get('transcript_id'):
            transcript_query = "SELECT full_text FROM transcripts WHERE id = %s"
            transcript_result = db.execute_query(transcript_query, (call_data['transcript_id'],))
            if transcript_result:
                return {
                    "success": True,
                    "transcript_id": call_data['transcript_id'],
                    "text": transcript_result[0]['full_text'],
                    "cached": True
                }
        
        # Download audio file
        temp_file_path = None
        try:
            if audio_url.startswith('http'):
                async with httpx.AsyncClient(timeout=30.0) as client:
                    response = await client.get(audio_url)
                    if response.status_code != 200:
                        raise HTTPException(status_code=400, detail="Failed to download audio file")
                    
                    audio_content = response.content
            elif audio_url.startswith('local://'):
                local_path = audio_url.replace('local://', '')
                with open(local_path, 'rb') as f:
                    audio_content = f.read()
            else:
                raise HTTPException(status_code=400, detail="Invalid audio URL")
            
            # Save audio to temp file
            temp_file_path = tempfile.NamedTemporaryFile(delete=False, suffix=".m4a").name
            with open(temp_file_path, "wb") as f:
                f.write(audio_content)
            
            # Transcribe with Whisper API
            headers = {
                "Authorization": f"Bearer {WHISPER_API_KEY}"
            }
            
            with open(temp_file_path, "rb") as f:
                files = {
                    "file": ("audio.m4a", f, "audio/m4a")
                }
                data = {
                    "model": "whisper-1",
                    "response_format": "json",
                    "language": "en"  # You can make this configurable for Indian languages
                }
                
                async with httpx.AsyncClient(timeout=120.0) as client:
                    response = await client.post(
                        WHISPER_API_URL,
                        headers=headers,
                        files=files,
                        data=data
                    )
            
            if response.status_code != 200:
                logger.error(f"Whisper API error: {response.text}")
                raise HTTPException(
                    status_code=response.status_code,
                    detail=f"Whisper API error: {response.text}"
                )
            
            transcript_response = response.json()
            transcript_text = transcript_response.get("text", "")
            
            if not transcript_text.strip():
                raise HTTPException(status_code=400, detail="No transcript generated")
            
            # Save transcript to PostgreSQL
            transcript_id = str(uuid.uuid4())
            insert_query = """
                INSERT INTO transcripts (id, call_id, full_text, provider, language, confidence_score)
                VALUES (%s, %s, %s, %s, %s, %s)
            """
            
            db.execute_command(
                insert_query,
                (transcript_id, call_id, transcript_text, "whisper", "en", 0.95)
            )
            
            # Update call status
            update_query = """
                UPDATE calls 
                SET status = %s, transcript_id = %s, updated_at = %s
                WHERE id = %s
            """
            
            db.execute_command(
                update_query,
                ("transcribed", transcript_id, datetime.now(), call_id)
            )
            
            logger.info(f"Call transcribed successfully: {call_id}")
            
            return {
                "success": True,
                "transcript_id": transcript_id,
                "text": transcript_text
            }
            
        finally:
            # Clean up temp file
            if temp_file_path and os.path.exists(temp_file_path):
                try:
                    os.unlink(temp_file_path)
                except:
                    pass
                    
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Transcription failed: {e}")
        raise HTTPException(status_code=500, detail=f"Internal server error: {str(e)}")

@app.post("/api/calls/{call_id}/ai-summary")
async def generate_ai_summary(
    call_id: str,
    user_token = Depends(verify_firebase_token)
):
    """Generate AI summary for a call using Gemini API"""
    try:
        user_id = user_token['uid']
        
        # Get call data from PostgreSQL
        query = "SELECT * FROM calls WHERE id = %s AND employee_id = %s"
        call_result = db.execute_query(query, (call_id, user_id))
        
        if not call_result:
            raise HTTPException(status_code=404, detail="Call not found")
        
        call_data = call_result[0]
        transcript_id = call_data.get("transcript_id")
        
        if not transcript_id:
            raise HTTPException(status_code=400, detail="Call has no transcript")
        
        # Check if already summarized
        if call_data.get('summary_id'):
            summary_query = "SELECT * FROM ai_summaries WHERE id = %s"
            summary_result = db.execute_query(summary_query, (call_data['summary_id'],))
            if summary_result:
                summary = summary_result[0]
                return {
                    "success": True,
                    "summary_id": summary['id'],
                    "summary": {
                        "highlights": json.loads(summary.get('highlights', '[]')),
                        "sentiment": summary.get('sentiment', 'neutral'),
                        "nextSteps": json.loads(summary.get('next_steps', '[]'))
                    },
                    "cached": True
                }
        
        # Get transcript from PostgreSQL
        transcript_query = "SELECT * FROM transcripts WHERE id = %s"
        transcript_result = db.execute_query(transcript_query, (transcript_id,))
        
        if not transcript_result:
            raise HTTPException(status_code=404, detail="Transcript not found")
        
        transcript_data = transcript_result[0]
        transcript_text = transcript_data.get("full_text", "")
        
        if not transcript_text.strip():
            raise HTTPException(status_code=400, detail="Empty transcript")
        
        # Generate AI summary with Gemini
        prompt = f"""
        You are an AI assistant for a sales team. Analyze this call transcript and provide:
        1. Key highlights (3-5 bullet points) - focus on main discussion points, customer needs, and important details
        2. Customer sentiment (positive, negative, or neutral with brief explanation)
        3. Suggested next steps (2-3 actionable items for the salesperson)
        
        Format your response as JSON with these exact keys: highlights, sentiment, nextSteps
        
        Transcript:
        {transcript_text}
        """
        
        payload = {
            "contents": [
                {
                    "parts": [
                        {
                            "text": prompt
                        }
                    ]
                }
            ]
        }
        
        headers = {
            "Content-Type": "application/json"
        }
        
        url = f"{GEMINI_API_URL}?key={GEMINI_API_KEY}"
        
        async with httpx.AsyncClient(timeout=60.0) as client:
            response = await client.post(
                url,
                headers=headers,
                json=payload
            )
        
        if response.status_code != 200:
            logger.error(f"Gemini API error: {response.text}")
            raise HTTPException(
                status_code=response.status_code,
                detail=f"Gemini API error: {response.text}"
            )
        
        response_data = response.json()
        ai_text = response_data.get("candidates", [{}])[0].get("content", {}).get("parts", [{}])[0].get("text", "")
        
        # Parse JSON from AI response
        try:
            # Extract JSON from the response (it might be wrapped in markdown code blocks)
            if "```json" in ai_text:
                json_str = ai_text.split("```json")[1].split("```")[0].strip()
            elif "```" in ai_text:
                json_str = ai_text.split("```")[1].strip()
            else:
                json_str = ai_text
            
            summary_data = json.loads(json_str)
        except Exception as e:
            logger.error(f"Failed to parse AI response: {e}")
            # Fallback if JSON parsing fails
            summary_data = {
                "highlights": ["Call analysis completed", "Customer interaction documented"],
                "sentiment": "neutral",
                "nextSteps": ["Follow up with customer", "Review call details"]
            }
        
        # Save AI summary to PostgreSQL
        summary_id = str(uuid.uuid4())
        insert_query = """
            INSERT INTO ai_summaries (id, call_id, transcript_id, highlights, 
                                     sentiment, next_steps, raw_response)
            VALUES (%s, %s, %s, %s, %s, %s, %s)
        """
        
        db.execute_command(
            insert_query,
            (summary_id, call_id, transcript_id,
             json.dumps(summary_data.get("highlights", [])),
             summary_data.get("sentiment", "neutral"),
             json.dumps(summary_data.get("nextSteps", [])),
             ai_text)
        )
        
        # Update call status
        update_query = """
            UPDATE calls 
            SET status = %s, summary_id = %s, updated_at = %s
            WHERE id = %s
        """
        
        db.execute_command(
            update_query,
            ("summarized", summary_id, datetime.now(), call_id)
        )
        
        logger.info(f"AI summary generated successfully: {call_id}")
        
        return {
            "success": True,
            "summary_id": summary_id,
            "summary": summary_data
        }
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"AI summary generation failed: {e}")
        raise HTTPException(status_code=500, detail=f"Internal server error: {str(e)}")
    # Get call data
    call_doc = db.collection("calls").document(call_id).get()
    if not call_doc.exists:
        raise HTTPException(status_code=404, detail="Call not found")
    
    call_data = call_doc.to_dict()
    transcript_id = call_data.get("transcriptId")
    
    if not transcript_id:
        raise HTTPException(status_code=400, detail="Call has no transcript")
    
    # Get transcript
    transcript_doc = db.collection("transcripts").document(transcript_id).get()
    if not transcript_doc.exists:
        raise HTTPException(status_code=404, detail="Transcript not found")
    
    transcript_data = transcript_doc.to_dict()
    transcript_text = transcript_data.get("fullText", "")
    
    # Generate AI summary with Gemini
    prompt = f"""
    You are an AI assistant for a sales team. Analyze this call transcript and provide:
    1. Key highlights (3-5 bullet points)
    2. Customer sentiment (positive, negative, or neutral with brief explanation)
    3. Suggested next steps (2-3 actionable items)
    
    Format your response as JSON with these keys: highlights, sentiment, nextSteps
    
    Transcript:
    {transcript_text}
    """
    
    payload = {
        "contents": [
            {
                "parts": [
                    {
                        "text": prompt
                    }
                ]
            }
        ]
    }
    
    headers = {
        "Content-Type": "application/json"
    }
    
    url = f"{GEMINI_API_URL}?key={GEMINI_API_KEY}"
    
    async with httpx.AsyncClient() as client:
        response = await client.post(
            url,
            headers=headers,
            json=payload
        )
    
    if response.status_code != 200:
        raise HTTPException(
            status_code=response.status_code,
            detail=f"Gemini API error: {response.text}"
        )
    
    response_data = response.json()
    ai_text = response_data.get("candidates", [{}])[0].get("content", {}).get("parts", [{}])[0].get("text", "")
    
    # Parse JSON from AI response
    try:
        # Extract JSON from the response (it might be wrapped in markdown code blocks)
        if "```json" in ai_text:
            json_str = ai_text.split("```json")[1].split("```")[0].strip()
        elif "```" in ai_text:
            json_str = ai_text.split("```")[1].strip()
        else:
            json_str = ai_text
        
        summary_data = json.loads(json_str)
    except Exception as e:
        # Fallback if JSON parsing fails
        summary_data = {
            "highlights": ["Failed to parse highlights"],
            "sentiment": "neutral",
            "nextSteps": ["Review transcript manually"]
        }
    
    # Save AI summary to Firestore
    summary_ref = db.collection("summaries").document()
    summary_data_db = {
        "id": summary_ref.id,
        "callId": call_id,
        "transcriptId": transcript_id,
        "highlights": summary_data.get("highlights", []),
        "sentiment": summary_data.get("sentiment", "neutral"),
        "nextSteps": summary_data.get("nextSteps", []),
        "rawResponse": ai_text,
        "createdAt": firestore.SERVER_TIMESTAMP
    }
    summary_ref.set(summary_data_db)
    
    # Update call status
    db.collection("calls").document(call_id).update({
        "status": "summarized",
        "summaryId": summary_ref.id
    })
    
    return {
        "success": True,
        "summaryId": summary_ref.id,
        "summary": summary_data
    }

@app.post("/api/customers/{customer_phone}/chat-ai")
async def chat_with_ai(
    customer_phone: str,
    message: str = Form(...),
    user_token = Depends(verify_firebase_token)
):
    """Chat with AI using context from all customer calls"""
    try:
        user_id = user_token['uid']
        
        # Get all calls for this customer and employee
        calls_query = """
            SELECT c.*, s.highlights, s.sentiment, s.next_steps, s.created_at as summary_created_at
            FROM calls c
            LEFT JOIN ai_summaries s ON c.summary_id = s.id
            WHERE c.customer_phone_number = %s AND c.employee_id = %s
            ORDER BY c.start_time DESC
        """
        
        calls_result = db.execute_query(calls_query, (customer_phone, user_id))
        
        # Format context from call summaries
        context_text = ""
        if calls_result:
            context_text = "PREVIOUS CALL SUMMARIES:\n"
            for i, call in enumerate(calls_result[:5]):  # Limit to last 5 calls
                context_text += f"\nCall {i+1} ({call.get('start_time', 'Unknown date')}):\n"
                
                if call.get('highlights'):
                    highlights = json.loads(call['highlights']) if isinstance(call['highlights'], str) else call['highlights']
                    context_text += "Highlights:\n"
                    for highlight in highlights:
                        context_text += f"- {highlight}\n"
                
                if call.get('sentiment'):
                    context_text += f"Sentiment: {call['sentiment']}\n"
                
                if call.get('next_steps'):
                    next_steps = json.loads(call['next_steps']) if isinstance(call['next_steps'], str) else call['next_steps']
                    context_text += "Next Steps:\n"
                    for step in next_steps:
                        context_text += f"- {step}\n"
                context_text += "\n"
        
        # Get recent chat history
        chat_query = """
            SELECT content, is_from_user, created_at 
            FROM chat_messages 
            WHERE customer_phone = %s AND employee_id = %s 
            ORDER BY created_at DESC 
            LIMIT 10
        """
        
        chat_result = db.execute_query(chat_query, (customer_phone, user_id))
        
        chat_history = ""
        if chat_result:
            chat_history = "\nRECENT CHAT HISTORY:\n"
            for chat in reversed(chat_result):  # Reverse to get chronological order
                sender = "User" if chat['is_from_user'] else "AI"
                chat_history += f"{sender}: {chat['content']}\n"
        
        # Generate AI response with Gemini
        prompt = f"""
        You are an AI assistant for a sales team member. Use the context from previous calls and chat history to provide helpful, personalized advice.
        
        {context_text}
        {chat_history}
        
        CURRENT QUESTION: {message}
        
        Provide a helpful, concise response that:
        1. Uses the context from previous calls to give personalized advice
        2. Suggests specific next steps based on the customer's history
        3. Identifies opportunities or concerns from past interactions
        4. Is professional and sales-focused
        """
        
        payload = {
            "contents": [
                {
                    "parts": [
                        {
                            "text": prompt
                        }
                    ]
                }
            ]
        }
        
        headers = {
            "Content-Type": "application/json"
        }
        
        url = f"{GEMINI_API_URL}?key={GEMINI_API_KEY}"
        
        async with httpx.AsyncClient(timeout=60.0) as client:
            response = await client.post(
                url,
                headers=headers,
                json=payload
            )
        
        if response.status_code != 200:
            logger.error(f"Gemini API error: {response.text}")
            raise HTTPException(
                status_code=response.status_code,
                detail=f"Gemini API error: {response.text}"
            )
        
        response_data = response.json()
        ai_response = response_data.get("candidates", [{}])[0].get("content", {}).get("parts", [{}])[0].get("text", "")
        
        if not ai_response.strip():
            ai_response = "I'm sorry, I couldn't generate a response. Please try again."
        
        # Save user message to PostgreSQL
        user_message_id = str(uuid.uuid4())
        user_message_query = """
            INSERT INTO chat_messages (id, customer_phone, employee_id, content, is_from_user)
            VALUES (%s, %s, %s, %s, %s)
        """
        
        db.execute_command(
            user_message_query,
            (user_message_id, customer_phone, user_id, message, True)
        )
        
        # Save AI response to PostgreSQL
        ai_message_id = str(uuid.uuid4())
        ai_message_query = """
            INSERT INTO chat_messages (id, customer_phone, employee_id, content, is_from_user)
            VALUES (%s, %s, %s, %s, %s)
        """
        
        db.execute_command(
            ai_message_query,
            (ai_message_id, customer_phone, user_id, ai_response, False)
        )
        
        logger.info(f"AI chat response generated for customer: {customer_phone}")
        
        return {
            "success": True,
            "response": ai_response,
            "message_id": ai_message_id
        }
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Chat with AI failed: {e}")
        raise HTTPException(status_code=500, detail=f"Internal server error: {str(e)}")

# Data retrieval endpoints
@app.get("/api/customers")
async def get_customers(user_token = Depends(verify_firebase_token)):
    """Get all customers for the current employee"""
    try:
        user_id = user_token['uid']
        
        query = """
            SELECT c.*, COUNT(calls.id) as call_count, MAX(calls.start_time) as last_call
            FROM customers c
            LEFT JOIN calls ON c.id = calls.customer_id
            WHERE c.employee_id = %s
            GROUP BY c.id, c.phone_number, c.alias, c.name, c.company, c.email, c.employee_id, c.last_call_at, c.created_at, c.updated_at
            ORDER BY c.last_call_at DESC NULLS LAST
        """
        
        result = db.execute_query(query, (user_id,))
        
        customers = []
        for row in result:
            customers.append({
                "id": row['id'],
                "phone_number": row['phone_number'],
                "alias": row['alias'],
                "name": row['name'],
                "company": row['company'],
                "email": row['email'],
                "call_count": row.get('call_count', 0),
                "last_call": row.get('last_call'),
                "last_call_at": row.get('last_call_at'),
                "created_at": row.get('created_at')
            })
        
        return {
            "success": True,
            "customers": customers
        }
    except Exception as e:
        logger.error(f"Get customers failed: {e}")
        raise HTTPException(status_code=500, detail=f"Internal server error: {str(e)}")

@app.get("/api/customers/{customer_phone}/calls")
async def get_customer_calls(customer_phone: str, user_token = Depends(verify_firebase_token)):
    """Get all calls for a specific customer"""
    try:
        user_id = user_token['uid']
        
        query = """
            SELECT c.*, t.full_text as transcript, s.highlights, s.sentiment, s.next_steps
            FROM calls c
            LEFT JOIN transcripts t ON c.transcript_id = t.id
            LEFT JOIN ai_summaries s ON c.summary_id = s.id
            WHERE c.customer_phone_number = %s AND c.employee_id = %s
            ORDER BY c.start_time DESC
        """
        
        result = db.execute_query(query, (customer_phone, user_id))
        
        calls = []
        for row in result:
            call_data = {
                "id": row['id'],
                "customer_phone_number": row['customer_phone_number'],
                "type": row['type'],
                "status": row['status'],
                "duration": row['duration'],
                "start_time": row['start_time'],
                "end_time": row['end_time'],
                "audio_url": row['audio_url'],
                "created_at": row['created_at']
            }
            
            if row.get('transcript'):
                call_data['transcript'] = row['transcript']
            
            if row.get('highlights') or row.get('sentiment') or row.get('next_steps'):
                call_data['summary'] = {
                    "highlights": json.loads(row.get('highlights', '[]')) if row.get('highlights') else [],
                    "sentiment": row.get('sentiment'),
                    "next_steps": json.loads(row.get('next_steps', '[]')) if row.get('next_steps') else []
                }
            
            calls.append(call_data)
        
        return {
            "success": True,
            "calls": calls
        }
    except Exception as e:
        logger.error(f"Get customer calls failed: {e}")
        raise HTTPException(status_code=500, detail=f"Internal server error: {str(e)}")

@app.get("/api/calls/{call_id}")
async def get_call_details(call_id: str, user_token = Depends(verify_firebase_token)):
    """Get detailed information about a specific call"""
    try:
        user_id = user_token['uid']
        
        query = """
            SELECT c.*, t.full_text as transcript, t.provider, t.language, t.confidence_score,
                   s.highlights, s.sentiment, s.next_steps, s.raw_response
            FROM calls c
            LEFT JOIN transcripts t ON c.transcript_id = t.id
            LEFT JOIN ai_summaries s ON c.summary_id = s.id
            WHERE c.id = %s AND c.employee_id = %s
        """
        
        result = db.execute_query(query, (call_id, user_id))
        
        if not result:
            raise HTTPException(status_code=404, detail="Call not found")
        
        call = result[0]
        call_data = {
            "id": call['id'],
            "customer_phone_number": call['customer_phone_number'],
            "type": call['type'],
            "status": call['status'],
            "duration": call['duration'],
            "start_time": call['start_time'],
            "end_time": call['end_time'],
            "audio_url": call['audio_url'],
            "audio_file_name": call['audio_file_name'],
            "audio_file_size": call['audio_file_size'],
            "created_at": call['created_at']
        }
        
        if call.get('transcript'):
            call_data['transcript'] = {
                "text": call['transcript'],
                "provider": call.get('provider'),
                "language": call.get('language'),
                "confidence_score": call.get('confidence_score')
            }
        
        if call.get('highlights') or call.get('sentiment') or call.get('next_steps'):
            call_data['summary'] = {
                "highlights": json.loads(call.get('highlights', '[]')) if call.get('highlights') else [],
                "sentiment": call.get('sentiment'),
                "next_steps": json.loads(call.get('next_steps', '[]')) if call.get('next_steps') else [],
                "raw_response": call.get('raw_response')
            }
        
        return {
            "success": True,
            "call": call_data
        }
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Get call details failed: {e}")
        raise HTTPException(status_code=500, detail=f"Internal server error: {str(e)}")

@app.get("/api/dashboard/stats")
async def get_dashboard_stats(user_token = Depends(verify_firebase_token)):
    """Get dashboard statistics for the current user"""
    try:
        user_id = user_token['uid']
        
        # Get total calls count
        calls_count_query = "SELECT COUNT(*) as total_calls FROM calls WHERE employee_id = %s"
        calls_count_result = db.execute_query(calls_count_query, (user_id,))
        total_calls = calls_count_result[0]['total_calls'] if calls_count_result else 0
        
        # Get total customers count
        customers_count_query = "SELECT COUNT(*) as total_customers FROM customers WHERE employee_id = %s"
        customers_count_result = db.execute_query(customers_count_query, (user_id,))
        total_customers = customers_count_result[0]['total_customers'] if customers_count_result else 0
        
        # Get calls with different statuses
        status_query = """
            SELECT status, COUNT(*) as count 
            FROM calls 
            WHERE employee_id = %s 
            GROUP BY status
        """
        status_result = db.execute_query(status_query, (user_id,))
        
        status_counts = {}
        for row in status_result:
            status_counts[row['status']] = row['count']
        
        # Get recent calls
        recent_calls_query = """
            SELECT c.id, c.customer_phone_number, c.duration, c.start_time, c.status
            FROM calls c
            WHERE c.employee_id = %s
            ORDER BY c.start_time DESC
            LIMIT 5
        """
        recent_calls_result = db.execute_query(recent_calls_query, (user_id,))
        
        return {
            "success": True,
            "stats": {
                "total_calls": total_calls,
                "total_customers": total_customers,
                "status_counts": status_counts,
                "recent_calls": recent_calls_result
            }
        }
    except Exception as e:
        logger.error(f"Get dashboard stats failed: {e}")
        raise HTTPException(status_code=500, detail=f"Internal server error: {str(e)}")

if __name__ == "__main__":
    import uvicorn
    
    host = os.getenv("HOST", "0.0.0.0")
    port = int(os.getenv("PORT", 8001))
    
    logger.info(f"Starting Call Companion API server on {host}:{port}")
    uvicorn.run(app, host=host, port=port)