# Setup Checklist - Call Companion

Use this checklist to ensure your app is properly configured before deployment.

## ✅ Pre-Development Setup

### Flutter Environment
- [ ] Flutter SDK installed (3.6.0+)
- [ ] Android Studio / Xcode installed
- [ ] Flutter doctor shows no issues
- [ ] Device/emulator connected

### Firebase Project
- [ ] Firebase project created
- [ ] Project name: `Call Companion`
- [ ] Billing enabled (for API usage)
- [ ] Project ID noted down

## ✅ Firebase Configuration

### Authentication
- [ ] Firebase Authentication enabled
- [ ] Email/Password provider enabled
- [ ] Test user created

### Firestore Database
- [ ] Firestore Database created
- [ ] Started in test mode (initially)
- [ ] Security rules updated (see README.md)
- [ ] Indexes created (if needed)

### Firebase Storage
- [ ] Storage enabled
- [ ] Started in test mode (initially)
- [ ] Security rules updated (see README.md)
- [ ] CORS configured (if needed)

### Firebase Config Files
- [ ] `google-services.json` downloaded (Android)
- [ ] `google-services.json` placed in `android/app/`
- [ ] `GoogleService-Info.plist` downloaded (iOS)
- [ ] `GoogleService-Info.plist` placed in `ios/Runner/`

## ✅ API Keys

### OpenAI Whisper
- [ ] OpenAI account created
- [ ] API key generated
- [ ] API key tested
- [ ] Billing/credits configured
- [ ] Usage limits understood

### Google Gemini
- [ ] Google AI Studio account created
- [ ] Gemini API key generated
- [ ] API key tested
- [ ] Quota limits understood

## ✅ App Configuration

### Android
- [ ] Package name verified: `com.example.call_companion`
- [ ] Minimum SDK: 21
- [ ] Permissions added to AndroidManifest.xml:
  - [ ] INTERNET
  - [ ] RECORD_AUDIO
  - [ ] READ_PHONE_STATE (optional)
  - [ ] READ_CALL_LOG (optional)
- [ ] Firebase dependencies added to build.gradle
- [ ] App signing configured (for release)

### iOS
- [ ] Bundle ID verified: `com.example.callCompanion`
- [ ] Minimum iOS: 12.0
- [ ] Permissions added to Info.plist:
  - [ ] NSMicrophoneUsageDescription
  - [ ] NSPhotoLibraryUsageDescription (if needed)
- [ ] Firebase dependencies added
- [ ] App signing configured (for release)

## ✅ Dependencies

### Installed Packages
- [ ] `flutter pub get` executed successfully
- [ ] No version conflicts
- [ ] All packages compatible with Flutter version

### Key Packages Verified
- [ ] firebase_core
- [ ] firebase_auth
- [ ] cloud_firestore
- [ ] firebase_storage
- [ ] provider
- [ ] record
- [ ] audioplayers
- [ ] http
- [ ] shared_preferences
- [ ] permission_handler

## ✅ Build & Run

### Development Build
- [ ] App builds without errors (Android)
- [ ] App builds without errors (iOS)
- [ ] App runs on emulator/simulator
- [ ] App runs on physical device
- [ ] Hot reload works

### Firebase Connection
- [ ] Firebase initializes successfully
- [ ] No Firebase errors in console
- [ ] Can create user account
- [ ] Can sign in/out
- [ ] Firestore writes work
- [ ] Storage uploads work

## ✅ Feature Testing

### Authentication
- [ ] Sign up works
- [ ] Login works
- [ ] Logout works
- [ ] Role selection works (Employee/Admin)
- [ ] Company ID grouping works

### Recording
- [ ] Microphone permission requested
- [ ] Can start recording
- [ ] Recording indicator shows
- [ ] Can stop recording
- [ ] Audio file uploads to Storage
- [ ] Call metadata saves to Firestore

### Transcription
- [ ] Settings screen accessible
- [ ] Can save Whisper API key
- [ ] Manual transcription works
- [ ] Auto-transcription works (if enabled)
- [ ] Transcript displays correctly
- [ ] Confidence score shows

### AI Features
- [ ] Can save Gemini API key
- [ ] Manual AI summary works
- [ ] Auto-summary works (if enabled)
- [ ] Summary displays correctly
- [ ] Sentiment analysis shows
- [ ] AI chat works
- [ ] Chat history persists

### Customer Management
- [ ] Customer auto-created from phone number
- [ ] Customer list displays
- [ ] Can edit customer info
- [ ] Can add alias/nickname
- [ ] Search works
- [ ] Thread view works

### Call Details
- [ ] Can navigate to call details
- [ ] Audio player works
- [ ] Play/pause works
- [ ] Progress bar works
- [ ] Transcript shows
- [ ] AI summary shows

### Admin Features
- [ ] Admin can login
- [ ] Employee list shows
- [ ] Can view employee details
- [ ] Can view employee's customers
- [ ] Can view employee's calls
- [ ] Can play recordings
- [ ] Can view transcripts/summaries

## ✅ UI/UX

### Visual Design
- [ ] Light theme works
- [ ] Dark theme works
- [ ] Colors consistent
- [ ] Fonts readable
- [ ] Icons display correctly
- [ ] Animations smooth

### User Experience
- [ ] Navigation intuitive
- [ ] Loading states show
- [ ] Error messages clear
- [ ] Success feedback shows
- [ ] Empty states helpful
- [ ] Back button works

### Responsive Design
- [ ] Works on small phones
- [ ] Works on large phones
- [ ] Works on tablets
- [ ] Landscape mode works
- [ ] Text scales properly

## ✅ Performance

### App Performance
- [ ] App starts quickly
- [ ] Screens load fast
- [ ] No lag in UI
- [ ] Smooth scrolling
- [ ] No memory leaks
- [ ] Battery usage acceptable

### Data Performance
- [ ] Queries are fast
- [ ] Images load quickly
- [ ] Audio streams smoothly
- [ ] No unnecessary network calls
- [ ] Offline handling graceful

## ✅ Security

### Firebase Security
- [ ] Firestore rules updated
- [ ] Storage rules updated
- [ ] Auth rules configured
- [ ] Test rules with Firebase emulator

### App Security
- [ ] API keys not hardcoded
- [ ] Sensitive data encrypted
- [ ] HTTPS only
- [ ] User data isolated
- [ ] No debug logs in production

## ✅ Error Handling

### Common Errors Tested
- [ ] No internet connection
- [ ] Invalid API keys
- [ ] Permission denied
- [ ] File upload failure
- [ ] API rate limits
- [ ] Invalid user input
- [ ] Firebase errors

### Error Messages
- [ ] User-friendly messages
- [ ] Actionable guidance
- [ ] No technical jargon
- [ ] Retry options available

## ✅ Documentation

### Code Documentation
- [ ] Key functions commented
- [ ] Complex logic explained
- [ ] TODOs marked
- [ ] Architecture documented

### User Documentation
- [ ] README.md complete
- [ ] QUICKSTART.md created
- [ ] Setup instructions clear
- [ ] Troubleshooting guide included

## ✅ Pre-Production

### Testing
- [ ] All features tested on Android
- [ ] All features tested on iOS
- [ ] Tested with real API keys
- [ ] Tested with multiple users
- [ ] Tested edge cases
- [ ] Performance tested

### Optimization
- [ ] App size optimized
- [ ] Images compressed
- [ ] Unused code removed
- [ ] Dependencies minimized
- [ ] Build optimized

### Release Preparation
- [ ] Version number set
- [ ] App icon added
- [ ] Splash screen configured
- [ ] App name finalized
- [ ] Store listings prepared

## ✅ Deployment

### Android Release
- [ ] Release build created
- [ ] APK/AAB signed
- [ ] ProGuard configured
- [ ] Play Store listing ready
- [ ] Screenshots prepared
- [ ] Privacy policy created

### iOS Release
- [ ] Release build created
- [ ] App signed
- [ ] App Store listing ready
- [ ] Screenshots prepared
- [ ] Privacy policy created

## ✅ Post-Deployment

### Monitoring
- [ ] Firebase Analytics enabled
- [ ] Crashlytics configured
- [ ] Performance monitoring enabled
- [ ] User feedback channel setup

### Support
- [ ] Support email configured
- [ ] FAQ created
- [ ] Bug reporting process
- [ ] Update plan defined

## 📝 Notes

### API Key Storage
```
Whisper API Key: sk-...
Gemini API Key: AI...
Firebase Project ID: call-companion-xxxxx
```

### Important URLs
```
Firebase Console: https://console.firebase.google.com/project/YOUR_PROJECT
OpenAI Dashboard: https://platform.openai.com/account/usage
Gemini Dashboard: https://makersuite.google.com/
```

### Test Accounts
```
Employee:
  Email: employee@test.com
  Password: test123
  Company ID: test-company

Admin:
  Email: admin@test.com
  Password: test123
  Company ID: test-company
```

## ✅ Final Checklist

Before going live:
- [ ] All above items checked
- [ ] App tested thoroughly
- [ ] Security reviewed
- [ ] Performance acceptable
- [ ] Documentation complete
- [ ] Support ready
- [ ] Backup plan in place

---

**Status**: [ ] Ready for Production

**Date**: _______________

**Verified by**: _______________

**Notes**: _______________________________________________
