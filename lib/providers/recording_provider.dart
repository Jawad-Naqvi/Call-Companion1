import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:call_companion/models/user_preferences.dart';
import 'package:call_companion/services/background_recording_service.dart';
import 'package:call_companion/services/call_service.dart';

class RecordingProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final CallService _callService = CallService();
  
  bool _isRecordingEnabled = false;
  bool _isInitialized = false;
  bool _isServiceRunning = false;
  String? _error;
  
  bool get isRecordingEnabled => _isRecordingEnabled;
  bool get isInitialized => _isInitialized;
  bool get isServiceRunning => _isServiceRunning;
  String? get error => _error;

  // Initialize the recording state for a user
  Future<void> initializeForUser(String userId) async {
    try {
      final doc = await _firestore
          .collection('user_preferences')
          .doc(userId)
          .get();

      if (doc.exists) {
        final prefs = UserPreferences.fromJson({...doc.data()!, 'userId': doc.id});
        _isRecordingEnabled = prefs.isRecordingEnabled;
      } else {
        // Create default preferences
        await _firestore.collection('user_preferences').doc(userId).set(
          UserPreferences(
            userId: userId,
            isRecordingEnabled: false,
            updatedAt: DateTime.now(),
          ).toJson(),
        );
        _isRecordingEnabled = false;
      }
      
      _isInitialized = true;
      
      // Start the background service if recording is enabled
      if (_isRecordingEnabled) {
        await BackgroundRecordingService.startService();
        // Attach phone state detection for automatic start/stop
        await _callService.enableGlobalRecording(employeeId: userId);
        _isServiceRunning = true;
      }
      
      notifyListeners();
    } catch (e) {
      _error = 'Failed to initialize recording preferences: $e';
      notifyListeners();
    }
  }

  // Toggle recording state
  Future<void> toggleRecording(String userId) async {
    try {
      final newState = !_isRecordingEnabled;
      
      // Update Firestore first
      await _firestore.collection('user_preferences').doc(userId).update({
        'isRecordingEnabled': newState,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Then update local state
      _isRecordingEnabled = newState;
      
      // Start or stop the background service
      if (newState) {
        await BackgroundRecordingService.startService();
        // Enable auto detection (Android) and permissions
        await _callService.enableGlobalRecording(employeeId: userId);
        _isServiceRunning = true;
      } else {
        await _callService.disableGlobalRecording();
        await BackgroundRecordingService.stopService();
        _isServiceRunning = false;
      }
      
      notifyListeners();
    } catch (e) {
      _error = 'Failed to toggle recording: $e';
      _isServiceRunning = false;
      notifyListeners();
      rethrow; // Allow UI to handle the error
    }
  }
  
  // Get current service status
  Future<void> checkServiceStatus() async {
    try {
      final status = await BackgroundRecordingService.isServiceRunning();
      _isServiceRunning = status;
      notifyListeners();
    } catch (e) {
      _error = 'Failed to check service status: $e';
      _isServiceRunning = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    if (_isRecordingEnabled) {
      BackgroundRecordingService.stopService();
    }
    super.dispose();
  }
}