# 🚀 Quick Start Guide

## ✅ Everything is Running!

### **Current Status:**
- ✅ **Backend Server**: Running on `http://0.0.0.0:8001`
- ✅ **Database**: Connected to Neon PostgreSQL
- ✅ **Frontend**: Running on `http://localhost:8080`
- ✅ **All Features**: Working (Auth, AI, Call Recording)

---

## 📱 Test on Device (APK)

### **Step 1: Ensure Backend is Accessible**

From your phone browser, open:
```
http://192.168.1.17:8001/api/health
```

Should show:
```json
{
  "status": "ok",
  "database_connected": true
}
```

### **Step 2: Build APK**

```bash
flutter build apk --release
```

APK location: `build\app\outputs\flutter-apk\app-release.apk`

### **Step 3: Install on Device**

**Option A - USB:**
```bash
adb install -r build\app\outputs\flutter-apk\app-release.apk
```

**Option B - GitHub Actions:**
1. Push to GitHub: `git push origin main`
2. Go to Actions tab
3. Download APK artifact
4. Transfer to phone and install

### **Step 4: Test on Device**

1. Open app
2. Sign up / Sign in
3. Navigate to dashboard
4. Enable call recording toggle
5. Make a test call
6. Call should appear on dashboard

---

## 🌐 Test on Web

Open browser:
```
http://localhost:8080
```

Test:
- ✅ Sign up
- ✅ Sign in
- ✅ Dashboard
- ✅ AI chat
- ✅ Customer management

---

## 🔄 Daily Restart (Simple!)

### **Option 1: One Command**
```bash
start_all.bat
```

### **Option 2: Manual**

**Terminal 1 - Backend:**
```bash
cd server
venv\Scripts\python.exe -m uvicorn main:app --host 0.0.0.0 --port 8001 --reload
```

**Terminal 2 - Frontend:**
```bash
flutter run -d chrome --web-port 8080
```

---

## 🔍 Verify Everything Works

### **1. Backend Health**
```bash
http://127.0.0.1:8001/api/health
```

### **2. API Documentation**
```bash
http://127.0.0.1:8001/docs
```

### **3. Frontend**
```bash
http://localhost:8080
```

### **4. Mobile Backend Access**
```bash
http://192.168.1.17:8001/api/health
```

---

## 📊 Available Endpoints

### **Authentication**
- `POST /api/auth/signup` - Register new user
- `POST /api/auth/login` - Login
- `GET /api/auth/me` - Get current user
- `POST /api/auth/logout` - Logout
- `GET /api/auth/employees` - Get company employees

### **AI Chat**
- `POST /api/ai/chat` - Chat with Gemini AI
- `GET /api/ai/diagnostics` - AI diagnostics
- `GET /api/ai/ping` - AI service ping

### **Call Recording**
- `POST /api/calls/upload` - Upload call recording
- `GET /api/calls` - Get call records
- `GET /api/calls/{id}` - Get specific call
- `GET /api/calls/{id}/audio` - Stream audio
- `DELETE /api/calls/{id}` - Delete call

### **Health**
- `GET /health` - Basic health check
- `GET /api/health` - Detailed health status

---

## ⚡ Key Features

### **✅ Persistent Database**
- No need to reconnect daily
- Auto-reconnection on failure
- Connection pooling for performance

### **✅ Call Recording**
- Automatic recording when enabled
- Saves to Firebase + Neon database
- Appears on employee dashboard
- Audio playback available

### **✅ Authentication**
- JWT-based auth
- Secure password hashing
- Role-based access (employee/admin)

### **✅ AI Integration**
- Gemini AI chat
- Customer insights
- Call analysis (future)

---

## 🛠️ Troubleshooting

### **Backend Not Accessible from Phone**

1. Check Windows Firewall:
   ```powershell
   New-NetFirewallRule -DisplayName "Call Companion Backend" -Direction Inbound -LocalPort 8001 -Protocol TCP -Action Allow
   ```

2. Verify IP address:
   ```powershell
   ipconfig
   ```
   Look for IPv4 Address under your WiFi adapter

3. Update `lib/services/auth_api_service.dart` and `lib/services/neon_call_service.dart` with correct IP

### **Port Already in Use**

```bash
# Kill process on port 8001
netstat -ano | findstr :8001
taskkill /F /PID <process_id>

# Or use startup script (does this automatically)
start_all.bat
```

### **Database Connection Failed**

1. Check `.env` has correct `NEON_CONNECTION_STRING`
2. Verify Neon database is active (not paused)
3. Restart backend server
4. Check server logs for errors

---

## 📋 Checklist Before Testing

- [ ] Backend running on port 8001
- [ ] Database connected (check `/api/health`)
- [ ] Frontend running on port 8080
- [ ] Phone on same WiFi network
- [ ] Backend accessible from phone browser
- [ ] APK built with latest changes
- [ ] APK installed on device

---

## 🎉 You're All Set!

Everything is configured and running. The app is production-ready with:

✅ Persistent database connection  
✅ All features working  
✅ No daily reconnection needed  
✅ One-command startup  
✅ Mobile APK ready  

**Just run `start_all.bat` each day and you're good to go!** 🚀
