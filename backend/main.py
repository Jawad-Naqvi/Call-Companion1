from fastapi import FastAPI, Depends, HTTPException, status, UploadFile, File, Form
from fastapi.middleware.cors import CORSMiddleware
from typing import Optional
import firebase_admin
from firebase_admin import credentials, auth, firestore, storage
import os
import uuid
import httpx
import json
from datetime import datetime
import tempfile
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

# Initialize FastAPI app
app = FastAPI(title="Call Companion API")

# Add CORS middleware
frontend_origin = os.getenv("FRONTEND_ORIGIN", "http://localhost")
app.add_middleware(
    CORSMiddleware,
    allow_origins=[frontend_origin],
    allow_credentials=True,
    allow_methods=["GET", "POST", "PUT", "DELETE", "OPTIONS"],
    allow_headers=["*"],
)

# Initialize Firebase
firebase_cred_path = os.getenv("FIREBASE_CREDENTIALS_PATH", "serviceAccountKey.json")
storage_bucket = os.getenv("STORAGE_BUCKET", "call-companion-dev.appspot.com")

cred = credentials.Certificate(firebase_cred_path)
firebase_admin.initialize_app(cred, {
    'storageBucket': storage_bucket
})
db = firestore.client()
bucket = storage.bucket()

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
    return {"message": "Call Companion API is running"}

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
    
    # Upload to Firebase Storage
    blob = bucket.blob(f"call_recordings/{employee_id}/{filename}")
    blob.upload_from_filename(temp_file_path)
    blob.make_public()
    
    # Clean up temp file
    os.unlink(temp_file_path)
    
    # Create call record in Firestore
    call_ref = db.collection("calls").document()
    call_data = {
        "id": call_ref.id,
        "employeeId": employee_id,
        "customerId": customer_id,
        "audioUrl": blob.public_url,
        "duration": call_duration,
        "startTime": firestore.SERVER_TIMESTAMP,
        "status": "recorded",
    }
    call_ref.set(call_data)
    
    return {
        "success": True,
        "callId": call_ref.id,
        "audioUrl": blob.public_url
    }

@app.post("/transcribe/{call_id}")
async def transcribe_call(
    call_id: str,
    whisper_api_key: Optional[str] = Form(None),
    authorization: str = Depends(verify_token)
):
    # Get call data
    call_doc = db.collection("calls").document(call_id).get()
    if not call_doc.exists:
        raise HTTPException(status_code=404, detail="Call not found")
    
    call_data = call_doc.to_dict()
    audio_url = call_data.get("audioUrl")
    
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
    
    # Save transcript to Firestore
    transcript_ref = db.collection("transcripts").document()
    transcript_data = {
        "id": transcript_ref.id,
        "callId": call_id,
        "fullText": transcript_text,
        "createdAt": firestore.SERVER_TIMESTAMP
    }
    transcript_ref.set(transcript_data)
    
    # Update call status
    db.collection("calls").document(call_id).update({
        "status": "transcribed",
        "transcriptId": transcript_ref.id
    })
    
    return {
        "success": True,
        "transcriptId": transcript_ref.id,
        "text": transcript_text
    }

@app.post("/ai-summary/{call_id}")
async def generate_ai_summary(
    call_id: str,
    authorization: str = Depends(verify_token)
):
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

@app.post("/chat-ai/{customer_id}")
async def chat_with_ai(
    customer_id: str,
    message: str = Form(...),
    employee_id: str = Form(...),
    authorization: str = Depends(verify_token)
):
    # Get all call summaries for this customer
    calls = db.collection("calls").where("customerId", "==", customer_id).stream()
    call_ids = [call.id for call in calls]
    
    context = []
    
    # Get summaries for these calls
    for call_id in call_ids:
        summaries = db.collection("summaries").where("callId", "==", call_id).stream()
        for summary in summaries:
            summary_data = summary.to_dict()
            context.append({
                "date": summary_data.get("createdAt", datetime.now()),
                "highlights": summary_data.get("highlights", []),
                "sentiment": summary_data.get("sentiment", "neutral"),
                "nextSteps": summary_data.get("nextSteps", [])
            })
    
    # Sort context by date
    context.sort(key=lambda x: x["date"])
    
    # Format context for prompt
    context_text = ""
    for i, ctx in enumerate(context):
        context_text += f"Call {i+1}:\n"
        context_text += "Highlights:\n"
        for highlight in ctx["highlights"]:
            context_text += f"- {highlight}\n"
        context_text += f"Sentiment: {ctx['sentiment']}\n"
        context_text += "Next Steps:\n"
        for step in ctx["nextSteps"]:
            context_text += f"- {step}\n"
        context_text += "\n"
    
    # Get chat history
    chat_messages = db.collection("chat_messages").where("customerId", "==", customer_id).where("employeeId", "==", employee_id).order_by("createdAt").stream()
    
    chat_history = ""
    for chat in chat_messages:
        chat_data = chat.to_dict()
        sender = "User" if chat_data.get("isFromUser", False) else "AI"
        chat_history += f"{sender}: {chat_data.get('content', '')}\n"
    
    # Generate AI response with Gemini
    prompt = f"""
    You are an AI assistant for a sales team member talking to a customer. Use the following context from previous calls with this customer to provide helpful insights and advice.
    
    PREVIOUS CALL SUMMARIES:
    {context_text}
    
    RECENT CHAT HISTORY:
    {chat_history}
    
    USER QUESTION: {message}
    
    Provide a helpful, concise response that uses the context from previous calls to give personalized advice.
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
    ai_response = response_data.get("candidates", [{}])[0].get("content", {}).get("parts", [{}])[0].get("text", "")
    
    # Save user message to Firestore
    user_message_ref = db.collection("chat_messages").document()
    user_message_data = {
        "id": user_message_ref.id,
        "customerId": customer_id,
        "employeeId": employee_id,
        "content": message,
        "isFromUser": True,
        "createdAt": firestore.SERVER_TIMESTAMP
    }
    user_message_ref.set(user_message_data)
    
    # Save AI response to Firestore
    ai_message_ref = db.collection("chat_messages").document()
    ai_message_data = {
        "id": ai_message_ref.id,
        "customerId": customer_id,
        "employeeId": employee_id,
        "content": ai_response,
        "isFromUser": False,
        "createdAt": firestore.SERVER_TIMESTAMP
    }
    ai_message_ref.set(ai_message_data)
    
    return {
        "success": True,
        "response": ai_response
    }

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)