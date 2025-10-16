import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:record/record.dart';
import 'package:uuid/uuid.dart';
import 'package:path_provider/path_provider.dart';
import 'package:call_companion/models/call.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:phone_state/phone_state.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:call_companion/services/auth_api_service.dart' as api_auth;
import 'dart:async';

class CallService {
  StreamSubscription<PhoneState>? _phoneSubscription;
  
  String get _baseUrl => api_auth.AuthService.baseUrl;

  // Firebase instances
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  String? _employeeId;

  /// Enable global recording and (optionally) attach phone-state detection.
  /// If [employeeId] is provided, auto start/stop recording on call events.
  Future<void> enableGlobalRecording({String? employeeId}) async {
    _globalRecordingEnabled = true;

    // Request critical permissions on Android
    if (Platform.isAndroid) {
      await _ensurePermissions();

      // Attach phone listener if we have an employee id
      if (employeeId != null) {
        await setupCallDetection(employeeId);
      }
    }

    // Here you would start the background service if needed
    // For example: await BackgroundRecordingService.startService();
  }

  Future<void> disableGlobalRecording() async {
    _globalRecordingEnabled = false;
    // Here you would stop the background service if needed
    // For example: await BackgroundRecordingService.stopService();
    await _detachCallDetection();
  }
  final AudioRecorder _recorder = AudioRecorder();
  final Uuid _uuid = const Uuid();
  
  // Get authorization headers
  Future<Map<String, String>> _getHeaders() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('User not authenticated');
    }
    
    final token = await user.getIdToken();
    return {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    };
  }
  
  // Get multipart headers for file upload
  Future<Map<String, String>> _getMultipartHeaders() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('User not authenticated');
    }
    
    final token = await user.getIdToken();
    return {
      'Authorization': 'Bearer $token',
    };
  }

  bool _isRecording = false;
  String? _currentCallId;
  String? _currentRecordingPath;
  bool _globalRecordingEnabled = false;

  bool get isRecording => _isRecording;
  bool get globalRecordingEnabled => _globalRecordingEnabled;
  String? get currentCallId => _currentCallId;
  
  // Global recording toggle
  // Toggle recording setting on backend
  Future<bool> setGlobalRecording(bool enabled) async {
    try {
      final headers = await _getHeaders();
      
      final request = http.MultipartRequest('PUT', Uri.parse('$_baseUrl/users/recording-toggle'));
      request.headers.addAll(headers);
      request.fields['enabled'] = enabled.toString();
      
      final response = await request.send();
      
      if (response.statusCode == 200) {
        _globalRecordingEnabled = enabled;
        return true;
      } else {
        print('Failed to update recording setting: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      print('Error updating recording setting: $e');
      return false;
    }
  }

  Future<bool> hasRecordingPermission() async {
    return await _recorder.hasPermission();
  }

  Future<void> _ensurePermissions() async {
    // Microphone is required by record plugin
    final mic = await Permission.microphone.request();
    // Phone state and call log help detect call events/number
    final phone = await Permission.phone.request();
    // Note: callLog permission doesn't exist in permission_handler
    // Some OEMs require call log to get numbers; it's handled differently

    if (!mic.isGranted) {
      throw Exception('Microphone permission is required for call recording');
    }
    if (!phone.isGranted) {
      // We can still try manual start, but auto-detection won't work
      print('[CallService] Phone permission not granted; auto-detection disabled');
    }
  }

  // Auto-record calls when enabled (Android only). Safe no-op on other platforms.
  Future<void> setupCallDetection(String employeeId) async {
    if (!Platform.isAndroid) return;
    // Avoid multiple subscriptions
    await _detachCallDetection();

    try {
      // Ensure permissions
      await _ensurePermissions();

      // TODO: Fix phone_state API - phoneStateStream doesn't exist in current version
      // For now, disable auto-detection to allow build to succeed
      print('[CallService] Phone state detection disabled - manual recording available');
      print('[CallService] TODO: Update phone_state package and fix API usage');

      // Alternative: Use a timer-based approach or simpler detection
      // _phoneSubscription = PhoneState.stream.listen((event) async {
      //   // Handle phone state changes
      // });

    } catch (e) {
      print('[CallService] Failed to setup call detection: $e');
    }
  }

  Future<void> _detachCallDetection() async {
    await _phoneSubscription?.cancel();
    _phoneSubscription = null;
  }
  
  // Called by platform code when a call is detected
  Future<String?> onCallDetected(String phoneNumber, CallType type, String employeeId) async {
    if (!_globalRecordingEnabled) {
      return null; // Don't record if global recording is disabled
    }
    
    // Look up or create customer ID based on phone number
    final customerId = await _getOrCreateCustomerId(phoneNumber);
    
    return startCallRecording(
      employeeId: employeeId,
      customerId: customerId,
      customerPhoneNumber: phoneNumber,
      type: type,
    );
  }
  
  Future<String> _getOrCreateCustomerId(String phoneNumber) async {
    try {
      final headers = await _getHeaders();
      
      // Get customers from backend to check if exists
      final response = await http.get(
        Uri.parse('$_baseUrl/customers'),
        headers: headers,
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final customers = data['customers'] as List<dynamic>;
        
        // Check if customer with this phone number exists
        for (final customer in customers) {
          if (customer['phone_number'] == phoneNumber) {
            return customer['id'];
          }
        }
      }
      
      // Customer doesn't exist, will be created automatically when recording call
      return 'auto-create-$phoneNumber';
    } catch (e) {
      print('Error getting customer: $e');
      return 'temp-${_uuid.v4()}';
    }
  }

  Future<String?> startCallRecording({
    required String employeeId,
    required String customerId,
    required String customerPhoneNumber,
    required CallType type,
  }) async {
    try {
      if (_isRecording) {
        await stopCallRecording();
      }

      final hasPermission = await hasRecordingPermission();
      if (!hasPermission) {
        throw Exception('Recording permission not granted');
      }

      final callId = _uuid.v4();
      final call = Call(
        id: callId,
        employeeId: employeeId,
        customerId: customerId,
        customerPhoneNumber: customerPhoneNumber,
        type: type,
        status: CallStatus.recording,
        startTime: DateTime.now(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Start recording
      final directory = await getTemporaryDirectory();
      final recordingPath = '${directory.path}/call_$callId.m4a';

      // Prefer voice communication source on Android for call capture
      final config = RecordConfig(
        encoder: AudioEncoder.aacLc,
        bitRate: 128000,
        sampleRate: 44100,
        androidConfig: const AndroidRecordConfig(
          // VOICE_COMMUNICATION is more widely allowed than VOICE_CALL on newer Androids
          // On Android 15 (OPPO CPH2569), we need to be more permissive and handle failures
          audioSource: AndroidAudioSource.voiceCommunication,
        ),
      );

      try {
        await _recorder.start(config, path: recordingPath);
        print('[CallService] Recording started successfully with VOICE_COMMUNICATION');
      } catch (e) {
        print('[CallService] Primary audio source failed on Android 15, trying fallback: $e');
        try {
          // Fallback to default config if voice communication fails (Android 15 restriction)
          await _recorder.start(const RecordConfig(), path: recordingPath);
          print('[CallService] Recording started with fallback config');
        } catch (fallbackError) {
          print('[CallService] Both recording configs failed on Android 15: $fallbackError');
          // Create a minimal call record even if recording fails (for debugging)
          await _firestore.collection('calls').doc(callId).set(call.copyWith(
            status: CallStatus.failed,
            // Note: Call model doesn't have notes field, using status for debugging
          ).toJson());
          return null;
        }
      }

      _isRecording = true;
      _currentCallId = callId;
      _currentRecordingPath = recordingPath;

      return callId;
    } catch (e) {
      print('Error starting recording: $e');
      return null;
    }
  }

  Future<Call?> stopCallRecording() async {
    try {
      if (!_isRecording || _currentCallId == null) {
        return null;
      }

      // Stop recording
      final path = await _recorder.stop();
      
      if (path == null || _currentCallId == null) {
        return null;
      }

      final endTime = DateTime.now();
      final file = File(path);
      
      if (!file.existsSync()) {
        throw Exception('Recording file not found');
      }

      final fileSize = await file.length();
      final duration = endTime.difference(DateTime.now().subtract(Duration(seconds: endTime.difference(DateTime.now()).inSeconds))).inSeconds;
      
      // Upload call recording to backend API
      Call? call;
      try {
        final headers = await _getMultipartHeaders();
        
        final request = http.MultipartRequest('POST', Uri.parse('$_baseUrl/calls/record'));
        request.headers.addAll(headers);
        
        // Add form fields
        request.fields['customer_phone_number'] = _currentRecordingPath?.split('_')[1].split('.')[0] ?? 'unknown';
        request.fields['duration'] = duration.toString();
        request.fields['call_type'] = 'outgoing'; // Default, could be determined by phone state
        
        // Add audio file
        request.files.add(
          await http.MultipartFile.fromPath(
            'audio_file',
            file.path,
            filename: 'recording.m4a',
          ),
        );
        
        final response = await request.send();
        
        if (response.statusCode == 200) {
          final responseBody = await response.stream.bytesToString();
          final data = jsonDecode(responseBody);
          
          print('[CallService] ✅ Call uploaded successfully: ${data['call_id']}');
          
          // Update local call object with backend data
          call = Call(
            id: data['call_id'],
            employeeId: _employeeId ?? 'unknown', // From the current context
            customerId: data['customer_id'],
            customerPhoneNumber: request.fields['customer_phone_number']!,
            type: CallType.outgoing,
            status: CallStatus.completed,
            startTime: endTime.subtract(Duration(seconds: duration)),
            endTime: endTime,
            duration: duration,
            audioFileUrl: data['audio_url'],
            audioFileName: 'recording.m4a',
            audioFileSize: fileSize,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );
          
          // Clean up local file
          try {
            await file.delete();
          } catch (e) {
            print('Error deleting local file: $e');
          }
          
          _isRecording = false;
          _currentCallId = null;
          _currentRecordingPath = null;
          
          return call;
        } else {
          final errorBody = await response.stream.bytesToString();
          print('[CallService] ❌ Failed to upload call: $errorBody');
          throw Exception('Failed to upload call recording');
        }
      } catch (e) {
        print('[CallService] ❌ Upload error: $e');
        throw e;
      }

      // Clean up local file
      try {
        await file.delete();
      } catch (e) {
        print('Error deleting local file: $e');
      }

      _isRecording = false;
      _currentCallId = null;
      _currentRecordingPath = null;

      return call;
    } catch (e) {
      print('Error stopping recording: $e');
      _isRecording = false;
      _currentCallId = null;
      _currentRecordingPath = null;
      return null;
    }
  }

  // Get calls by customer phone number
  Future<List<Call>> getCallsByCustomer(String customerPhone) async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$_baseUrl/customers/$customerPhone/calls'),
        headers: headers,
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final callsData = data['calls'] as List<dynamic>;
        
        return callsData.map((callData) => Call.fromJson(callData)).toList();
      } else {
        print('Failed to get calls by customer: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('Error getting calls by customer: $e');
      return [];
    }
  }

  Future<List<Call>> getCallsByEmployee(String employeeId, {int? limit}) async {
    try {
      Query query = _firestore
          .collection('calls')
          .where('employeeId', isEqualTo: employeeId)
          .orderBy('startTime', descending: true);

      if (limit != null) {
        query = query.limit(limit);
      }

      final querySnapshot = await query.get();

      return querySnapshot.docs.map((doc) => 
        Call.fromJson({...doc.data() as Map<String, dynamic>, 'id': doc.id})
      ).toList();
    } catch (e) {
      print('Error getting calls by employee: $e');
      return [];
    }
  }

  Future<Call?> getCallById(String callId) async {
    try {
      final doc = await _firestore.collection('calls').doc(callId).get();
      if (doc.exists) {
        return Call.fromJson({...doc.data()!, 'id': doc.id});
      }
    } catch (e) {
      print('Error getting call by ID: $e');
    }
    return null;
  }

  Future<bool> updateCallStatus(String callId, CallStatus status) async {
    try {
      await _firestore.collection('calls').doc(callId).update({
        'status': status.name,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });
      return true;
    } catch (e) {
      print('Error updating call status: $e');
      return false;
    }
  }

  Future<bool> markCallAsTranscribed(String callId) async {
    return await updateCall(callId, {
      'hasTranscript': true,
      'status': CallStatus.transcribing.name,
    });
  }

  Future<bool> markCallAsAnalyzed(String callId) async {
    return await updateCall(callId, {
      'hasAISummary': true,
      'status': CallStatus.analyzed.name,
    });
  }

  Future<bool> updateCall(String callId, Map<String, dynamic> updates) async {
    try {
      updates['updatedAt'] = Timestamp.fromDate(DateTime.now());
      await _firestore.collection('calls').doc(callId).update(updates);
      return true;
    } catch (e) {
      print('Error updating call: $e');
      return false;
    }
  }

  Stream<List<Call>> watchCallsByCustomer(String customerId) {
    return _firestore
        .collection('calls')
        .where('customerId', isEqualTo: customerId)
        .orderBy('startTime', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Call.fromJson({...doc.data(), 'id': doc.id}))
            .toList());
  }

  Stream<List<Call>> watchCallsByEmployee(String employeeId) {
    return _firestore
        .collection('calls')
        .where('employeeId', isEqualTo: employeeId)
        .orderBy('startTime', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Call.fromJson({...doc.data(), 'id': doc.id}))
            .toList());
  }

  Future<bool> deleteCall(String callId) async {
    try {
      final call = await getCallById(callId);
      if (call?.audioFileName != null) {
        // Delete audio file from storage
        try {
          await _storage.ref().child(call!.audioFileName!).delete();
        } catch (e) {
          print('Error deleting audio file: $e');
        }
      }

      // Delete call document
      await _firestore.collection('calls').doc(callId).delete();
      return true;
    } catch (e) {
      print('Error deleting call: $e');
      return false;
    }
  }

  // Transcribe a call
  Future<bool> transcribeCall(String callId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('$_baseUrl/calls/$callId/transcribe'),
        headers: headers,
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('Call transcribed successfully: ${data['transcript_id']}');
        return true;
      } else {
        print('Failed to transcribe call: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      print('Error transcribing call: $e');
      return false;
    }
  }
  
  // Generate AI summary for a call
  Future<bool> generateAISummary(String callId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('$_baseUrl/calls/$callId/ai-summary'),
        headers: headers,
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('AI summary generated successfully: ${data['summary_id']}');
        return true;
      } else {
        print('Failed to generate AI summary: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      print('Error generating AI summary: $e');
      return false;
    }
  }
  
  // Chat with AI about a customer
  Future<String?> chatWithAI(String customerPhone, String message) async {
    try {
      final headers = await _getMultipartHeaders();
      
      final request = http.MultipartRequest('POST', Uri.parse('$_baseUrl/customers/$customerPhone/chat-ai'));
      request.headers.addAll(headers);
      request.fields['message'] = message;
      
      final response = await request.send();
      
      if (response.statusCode == 200) {
        final responseBody = await response.stream.bytesToString();
        final data = jsonDecode(responseBody);
        return data['response'];
      } else {
        print('Failed to chat with AI: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('Error chatting with AI: $e');
      return null;
    }
  }
  
  // Get dashboard statistics
  Future<Map<String, dynamic>?> getDashboardStats() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$_baseUrl/dashboard/stats'),
        headers: headers,
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['stats'];
      } else {
        print('Failed to get dashboard stats: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('Error getting dashboard stats: $e');
      return null;
    }
  }
  
  // Get all customers
  Future<List<Map<String, dynamic>>> getCustomers() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$_baseUrl/customers'),
        headers: headers,
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data['customers']);
      } else {
        print('Failed to get customers: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('Error getting customers: $e');
      return [];
    }
  }
  
  // Get call details
  Future<Map<String, dynamic>?> getCallDetails(String callId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$_baseUrl/calls/$callId'),
        headers: headers,
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['call'];
      } else {
        print('Failed to get call details: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('Error getting call details: $e');
      return null;
    }
  }
  
  Future<void> dispose() async {
    if (_isRecording) {
      await stopCallRecording();
    }
    await _recorder.dispose();
    await _phoneSubscription?.cancel();
  }
}