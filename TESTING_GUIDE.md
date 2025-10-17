# Testing Guide - Alarm Storage & Geofencing

## Running the App with Debug Logs

```bash
cd /Users/anupama4you/projects/wakemeup
flutter run
```

## Test Case 1: Save Alarm (Start Now)

### Steps:
1. Launch the app
2. Tap the "+" button to add a new alarm
3. Select a location (search or drop a pin)
4. Tap "Next" to go to Alarm Settings
5. Enter a name (e.g., "Test Alarm 1")
6. Tap **"Start Alarm"** button

### Expected Logs:
```
💾 Saving alarm to storage: Test Alarm 1 (ID: 1234567890)
   - ID: 1234567890
   - Name: Test Alarm 1
   - Active: true
   - Box path: /path/to/hive/alarms
   - Box length before: 0
💾 AlarmStorageService.saveAlarm() called
   - Box length after: 1
   - Alarm keys in box: [1234567890]
✅ Alarm saved to Hive
✅ Alarm saved successfully to Hive
✅ Verified: Alarm found in storage with isActive=true
📍 Starting geofencing for alarm: Test Alarm 1
✅ Geofencing started for: Test Alarm 1
```

### Verification:
- [ ] Alarm appears in the main screen alarm list
- [ ] Alarm toggle is ON (green)
- [ ] No error messages shown
- [ ] Geofencing started message appears

---

## Test Case 2: Save Alarm (Save for Later)

### Steps:
1. Tap the "+" button
2. Select a location
3. Configure alarm settings
4. Tap **"Save for Later"** button

### Expected Logs:
```
💾 Saving alarm to storage: Test Alarm 2 (ID: 1234567891)
   - Active: false
   - Box length before: 1
   - Box length after: 2
✅ Alarm saved to Hive
✅ Verified: Alarm found in storage with isActive=false
```

### Verification:
- [ ] Alarm appears in the main screen
- [ ] Alarm toggle is OFF (grey)
- [ ] No geofencing started (not active)
- [ ] Success snackbar shown

---

## Test Case 3: Load Alarms on App Restart

### Steps:
1. Create 2-3 alarms (mix of active and inactive)
2. **Completely close the app** (swipe away from app switcher)
3. Reopen the app

### Expected Logs:
```
📦 Calling Hive.initFlutter()...
📦 Hive.initFlutter() completed
📦 Opening box: alarms...
📦 Box opened successfully: /path/to/alarms
✅ AlarmStorageService initialized successfully
🔄 MainScreen: Loading alarms from storage...
📖 AlarmStorageService.getAllAlarms() called
   - Box length: 3
   - Box keys: [1234567890, 1234567891, 1234567892]
   - Loaded 3 alarms:
     • Test Alarm 1 (ID: 1234567890, Active: true)
     • Test Alarm 2 (ID: 1234567891, Active: false)
     • Test Alarm 3 (ID: 1234567892, Active: true)
🔄 MainScreen: Loaded 3 alarms from storage
✅ MainScreen: State updated with 3 alarms
🔄 Syncing geofences with stored alarms...
📍 Starting geofencing for alarm: Test Alarm 1
✅ Geofencing started for: Test Alarm 1
📍 Starting geofencing for alarm: Test Alarm 3
✅ Geofencing started for: Test Alarm 3
✅ Synced 2 active alarms
✅ Geofences synced with active alarms
```

### Verification:
- [ ] All alarms loaded from storage
- [ ] Active alarms have their toggle ON
- [ ] Inactive alarms have their toggle OFF
- [ ] Geofences restored for active alarms only
- [ ] No "alarm service not initiated" error

---

## Test Case 4: Toggle Alarm On/Off

### Steps:
1. From main screen, toggle an alarm OFF (if it's ON)
2. Toggle it back ON

### Expected Logs (Toggle OFF):
```
🛑 Stopping geofencing for alarm: 1234567890
✅ Geofence removed for: 1234567890
```

### Expected Logs (Toggle ON):
```
📍 Starting geofencing for alarm: Test Alarm 1
✅ Geofencing started for: Test Alarm 1
```

### Verification:
- [ ] Toggle state changes immediately in UI
- [ ] Geofence starts/stops correctly
- [ ] Changes persist after app restart

---

## Test Case 5: Delete Alarm

### Steps:
1. Long-press or swipe to delete an alarm
2. Confirm deletion

### Expected Logs:
```
🛑 Stopping geofencing for deleted alarm: 1234567890
✅ Geofence removed for: 1234567890
```

### Verification:
- [ ] Alarm removed from UI
- [ ] Alarm removed from storage
- [ ] Geofence stopped
- [ ] After app restart, alarm doesn't reappear

---

## Troubleshooting

### Issue: "Alarm service not initiated"

**Check logs for:**
```
❌ Hive initialization failed: [error]
```

**Solutions:**
- Ensure app has storage permissions
- Check that Hive initialization completed
- Try uninstalling and reinstalling the app

---

### Issue: Alarms not showing after restart

**Check logs for:**
```
📖 AlarmStorageService.getAllAlarms() called
   - Box length: 0
```

**Solutions:**
- Verify alarms were actually saved (check save logs)
- Check Hive box path is accessible
- Ensure app wasn't uninstalled (clears app data)

---

### Issue: Geofencing not starting

**Check logs for:**
```
❌ Error starting geofencing: [error]
```

**Solutions:**
- Grant location permissions ("Always" on iOS)
- Enable location services
- Check for permission denied errors in logs

---

## Expected Storage Behavior

### What Gets Saved:
✅ Alarm ID (unique identifier)
✅ Alarm name
✅ Location coordinates (lat/lng)
✅ Address
✅ Radius
✅ Sound level
✅ Active state (true/false)

### When Data Is Saved:
- When you tap "Start Alarm" → Saved with `isActive: true`
- When you tap "Save for Later" → Saved with `isActive: false`
- When you toggle alarm on/off → Updated in storage
- When you delete alarm → Removed from storage

### When Data Is Loaded:
- On app startup (after Hive initialization)
- After adding/editing an alarm
- After toggling or deleting an alarm (state update)

---

## Performance Metrics

### Expected Timing:
- **Hive initialization**: < 500ms
- **Save alarm**: < 50ms
- **Load all alarms**: < 100ms (for 100 alarms)
- **Start geofencing**: < 1000ms

### Memory Usage:
- Each alarm: ~200 bytes in storage
- 100 alarms: ~20KB total
- Negligible memory footprint

---

## Logs Legend

| Icon | Meaning |
|------|---------|
| 📦 | Hive/Storage operations |
| 💾 | Saving data |
| 📖 | Reading/Loading data |
| 🔄 | Syncing/Updating |
| 📍 | Location/Geofencing |
| 🎯 | Geofence event |
| ⏰ | Alarm trigger |
| ✅ | Success |
| ⚠️ | Warning |
| ❌ | Error |
| 🔔 | Notification/Alert |
| 🛑 | Stop/Remove |

---

## Quick Verification Checklist

Run through these quickly to verify everything works:

1. [ ] Create alarm with "Start Alarm" → Appears in list as active
2. [ ] Create alarm with "Save for Later" → Appears as inactive
3. [ ] Close and reopen app → Both alarms still there
4. [ ] Toggle alarm off → Stays off after restart
5. [ ] Toggle alarm on → Stays on after restart
6. [ ] Delete alarm → Gone after restart
7. [ ] Check logs for any ❌ errors
8. [ ] All geofencing started messages appear for active alarms

If all checks pass, storage and geofencing are working correctly! ✅
