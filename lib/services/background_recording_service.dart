import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_background_service_android/flutter_background_service_android.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:call_companion/services/call_service.dart';

class BackgroundRecordingService {
  static final FlutterBackgroundService _service = FlutterBackgroundService();
  static final CallService _callService = CallService();
  static final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  
  static bool _initialized = false;

  static Future<void> initialize() async {
    // Initialize notifications
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();
    const initSettings = InitializationSettings(android: androidSettings, iOS: iosSettings);
    await _notifications.initialize(initSettings);

    // Configure background service
    await _service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: onStart,
        autoStart: false,
        isForegroundMode: true,
        notificationChannelId: 'recording_service',
        initialNotificationTitle: 'Call Recording Service',
        initialNotificationContent: 'Monitoring incoming calls',
        foregroundServiceNotificationId: 888,
      ),
      iosConfiguration: IosConfiguration(
        autoStart: false,
        onForeground: onStart,
        onBackground: onIosBackground,
      ),
    );
  }

  @pragma('vm:entry-point')
  static void onStart(ServiceInstance service) async {
    if (service is AndroidServiceInstance) {
      service.on('stopService').listen((event) {
        service.stopSelf();
      });

      // Start foreground service
      await service.setAsForegroundService();
    }

    // Start monitoring calls
    _callService.setGlobalRecording(true);
    
    // Update notification periodically
    service.on('update').listen((event) async {
      if (service is AndroidServiceInstance) {
        await service.setForegroundNotificationInfo(
          title: 'Call Recording Active',
          content: 'Monitoring for incoming calls',
        );
      }
    });
  }

  @pragma('vm:entry-point')
  static Future<bool> onIosBackground(ServiceInstance service) async {
    WidgetsFlutterBinding.ensureInitialized();
    return true;
  }

  static Future<void> startService() async {
    if (!await _service.isRunning()) {
      await _service.startService();
      
      // Show notification
      const androidDetails = AndroidNotificationDetails(
        'recording_service',
        'Call Recording Service',
        channelDescription: 'Monitors and records incoming calls',
        importance: Importance.low,
        priority: Priority.low,
        showWhen: false,
      );
      const notificationDetails = NotificationDetails(android: androidDetails);
      
      await _notifications.show(
        888,
        'Call Recording Active',
        'Monitoring for incoming calls',
        notificationDetails,
      );
    }
  }

  static Future<void> stopService() async {
    if (await _service.isRunning()) {
      _service.invoke('stopService');
      await _notifications.cancel(888);
      _initialized = false;
    }
    _callService.setGlobalRecording(false);
  }

  static Future<bool> isServiceRunning() async {
    return _service.isRunning();
  }

  static Future<void> checkPermissions() async {
  // Permission check not implemented; remove or implement if needed
  }
}