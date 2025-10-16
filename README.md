# Call Companion App

> Real-time call management app for container sales teams with AI-powered transcription, summaries, and intelligent insights.

## 🎯 Overview

Call Companion is a production-ready application that automatically records customer calls, transcribes them in Indian languages, and provides AI-powered analysis. Built for sales teams who need to manage customer interactions efficiently.

### Key Features

- **🎙️ Automatic Call Recording**: Global toggle to record all calls automatically
- **🗣️ Multi-language Transcription**: Supports Hindi, English, and Hinglish using Whisper API
- **🤖 AI-Powered Analysis**: Gemini AI provides call summaries, sentiment analysis, and next steps
- **💬 Intelligent Chat**: Context-aware AI chat using all past customer interactions
- **👥 WhatsApp-style Interface**: Intuitive customer thread management
- **📊 Admin Dashboard**: Complete oversight of employee activities and call analytics
- **🔒 Enterprise Security**: Firebase authentication with role-based access
- **☁️ Production Database**: PostgreSQL (Neon) with reliable connection handling

## 🚀 Quick Start

### Prerequisites

- **Python 3.8+** (for backend)
- **Flutter SDK** (for frontend)
- **Firebase Project** (for authentication & storage)
- **Neon PostgreSQL** (for database)
- **API Keys**: Whisper (OpenAI) and Gemini (Google)

### 1. Clone Repository

```bash
git clone <repository-url>
cd call_companion
```

### 2. Backend Setup

```bash
cd backend

# Install dependencies
pip install -r requirements.txt

# Copy environment file
copy .env.example .env

# Edit .env with your configuration
notepad .env
```

**Configure your `.env` file:**

```env
# Database
NEON_CONNECTION_STRING=postgresql://username:password@host/database

# Firebase
FIREBASE_CREDENTIALS_PATH=call-companion.json
FIREBASE_STORAGE_BUCKET=your-project.appspot.com

# API Keys
WHISPER_API_KEY=sk-proj-...
GEMINI_API_KEY=AIzaSy...

# Server
HOST=0.0.0.0
PORT=8001
```

**Add Firebase Service Account Key:**

1. Download your Firebase service account key from Firebase Console
2. Save it as `call-companion.json` in the backend folder
3. Update the path in `.env` if different

### 3. Start Backend Server

**Windows:**
```cmd
start_server.bat
```

**Linux/Mac:**
```bash
python start_server.py
```

The server will start at `http://localhost:8001`

### 4. Frontend Setup

```bash
cd .. # Back to root directory

# Install Flutter dependencies
flutter pub get

# Update your API base URL in .env
echo "API_BASE_URL=http://192.168.1.24:8001/api" >> .env
```

**Note**: Replace `192.168.1.24` with your actual IP address for mobile device testing.

### 5. Run Frontend

**Web (Development):**
```bash
flutter run -d chrome
```

**Android (APK):**
```bash
flutter build apk --release
```

The APK will be available at `build/app/outputs/flutter-apk/app-release.apk`

## 📱 Usage Guide

### For Sales Employees

1. **Login** with Firebase authentication (Google Sign-In supported)
2. **Enable Recording** using the global toggle in settings
3. **Make Calls** - they'll be automatically recorded when toggle is on
4. **View Call History** in WhatsApp-style threads organized by customer
5. **Get AI Insights**:
   - Tap "AI Summary" on any call for highlights and next steps
   - Use "Chat with AI" for personalized coaching based on call history
6. **Manage Customers** - assign aliases/nicknames to phone numbers

### For Admins

1. **Login** with admin role
2. **View All Employees** and their activity
3. **Access Call Data** - recordings, transcripts, and AI summaries
4. **Monitor Performance** through dashboard analytics
5. **Review Interactions** across all customer touchpoints

## 🛠️ Technical Architecture

### Backend (FastAPI)
- **Database**: Neon PostgreSQL with automatic connection recovery
- **Authentication**: Firebase Admin SDK
- **File Storage**: Firebase Storage for call recordings
- **AI Services**: OpenAI Whisper + Google Gemini
- **CORS**: Configured for both web and mobile clients

### Frontend (Flutter)
- **Authentication**: Firebase Auth with Google Sign-In
- **State Management**: Provider pattern
- **Recording**: Native audio recording with permissions
- **Cross-platform**: Web browser + Android APK

### Database Schema
- `users` - Employee/admin accounts with recording preferences
- `customers` - Phone numbers with aliases and metadata
- `calls` - Call records with status tracking
- `transcripts` - Speech-to-text results
- `ai_summaries` - Gemini-generated insights
- `chat_messages` - AI conversation history

## 🔧 API Endpoints

### Authentication
- `POST /api/auth/signup` - Create new user account
- `POST /api/auth/login` - Login with credentials
- `GET /api/users/me` - Get current user info
- `PUT /api/users/recording-toggle` - Enable/disable recording

### Call Management
- `POST /api/calls/record` - Upload call recording
- `POST /api/calls/{id}/transcribe` - Generate transcript
- `POST /api/calls/{id}/ai-summary` - Create AI summary
- `GET /api/calls/{id}` - Get call details

### Customer & Analytics
- `GET /api/customers` - List all customers
- `GET /api/customers/{phone}/calls` - Get customer call history
- `POST /api/customers/{phone}/chat-ai` - Chat with AI about customer
- `GET /api/dashboard/stats` - Get dashboard statistics

## 🔒 Security Features

- **Firebase Authentication**: Secure token-based auth
- **Role-based Access**: Employee vs Admin permissions
- **Database Security**: PostgreSQL with connection pooling
- **File Encryption**: AES-256 for stored audio files
- **API Rate Limiting**: Built-in FastAPI protection
- **CORS Configuration**: Restricted to known origins

## 📊 Monitoring & Analytics

- **Call Success Rate**: Track recording/transcription success
- **AI Usage Metrics**: Monitor summary and chat engagement
- **Performance Tracking**: Database query optimization
- **Error Logging**: Comprehensive error tracking and recovery

## 🚨 Troubleshooting

### Common Issues

**Backend won't start:**
- Check `.env` file configuration
- Verify Firebase credentials file exists
- Test database connection string
- Ensure all required API keys are set

**Frontend authentication issues:**
- Verify Firebase configuration matches project
- Check API base URL in `.env`
- Ensure backend is running and accessible

**Call recording not working:**
- Check microphone permissions
- Verify recording toggle is enabled
- Test audio file upload to backend

**AI features not responding:**
- Verify Whisper and Gemini API keys
- Check API quota limits
- Review backend logs for API errors

### Logs & Debugging

**Backend logs:**
```bash
# View server logs
tail -f backend/logs/app.log

# Check database connections
curl http://localhost:8001/api/health
```

**Frontend debugging:**
```bash
# Run with verbose logging
flutter run --verbose

# Check API connectivity
curl -H "Authorization: Bearer <token>" http://localhost:8001/api/users/me
```

## 🔄 Deployment

### Production Checklist

- [ ] Update CORS origins to production domains
- [ ] Use HTTPS for all API endpoints
- [ ] Set up proper database backups
- [ ] Configure log rotation
- [ ] Set up monitoring and alerting
- [ ] Update Firebase security rules
- [ ] Test recording permissions on target devices
- [ ] Verify API rate limits for production load

### Environment Variables (Production)

```env
# Production database with connection pooling
NEON_CONNECTION_STRING=postgresql://user:pass@prod-db:5432/callcompanion

# Production Firebase project
FIREBASE_PROJECT_ID=callcompanion-prod
FIREBASE_STORAGE_BUCKET=callcompanion-prod.appspot.com

# Production server config
HOST=0.0.0.0
PORT=8001
LOG_LEVEL=INFO

# Production API endpoints
API_BASE_URL=https://api.yourcompany.com/api
```

## 📝 License

This project is licensed under the MIT License - see the LICENSE file for details.

## 🤝 Support

For issues and questions:
1. Check the troubleshooting guide above
2. Review backend logs for specific errors
3. Test API endpoints directly using the provided curl commands
4. Verify all environment variables are correctly set

---

**Built for sales teams who demand reliability and intelligence in their customer interactions.**

# Call Companion - AI-Powered Sales Call Management

A real-time call management app for container sales teams that records, transcribes, and analyzes customer conversations using AI.

## Deployment Guide

### Device testing (APK) and backend URL

Create a `.env` in the project root with your backend base URL so physical devices can reach it over LAN. Ensure your backend is started with host `0.0.0.0` (the provided `server/start_server.bat` already does this).

```
# Required for devices/APK. Include the /api suffix
API_BASE_URL=http://<YOUR_PC_LAN_IP>:8001/api

# Optional
GEMINI_API_KEY=...
WHISPER_API_KEY=...
NEON_CONNECTION_STRING=postgres://...
```

Commands:
```
server/start_server.bat   # starts FastAPI on 0.0.0.0:8001
flutter pub get
flutter run -d chrome     # web
flutter run -d <android>  # device uses .env API_BASE_URL
flutter build apk --release
```

## 🎯 Features

### For Employees (Salespeople)
- **Automatic Call Recording**: Global toggle to record all calls automatically
- **WhatsApp-Style Interface**: Customer threads organized by phone number
- **Real-Time Transcription**: Instant call transcription in multiple languages (Whisper API)
- **AI-Powered Summaries**: 
  - Call highlights
  - Sentiment analysis (positive/negative/neutral)
  - Suggested next steps
  - Customer concerns tracking
- **Thread-Level AI Chat**: Ask AI questions about customer history and get strategic sales advice
- **Customer Management**: Add aliases/nicknames, company info, and contact details

### For Admins (Managers)
- **Employee Management**: View all employees in your company
- **Call Review**: Access all employee calls, recordings, transcripts, and AI summaries
- **Customer Analytics**: Track customer interactions across your team
- **Performance Monitoring**: Review call quality and sales effectiveness

## 🛠 Tech Stack

### Frontend
- **Flutter**: Cross-platform mobile app framework
- **Provider**: State management
- **Material Design 3**: Modern UI with light/dark themes

### Backend Services
- **Firebase Auth**: User authentication with role-based access
- **Cloud Firestore**: Real-time database for calls, customers, and metadata
- **Firebase Storage**: Encrypted audio file storage

### AI & Transcription
- **OpenAI Whisper API**: Multi-lingual call transcription
- **Google Gemini API**: AI summaries and conversational chat
- **Deepgram** (optional): Alternative transcription provider

## 📋 Prerequisites

Before you begin, ensure you have:

1. **Flutter SDK** (3.6.0 or higher)
   ```bash
   flutter --version
   ```

2. **Firebase Project**
   - Create a project at [Firebase Console](https://console.firebase.google.com/)
   - Enable Authentication (Email/Password)
   - Enable Cloud Firestore
   - Enable Firebase Storage

3. **API Keys**
   - **OpenAI API Key**: For Whisper transcription ([Get API Key](https://platform.openai.com/api-keys))
   - **Google Gemini API Key**: For AI summaries and chat ([Get API Key](https://makersuite.google.com/app/apikey))

## 🚀 Setup Instructions

### 1. Clone the Repository

```bash
cd call_companion
```

### 2. Install Dependencies

```bash
flutter pub get
```

### 3. Configure Firebase

#### For Android:
1. Download `google-services.json` from Firebase Console
2. Place it in `android/app/`

#### For iOS:
1. Download `GoogleService-Info.plist` from Firebase Console
2. Place it in `ios/Runner/`

### 4. Configure Firestore Security Rules

In Firebase Console → Firestore Database → Rules:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // User authentication required
    function isAuthenticated() {
      return request.auth != null;
    }
    
    function isOwner(userId) {
      return isAuthenticated() && request.auth.uid == userId;
    }
    
    function isAdmin() {
      return isAuthenticated() && 
             get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'admin';
    }
    
    // Users collection
    match /users/{userId} {
      allow read: if isOwner(userId) || isAdmin();
      allow create: if isAuthenticated();
      allow update: if isOwner(userId);
    }
    
    // Customers collection
    match /customers/{customerId} {
      allow read, write: if isAuthenticated();
    }
    
    // Calls collection
    match /calls/{callId} {
      allow read: if isAuthenticated();
      allow create, update: if isAuthenticated();
      allow delete: if isOwner(resource.data.employeeId) || isAdmin();
    }
    
    // Transcripts collection
    match /transcripts/{transcriptId} {
      allow read, write: if isAuthenticated();
    }
    
    // AI Summaries collection
    match /ai_summaries/{summaryId} {
      allow read, write: if isAuthenticated();
    }
    
    // Chat Messages collection
    match /chat_messages/{messageId} {
      allow read, write: if isAuthenticated();
    }
  }
}
```

### 5. Configure Firebase Storage Rules

In Firebase Console → Storage → Rules:

```javascript
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    match /calls/{callId}/{fileName} {
      allow read: if request.auth != null;
      allow write: if request.auth != null;
    }
  }
}
```

### 6. Set Up Android Permissions

The app requires these permissions (already configured in `android/app/src/main/AndroidManifest.xml`):

```xml
<uses-permission android:name="android.permission.INTERNET"/>
<uses-permission android:name="android.permission.RECORD_AUDIO"/>
<uses-permission android:name="android.permission.READ_PHONE_STATE"/>
<uses-permission android:name="android.permission.READ_CALL_LOG"/>
```

### 7. Build and Run

```bash
# For Android
flutter run

# For iOS
flutter run -d ios

# For release build
flutter build apk --release
flutter build ios --release
```

## 📱 Usage Guide

### First Time Setup

1. **Register an Account**
   - Open the app
   - Click "Sign Up"
   - Choose role: Employee or Admin
   - Enter company ID (same for all team members)

2. **Enable Recording**
   - Toggle the recording switch ON in the dashboard
   - Grant microphone permissions when prompted

### Recording Calls

1. **Manual Recording**
   - Open the app
   - Ensure recording toggle is ON
   - Make or receive a call
   - Recording starts automatically
   - Call is saved when you hang up

2. **View Call Details**
   - Navigate to customer thread
   - Tap on any call
   - Play audio recording
   - Generate transcript (requires Whisper API key)
   - Generate AI summary (requires Gemini API key)

### Using AI Features

#### Per-Call AI Summary
1. Open call details
2. Click "Generate Transcript" (enter Whisper API key)
3. Click "Generate AI Summary" (enter Gemini API key)
4. View:
   - Call summary
   - Sentiment analysis
   - Key highlights
   - Next steps
   - Customer concerns

#### Thread-Level AI Chat
1. Open customer thread
2. Click "Chat with AI"
3. Enter Gemini API key when prompted
4. Ask questions like:
   - "What should I discuss in my next call?"
   - "Summarize this customer's main concerns"
   - "How close are we to closing the deal?"

### Admin Features

1. **View Employees**
   - Login as Admin
   - See all employees in your company

2. **Review Calls**
   - Select an employee
   - View their customer threads
   - Access all call recordings and summaries

## 🔐 Security & Privacy

- **Encryption**: All audio files are encrypted in Firebase Storage
- **Authentication**: Firebase Auth with role-based access control
- **API Keys**: Stored locally, never transmitted to backend
- **Permissions**: Granular Firestore security rules
- **Compliance**: GDPR-ready with data deletion capabilities

## 🔑 API Key Management

API keys are requested when needed and stored locally in the app session. For production:

1. **Recommended**: Implement a secure backend proxy
2. Store API keys server-side
3. Use Firebase Functions to call external APIs
4. Never hardcode API keys in the app

## 📊 Database Schema

### Collections

#### `users`
```json
{
  "id": "user_id",
  "email": "user@example.com",
  "name": "John Doe",
  "role": "employee|admin",
  "companyId": "company_id",
  "isActive": true,
  "createdAt": "timestamp",
  "updatedAt": "timestamp"
}
```

#### `customers`
```json
{
  "id": "customer_id",
  "employeeId": "user_id",
  "phoneNumber": "+1234567890",
  "name": "Jane Smith",
  "alias": "ABC Corp Contact",
  "company": "ABC Corporation",
  "email": "jane@abc.com",
  "lastContactDate": "timestamp",
  "createdAt": "timestamp",
  "updatedAt": "timestamp"
}
```

#### `calls`
```json
{
  "id": "call_id",
  "employeeId": "user_id",
  "customerId": "customer_id",
  "customerPhoneNumber": "+1234567890",
  "type": "incoming|outgoing",
  "status": "recording|completed|transcribing|analyzed",
  "startTime": "timestamp",
  "endTime": "timestamp",
  "duration": 120,
  "audioFileUrl": "https://...",
  "audioFileName": "calls/call_id/recording.m4a",
  "audioFileSize": 1024000,
  "hasTranscript": true,
  "hasAISummary": true,
  "createdAt": "timestamp",
  "updatedAt": "timestamp"
}
```

#### `transcripts`
```json
{
  "id": "transcript_id",
  "callId": "call_id",
  "employeeId": "user_id",
  "customerId": "customer_id",
  "fullText": "Transcript text...",
  "segments": [
    {
      "text": "Hello",
      "startTime": 0.0,
      "endTime": 1.5
    }
  ],
  "confidence": 0.95,
  "transcriptionProvider": "whisper",
  "createdAt": "timestamp",
  "updatedAt": "timestamp"
}
```

#### `ai_summaries`
```json
{
  "id": "summary_id",
  "callId": "call_id",
  "employeeId": "user_id",
  "customerId": "customer_id",
  "summary": "Brief call overview...",
  "keyHighlights": ["Point 1", "Point 2"],
  "sentiment": "positive|neutral|negative",
  "sentimentScore": 0.8,
  "nextSteps": ["Action 1", "Action 2"],
  "concerns": ["Concern 1"],
  "aiProvider": "gemini",
  "createdAt": "timestamp",
  "updatedAt": "timestamp"
}
```

#### `chat_messages`
```json
{
  "id": "message_id",
  "customerId": "customer_id",
  "employeeId": "user_id",
  "content": "Message text...",
  "sender": "user|ai",
  "relatedCallId": "call_id",
  "createdAt": "timestamp",
  "updatedAt": "timestamp"
}
```

## 🐛 Troubleshooting

### Firebase Initialization Error
```
Solution: Ensure google-services.json (Android) or GoogleService-Info.plist (iOS) is properly configured
```

### Recording Permission Denied
```
Solution: Go to App Settings → Permissions → Enable Microphone
```

### Transcription Failed
```
Solution: 
1. Check Whisper API key is valid
2. Ensure audio file was uploaded successfully
3. Verify internet connection
```

### AI Summary Error
```
Solution:
1. Verify Gemini API key is correct
2. Ensure transcript exists first
3. Check API quota limits
```

## 🚧 Roadmap

### Phase 1 (MVP) ✅
- [x] Firebase authentication
- [x] Call recording and storage
- [x] Per-call transcription
- [x] Per-call AI summary
- [x] Customer thread interface
- [x] Admin dashboard

### Phase 2 (Enhanced)
- [x] Thread-level AI chat
- [x] Call detail screen with audio player
- [ ] Automatic call detection
- [ ] Background recording service
- [ ] Push notifications

### Phase 3 (Future)
- [ ] Customer sentiment trends
- [ ] Deal closure prediction
- [ ] CRM integration (Salesforce, HubSpot)
- [ ] Export reports (PDF, CSV)
- [ ] Team analytics dashboard
- [ ] Voice activity detection
- [ ] Speaker diarization

## 📄 License

This project is created for educational and commercial purposes.

## 🤝 Support

For issues and questions:
1. Check the troubleshooting section
2. Review Firebase Console logs
3. Check API provider status pages

## 🙏 Acknowledgments

- **Flutter Team**: For the amazing framework
- **Firebase**: For backend infrastructure
- **OpenAI**: For Whisper transcription
- **Google**: For Gemini AI
- **DreamFlow**: For the initial project concept

---

**Built with ❤️ for sales teams who want to close more deals**
#   C a l l - C o m p a n i o n 1 
 
 
