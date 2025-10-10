import 'package:flutter/foundation.dart' show kIsWeb;

class AppConfig {
  // When true, the app uses REST API auth (AuthApiService) instead of Firebase.
  // Default: on web true; on mobile/desktop false unless Firebase init fails.
  static bool useApiAuth = kIsWeb;
}
