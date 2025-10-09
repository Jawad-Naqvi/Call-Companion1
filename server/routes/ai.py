from fastapi import APIRouter, HTTPException, Depends
from pydantic import BaseModel
import httpx
import logging
from collections import deque
import os
from config import settings
from auth import get_current_user, optional_current_user
from models import User

logger = logging.getLogger(__name__)
# Keep last N AI errors in memory for quick debugging
_AI_ERRORS = deque(maxlen=50)
_AI_EVENTS = deque(maxlen=50)

def _record_error(source: str, api_version: str | None, model: str | None, status: int | None, body: str | None, note: str | None = None):
    entry = {
        "source": source,
        "api_version": api_version,
        "model": model,
        "status": status,
        "body": (body or "")[:2000],
        "note": note,
    }
    _AI_ERRORS.appendleft(entry)
    logger.error(f"AI error: {entry}")

def _record_event(event: str, detail: dict | None = None):
    entry = {"event": event, "detail": detail or {}}
    _AI_EVENTS.appendleft(entry)
    logger.info(f"AI event: {entry}")
router = APIRouter(prefix="/ai", tags=["ai"])


class ChatRequest(BaseModel):
    message: str
    context: str | None = None
    temperature: float | None = 0.7
    apiKey: str | None = None


class ChatResponse(BaseModel):
    reply: str


@router.post("/chat", response_model=ChatResponse)
async def chat_with_gemini(payload: ChatRequest, _user: User | None = Depends(optional_current_user)):
    _record_event("chat_request_received", {"has_context": bool(payload.context), "message_len": len(payload.message or "")})
    # Prefer client-provided key so updating the app .env takes effect immediately,
    # but if it is invalid (e.g., referrer-restricted), we'll fall back to server env key.
    client_key = (payload.apiKey or '').strip() or None
    server_key = (settings.gemini_api_key or '').strip() or None
    # Prefer server key in dev to avoid client .env issues; fall back to client key
    api_key = server_key or client_key
    if not api_key:
        raise HTTPException(status_code=500, detail="Gemini API key is not configured")

    # Prefer env GEMINI_MODEL, fallback to modern models list
    preferred_model = os.getenv("GEMINI_MODEL")
    model_candidates = [
        preferred_model,
        # Prefer latest/free 2.0 flash models first
        "gemini-2.0-flash",
        "gemini-2.0-flash-lite",
        # Then 1.5 flash/pro models as fallbacks
        "gemini-1.5-flash-latest",
        "gemini-1.5-flash",
        "gemini-1.5-pro-latest",
        "gemini-1.5-pro",
    ]
    model_candidates = [m for m in model_candidates if m]

    prompt = payload.message if not payload.context else f"""Context:\n{payload.context}\n\nUser: {payload.message}"""

    # Trim overly long prompts to stay within free-tier limits
    if len(prompt) > 6000:
        prompt = prompt[:6000]

    data = {
        "contents": [{"parts": [{"text": prompt}]}],
        "generationConfig": {
            "temperature": min(max(payload.temperature or 0.6, 0.0), 1.0),
            "topK": 40,
            "topP": 0.95,
            "maxOutputTokens": 512,
        },
    }

    async with httpx.AsyncClient(timeout=40.0) as client:
        last_error_text = None
        # Try with client key first (if provided), then server key (if different)
        key_sequence = []
        if client_key:
            key_sequence.append(("client", client_key))
        if server_key and server_key != client_key:
            key_sequence.append(("server", server_key))

        api_versions = ["v1", "v1beta"]  # prefer GA first, then beta

        for key_label, key_value in key_sequence:
            masked = key_value[:6] + "..." if len(key_value) > 10 else "***"
            logger.info(f"Using {key_label} Gemini key: {masked}")
            for api_version in api_versions:
                for model in model_candidates:
                    url = f"https://generativelanguage.googleapis.com/{api_version}/models/{model}:generateContent?key={key_value}"
                    try:
                        resp = await client.post(url, json=data)
                    except Exception as e:
                        last_error_text = str(e)
                        _record_error(key_label, api_version, model, None, last_error_text, "exception during request")
                        continue

                    if resp.status_code == 200:
                        try:
                            d = resp.json()
                            candidates = d.get("candidates") or []
                            if candidates:
                                content = candidates[0].get("content", {})
                                parts = content.get("parts") or []
                                if parts:
                                    text = parts[0].get("text") or ""
                                    _record_event("chat_success", {"model": model, "api_version": api_version})
                                    return ChatResponse(reply=text)
                        except Exception as parse_err:
                            _record_error(key_label, api_version, model, resp.status_code, resp.text, f"parse error: {parse_err}")
                            # try next model
                            continue
                    else:
                        # If key invalid, try next key source; otherwise continue across versions/models
                        last_error_text = resp.text
                        _record_error(key_label, api_version, model, resp.status_code, resp.text, "http error")
                        if resp.status_code == 400 and 'API_KEY_INVALID' in resp.text:
                            logger.error(f"Gemini key invalid for {key_label}. Trying next key if available.")
                            # break out of version/model loops to move to next key
                            api_version = None
                            break
                        logger.error(f"Gemini error ({key_label}/{api_version}/{model}) {resp.status_code}: {resp.text}")
                        continue

    # If all models failed, return helpful guidance
    diagnostic = ""
    if last_error_text:
        diagnostic = f"\n\n[diagnostic]\n{last_error_text[:400]}"
    return ChatResponse(
        reply=(
            "I'm having trouble reaching the AI provider right now. "
            "Please verify the server AI key and quota, then try again." + diagnostic
        )
    )

@router.get("/diagnostics")
async def ai_diagnostics():
    """Return last AI errors for debugging (dev use only)."""
    if not settings.debug_ai:
        return {"message": "AI diagnostics disabled"}
    return {"recent_errors": list(_AI_ERRORS), "recent_events": list(_AI_EVENTS)}

@router.get("/ping")
async def ai_ping():
    return {"ok": True, "note": "AI router is reachable"}
