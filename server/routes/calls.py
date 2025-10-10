from fastapi import APIRouter, Depends, HTTPException, status, UploadFile, File, Form
from fastapi.responses import StreamingResponse
from sqlalchemy.orm import Session
from database import get_db
from models import CallRecord, CallStatus, User
from schemas import CallRecordResponse, MessageResponse
from auth import get_current_user
from datetime import datetime
from typing import Optional, List
import logging
import io

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/calls", tags=["calls"])

@router.post("/upload", response_model=CallRecordResponse)
async def upload_call_recording(
    user_id: str = Form(...),
    customer_number: str = Form(...),
    customer_name: Optional[str] = Form(None),
    call_type: str = Form(...),
    started_at: str = Form(...),
    ended_at: Optional[str] = Form(None),
    duration_sec: Optional[int] = Form(None),
    firebase_call_id: Optional[str] = Form(None),
    firebase_audio_url: Optional[str] = Form(None),
    audio_file: Optional[UploadFile] = File(None),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """
    Upload a call recording with metadata and audio file.
    Audio is stored in Neon database as BYTEA.
    """
    try:
        logger.info(f"[upload_call_recording] user_id={user_id}, customer={customer_number}, type={call_type}")
        
        # Parse datetime strings
        started_at_dt = datetime.fromisoformat(started_at.replace('Z', '+00:00'))
        ended_at_dt = None
        if ended_at:
            ended_at_dt = datetime.fromisoformat(ended_at.replace('Z', '+00:00'))
        
        # Read audio file if provided
        audio_bytes = None
        audio_size = None
        audio_mime = None
        if audio_file:
            audio_bytes = await audio_file.read()
            audio_size = len(audio_bytes)
            audio_mime = audio_file.content_type or 'audio/m4a'
            logger.info(f"[upload_call_recording] audio file size: {audio_size} bytes, mime: {audio_mime}")
        
        # Create call record
        call_record = CallRecord(
            user_id=user_id,
            customer_number=customer_number,
            customer_name=customer_name,
            call_type=call_type,
            status=CallStatus.COMPLETED if ended_at else CallStatus.RECORDING,
            started_at=started_at_dt,
            ended_at=ended_at_dt,
            duration_sec=duration_sec,
            audio_file_size=audio_size,
            audio_mime_type=audio_mime,
            audio_bytes=audio_bytes,
            firebase_call_id=firebase_call_id,
            firebase_audio_url=firebase_audio_url,
        )
        
        db.add(call_record)
        db.commit()
        db.refresh(call_record)
        
        logger.info(f"[upload_call_recording] saved call record id={call_record.id}")
        
        return CallRecordResponse(**call_record.to_dict(include_audio=True))
        
    except Exception as e:
        db.rollback()
        logger.exception(f"Error uploading call recording: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to upload call recording: {str(e)}"
        )

@router.get("", response_model=List[CallRecordResponse])
async def get_call_records(
    customer_number: Optional[str] = None,
    user_id: Optional[str] = None,
    limit: int = 50,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """
    Get call records filtered by customer number or user ID.
    Returns most recent calls first.
    """
    try:
        query = db.query(CallRecord).order_by(CallRecord.started_at.desc())
        
        if customer_number:
            query = query.filter(CallRecord.customer_number == customer_number)
        
        if user_id:
            query = query.filter(CallRecord.user_id == user_id)
        
        # Non-admin users can only see their own calls
        if current_user.role != "admin":
            query = query.filter(CallRecord.user_id == current_user.id)
        
        query = query.limit(limit)
        
        call_records = query.all()
        
        logger.info(f"[get_call_records] found {len(call_records)} records")
        
        return [CallRecordResponse(**record.to_dict(include_audio=True)) for record in call_records]
        
    except Exception as e:
        logger.exception(f"Error getting call records: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to get call records: {str(e)}"
        )

@router.get("/{call_id}", response_model=CallRecordResponse)
async def get_call_record(
    call_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Get a specific call record by ID."""
    try:
        call_record = db.query(CallRecord).filter(CallRecord.id == call_id).first()
        
        if not call_record:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Call record not found"
            )
        
        # Non-admin users can only see their own calls
        if current_user.role != "admin" and call_record.user_id != current_user.id:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Access denied"
            )
        
        return CallRecordResponse(**call_record.to_dict(include_audio=True))
        
    except HTTPException:
        raise
    except Exception as e:
        logger.exception(f"Error getting call record: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to get call record: {str(e)}"
        )

@router.get("/{call_id}/audio")
async def get_call_audio(
    call_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Stream the audio file for a call recording."""
    try:
        call_record = db.query(CallRecord).filter(CallRecord.id == call_id).first()
        
        if not call_record:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Call record not found"
            )
        
        # Non-admin users can only access their own calls
        if current_user.role != "admin" and call_record.user_id != current_user.id:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Access denied"
            )
        
        if not call_record.audio_bytes:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Audio file not found"
            )
        
        # Stream audio
        audio_stream = io.BytesIO(call_record.audio_bytes)
        
        return StreamingResponse(
            audio_stream,
            media_type=call_record.audio_mime_type or 'audio/m4a',
            headers={
                "Content-Disposition": f"inline; filename=call_{call_id}.m4a",
                "Content-Length": str(call_record.audio_file_size or len(call_record.audio_bytes))
            }
        )
        
    except HTTPException:
        raise
    except Exception as e:
        logger.exception(f"Error streaming call audio: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to stream audio: {str(e)}"
        )

@router.delete("/{call_id}", response_model=MessageResponse)
async def delete_call_record(
    call_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Delete a call record (admin only or own calls)."""
    try:
        call_record = db.query(CallRecord).filter(CallRecord.id == call_id).first()
        
        if not call_record:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Call record not found"
            )
        
        # Non-admin users can only delete their own calls
        if current_user.role != "admin" and call_record.user_id != current_user.id:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Access denied"
            )
        
        db.delete(call_record)
        db.commit()
        
        logger.info(f"[delete_call_record] deleted call id={call_id}")
        
        return MessageResponse(message="Call record deleted successfully")
        
    except HTTPException:
        raise
    except Exception as e:
        db.rollback()
        logger.exception(f"Error deleting call record: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to delete call record: {str(e)}"
        )
