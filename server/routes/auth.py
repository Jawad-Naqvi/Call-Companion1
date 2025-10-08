from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from sqlalchemy.exc import IntegrityError
from database import get_db
from models import User, UserRole
from schemas import UserSignupRequest, UserLoginRequest, UserResponse, LoginResponse, MessageResponse, ErrorResponse
from auth import authenticate_user, create_access_token, get_password_hash, get_current_user, get_current_admin_user
import logging

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/auth", tags=["authentication"])

@router.post("/signup", response_model=LoginResponse)
async def signup(user_data: UserSignupRequest, db: Session = Depends(get_db)):
    """Register a new user."""
    try:
        # Normalize inputs
        email_norm = user_data.email.strip().lower()
        name_norm = user_data.name.strip()
        company_norm = (user_data.company_id or "").strip() or "default-company"
        logger.info(f"[signup] start email={email_norm} role={user_data.role} company_id={company_norm}")

        # Check if user already exists
        from sqlalchemy import func
        existing_user = (
            db.query(User)
            .filter(func.trim(func.lower(User.email)) == email_norm)
            .first()
        )
        if existing_user:
            logger.info(f"[signup] email already exists (normalized): {email_norm}")
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail="User with this email already exists"
            )
        
        # Create new user
        logger.info("[signup] hashing password")
        hashed_password = get_password_hash(user_data.password)

        logger.info("[signup] creating user model")
        # Ensure role is a valid string
        role_str = str(user_data.role).lower()
        if role_str not in ['employee', 'admin']:
            role_str = 'employee'  # Default to employee
            
        db_user = User(
            email=email_norm,
            hashed_password=hashed_password,
            name=name_norm,
            role=role_str,
            company_id=company_norm,
            is_active=True
        )
        
        logger.info("[signup] saving user")
        db.add(db_user)
        db.commit()
        db.refresh(db_user)
        logger.info(f"[signup] user saved id={db_user.id}")
        
        # Create access token
        access_token = create_access_token(data={"sub": str(db_user.id)})
        logger.info("[signup] token created")
        
        # Build response explicitly to avoid serialization pitfalls
        user_resp = UserResponse(
            id=str(db_user.id),
            email=db_user.email,
            name=db_user.name,
            role=str(db_user.role),
            companyId=db_user.company_id,
            isActive=bool(db_user.is_active),
            createdAt=db_user.created_at.isoformat() if getattr(db_user, "created_at", None) else None,
            updatedAt=db_user.updated_at.isoformat() if getattr(db_user, "updated_at", None) else None,
        )

        logger.info(f"New user registered: {user_data.email} ({user_resp.role})")
        
        return LoginResponse(
            access_token=access_token,
            token_type="bearer",
            user=user_resp
        )
        
    except IntegrityError as e:
        db.rollback()
        # Map only UNIQUE(email) violations to 409; otherwise surface as 500
        msg = str(e.orig) if hasattr(e, "orig") else str(e)
        logger.error(f"Database integrity error during signup: {msg}")
        if "unique" in msg.lower() and "email" in msg.lower():
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail="User with this email already exists"
            )
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Internal server error during signup: {msg}"
        )
    except HTTPException:
        # Let HTTPException pass through
        raise
    except Exception as e:
        db.rollback()
        logger.exception(f"Signup error: {e}")
        # Expose error detail in development to aid debugging
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Internal server error during signup: {e}"
        )

@router.post("/login", response_model=LoginResponse)
async def login(user_data: UserLoginRequest, db: Session = Depends(get_db)):
    """Authenticate and login a user."""
    try:
        # Authenticate user
        user = authenticate_user(db, user_data.email, user_data.password)
        if not user:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid email or password"
            )
        
        if not user.is_active:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Account is deactivated"
            )
        
        # Create access token
        access_token = create_access_token(data={"sub": str(user.id)})
        
        logger.info(f"User logged in: {user.email}")
        
        return LoginResponse(
            access_token=access_token,
            token_type="bearer",
            user=UserResponse(**user.to_dict())
        )
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Login error: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Internal server error during login"
        )

@router.get("/me", response_model=UserResponse)
async def get_current_user_info(current_user: User = Depends(get_current_user)):
    """Get current authenticated user information."""
    return UserResponse(**current_user.to_dict())

@router.post("/logout", response_model=MessageResponse)
async def logout():
    """Logout user (client should remove token)."""
    return MessageResponse(message="Successfully logged out")

@router.get("/employees", response_model=list[UserResponse])
async def get_company_employees(
    company_id: str | None = None,
    current_user: User = Depends(get_current_admin_user),
    db: Session = Depends(get_db)
):
    """Get all employees for a company (admin only)."""
    try:
        # Admin-only access is already enforced by dependency `get_current_admin_user`.
        # If company_id is omitted, return all employees; otherwise filter by company.
        from sqlalchemy import func
        q = db.query(User).filter(
            func.lower(User.role) == 'employee',
            User.is_active == True
        )
        if company_id:
            q = q.filter(User.company_id == company_id)
        employees = q.all()
        
        logger.info(f"Admin {current_user.email} retrieved {len(employees)} employees for company {company_id or 'ALL'}")
        
        return [UserResponse(**employee.to_dict()) for employee in employees]
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error retrieving employees: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Internal server error while retrieving employees"
        )
