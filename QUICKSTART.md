# Quick Start Guide - Call Companion

Get your Call Companion app up and running in 10 minutes!

## ⚡ Quick Setup

### 1. Install Flutter Dependencies
```bash
cd call_companion
flutter pub get
```

### 2. Set Up Firebase (5 minutes)

#### Create Firebase Project
1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Click "Add Project"
3. Name it "Call Companion" and follow the wizard

#### Enable Services
In your Firebase project:
- **Authentication** → Get Started → Enable "Email/Password"
- **Firestore Database** → Create Database → Start in test mode
- **Storage** → Get Started → Start in test mode

#### Download Config Files

**For Android:**
1. Project Settings → Add App → Android
2. Package name: `com.example.call_companion`
3. Download `google-services.json`
4. Place in: `android/app/google-services.json`

**For iOS:**
1. Project Settings → Add App → iOS
2. Bundle ID: `com.example.callCompanion`
3. Download `GoogleService-Info.plist`
4. Place in: `ios/Runner/GoogleService-Info.plist`

### 3. Get API Keys (2 minutes)

#### OpenAI Whisper API Key
1. Visit [OpenAI Platform](https://platform.openai.com/api-keys)
2. Sign up/Login
3. Click "Create new secret key"
4. Copy the key (starts with `sk-...`)

#### Google Gemini API Key
1. Visit [Google AI Studio](https://makersuite.google.com/app/apikey)
2. Sign in with Google
3. Click "Create API Key"
4. Copy the key

### 4. Run the App
```bash
# Connect your Android device or start emulator
flutter run

# Or for iOS
flutter run -d ios
```

## 🎯 First Time Usage

### Step 1: Register Account
1. Open the app
2. Tap "Sign Up"
3. Enter:
   - **Email**: your@email.com
   - **Password**: (min 6 characters)
   - **Name**: Your Name
   - **Role**: Employee (for testing)
   - **Company ID**: test-company

### Step 2: Configure API Keys
1. Tap the ⚙️ Settings icon
2. Enter your **Whisper API Key**
3. Enter your **Gemini API Key**
4. Enable **Auto-Transcribe Calls**
5. Enable **Auto-Generate AI Summary**
6. Tap Save ✓

### Step 3: Record Your First Call
1. Go back to dashboard
2. Tap "Start Recording"
3. Enter a test phone number: `+1234567890`
4. Speak for 10-15 seconds
5. Tap "Stop Recording"
6. Wait for automatic processing

### Step 4: View Results
1. Tap on the customer card
2. Tap on the call
3. See:
   - ▶️ Audio playback
   - 📝 Transcript
   - 🤖 AI Summary with sentiment

### Step 5: Try AI Chat
1. Go back to customer thread
2. Tap "Chat with AI"
3. Ask: "What did we discuss in this call?"
4. Get AI-powered insights!

## 🔧 Troubleshooting

### "Firebase initialization error"
**Solution**: Make sure `google-services.json` (Android) or `GoogleService-Info.plist` (iOS) is in the correct location.

### "Microphone permission denied"
**Solution**: 
- Android: Settings → Apps → Call Companion → Permissions → Microphone → Allow
- iOS: Settings → Call Companion → Microphone → Enable

### "Transcription failed"
**Solution**:
1. Check your Whisper API key is correct
2. Verify you have API credits
3. Check internet connection

### "AI Summary error"
**Solution**:
1. Verify Gemini API key
2. Ensure transcript was generated first
3. Check API quota limits

## 📱 Testing Admin Features

### Create Admin Account
1. Sign out
2. Sign up with:
   - **Role**: Admin
   - **Company ID**: test-company (same as employee)

### View Employee Data
1. Login as admin
2. See list of employees
3. Tap on employee
4. View their customer threads
5. Access all call recordings and summaries

## 🎨 Features to Test

- [x] Call recording with phone number
- [x] Automatic transcription
- [x] AI summary generation
- [x] Sentiment analysis
- [x] Customer thread management
- [x] Customer alias/nickname
- [x] AI chat for sales insights
- [x] Audio playback
- [x] Admin dashboard
- [x] Employee management

## 📊 Sample Test Scenario

### Scenario: Container Sales Call

1. **Start Recording** with phone: `+1-555-CONTAINER`
2. **Speak**: 
   > "Hi, this is John from ABC Containers. I'm calling about your inquiry for 20-foot shipping containers. We have them available at $3,000 each. The customer mentioned they need delivery by next month and are concerned about the condition. I assured them all containers are inspected and certified. Next steps: Send quote by email and schedule site visit."

3. **Stop Recording**
4. **Wait 30 seconds** for processing
5. **View Results**:
   - Transcript of your speech
   - AI Summary with key points
   - Sentiment: Positive
   - Next Steps identified
   - Concerns noted

6. **Chat with AI**:
   - "What are the customer's main concerns?"
   - "What should I prepare for the next call?"
   - "Summarize the pricing discussion"

## 🚀 Next Steps

### For Production Use

1. **Update Firestore Rules** (see README.md)
2. **Update Storage Rules** (see README.md)
3. **Set up proper API key management**
4. **Configure app signing** for release
5. **Test on real devices**
6. **Add your company branding**

### Recommended Improvements

- Set up Firebase Cloud Functions for server-side processing
- Implement proper API key encryption
- Add analytics tracking
- Set up crash reporting
- Configure push notifications
- Add data export features

## 💡 Tips

- **Save API Keys**: They're stored locally and persist between sessions
- **Auto-Processing**: Enable in settings to automatically transcribe and summarize all calls
- **Customer Aliases**: Add nicknames to customers for easy identification
- **Call History**: All calls are organized by customer in WhatsApp-style threads
- **Admin Access**: Admins can review all employee calls for quality assurance

## 📞 Support

If you encounter issues:
1. Check the troubleshooting section
2. Review Firebase Console for errors
3. Check API provider status pages
4. Verify all permissions are granted

## 🎉 You're Ready!

Your Call Companion app is now fully functional. Start recording calls, get AI-powered insights, and close more deals!

---

**Happy Selling! 🚀**
