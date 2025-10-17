# Alarm Sound Assets

## Adding an Alarm Sound

Place an MP3 file named `alarm.mp3` in this directory to use a custom alarm sound.

### Recommended Sound Specifications:
- **Format**: MP3
- **Sample Rate**: 44.1 kHz
- **Bitrate**: 128-192 kbps
- **Duration**: 3-5 seconds (will loop automatically)
- **Volume**: Normalized to -3dB peak

### Free Alarm Sound Resources:
- [Freesound.org](https://freesound.org/) - Search for "alarm" or "ringtone"
- [Zapsplat.com](https://www.zapsplat.com/) - Free sound effects
- [Pixabay Audio](https://pixabay.com/music/) - Royalty-free audio

### Example Sound Download:
1. Go to https://freesound.org/
2. Search for "alarm clock"
3. Download a free sound (requires account)
4. Convert to MP3 if needed
5. Rename to `alarm.mp3`
6. Place in this directory

### Testing Without Custom Sound:
If no `alarm.mp3` file is present, the app will:
1. Attempt to play the asset (will fail silently)
2. Fall back to vibration only
3. Show notification

### Alternative: Use Device System Sound

You can modify `lib/services/alarm_sound_service.dart` to use a URL-based sound:

```dart
// Use a web-hosted alarm sound (temporary for testing)
final source = UrlSource('https://example.com/alarm.mp3');
await _audioPlayer!.play(source);
```

Or use a low-latency asset:

```dart
// Use built-in notification sound (Android/iOS)
// Requires platform-specific configuration
```

## Current Status

**⚠️ No alarm.mp3 file present** - App will vibrate but not play sound.

To enable sound:
1. Add an `alarm.mp3` file to this directory
2. Run `flutter pub get` (if needed)
3. Rebuild the app: `flutter run`
