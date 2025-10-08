from fastapi import FastAPI, Depends, HTTPException, status, UploadFile, File, Form
from fastapi.middleware.cors import CORSMiddleware
from typing import Optional
import firebase_admin
from firebase_admin import credentials, auth
import os
import uuid
import httpx
import json
from datetime import datetime
import tempfile
from dotenv import load_dotenv

# Import our PostgreSQL database
from database import db

# Load environment variables
load_dotenv()

# Initialize FastAPI app
app = FastAPI(title="Call Companion API - PostgreSQL")

# Add CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # In production, replace with specific origins
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Initialize Firebase for authentication only
firebase_cred_path = os.getenv("FIREBASE_CREDENTIALS_PATH", "serviceAccountKey.json")

cred = credentials.Certificate(firebase_cred_path)
firebase_admin.initialize_app(cred)

# API Configuration
WHISPER_API_URL = "https://api.openai.com/v1/audio/transcriptions"
GEMINI_API_URL = "https://generativelanguage.googleapis.com/v1beta/models/gemini-pro:generateContent"
WHISPER_API_KEY = os.getenv("WHISPER_API_KEY")
GEMINI_API_KEY = os.getenv("GEMINI_API_KEY")

# Firebase auth middleware
async def verify_token(authorization: str):
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid authentication credentials",
        )
    
    token = authorization.split("Bearer ")[1]
    try:
        decoded_token = auth.verify_id_token(token)
        return decoded_token
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=f"Invalid token: {str(e)}",
        )

# Routes
@app.get("/")
async def root():
    return {"message": "Call Companion API is running with PostgreSQL"}

@app.get("/health")
async def health_check():
    try:
        # Test database connection
        db.execute_query("SELECT 1")
        return {
            "status": "healthy", 
            "database": "connected",
            "mode": "production"
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Database connection failed: {e}")

@app.post("/upload-call")
async def upload_call(
    audio_file: UploadFile = File(...),
    employee_id: str = Form(...),
    customer_id: str = Form(...),
    call_duration: int = Form(...),
    authorization: str = Depends(verify_token)
):
    # Generate unique filename
    filename = f"{uuid.uuid4()}.m4a"
    
    # Save file temporarily
    temp_file_path = tempfile.NamedTemporaryFile(delete=False).name
    with open(temp_file_path, "wb") as buffer:
        buffer.write(await audio_file.read())
    
    # TODO: Upload to cloud storage (S3, Azure Blob, etc.)
    # For now, we'll just store the file path
    audio_url = f"https://storage.example.com/call_recordings/{employee_id}/{filename}"
    
    # Clean up temp file
    os.unlink(temp_file_path)
    
    # Create call record in PostgreSQL
    call_id = str(uuid.uuid4())
    query = """
        INSERT INTO calls (id, employee_id, customer_id, customer_phone_number, 
                          type, status, audio_url, duration, start_time)
        VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s)
    """
    
    # Get customer phone number (you might need to fetch this from customers table)
    customer_phone = "+1234567890"  # Placeholder - should fetch from customers table
    
    db.execute_command(
        query, 
        (call_id, employee_id, customer_id, customer_phone, 
         "incoming", "recorded", audio_url, call_duration, datetime.now())
    )
    
    return {
        "success": True,
        "callId": call_id,
        "audioUrl": audio_url
    }

@app.post("/transcribe/{call_id}")
async def transcribe_call(
    call_id: str,
    whisper_api_key: Optional[str] = Form(None),
    authorization: str = Depends(verify_token)
):
    # Get call data from PostgreSQL
    query = "SELECT * FROM calls WHERE id = %s"
    call_result = db.execute_query(query, (call_id,))
    
    if not call_result:
        raise HTTPException(status_code=404, detail="Call not found")
    
    call_data = call_result[0]
    audio_url = call_data.get("audio_url")
    
    if not audio_url:
        raise HTTPException(status_code=400, detail="Call has no audio URL")
    
    # Download audio file
    async with httpx.AsyncClient() as client:
        response = await client.get(audio_url)
        if response.status_code != 200:
            raise HTTPException(status_code=400, detail="Failed to download audio file")
        
        audio_content = response.content
    
    # Save audio to temp file
    temp_file_path = tempfile.NamedTemporaryFile(delete=False, suffix=".m4a").name
    with open(temp_file_path, "wb") as f:
        f.write(audio_content)
    
    # Transcribe with Whisper API
    headers = {
        "Authorization": f"Bearer {whisper_api_key}"
    }
    
    with open(temp_file_path, "rb") as f:
        files = {
            "file": ("audio.m4a", f, "audio/m4a")
        }
        data = {
            "model": "whisper-1",
            "response_format": "json"
        }
        
        async with httpx.AsyncClient() as client:
            response = await client.post(
                WHISPER_API_URL,
                headers=headers,
                files=files,
                data=data
            )
    
    # Clean up temp file
    os.unlink(temp_file_path)
    
    if response.status_code != 200:
        raise HTTPException(
            status_code=response.status_code,
            detail=f"Whisper API error: {response.text}"
        )
    
    transcript_data = response.json()
    transcript_text = transcript_data.get("text", "")
    
    # Save transcript to PostgreSQL
    transcript_id = str(uuid.uuid4())
    query = """
        INSERT INTO transcripts (id, call_id, full_text, provider, language, confidence_score)
        VALUES (%s, %s, %s, %s, %s, %s)
    """
    
    db.execute_command(
        query, 
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
    
    return {
        "success": True,
        "transcriptId": transcript_id,
        "text": transcript_text
    }

@app.post("/ai-summary/{call_id}")
async def generate_ai_summary(
    call_id: str,
    authorization: str = Depends(verify_token)
):
    # Get call data from PostgreSQL
    query = "SELECT * FROM calls WHERE id = %s"
    call_result = db.execute_query(query, (call_id,))
    
    if not call_result:
        raise HTTPException(status_code=404, detail="Call not found")
    
    call_data = call_result[0]
    transcript_id = call_data.get("transcript_id")
    
    if not transcript_id:
        raise HTTPException(status_code=400, detail="Call has no transcript")
    
    # Get transcript from PostgreSQL
    transcript_query = "SELECT * FROM transcripts WHERE id = %s"
    transcript_result = db.execute_query(transcript_query, (transcript_id,))
    
    if not transcript_result:
        raise HTTPException(status_code=404, detail="Transcript not found")
    
    transcript_data = transcript_result[0]
    transcript_text = transcript_data.get("full_text", "")
    
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
    
    # Save AI summary to PostgreSQL
    summary_id = str(uuid.uuid4())
    query = """
        INSERT INTO ai_summaries (id, call_id, transcript_id, highlights, 
                                 sentiment, next_steps, raw_response)
        VALUES (%s, %s, %s, %s, %s, %s, %s)
    """
    
    db.execute_command(
        query, 
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
    
    return {
        "success": True,
        "summaryId": summary_id,
        "summary": summary_data
    }

# Additional endpoints for data retrieval
@app.get("/calls/{call_id}")
async def get_call(call_id: str, authorization: str = Depends(verify_token)):
    query = "SELECT * FROM calls WHERE id = %s"
    result = db.execute_query(query, (call_id,))
    
    if not result:
        raise HTTPException(status_code=404, detail="Call not found")
    
    return result[0]

@app.get("/transcripts/{transcript_id}")
async def get_transcript(transcript_id: str, authorization: str = Depends(verify_token)):
    query = "SELECT * FROM transcripts WHERE id = %s"
    result = db.execute_query(query, (transcript_id,))
    
    if not result:
        raise HTTPException(status_code=404, detail="Transcript not found")
    
    return result[0]

@app.get("/summaries/{summary_id}")
async def get_summary(summary_id: str, authorization: str = Depends(verify_token)):
    query = "SELECT * FROM ai_summaries WHERE id = %s"
    result = db.execute_query(query, (summary_id,))
    
    if not result:
        raise HTTPException(status_code=404, detail="Summary not found")
    
    return result[0]

@app.get("/customers/{customer_id}/calls")
async def get_customer_calls(customer_id: str, authorization: str = Depends(verify_token)):
    query = "SELECT * FROM calls WHERE customer_id = %s ORDER BY start_time DESC"
    result = db.execute_query(query, (customer_id,))
    
    return result

@app.get("/employees/{employee_id}/calls")
async def get_employee_calls(employee_id: str, authorization: str = Depends(verify_token)):
    query = "SELECT * FROM calls WHERE employee_id = %s ORDER BY start_time DESC"
    result = db.execute_query(query, (employee_id,))
    
    return result

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)