import 'package:flutter/foundation.dart' show kIsWeb;

class AppConfig {
  // When true, the app uses REST API auth (AuthApiService) instead of Firebase.
  // Default: on web true; on mobile/desktop false unless Firebase init fails.
  static bool useApiAuth = kIsWeb;

  // When true, the app will not auto-login with a stored token/session on startup
  // and will always show the login page until the user signs in.
  // Set to true per user's request to always land on login after restart.
  static bool forceLoginOnStartup = true;
}
