import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:call_companion/services/backend_services.dart';
import 'package:call_companion/models/call.dart';

class CallProvider extends ChangeNotifier {
  bool _isGlobalRecording = false;
  bool get isGlobalRecording => _isGlobalRecording;
  Future<void> enableGlobalRecording() async {
    try {
      if (kIsWeb) {
        _error = 'Global recording is unavailable on web preview';
        notifyListeners();
        return;
      }
      _callService ??= CallService();
      await _callService!.enableGlobalRecording();
      _isGlobalRecording = true;
      _error = null;
      notifyListeners();
    } catch (e) {
      _error = 'Error enabling global recording: $e';
      notifyListeners();
    }
  }

  Future<void> disableGlobalRecording() async {
    try {
      if (kIsWeb) {
        _error = 'Global recording is unavailable on web preview';
        notifyListeners();
        return;
      }
      _callService ??= CallService();
      await _callService!.disableGlobalRecording();
      _isGlobalRecording = false;
      _error = null;
      notifyListeners();
    } catch (e) {
      _error = 'Error disabling global recording: $e';
      notifyListeners();
    }
  }
  CallService? _callService; // initialize only on non-web
  
  List<Call> _calls = [];
  bool _isLoading = false;
  String? _error;
  bool _isRecording = false;
  String? _currentCallId;

  List<Call> get calls => _calls;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isRecording => _isRecording;
  String? get currentCallId => _currentCallId;

  Future<void> loadCalls(String employeeId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      if (kIsWeb) {
        _calls = [];
      } else {
        _callService ??= CallService();
        _calls = await _callService!.getCallsByEmployee(employeeId);
      }
    } catch (e) {
      _error = 'Failed to load calls: $e';
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<List<Call>> getCallsByCustomer(String customerId) async {
    try {
      if (kIsWeb) return [];
      _callService ??= CallService();
      return await _callService!.getCallsByCustomer(customerId);
    } catch (e) {
      _error = 'Failed to load customer calls: $e';
      notifyListeners();
      return [];
    }
  }

  Future<bool> startRecording({
    required String employeeId,
    required String customerId,
    required String customerPhoneNumber,
    CallType type = CallType.outgoing,
  }) async {
    try {
      if (kIsWeb) {
        _error = 'Recording is unavailable on web preview without backend setup';
        notifyListeners();
        return false;
      }
      _callService ??= CallService();
      final callId = await _callService!.startCallRecording(
        employeeId: employeeId,
        customerId: customerId,
        customerPhoneNumber: customerPhoneNumber,
        type: type,
      );

      if (callId != null) {
        _isRecording = true;
        _currentCallId = callId;
        _error = null;
        notifyListeners();
        return true;
      } else {
        _error = 'Failed to start recording';
        notifyListeners();
        return false;
      }
    } catch (e) {
      _error = 'Error starting recording: $e';
      notifyListeners();
      return false;
    }
  }

  Future<Call?> stopRecording() async {
    try {
      if (kIsWeb) {
        _error = 'Recording is unavailable on web preview without backend setup';
        notifyListeners();
        return null;
      }
      _callService ??= CallService();
      final call = await _callService!.stopCallRecording();
      
      if (call != null) {
        _isRecording = false;
        _currentCallId = null;
        _calls.insert(0, call);
        _error = null;
        notifyListeners();
        return call;
      } else {
        _error = 'Failed to stop recording';
        notifyListeners();
        return null;
      }
    } catch (e) {
      _error = 'Error stopping recording: $e';
      notifyListeners();
      return null;
    }
  }

  Future<bool> updateCallStatus(String callId, CallStatus status) async {
    try {
      if (kIsWeb) {
        final index = _calls.indexWhere((call) => call.id == callId);
        if (index != -1) {
          _calls[index] = _calls[index].copyWith(status: status, updatedAt: DateTime.now());
          notifyListeners();
          return true;
        }
        return false;
      }
      _callService ??= CallService();
      final success = await _callService!.updateCallStatus(callId, status);
      if (success) {
        final index = _calls.indexWhere((call) => call.id == callId);
        if (index != -1) {
          _calls[index] = _calls[index].copyWith(status: status, updatedAt: DateTime.now());
          notifyListeners();
        }
      }
      return success;
    } catch (e) {
      _error = 'Error updating call status: $e';
      notifyListeners();
      return false;
    }
  }

  Future<Call?> getCallById(String callId) async {
    try {
      if (kIsWeb) {
        try {
          return _calls.firstWhere((c) => c.id == callId);
        } catch (_) {
          return null;
        }
      }
      _callService ??= CallService();
      return await _callService!.getCallById(callId);
    } catch (e) {
      _error = 'Error getting call: $e';
      notifyListeners();
      return null;
    }
  }

  Future<bool> deleteCall(String callId) async {
    try {
      if (kIsWeb) {
        _calls.removeWhere((call) => call.id == callId);
        notifyListeners();
        return true;
      }
      _callService ??= CallService();
      final success = await _callService!.deleteCall(callId);
      if (success) {
        _calls.removeWhere((call) => call.id == callId);
        notifyListeners();
      }
      return success;
    } catch (e) {
      _error = 'Error deleting call: $e';
      notifyListeners();
      return false;
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _callService?.dispose();
    super.dispose();
  }
}