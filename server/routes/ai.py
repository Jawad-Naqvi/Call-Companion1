from fastapi import APIRouter, HTTPException, Depends
from pydantic import BaseModel
import httpx
import logging
import os
from config import settings
from auth import get_current_user
from models import User

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/ai", tags=["ai"])


class ChatRequest(BaseModel):
    message: str
    context: str | None = None
    temperature: float | None = 0.7
    apiKey: str | None = None


class ChatResponse(BaseModel):
    reply: str


@router.post("/chat", response_model=ChatResponse)
async def chat_with_gemini(payload: ChatRequest, _: User = Depends(get_current_user)):
    # Prefer client-provided key so updating the app .env takes effect immediately,
    # but if it is invalid (e.g., referrer-restricted), we'll fall back to server env key.
    client_key = (payload.apiKey or '').strip() or None
    server_key = (settings.gemini_api_key or '').strip() or None
    api_key = client_key or server_key
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
                        logger.error(f"Gemini request failed ({key_label}/{api_version}/{model}): {e}")
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
                                    return ChatResponse(reply=text)
                        except Exception as parse_err:
                            logger.error(f"Gemini parse error ({key_label}/{api_version}/{model}): {parse_err} | body={resp.text}")
                            # try next model
                            continue
                    else:
                        # If key invalid, try next key source; otherwise continue across versions/models
                        last_error_text = resp.text
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
