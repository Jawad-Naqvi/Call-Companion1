from pydantic import BaseModel, EmailStr, field_validator
from typing import Optional, Union
from datetime import datetime
from models import UserRole

# Request schemas
class UserSignupRequest(BaseModel):
    email: EmailStr
    password: str
    name: str
    role: str  # Accept as string directly
    company_id: str

class UserLoginRequest(BaseModel):
    email: EmailStr
    password: str

class GoogleAuthSyncRequest(BaseModel):
    email: EmailStr
    name: str
    role: str  # 'admin' or 'employee'
    company_id: Optional[str] = 'default-company'
    firebase_uid: str

class UserUpdateRequest(BaseModel):
    name: Optional[str] = None
    is_active: Optional[bool] = None

# Response schemas
class UserResponse(BaseModel):
    id: str
    email: str
    name: str
    role: str
    companyId: str
    isActive: bool
    createdAt: Optional[str] = None
    updatedAt: Optional[str] = None

    class Config:
        from_attributes = True

class LoginResponse(BaseModel):
    access_token: str
    token_type: str
    user: UserResponse

class MessageResponse(BaseModel):
    message: str

class ErrorResponse(BaseModel):
    error: str
    detail: Optional[str] = None

# Call Recording schemas
class CallRecordUploadRequest(BaseModel):
    user_id: str
    customer_number: str
    customer_name: Optional[str] = None
    call_type: str  # incoming/outgoing
    started_at: str  # ISO format
    ended_at: Optional[str] = None  # ISO format
    duration_sec: Optional[int] = None
    firebase_call_id: Optional[str] = None
    firebase_audio_url: Optional[str] = None

class CallRecordResponse(BaseModel):
    id: str
    userId: str
    customerNumber: str
    customerName: Optional[str] = None
    callType: str
    status: str
    startedAt: Optional[str] = None
    endedAt: Optional[str] = None
    durationSec: Optional[int] = None
    audioFileSize: Optional[int] = None
    audioMimeType: Optional[str] = None
    firebaseCallId: Optional[str] = None
    firebaseAudioUrl: Optional[str] = None
    transcriptText: Optional[str] = None
    aiSummary: Optional[str] = None
    sentimentScore: Optional[float] = None
    notes: Optional[str] = None
    createdAt: Optional[str] = None
    updatedAt: Optional[str] = None
    hasAudio: Optional[bool] = None

    class Config:
        from_attributes = True
