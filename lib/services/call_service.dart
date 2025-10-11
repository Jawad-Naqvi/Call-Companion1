import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:record/record.dart';
import 'package:uuid/uuid.dart';
import 'package:path_provider/path_provider.dart';
import 'package:call_companion/models/call.dart';
import 'package:call_companion/services/neon_call_service.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:phone_state/phone_state.dart';
import 'dart:async';

class CallService {
  final NeonCallService _neonService = NeonCallService();
  StreamSubscription<PhoneState>? _phoneSubscription;

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
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final AudioRecorder _recorder = AudioRecorder();
  final Uuid _uuid = const Uuid();

  bool _isRecording = false;
  String? _currentCallId;
  String? _currentRecordingPath;
  bool _globalRecordingEnabled = false;

  bool get isRecording => _isRecording;
  bool get globalRecordingEnabled => _globalRecordingEnabled;
  String? get currentCallId => _currentCallId;
  
  // Global recording toggle
  void setGlobalRecording(bool enabled) {
    _globalRecordingEnabled = enabled;
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
      // Check if customer exists
      final querySnapshot = await _firestore
          .collection('customers')
          .where('phoneNumber', isEqualTo: phoneNumber)
          .limit(1)
          .get();
      
      if (querySnapshot.docs.isNotEmpty) {
        return querySnapshot.docs.first.id;
      }
      
      // Create new customer
      final customerId = _uuid.v4();
      await _firestore.collection('customers').doc(customerId).set({
        'id': customerId,
        'phoneNumber': phoneNumber,
        'alias': null, // Can be set later by employee
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      return customerId;
    } catch (e) {
      print('Error getting/creating customer: $e');
      // Return a temporary ID if we can't create a customer
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

      // Save call to Firestore
      await _firestore.collection('calls').doc(callId).set(call.toJson());

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
      
      // Upload to Firebase Storage
      final fileName = 'calls/${_currentCallId!}/recording.m4a';
      final storageRef = _storage.ref().child(fileName);
      
      final uploadTask = storageRef.putFile(file);
      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();

      // Calculate duration
      final call = await getCallById(_currentCallId!);
      if (call == null) {
        throw Exception('Call not found');
      }

      final duration = endTime.difference(call.startTime).inSeconds;

      // Update call in Firestore
      final updatedCall = call.copyWith(
        endTime: endTime,
        duration: duration,
        audioFileUrl: downloadUrl,
        audioFileName: fileName,
        audioFileSize: fileSize,
        status: CallStatus.completed,
        updatedAt: DateTime.now(),
      );

      await _firestore
          .collection('calls')
          .doc(_currentCallId!)
          .update(updatedCall.toJson());

      // Also upload to Neon database for backup and analytics
      try {
        print('[CallService] Uploading call to Neon database...');
        await _neonService.uploadCallRecording(
          userId: call.employeeId,
          customerNumber: call.customerPhoneNumber,
          customerName: null, // Can be enriched later
          callType: call.type == CallType.incoming ? 'incoming' : 'outgoing',
          startedAt: call.startTime,
          endedAt: endTime,
          durationSec: duration,
          firebaseCallId: _currentCallId,
          firebaseAudioUrl: downloadUrl,
          audioFile: file,
        );
        print('[CallService] ✅ Call uploaded to Neon database');
      } catch (e) {
        print('[CallService] ⚠️ Failed to upload to Neon (non-critical): $e');
        // Don't fail the whole operation if Neon upload fails
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

      return updatedCall;
    } catch (e) {
      print('Error stopping recording: $e');
      _isRecording = false;
      _currentCallId = null;
      _currentRecordingPath = null;
      return null;
    }
  }

  Future<List<Call>> getCallsByCustomer(String customerId) async {
    try {
      final querySnapshot = await _firestore
          .collection('calls')
          .where('customerId', isEqualTo: customerId)
          .orderBy('startTime', descending: true)
          .get();

      return querySnapshot.docs.map((doc) => 
        Call.fromJson({...doc.data(), 'id': doc.id})
      ).toList();
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

  Future<void> dispose() async {
    if (_isRecording) {
      await stopCallRecording();
    }
    await _recorder.dispose();
  }
}