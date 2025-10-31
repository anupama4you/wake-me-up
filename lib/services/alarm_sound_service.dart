import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:vibration/vibration.dart';
import 'settings_service.dart';

/// Service to manage alarm sounds and vibration
class AlarmSoundService {
  static final AlarmSoundService _instance = AlarmSoundService._internal();
  factory AlarmSoundService() => _instance;
  AlarmSoundService._internal();

  AudioPlayer? _audioPlayer;
  bool _isPlaying = false;
  String? _currentAlarmId;

  /// Start playing alarm sound with vibration
  /// soundLevel: 'loud', 'medium', or 'soft'
  Future<void> startAlarm({
    required String alarmId,
    String soundLevel = 'loud',
  }) async {
    debugPrint('═══════════════════════════════════════════════');
    debugPrint('🔊 START ALARM SOUND CALLED');
    debugPrint('   - Alarm ID: $alarmId');
    debugPrint('   - Sound Level: $soundLevel');
    debugPrint('   - Currently playing: $_isPlaying');
    debugPrint('   - Current alarm ID: $_currentAlarmId');
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

    try {
      // Initialize audio player
      debugPrint('🎵 Creating AudioPlayer instance...');
      _audioPlayer = AudioPlayer();

      // Configure audio player for background playback
      debugPrint('🎵 Configuring audio session for background playback...');
      await _audioPlayer!.setPlayerMode(PlayerMode.mediaPlayer);

      // Set audio context for iOS background playback
      final audioContext = AudioContext(
        iOS: AudioContextIOS(
          category: AVAudioSessionCategory.playback,
          options: {
            AVAudioSessionOptions.mixWithOthers,
            AVAudioSessionOptions.duckOthers,
          },
        ),
        android: AudioContextAndroid(
          isSpeakerphoneOn: true,
          stayAwake: true,
          contentType: AndroidContentType.sonification,
          usageType: AndroidUsageType.alarm,
          audioFocus: AndroidAudioFocus.gain,
        ),
      );
      await _audioPlayer!.setAudioContext(audioContext);
      debugPrint('✅ Audio session configured for background');

      // Set volume based on sound level
      final volume = _getVolumeFromLevel(soundLevel);
      debugPrint('🎵 Setting volume to: $volume');
      await _audioPlayer!.setVolume(volume);

      // Set to loop continuously
      debugPrint('🎵 Setting release mode to loop...');
      await _audioPlayer!.setReleaseMode(ReleaseMode.loop);

      // Use a default system alarm sound URL
      // This is a built-in Android/iOS alarm tone
      final source = AssetSource('sounds/alarm.mp3');
      debugPrint('🎵 Playing sound from: sounds/alarm.mp3');

      // Play the sound
      await _audioPlayer!.play(source);

      debugPrint('✅ Alarm sound started successfully');

      // Start vibration pattern
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

  /// Stop playing alarm sound and vibration
  Future<void> stopAlarm() async {
    if (!_isPlaying) return;

    debugPrint('🛑 Stopping alarm sound');

    try {
      // Stop audio
      if (_audioPlayer != null) {
        await _audioPlayer!.stop();
        await _audioPlayer!.dispose();
        _audioPlayer = null;
      }

      // Stop vibration
      await Vibration.cancel();

      _isPlaying = false;
      _currentAlarmId = null;

      debugPrint('✅ Alarm sound stopped');
    } catch (e) {
      debugPrint('❌ Error stopping alarm sound: $e');
    }
  }

  /// Start vibration pattern based on sound level
  Future<void> _startVibration(String soundLevel) async {
    try {
      // Check if vibration is enabled in settings
      if (!SettingsService.vibrationEnabled) {
        debugPrint('⚠️ Vibration is disabled in settings');
        return;
      }

      // Check if device supports vibration
      final hasVibrator = await Vibration.hasVibrator();
      if (!hasVibrator) {
        debugPrint('⚠️ Device does not support vibration');
        return;
      }

      // Check if device supports custom vibration patterns
      final hasCustomVibrations =
          await Vibration.hasCustomVibrationsSupport();

      if (hasCustomVibrations) {
        // Create vibration pattern based on sound level
        final pattern = _getVibrationPattern(soundLevel);

        // Start repeating vibration pattern
        await Vibration.vibrate(
          pattern: pattern,
          repeat: 0, // Repeat from index 0 (continuous loop)
        );

        debugPrint('✅ Vibration started with pattern: $pattern');
      } else {
        // Simple vibration for devices that don't support patterns
        final duration = soundLevel == 'loud'
            ? 1000
            : soundLevel == 'medium'
                ? 500
                : 300;

        await Vibration.vibrate(duration: duration);
        debugPrint('✅ Simple vibration started');
      }
    } catch (e) {
      debugPrint('❌ Error starting vibration: $e');
    }
  }

  /// Get volume level (0.0 to 1.0) from sound level string
  double _getVolumeFromLevel(String soundLevel) {
    switch (soundLevel.toLowerCase()) {
      case 'loud':
        return 1.0;
      case 'medium':
        return 0.6;
      case 'soft':
        return 0.3;
      default:
        return 1.0;
    }
  }

  /// Get vibration pattern from sound level
  /// Pattern format: [wait, vibrate, wait, vibrate, ...]
  /// Pattern repeats continuously when used with repeat: 0
  List<int> _getVibrationPattern(String soundLevel) {
    switch (soundLevel.toLowerCase()) {
      case 'loud':
        // Aggressive pattern: 1000ms vibrate, 100ms pause (nearly continuous)
        return [0, 1000, 100];
      case 'medium':
        // Moderate pattern: 700ms vibrate, 300ms pause
        return [0, 700, 300];
      case 'soft':
        // Gentle pattern: 500ms vibrate, 500ms pause
        return [0, 500, 500];
      default:
        return [0, 1000, 100];
    }
  }

  /// Check if alarm is currently playing
  bool get isPlaying => _isPlaying;

  /// Get current alarm ID
  String? get currentAlarmId => _currentAlarmId;

  /// Dispose resources
  void dispose() {
    stopAlarm();
  }
}
