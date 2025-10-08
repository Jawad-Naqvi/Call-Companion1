import 'package:call_companion/models/call.dart';

class CallService {
  Future<void> enableGlobalRecording() async {}
  Future<void> disableGlobalRecording() async {}
  bool _isRecording = false;
  String? _currentCallId;

  bool get isRecording => _isRecording;
  String? get currentCallId => _currentCallId;

  Future<bool> hasRecordingPermission() async => false;

  Future<String?> startCallRecording({
    required String employeeId,
    required String customerId,
    required String customerPhoneNumber,
    required CallType type,
  }) async {
    return null;
  }

  Future<Call?> stopCallRecording() async => null;

  Future<List<Call>> getCallsByCustomer(String customerId) async => [];

  Future<List<Call>> getCallsByEmployee(String employeeId, {int? limit}) async => [];

  Future<Call?> getCallById(String callId) async => null;

  Future<bool> updateCallStatus(String callId, CallStatus status) async => false;

  Future<bool> markCallAsTranscribed(String callId) async => false;

  Future<bool> markCallAsAnalyzed(String callId) async => false;

  Future<bool> updateCall(String callId, Map<String, dynamic> updates) async => false;

  Stream<List<Call>> watchCallsByCustomer(String customerId) => const Stream.empty();

  Stream<List<Call>> watchCallsByEmployee(String employeeId) => const Stream.empty();

  Future<bool> deleteCall(String callId) async => false;

  Future<void> dispose() async {}
}
