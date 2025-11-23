import 'dart:async';
import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vibration/vibration.dart';
import 'settings_service.dart';
import 'native_ios_geofence_service.dart';

/// Available alarm ringtones - uses MP3 files from assets/sounds/
enum AlarmRingtone {
  alarm('Default Alarm', 'alarm.mp3'),
  digital('Digital', 'digital_alarm.mp3'),
  gentle('Gentle', 'gentle_alarm.mp3'),
  melody('Melody', 'melody_alarm.mp3'),
  urgent('Urgent', 'urgent_alarm.mp3');

  final String displayName;
  final String fileName; // The actual MP3 file name in assets/sounds/

  const AlarmRingtone(this.displayName, this.fileName);

  /// Get the asset file path for audio player
  String get assetPath => 'sounds/$fileName';

  /// Get just the file name without extension (for native iOS)
  String get soundId => fileName.replaceAll('.mp3', '');

  static AlarmRingtone fromString(String? value) {
    if (value == null) return AlarmRingtone.alarm;
    return AlarmRingtone.values.firstWhere(
      (e) => e.name == value || e.soundId == value || e.fileName == value,
      orElse: () => AlarmRingtone.alarm,
    );
  }
}

/// Service to manage alarm sounds and vibration
class AlarmSoundService {
  static final AlarmSoundService _instance = AlarmSoundService._internal();
  factory AlarmSoundService() => _instance;
  AlarmSoundService._internal();

  AudioPlayer? _audioPlayer;
  bool _isPlaying = false;
  String? _currentAlarmId;
  Timer? _vibrationTimer;
  bool _callbackRegistered = false;

  /// Lazy getter for NativeIOSGeofenceService - avoids circular initialization
  NativeIOSGeofenceService? _nativeIOSServiceInstance;
  NativeIOSGeofenceService get _nativeIOSService {
    _nativeIOSServiceInstance ??= NativeIOSGeofenceService();
    // Register callback if not already done
    if (!_callbackRegistered) {
      _callbackRegistered = true;
      _nativeIOSServiceInstance!.onStopAlarmRequested = () async {
        await stopAlarm();
      };
    }
    return _nativeIOSServiceInstance!;
  }

  /// Start playing alarm sound with vibration
  /// soundLevel: 'Loud', 'Medium', or 'Soft'
  /// ringtone: Optional ringtone selection
  Future<void> startAlarm({
    required String alarmId,
    String soundLevel = 'Loud',
    String? ringtone,
  }) async {
    debugPrint('═══════════════════════════════════════════════');
    debugPrint('🔊 START ALARM SOUND CALLED');
    debugPrint('   - Alarm ID: $alarmId');
    debugPrint('   - Sound Level: $soundLevel');
    debugPrint('   - Ringtone: $ringtone');
    debugPrint('   - Currently playing: $_isPlaying');
    debugPrint('   - Current alarm ID: $_currentAlarmId');
    debugPrint('   - Platform: ${Platform.isIOS ? "iOS" : "Android"}');
    debugPrint('═══════════════════════════════════════════════');

    // Don't start if already playing this alarm
    if (_isPlaying && _currentAlarmId == alarmId) {
      debugPrint('⏰ Alarm already playing for: $alarmId');
      return;
    }

    // Stop any existing alarm first
    await stopAlarm();

    debugPrint('🔊 Initializing alarm sound...');
    _currentAlarmId = alarmId;
    _isPlaying = true;

    // Determine which ringtone to play
    final selectedRingtone = AlarmRingtone.fromString(ringtone);

    try {
      if (Platform.isIOS) {
        // Use native iOS system sounds - these bypass silent mode and play at system volume
        debugPrint('🍎 Using iOS system sound: ${selectedRingtone.soundId}');
        await _nativeIOSService.playSystemSound(
          soundType: selectedRingtone.soundId,
          loop: true,
        );
        debugPrint('✅ iOS system sound started successfully');
      } else {
        // Android: use AudioPlayer with asset files
        await _startAndroidAlarm(soundLevel, selectedRingtone);
      }

      // Start vibration pattern (works on both platforms)
      debugPrint('📳 Starting vibration...');
      await _startVibration(soundLevel);
    } catch (e, stackTrace) {
      debugPrint('❌❌❌ ERROR STARTING ALARM SOUND ❌❌❌');
      debugPrint('Error: $e');
      debugPrint('Stack trace: $stackTrace');
      // Fallback: just vibrate
      debugPrint('🔄 Attempting vibration fallback...');
      await _startVibration(soundLevel);
    }

    debugPrint('═══════════════════════════════════════════════');
  }

  /// Start alarm sound on Android using AudioPlayer
  Future<void> _startAndroidAlarm(String soundLevel, AlarmRingtone selectedRingtone) async {
    debugPrint('🤖 Using Android AudioPlayer...');
    _audioPlayer = AudioPlayer();

    // Configure audio player for ALARM playback
    debugPrint('🎵 Configuring audio session for ALARM playback...');
    await _audioPlayer!.setPlayerMode(PlayerMode.mediaPlayer);

    // Set audio context for alarm - bypasses silent mode on Android
    final audioContext = AudioContext(
      iOS: AudioContextIOS(
        category: AVAudioSessionCategory.playback,
        options: {AVAudioSessionOptions.duckOthers},
      ),
      android: AudioContextAndroid(
        isSpeakerphoneOn: true,
        stayAwake: true,
        contentType: AndroidContentType.sonification,
        usageType: AndroidUsageType.alarm,
        audioFocus: AndroidAudioFocus.gainTransientMayDuck,
      ),
    );
    await _audioPlayer!.setAudioContext(audioContext);
    debugPrint('✅ Audio session configured for ALARM mode');

    // Set volume based on sound level
    final volume = _getVolumeFromLevel(soundLevel);
    debugPrint('🎵 Setting volume to: $volume');
    await _audioPlayer!.setVolume(volume);

    // Set to loop continuously
    await _audioPlayer!.setReleaseMode(ReleaseMode.loop);

    // Use the ringtone's asset path
    final source = AssetSource(selectedRingtone.assetPath);
    debugPrint('🎵 Playing sound from: ${selectedRingtone.assetPath}');

    await _audioPlayer!.play(source);
    debugPrint('✅ Android alarm sound started successfully');
  }

  /// Stop playing alarm sound and vibration
  Future<void> stopAlarm() async {
    if (!_isPlaying) return;

    debugPrint('🛑 Stopping alarm sound');

    try {
      // Stop iOS system sound if on iOS
      if (Platform.isIOS) {
        await _nativeIOSService.stopSystemSound();
      }

      // Stop audio player (for Android or fallback)
      if (_audioPlayer != null) {
        await _audioPlayer!.stop();
        await _audioPlayer!.dispose();
        _audioPlayer = null;
      }

      // Stop vibration timer
      _vibrationTimer?.cancel();
      _vibrationTimer = null;

      // Stop any ongoing vibration
      try {
        await Vibration.cancel();
      } catch (e) {
        debugPrint('⚠️ Error canceling vibration: $e');
      }

      _isPlaying = false;
      _currentAlarmId = null;

      debugPrint('✅ Alarm sound stopped');
    } catch (e) {
      debugPrint('❌ Error stopping alarm sound: $e');
      _isPlaying = false;
      _currentAlarmId = null;
    }
  }

  /// Start vibration pattern based on sound level
  /// Uses a timer-based approach for iOS compatibility
  Future<void> _startVibration(String soundLevel) async {
    try {
      // Check if vibration is enabled in settings
      if (!SettingsService.vibrationEnabled) {
        debugPrint('⚠️ Vibration is disabled in settings');
        return;
      }

      // Check if device supports vibration
      bool? hasVibrator;
      try {
        hasVibrator = await Vibration.hasVibrator();
      } catch (e) {
        debugPrint('⚠️ Could not check vibrator support: $e');
        hasVibrator = false;
      }

      if (hasVibrator != true) {
        debugPrint('⚠️ Device does not support vibration (or simulator)');
        // On iOS simulator, use haptic feedback as fallback
        if (Platform.isIOS) {
          _startHapticFeedbackLoop(soundLevel);
        }
        return;
      }

      // For iOS, use a timer-based vibration since patterns don't work well
      if (Platform.isIOS) {
        _startIOSVibrationLoop(soundLevel);
      } else {
        // For Android, use pattern-based vibration
        await _startAndroidVibration(soundLevel);
      }
    } catch (e) {
      debugPrint('❌ Error starting vibration: $e');
    }
  }

  /// Start iOS vibration using timer-based approach
  void _startIOSVibrationLoop(String soundLevel) {
    // Cancel any existing timer
    _vibrationTimer?.cancel();

    // Determine interval based on sound level
    final interval = soundLevel.toLowerCase() == 'loud'
        ? const Duration(milliseconds: 800)
        : soundLevel.toLowerCase() == 'medium'
            ? const Duration(milliseconds: 1200)
            : const Duration(milliseconds: 1800);

    debugPrint('📳 Starting iOS vibration loop with interval: ${interval.inMilliseconds}ms');

    // Start periodic vibration
    _vibrationTimer = Timer.periodic(interval, (_) async {
      if (_isPlaying) {
        try {
          // Use default vibration duration for iOS
          await Vibration.vibrate(duration: 500);
        } catch (e) {
          // Silently fail - might be on simulator
        }
      } else {
        _vibrationTimer?.cancel();
      }
    });

    // Trigger first vibration immediately
    Vibration.vibrate(duration: 500).catchError((_) {});
  }

  /// Start haptic feedback loop for iOS simulator
  void _startHapticFeedbackLoop(String soundLevel) {
    _vibrationTimer?.cancel();

    final interval = soundLevel.toLowerCase() == 'loud'
        ? const Duration(milliseconds: 500)
        : soundLevel.toLowerCase() == 'medium'
            ? const Duration(milliseconds: 800)
            : const Duration(milliseconds: 1200);

    debugPrint('📳 Starting haptic feedback loop (simulator fallback)');

    _vibrationTimer = Timer.periodic(interval, (_) {
      if (_isPlaying) {
        HapticFeedback.heavyImpact();
      } else {
        _vibrationTimer?.cancel();
      }
    });

    // Trigger first haptic immediately
    HapticFeedback.heavyImpact();
  }

  /// Start Android pattern-based vibration
  Future<void> _startAndroidVibration(String soundLevel) async {
    // Check if device supports custom vibration patterns
    bool? hasCustomVibrations;
    try {
      hasCustomVibrations = await Vibration.hasCustomVibrationsSupport();
    } catch (e) {
      hasCustomVibrations = false;
    }

    if (hasCustomVibrations == true) {
      // Create vibration pattern based on sound level
      final pattern = _getVibrationPattern(soundLevel);

      // Start repeating vibration pattern
      await Vibration.vibrate(
        pattern: pattern,
        repeat: 0, // Repeat from index 0 (continuous loop)
      );

      debugPrint('✅ Android vibration started with pattern: $pattern');
    } else {
      // Simple vibration for devices that don't support patterns
      // Use timer-based approach
      _startIOSVibrationLoop(soundLevel);
    }
  }

  /// Get volume level (0.0 to 1.0) from sound level string
  double _getVolumeFromLevel(String soundLevel) {
    switch (soundLevel.toLowerCase()) {
      case 'loud':
        return 1.0;
      case 'medium':
        return 0.7;
      case 'soft':
        return 0.4;
      default:
        return 1.0;
    }
  }

  /// Get vibration pattern from sound level (for Android)
  /// Pattern format: [wait, vibrate, wait, vibrate, ...]
  /// Pattern repeats continuously when used with repeat: 0
  List<int> _getVibrationPattern(String soundLevel) {
    switch (soundLevel.toLowerCase()) {
      case 'loud':
        // Aggressive pattern: 800ms vibrate, 200ms pause
        return [0, 800, 200];
      case 'medium':
        // Moderate pattern: 600ms vibrate, 400ms pause
        return [0, 600, 400];
      case 'soft':
        // Gentle pattern: 400ms vibrate, 600ms pause
        return [0, 400, 600];
      default:
        return [0, 800, 200];
    }
  }

  /// Check if alarm is currently playing
  bool get isPlaying => _isPlaying;

  /// Get current alarm ID
  String? get currentAlarmId => _currentAlarmId;

  /// Get list of available ringtones
  static List<AlarmRingtone> get availableRingtones => AlarmRingtone.values;

  /// Dispose resources
  void dispose() {
    _vibrationTimer?.cancel();
    stopAlarm();
  }
}
