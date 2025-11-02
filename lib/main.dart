import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'screens/main_screen.dart';
import 'theme/app_theme.dart';
import 'services/settings_service.dart';

// Global notification plugin instance
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

Future<void> main() async {
  // IMPORTANT: Ensure Flutter binding is initialized FIRST
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // Load environment variables - prioritize .env.local for development
    // .env.local is gitignored and contains actual API keys
    // .env is committed with placeholders for CI/CD and new developers
    try {
      await dotenv.load(fileName: ".env.local");
      debugPrint('✅ Loaded .env.local (local development)');
    } catch (e) {
      await dotenv.load(fileName: ".env");
      debugPrint('✅ Loaded .env (default configuration)');
    }
  } catch (e) {
    // Log initialization errors
    debugPrint('❌ Error loading environment variables: $e');
  }

  try {
    // Initialize settings service early
    await SettingsService.init();
    debugPrint('✅ Settings service initialized');
  } catch (e) {
    debugPrint('⚠️ Error initializing settings: $e');
  }

  // Initialize notifications BEFORE running app
  await _initializeNotifications();

  // NOTE: Hive initialization moved to MainScreen.initState()
  // to avoid platform channel issues before app starts
  runApp(const LocationAlarmApp());
}

/// Initialize local notifications with proper iOS permissions
Future<void> _initializeNotifications() async {
  debugPrint('🔔 Initializing notifications...');

  // Android initialization settings
  const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');

  // iOS initialization settings - request all permissions upfront
  const iosSettings = DarwinInitializationSettings(
    requestAlertPermission: true,
    requestBadgePermission: true,
    requestSoundPermission: true,
    requestCriticalPermission: false, // Don't request critical for now
  );

  const initSettings = InitializationSettings(
    android: androidSettings,
    iOS: iosSettings,
  );

  await flutterLocalNotificationsPlugin.initialize(
    initSettings,
    onDidReceiveNotificationResponse: (details) {
      debugPrint('🔔 Notification tapped: ${details.payload}');
    },
  );

  // Explicitly request iOS permissions
  final iosPlugin = flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();

  if (iosPlugin != null) {
    final granted = await iosPlugin.requestPermissions(
      alert: true,
      badge: true,
      sound: true,
    );
    debugPrint('📱 iOS notification permissions granted: $granted');
  }

  debugPrint('✅ Notifications initialized');
}

class LocationAlarmApp extends StatelessWidget {
  const LocationAlarmApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'WakeMeUp',
      theme: AppTheme.lightTheme,
      home: const MainScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
