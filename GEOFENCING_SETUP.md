# Background Geofencing Setup Guide

## Overview

This app now supports **native background geofencing**, which means your location-based alarms will trigger even when:
- The app is completely closed
- The system terminates the app
- Your device screen is off
- Your device reboots (Android only - requires one-time app launch after reboot)

## How It Works

### 1. Geofence Registration
When you activate an alarm (or start it immediately), the app:
- Registers a native geofence with your device's operating system
- Sets up a circular region around your selected location
- Configures the radius based on your alarm settings (100m - 2km)

### 2. Background Monitoring
The operating system continuously monitors your location in the background:
- Uses native GPS/location services (iOS Core Location, Android Geofencing API)
- Optimizes battery usage with activity recognition
- Checks location every 5 seconds when moving
- Reduces frequency when stationary

### 3. Alarm Triggering
When you enter the geofence region:
- The OS wakes up the app (even if closed)
- A notification is displayed with the alarm name and location
- Sound plays based on your selected sound level (Loud/Medium/Soft)
- Full-screen notification appears for critical alarms

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                   Flutter App Layer                     │
│  ┌─────────────────┐  ┌──────────────────────────────┐ │
│  │ Alarm Settings  │  │  Main Screen                 │ │
│  │ Screen          │  │  - Toggle alarms             │ │
│  │ - Start alarm   │  │  - Delete alarms             │ │
│  └────────┬────────┘  └──────────┬───────────────────┘ │
│           │                      │                      │
│           └──────────┬───────────┘                      │
│                      ▼                                  │
│         ┌────────────────────────┐                      │
│         │ GeofenceAlarmService   │                      │
│         │ - Initialize           │                      │
│         │ - Start geofencing     │                      │
│         │ - Stop geofencing      │                      │
│         │ - Sync geofences       │                      │
│         └────────────┬───────────┘                      │
└──────────────────────┼──────────────────────────────────┘
                       │
        ┌──────────────┴──────────────┐
        ▼                             ▼
┌────────────────┐           ┌────────────────┐
│ iOS            │           │ Android        │
│ Core Location  │           │ Geofencing API │
│ - Background   │           │ - Foreground   │
│   modes        │           │   service      │
│ - Geofence     │           │ - Boot         │
│   monitoring   │           │   receiver     │
└────────────────┘           └────────────────┘
```

## Files Modified/Created

### Core Service
- **`lib/services/geofence_service.dart`** (NEW)
  - Main geofencing service with singleton pattern
  - Manages geofence lifecycle (add, remove, sync)
  - Handles notifications and callbacks
  - Battery optimization with activity recognition

### Integration
- **`lib/screens/map/alarm_settings_screen.dart`**
  - Starts geofencing when "Start Alarm" is pressed

- **`lib/screens/main_screen.dart`**
  - Syncs geofences on app startup (restores after app restart)
  - Starts/stops geofencing when alarms are toggled
  - Removes geofences when alarms are deleted

### Configuration

#### iOS ([ios/Runner/Info.plist](ios/Runner/Info.plist))
```xml
<!-- Background modes -->
<key>UIBackgroundModes</key>
<array>
    <string>location</string>
    <string>fetch</string>
    <string>processing</string>
</array>

<!-- Location permissions -->
<key>NSLocationWhenInUseUsageDescription</key>
<key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
<key>NSLocationAlwaysUsageDescription</key>

<!-- Motion/Activity recognition -->
<key>NSMotionUsageDescription</key>
```

#### Android ([android/app/src/main/AndroidManifest.xml](android/app/src/main/AndroidManifest.xml))
```xml
<!-- Permissions -->
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_BACKGROUND_LOCATION" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_LOCATION" />
<uses-permission android:name="android.permission.WAKE_LOCK" />
<uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED" />
<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
<uses-permission android:name="android.permission.ACTIVITY_RECOGNITION" />

<!-- Foreground service -->
<service android:name="com.lamnhan.fl_location.service.ForegroundLocationService"
         android:foregroundServiceType="location" />
```

## Dependencies Added

```yaml
dependencies:
  flutter_local_notifications: ^17.0.0  # For notifications
  geofencing_api: ^2.0.0               # For geofencing (modern API)
```

**Note:** We use `geofencing_api` instead of the deprecated `geofence_service`. The new library provides:
- Modern API design
- Better performance
- Active maintenance
- Built on top of `fl_location` for reliable location tracking

## Permissions Required

### iOS
- **Location When In Use**: Required for initial location access
- **Location Always**: Required for background geofencing
- **Motion & Fitness**: Optional, for battery optimization

The app will request these permissions when you first activate an alarm.

### Android
- **Location (Fine & Background)**: Required for geofencing
- **Foreground Service**: Required to run in background
- **Notifications**: Required for alarm notifications (Android 13+)
- **Activity Recognition**: Optional, for battery optimization
- **Boot Completed**: To restore geofences after device reboot

## Usage Flow

### Creating and Activating an Alarm

1. **Set Location**:
   - Search for a location or drop a pin on the map

2. **Configure Alarm**:
   - Set alarm name
   - Adjust trigger radius (100m - 2km)
   - Choose sound level (Loud/Medium/Soft)

3. **Start Alarm**:
   - Press "Start Alarm" button
   - Grant location permissions if prompted
   - Geofence is registered with the OS
   - Background monitoring begins

4. **Background Monitoring**:
   - App continues monitoring even when closed
   - No need to keep app open or in foreground
   - System manages battery optimization

5. **Arrival Notification**:
   - When you enter the geofence region
   - Notification appears with alarm details
   - Sound plays based on your settings

### Saving for Later

If you press "Save for Later":
- Alarm is saved to local storage
- No geofence is registered (alarm is inactive)
- You can activate it later from the home screen
- Toggle the switch to start background monitoring

### Toggling Alarms

From the home screen:
- **Toggle ON**: Starts geofencing for that alarm
- **Toggle OFF**: Stops geofencing
- Only one alarm can be active at a time

### Deleting Alarms

When you delete an alarm:
- Geofence is automatically removed
- Background monitoring for that location stops
- Alarm data is removed from local storage

## App Lifecycle Behavior

### App Restart
- When app restarts, it automatically syncs geofences
- All active alarms have their geofences restored
- No manual intervention required

### Device Reboot (Android)
- Boot receiver automatically triggers
- Geofences are restored on first app launch after reboot
- iOS handles this automatically without receiver

### App Termination
- Geofences persist even if app is force-closed
- OS continues monitoring in the background
- Notifications will still trigger when entering regions

## Battery Optimization

The geofencing implementation includes several battery-saving features:

1. **Activity Recognition**: Reduces location checks when stationary
2. **Adaptive Frequency**: Checks every 5s when moving, less when still
3. **Native OS APIs**: Uses platform-optimized geofencing
4. **Radius-based Sorting**: Prioritizes closer geofences
5. **Smart Wake-up**: Only wakes app when necessary

### Recommended Settings
- **Radius**: Use larger radius (500m+) for better battery life
- **Sound Level**: Lower sound uses less resources
- **Active Alarms**: Keep only necessary alarms active

## Troubleshooting

### Notifications Not Showing

**iOS:**
- Check Settings → Notifications → Wakemeup → Allow Notifications
- Ensure "Critical Alerts" is enabled for important alarms
- Check Do Not Disturb settings

**Android:**
- Go to Settings → Apps → Wakemeup → Notifications
- Ensure "Location Alarms" channel is enabled
- Check battery optimization settings (disable for Wakemeup)
- Grant "Display over other apps" permission

### Geofencing Not Working

1. **Check Permissions**:
   - Ensure "Always" location permission is granted
   - On Android 11+, manually enable background location in settings

2. **Check Location Services**:
   - Location services must be enabled on device
   - High accuracy mode recommended

3. **Check Battery Settings**:
   - Disable battery optimization for Wakemeup
   - Android: Settings → Battery → Battery Optimization → Wakemeup → Don't optimize
   - iOS: Settings → Battery → Low Power Mode (may limit background activity)

4. **Check Logs**:
   - Run app from terminal: `flutter run`
   - Look for debug messages starting with:
     - `🔔` Geofence initialization
     - `📍` Geofence registration
     - `🎯` Geofence status changes
     - `⏰` Alarm triggered

### Geofences Lost After Update

If geofences are cleared after app update:
- Simply toggle the alarm OFF and ON again
- Or restart the app to auto-sync

## Testing

### Testing Geofences Without Travel

**iOS Simulator:**
```bash
# Set location to alarm location
Features → Location → Custom Location
# Wait a few seconds, then move to different location
Features → Location → Custom Location (different coordinates)
```

**Android Emulator:**
```bash
# In Extended Controls (⋮) → Location
1. Set location to alarm coordinates
2. Wait ~10 seconds
3. Set location to different coordinates inside/outside radius
```

**Physical Device:**
- Use a VPN or location spoofing app
- Or test with a short trip to nearby location

### Debug Logging

The app includes comprehensive debug logging:
```
📦 Hive/Storage operations
🔔 Geofencing initialization
📍 Location changes
🎯 Geofence status changes
⏰ Alarm triggers
✅ Success messages
⚠️ Warnings
❌ Errors
```

Run with: `flutter run` to see real-time logs

## Known Limitations

1. **iOS Background Limits**: iOS may limit background location after 24 hours of continuous use
2. **Android Doze Mode**: Geofences may be delayed in Doze mode (add Wakemeup to battery optimization exceptions)
3. **Geofence Accuracy**: Typically 30-100m accuracy depending on GPS signal
4. **Network Required**: Some platforms require network for geofence registration
5. **Maximum Geofences**: Limited to 100 active geofences per app (OS limit)

## Privacy & Data

- Location data is only used for geofencing
- No location data is sent to external servers
- All data stored locally using Hive database
- Geofences are managed by device OS, not our servers

## Future Enhancements

Potential improvements for future versions:
- [ ] Sound/ringtone customization per alarm
- [ ] Repeating alarms (daily/weekly schedules)
- [ ] Multiple active alarms simultaneously
- [ ] Alarm history and statistics
- [ ] Smart radius suggestions based on location type
- [ ] Low battery mode with reduced accuracy
- [ ] Export/import alarm configurations
- [ ] Alarm groups and categories

## Support

For issues or questions:
1. Check troubleshooting section above
2. Review debug logs for error messages
3. Ensure all permissions are granted
4. Check device OS version compatibility:
   - iOS 14.0+
   - Android 7.0+ (API 24+)

## Technical Details

### Geofence Service Configuration

```dart
Geofencing.instance.setup(
  interval: 5000,              // Check every 5 seconds
  accuracy: 100,               // 100m accuracy
  statusChangeDelay: 10000,    // 10s status change delay
  allowsMockLocation: false,   // Prevent fake GPS
  printsDebugLog: true,        // Debug logging
);
```

### Notification Priority Levels

- **Loud**: Max importance, full-screen notification, critical alert
- **Medium**: High importance, heads-up notification
- **Soft**: Default importance, standard notification

### Persistence Strategy

1. **Alarm Storage**: Hive database (key-value store)
2. **Geofence Storage**: OS-managed (survives app termination)
3. **Sync Strategy**: On app start, restore geofences for all active alarms
