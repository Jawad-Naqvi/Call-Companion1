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
