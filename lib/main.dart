import 'package:flutter/material.dart';
import 'screens/main_screen.dart';

void main() {
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
