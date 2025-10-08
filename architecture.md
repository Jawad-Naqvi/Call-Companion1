# Call Companion App Architecture

## Overview
A real-time call management app for container sales teams with recording, transcription, AI analysis, and WhatsApp-style interface.

## Core Features
- **Employee Role**: Record calls, view transcripts, AI summaries, thread-level AI chat
- **Admin Role**: Review all employee data, calls, and analytics
- **Real-time transcription** in Indian languages (Whisper API)
- **AI-powered insights** using Gemini API
- **WhatsApp-style interface** for customer threads

## Technical Architecture

### Frontend (Flutter)
- **Authentication**: Firebase Auth with role-based access
- **UI Pattern**: WhatsApp-style chat threads
- **Recording**: Local audio recording with auto-upload
- **Storage**: Firebase Storage for audio files
- **State Management**: Provider pattern

### Backend Services
- **Database**: Firebase Firestore
- **Authentication**: Firebase Auth
- **Storage**: Firebase Storage (encrypted audio)
- **Transcription**: Whisper API integration
- **AI**: Gemini API for summaries and chat

### Data Models
1. **User**: Employee/Admin profiles with roles
2. **Customer**: Contact info with aliases
3. **Call**: Recording metadata and relationships
4. **Transcript**: Auto-generated call transcripts
5. **AISummary**: Call highlights, sentiment, next steps
6. **ChatMessage**: Thread-level AI conversations

### Key Services
1. **AuthService**: Firebase authentication and role management
2. **CallService**: Recording, upload, and metadata management
3. **TranscriptionService**: Whisper API integration
4. **AIService**: Gemini API for summaries and chat
5. **CustomerService**: Contact management with aliases
6. **AnalyticsService**: Admin dashboard data

### UI Structure
```
├── Authentication (Login/Register)
├── Employee Dashboard
│   ├── Recording Toggle
│   ├── Customer Threads (WhatsApp-style)
│   └── Individual Call Views
├── Admin Dashboard
│   ├── Employee Management
│   ├── Customer Analytics
│   └── Call Review Interface
└── AI Chat Interface
```

### Implementation Priority
**Phase 1 (MVP)**:
1. Firebase Auth setup with roles
2. Call recording and storage
3. Basic transcription integration
4. Simple AI summary generation
5. Customer thread interface

**Phase 2 (Enhanced)**:
1. Thread-level AI chat
2. Admin dashboard
3. Advanced analytics
4. Sentiment analysis
5. Performance optimization

## Security & Compliance
- Audio file encryption (AES-256)
- Role-based access control
- Firebase security rules
- GDPR compliance features