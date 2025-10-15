import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'screens/main_screen.dart';

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

  // NOTE: Hive initialization moved to MainScreen.initState()
  // to avoid platform channel issues before app starts
  runApp(const LocationAlarmApp());
}

class LocationAlarmApp extends StatelessWidget {
  const LocationAlarmApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Location Alarm',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const MainScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
