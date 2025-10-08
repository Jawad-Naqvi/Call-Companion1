// Unified backend services entrypoint with conditional exports
// On web, use API services; on other platforms, use Firebase services

export 'auth_service.dart' if (dart.library.html) 'auth_api_service.dart';
export 'call_service.dart' if (dart.library.html) 'stubs/call_service_stub.dart';
export 'customer_service.dart' if (dart.library.html) 'stubs/customer_service_stub.dart';
export 'ai_service.dart' if (dart.library.html) 'stubs/ai_service_stub.dart';
export 'transcription_service.dart' if (dart.library.html) 'stubs/transcription_service_stub.dart';
