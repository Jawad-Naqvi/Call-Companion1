import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'package:call_companion/theme.dart';
import 'package:call_companion/providers/auth_provider.dart';
import 'package:call_companion/providers/call_provider.dart';
import 'package:call_companion/providers/customer_provider.dart';
import 'package:call_companion/screens/auth/login_screen.dart';
import 'package:call_companion/screens/employee/employee_dashboard.dart';
import 'package:call_companion/screens/admin/admin_dashboard.dart';
import 'package:call_companion/screens/auth/role_select_screen.dart';
import 'package:call_companion/services/env_service.dart';
import 'package:call_companion/config/app_config.dart';
import 'package:call_companion/services/auth_api_service.dart' as api_auth;
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Load environment variables
  try {
    if (!kIsWeb) {
      await dotenv.load(fileName: ".env");
      print('Environment variables loaded successfully');
    } else {
      // On web we rely on the backend's Gemini key; avoid fetching assets/.env
      print('Skipping .env load on web');
    }
    EnvService.printConfiguration();
    // Print resolved API base URL for diagnostics on device/APK
    try {
      print('Resolved API base URL: ' + api_auth.AuthService.baseUrl);
    } catch (_) {}
  } catch (e) {
    print('Error loading .env file: $e');
    // Continue without .env on web; backend will supply AI key
  }
  
  // Initialize Firebase on all platforms (needed for Google Sign-In on web and mobile)
  try {
    if (kIsWeb) {
      await Firebase.initializeApp(
        options: const FirebaseOptions(
          apiKey: 'AIzaSyBWhnCDLZxjXEA1S5ogdtWFltuHoa-O9PI',
          authDomain: 'call-companion-ff585.firebaseapp.com',
          projectId: 'call-companion-ff585',
          storageBucket: 'call-companion-ff585.appspot.com',
          messagingSenderId: '605403679937',
          appId: '1:605403679937:web:2f6383a933b38730579840',
        ),
      );
    } else {
      await Firebase.initializeApp();
    }
    print('Firebase initialized successfully');
  } catch (e) {
    print('Firebase initialization error: $e');
  }

  // Prefer Firebase auth by default to support Google Sign-In across platforms
  AppConfig.useApiAuth = false;

  print('Auth mode: ' + (AppConfig.useApiAuth ? 'API auth' : 'Firebase auth'));
  
  runApp(const CallCompanionApp());
}

class CallCompanionApp extends StatelessWidget {
  const CallCompanionApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => CallProvider()),
        ChangeNotifierProvider(create: (_) => CustomerProvider()),
      ],
      child: MaterialApp(
        title: 'Call Companion',
        debugShowCheckedModeBanner: false,
        theme: lightTheme,
        darkTheme: darkTheme,
        themeMode: ThemeMode.system,
        home: const AuthWrapper(),
      ),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        if (authProvider.isLoading) {
          return const Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Loading...'),
                ],
              ),
            ),
          );
        }

        if (authProvider.isAuthenticated) {
          if (authProvider.needsRoleSelection) {
            return const RoleSelectScreen();
          }
          if (authProvider.isEmployee) {
            return const EmployeeDashboard();
          } else {
            return const AdminDashboard();
          }
        }

        return const LoginScreen();
      },
    );
  }
}
