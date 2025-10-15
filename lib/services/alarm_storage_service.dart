import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/alarm.dart';

class AlarmStorageService {
  static const String _alarmsBoxName = 'alarms';
  static Box<Map>? _alarmsBox;

  /// Initialize Hive and open the alarms box
  static Future<void> init() async {
    try {
      // Initialize Hive with Flutter-specific path handling
      debugPrint('📦 Calling Hive.initFlutter()...');
      await Hive.initFlutter();
      debugPrint('📦 Hive.initFlutter() completed');

      // Open the alarms box
      debugPrint('📦 Opening box: $_alarmsBoxName...');
      _alarmsBox = await Hive.openBox<Map>(_alarmsBoxName);
      debugPrint('📦 Box opened successfully: ${_alarmsBox!.path}');
    } catch (e, stackTrace) {
      // Log detailed error
      debugPrint('❌ Hive initialization failed: $e');
      debugPrint('Stack trace: $stackTrace');
      // Re-throw with more context
      throw Exception('Failed to initialize Hive storage: $e');
    }
  }

  /// Get the alarms box (lazy initialization)
  static Box<Map> get _box {
    if (_alarmsBox == null || !_alarmsBox!.isOpen) {
      throw Exception('AlarmStorageService not initialized. Call init() first.');
    }
    return _alarmsBox!;
  }

  /// Check if storage is initialized
  static bool get isInitialized => _alarmsBox != null && _alarmsBox!.isOpen;

  /// Save an alarm to local storage
  static Future<void> saveAlarm(Alarm alarm) async {
    await _box.put(alarm.id, alarm.toJson());
  }

  /// Get all saved alarms
  static List<Alarm> getAllAlarms() {
    try {
      final alarmMaps = _box.values.toList();
      return alarmMaps
          .map((map) => Alarm.fromJson(Map<String, dynamic>.from(map)))
          .toList();
    } catch (e) {
      // Error loading alarms - return empty list
      return [];
    }
  }

  /// Get a specific alarm by ID
  static Alarm? getAlarm(String id) {
    try {
      final alarmMap = _box.get(id);
      if (alarmMap == null) return null;
      return Alarm.fromJson(Map<String, dynamic>.from(alarmMap));
    } catch (e) {
      // Error loading alarm - return null
      return null;
    }
  }

  /// Update an existing alarm
  static Future<void> updateAlarm(Alarm alarm) async {
    await _box.put(alarm.id, alarm.toJson());
  }

  /// Delete an alarm
  static Future<void> deleteAlarm(String id) async {
    await _box.delete(id);
  }

  /// Delete all alarms
  static Future<void> deleteAllAlarms() async {
    await _box.clear();
  }

  /// Get active alarms only
  static List<Alarm> getActiveAlarms() {
    return getAllAlarms().where((alarm) => alarm.isActive).toList();
  }

  /// Get inactive alarms only
  static List<Alarm> getInactiveAlarms() {
    return getAllAlarms().where((alarm) => !alarm.isActive).toList();
  }

  /// Check if an alarm exists
  static bool alarmExists(String id) {
    return _box.containsKey(id);
  }

  /// Get count of saved alarms
  static int get alarmCount => _box.length;

  /// Listen to changes in the alarms box
  static Stream<BoxEvent> watchAlarms() {
    return _box.watch();
  }

  /// Close the box (call when app is closing)
  static Future<void> close() async {
    await _alarmsBox?.close();
  }
}
