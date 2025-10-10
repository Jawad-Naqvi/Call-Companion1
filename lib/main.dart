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
import 'package:call_companion/services/env_service.dart';
import 'package:call_companion/config/app_config.dart';
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
  } catch (e) {
    print('Error loading .env file: $e');
    // Continue without .env on web; backend will supply AI key
  }
  
  // Initialize Firebase with environment variables
  if (!kIsWeb) {
    try {
      await Firebase.initializeApp();
      print('Firebase initialized successfully');
      AppConfig.useApiAuth = false; // use Firebase auth on mobile
    } catch (e) {
      print('Firebase initialization error: $e');
      // Fall back to API auth on mobile if Firebase is unavailable
      AppConfig.useApiAuth = true;
      print('AppConfig.useApiAuth enabled (Firebase unavailable)');
    }
  } else {
    // On web we always use API auth
    AppConfig.useApiAuth = true;
  }

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
