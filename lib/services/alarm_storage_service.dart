import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/alarm.dart';

class AlarmStorageService {
  static const String _alarmsBoxName = 'alarms';
  static Box<Map>? _alarmsBox;

  /// Initialize Hive and open the alarms box
  static Future<void> init() async {
    try {
      // Check if box is already open (from previous session)
      if (_alarmsBox != null && _alarmsBox!.isOpen) {
        debugPrint('📦 Hive box already open, reusing existing box');
        return;
      }

      // Initialize Hive with Flutter-specific path handling
      debugPrint('📦 Calling Hive.initFlutter()...');
      await Hive.initFlutter();
      debugPrint('📦 Hive.initFlutter() completed');

      // Check if box already exists and is open
      if (Hive.isBoxOpen(_alarmsBoxName)) {
        debugPrint('📦 Box already open, getting existing box...');
        _alarmsBox = Hive.box<Map>(_alarmsBoxName);
      } else {
        // Open the alarms box
        debugPrint('📦 Opening box: $_alarmsBoxName...');
        _alarmsBox = await Hive.openBox<Map>(_alarmsBoxName);
      }

      debugPrint('📦 Box ready: ${_alarmsBox!.path}');
    } catch (e, stackTrace) {
      // Log detailed error
      debugPrint('❌ Hive initialization failed: $e');
      debugPrint('Stack trace: $stackTrace');

      // Try to recover by getting existing box if it's already open
      if (Hive.isBoxOpen(_alarmsBoxName)) {
        debugPrint('🔄 Attempting recovery: getting existing open box...');
        _alarmsBox = Hive.box<Map>(_alarmsBoxName);
        debugPrint('✅ Recovery successful');
      } else {
        // Re-throw with more context
        throw Exception('Failed to initialize Hive storage: $e');
      }
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
    debugPrint('💾 AlarmStorageService.saveAlarm() called');
    debugPrint('   - ID: ${alarm.id}');
    debugPrint('   - Name: ${alarm.name}');
    debugPrint('   - Active: ${alarm.isActive}');
    debugPrint('   - Box path: ${_box.path}');
    debugPrint('   - Box length before: ${_box.length}');

    await _box.put(alarm.id, alarm.toJson());

    debugPrint('   - Box length after: ${_box.length}');
    debugPrint('   - Alarm keys in box: ${_box.keys.toList()}');
    debugPrint('✅ Alarm saved to Hive');
  }

  /// Get all saved alarms
  static List<Alarm> getAllAlarms() {
    try {
      debugPrint('📖 AlarmStorageService.getAllAlarms() called');
      debugPrint('   - Box length: ${_box.length}');
      debugPrint('   - Box keys: ${_box.keys.toList()}');

      final alarmMaps = _box.values.toList();
      final alarms = alarmMaps
          .map((map) => Alarm.fromJson(Map<String, dynamic>.from(map)))
          .toList();

      debugPrint('   - Loaded ${alarms.length} alarms:');
      for (var alarm in alarms) {
        debugPrint('     • ${alarm.name} (ID: ${alarm.id}, Active: ${alarm.isActive}, Completed: ${alarm.isCompleted})');
      }

      return alarms;
    } catch (e) {
      debugPrint('❌ Error loading alarms: $e');
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
