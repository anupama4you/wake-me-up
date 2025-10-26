import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'screens/main_screen.dart';
import 'theme/app_theme.dart';
import 'services/settings_service.dart';

Future<void> main() async {
  // IMPORTANT: Ensure Flutter binding is initialized FIRST
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // Load environment variables from .env file
    await dotenv.load(fileName: ".env");
  } catch (e) {
    // Log initialization errors
    debugPrint('Error loading .env: $e');
  }

  try {
    // Initialize settings service early
    await SettingsService.init();
    debugPrint('✅ Settings service initialized');
  } catch (e) {
    debugPrint('⚠️ Error initializing settings: $e');
  }

  // NOTE: Hive initialization moved to MainScreen.initState()
  // to avoid platform channel issues before app starts
  runApp(const LocationAlarmApp());
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
