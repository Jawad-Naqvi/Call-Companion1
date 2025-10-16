import 'package:flutter/foundation.dart' show kIsWeb;

class AppConfig {
  // Use Firebase-based auth wrapper so Google session is restored on reload.
  // Note: email/password auth is still routed to your API inside fb_auth.AuthService.
  static bool useApiAuth = false;

  // Allow auto-restore of session on reload.
  static bool forceLoginOnStartup = false;
}
