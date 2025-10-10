from sqlalchemy import Column, Integer, String, DateTime, Boolean, Text, ForeignKey, LargeBinary, Float
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func
from database import Base
from enum import Enum
from uuid import uuid4

class UserRole(str, Enum):
    EMPLOYEE = "employee"
    ADMIN = "admin"

class CallType(str, Enum):
    INCOMING = "incoming"
    OUTGOING = "outgoing"

class CallStatus(str, Enum):
    RECORDING = "recording"
    COMPLETED = "completed"
    TRANSCRIBING = "transcribing"
    ANALYZED = "analyzed"
    FAILED = "failed"

class User(Base):
    __tablename__ = "users"

    id = Column(String(36), primary_key=True, index=True, default=lambda: str(uuid4()))
    email = Column(String(255), unique=True, index=True, nullable=False)
    hashed_password = Column(String(255), nullable=False)
    name = Column(String(255), nullable=False)
    role = Column(String(50), nullable=False, default=UserRole.EMPLOYEE)
    company_id = Column(String(255), nullable=False)
    is_active = Column(Boolean, default=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())

    def to_dict(self):
        return {
            "id": str(self.id),
            "email": self.email,
            "name": self.name,
            "role": self.role,
            "companyId": self.company_id,
            "isActive": self.is_active,
            "createdAt": self.created_at.isoformat() if self.created_at else None,
            "updatedAt": self.updated_at.isoformat() if self.updated_at else None,
        }

class Company(Base):
    __tablename__ = "companies"

    id = Column(String(255), primary_key=True, index=True)
    name = Column(String(255), nullable=False)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())

    def to_dict(self):
        return {
            "id": self.id,
            "name": self.name,
            "createdAt": self.created_at.isoformat() if self.created_at else None,
            "updatedAt": self.updated_at.isoformat() if self.updated_at else None,
        }

class CallRecord(Base):
    __tablename__ = "call_records"

    id = Column(String(36), primary_key=True, index=True, default=lambda: str(uuid4()))
    user_id = Column(String(36), ForeignKey('users.id'), nullable=False, index=True)
    customer_number = Column(String(50), nullable=False, index=True)
    customer_name = Column(String(255), nullable=True)
    call_type = Column(String(20), nullable=False)  # incoming/outgoing
    status = Column(String(20), nullable=False, default=CallStatus.RECORDING)
    started_at = Column(DateTime(timezone=True), nullable=False)
    ended_at = Column(DateTime(timezone=True), nullable=True)
    duration_sec = Column(Integer, nullable=True)
    
    # Audio file metadata
    audio_file_size = Column(Integer, nullable=True)
    audio_mime_type = Column(String(50), nullable=True, default='audio/m4a')
    audio_bytes = Column(LargeBinary, nullable=True)  # Store audio in DB
    
    # Firebase reference (for backward compatibility)
    firebase_call_id = Column(String(255), nullable=True, index=True)
    firebase_audio_url = Column(Text, nullable=True)
    
    # Transcription and analysis
    transcript_text = Column(Text, nullable=True)
    ai_summary = Column(Text, nullable=True)
    sentiment_score = Column(Float, nullable=True)
    
    # Additional metadata
    notes = Column(Text, nullable=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())

    # Relationship
    user = relationship("User", backref="call_records")

    def to_dict(self, include_audio=False):
        result = {
            "id": str(self.id),
            "userId": str(self.user_id),
            "customerNumber": self.customer_number,
            "customerName": self.customer_name,
            "callType": self.call_type,
            "status": self.status,
            "startedAt": self.started_at.isoformat() if self.started_at else None,
            "endedAt": self.ended_at.isoformat() if self.ended_at else None,
            "durationSec": self.duration_sec,
            "audioFileSize": self.audio_file_size,
            "audioMimeType": self.audio_mime_type,
            "firebaseCallId": self.firebase_call_id,
            "firebaseAudioUrl": self.firebase_audio_url,
            "transcriptText": self.transcript_text,
            "aiSummary": self.ai_summary,
            "sentimentScore": self.sentiment_score,
            "notes": self.notes,
            "createdAt": self.created_at.isoformat() if self.created_at else None,
            "updatedAt": self.updated_at.isoformat() if self.updated_at else None,
        }
        if include_audio and self.audio_bytes:
            result["hasAudio"] = True
        return result
