import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyBWhnCDLZxjXEA1S5ogdtWFltuHoa-O9PI',
    authDomain: 'call-companion-ff585.firebaseapp.com',
    projectId: 'call-companion-ff585',
    storageBucket: 'call-companion-ff585.firebasestorage.app',
    messagingSenderId: '605403679937',
    appId: '1:605403679937:web:2f6383a933b38730579840',
    measurementId: 'G-5QRNB82CWR',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBWhnCDLZxjXEA1S5ogdtWFltuHoa-O9PI',
    appId: '1:605403679937:android:2f6383a933b38730579840',
    messagingSenderId: '605403679937',
    projectId: 'call-companion-ff585',
    storageBucket: 'call-companion-ff585.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyBWhnCDLZxjXEA1S5ogdtWFltuHoa-O9PI',
    appId: '1:605403679937:ios:2f6383a933b38730579840',
    messagingSenderId: '605403679937',
    projectId: 'call-companion-ff585',
    storageBucket: 'call-companion-ff585.firebasestorage.app',
    iosBundleId: 'com.example.callCompanion',
  );
}