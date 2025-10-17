# Geofencing Testing Plan

## Quick Test (5 minutes) - Emulator/Simulator

### Prerequisites
- App installed on emulator/simulator
- Location permissions granted

### Steps

1. **Launch app**
   ```bash
   flutter run
   ```

2. **Create test alarm**
   - Location: Union Square, San Francisco
   - Coordinates: 37.7879, -122.4075
   - Radius: 500m
   - Sound: Loud
   - Tap "Start Alarm"

3. **Verify alarm started**
   - Check logs for: `✅ Geofencing started for:`
   - Check logs for: `📍 Starting geofencing for alarm:`

4. **Set location OUTSIDE geofence**
   - **Android Emulator:** Extended Controls → Location
   - **iOS Simulator:** Features → Location → Custom Location
   - Latitude: `37.7849`
   - Longitude: `-122.4094`
   - Send/Apply

5. **Wait 10-15 seconds**
   - Watch logs for: `📍 Location changed:`
   - Should show you're outside (distance > 500m)

6. **Set location INSIDE geofence**
   - Latitude: `37.7879` (alarm center)
   - Longitude: `-122.4075` (alarm center)
   - Send/Apply

7. **Expected Results** ✅
   ```
   Console logs:
   📍 Location changed: 37.7879, -122.4075
   🎯 Geofence status changed:
     - Region ID: [your_alarm_id]
     - Status: enter
   ⏰ Alarm triggered: [your_alarm_id]
   ✅ Notification shown for alarm: Union Square

   Device:
   - Notification appears at top
   - Title: "⏰ Union Square"
   - Body: "You have arrived at [address]"
   ```

---

## Full Test Suite (30 minutes)

### Test 1: Basic Geofence Creation

**Objective:** Verify geofence registers correctly

| Step | Action | Expected Result | Pass/Fail |
|------|--------|-----------------|-----------|
| 1 | Create alarm with location | Alarm appears in list | ⬜ |
| 2 | Press "Start Alarm" | Navigate to tracking screen | ⬜ |
| 3 | Check logs | `✅ Geofencing started for: [name]` | ⬜ |
| 4 | Check permissions | Location permission = "Always" | ⬜ |

### Test 2: Geofence Entry Detection

**Objective:** Verify alarm triggers when entering geofence

| Step | Action | Expected Result | Pass/Fail |
|------|--------|-----------------|-----------|
| 1 | Start alarm | Geofence active | ⬜ |
| 2 | Set location outside radius | Logs show distance > radius | ⬜ |
| 3 | Wait 10 seconds | No notification | ⬜ |
| 4 | Set location inside radius | Notification appears | ⬜ |
| 5 | Check notification | Shows alarm name & address | ⬜ |

### Test 3: Background Execution

**Objective:** Verify geofencing works when app is closed

| Step | Action | Expected Result | Pass/Fail |
|------|--------|-----------------|-----------|
| 1 | Start alarm | Geofence active | ⬜ |
| 2 | Force close app | App not in recent apps | ⬜ |
| 3 | Simulate entering geofence | Notification appears | ⬜ |
| 4 | Verify timing | Within 15 seconds of entry | ⬜ |

### Test 4: Multiple Alarms

**Objective:** Verify multiple geofences work simultaneously

| Step | Action | Expected Result | Pass/Fail |
|------|--------|-----------------|-----------|
| 1 | Create 3 alarms at different locations | All saved | ⬜ |
| 2 | Activate alarm 1 only | Only 1 geofence active | ⬜ |
| 3 | Enter alarm 1 location | Notification for alarm 1 | ⬜ |
| 4 | Enter alarm 2 location (inactive) | No notification | ⬜ |

### Test 5: App Restart Persistence

**Objective:** Verify geofences restore after app restart

| Step | Action | Expected Result | Pass/Fail |
|------|--------|-----------------|-----------|
| 1 | Create and activate alarm | Geofence running | ⬜ |
| 2 | Force close app | App closed | ⬜ |
| 3 | Reopen app | Alarm still shows active | ⬜ |
| 4 | Check logs | `✅ Synced X active alarms` | ⬜ |
| 5 | Simulate entry | Notification appears | ⬜ |

### Test 6: Alarm Deactivation

**Objective:** Verify geofence stops when alarm deactivated

| Step | Action | Expected Result | Pass/Fail |
|------|--------|-----------------|-----------|
| 1 | Start alarm | Geofence active | ⬜ |
| 2 | Press "Finish & Return Home" | Returns to home | ⬜ |
| 3 | Check alarm status | Shows as inactive (toggle OFF) | ⬜ |
| 4 | Check logs | `🛑 Stopping geofencing for alarm` | ⬜ |
| 5 | Simulate entering location | No notification | ⬜ |

### Test 7: Permission Denial

**Objective:** Handle permission denial gracefully

| Step | Action | Expected Result | Pass/Fail |
|------|--------|-----------------|-----------|
| 1 | Revoke location permission | Permission denied | ⬜ |
| 2 | Try to start alarm | Permission requested | ⬜ |
| 3 | Deny permission | Error message shown | ⬜ |
| 4 | Alarm status | Remains inactive | ⬜ |

### Test 8: Location Services Disabled

**Objective:** Handle disabled location services

| Step | Action | Expected Result | Pass/Fail |
|------|--------|-----------------|-----------|
| 1 | Disable location services | Location OFF | ⬜ |
| 2 | Try to start alarm | Warning notification | ⬜ |
| 3 | Check logs | `🌍 Location services status: disabled` | ⬜ |

### Test 9: Radius Variations

**Objective:** Test different geofence radius sizes

| Radius | Location | Expected Trigger Distance | Pass/Fail |
|--------|----------|---------------------------|-----------|
| 100m | Test location 1 | ~100m from center | ⬜ |
| 500m | Test location 2 | ~500m from center | ⬜ |
| 1000m | Test location 3 | ~1000m from center | ⬜ |
| 2000m | Test location 4 | ~2000m from center | ⬜ |

### Test 10: Sound Levels

**Objective:** Verify different sound levels work

| Sound Level | Expected Notification | Pass/Fail |
|-------------|----------------------|-----------|
| Loud | Max priority, full screen | ⬜ |
| Medium | High priority, heads up | ⬜ |
| Soft | Default priority, standard | ⬜ |

---

## Real-World Test (1-2 hours)

### Scenario 1: Morning Commute

**Setup:**
1. Night before: Create alarm for work location
2. Set radius: 400m
3. Start alarm before going to bed
4. Close app

**Test:**
1. Morning: Commute to work
2. **Expected:** Notification when arriving at work

**Log:**
- Time alarm created: ___________
- Time left home: ___________
- Time notification received: ___________
- Distance from work when triggered: ___________
- Pass/Fail: ⬜

### Scenario 2: Grocery Store

**Setup:**
1. Create alarm for local grocery store
2. Set radius: 200m
3. Start alarm
4. Close app

**Test:**
1. Drive/walk to grocery store
2. **Expected:** Notification when arriving

**Log:**
- Store name: ___________
- Radius: ___________
- Time alarm created: ___________
- Time arrived: ___________
- Notification received: YES / NO
- Pass/Fail: ⬜

### Scenario 3: Home Return

**Setup:**
1. While away from home
2. Create alarm for home address
3. Set radius: 500m
4. Start alarm, close app

**Test:**
1. Return home
2. **Expected:** Notification when arriving home

**Log:**
- Home address: ___________
- Time alarm created: ___________
- Time arrived home: ___________
- Notification received: YES / NO
- Pass/Fail: ⬜

---

## Debugging Guide

### If geofencing doesn't trigger:

#### Check 1: Permissions
```bash
# Android
adb shell dumpsys package com.example.wakemeup | grep permission

# Look for:
# android.permission.ACCESS_FINE_LOCATION: granted=true
# android.permission.ACCESS_BACKGROUND_LOCATION: granted=true
```

#### Check 2: Location Services
- Android: Settings → Location → ON
- iOS: Settings → Privacy → Location Services → ON

#### Check 3: App Logs
```bash
flutter run

# Look for:
# ✅ Geofencing started for: [name]
# 📍 Location changed: [lat], [lng]
# 🎯 Geofence status changed
```

#### Check 4: Battery Optimization (Android)
```bash
# Disable battery optimization
Settings → Battery → Battery Optimization
→ Find "wakemeup"
→ Don't optimize
```

#### Check 5: Geofence Service Running
Add this debug method to test manually:

```dart
// In lib/services/geofence_service.dart
void debugPrintStatus() {
  debugPrint('🔍 Geofence Debug Info:');
  debugPrint('  - Service running: $_isRunning');
  debugPrint('  - Active regions: ${_geofencing.regions.length}');
  for (final region in _geofencing.regions) {
    debugPrint('    • ${region.id}');
  }
}
```

### Common Issues & Solutions

| Issue | Cause | Solution |
|-------|-------|----------|
| No notification | Permission denied | Grant "Always" location permission |
| Service stops | Battery optimization | Disable optimization for app |
| Delayed trigger | GPS drift | Increase radius to 500m+ |
| Not working when closed | Background permission | Enable background location |
| Mock location fails | Mock not allowed | Set `allowsMockLocation: true` |

---

## Test Checklist Summary

Use this for quick verification:

- [ ] Alarm creation works
- [ ] Geofence registers on start
- [ ] Entry detection triggers notification
- [ ] Works when app is closed
- [ ] Works when app is force stopped
- [ ] Multiple alarms don't conflict
- [ ] App restart restores geofences
- [ ] Deactivation stops geofence
- [ ] Deletion removes geofence
- [ ] All permission states handled
- [ ] All sound levels work
- [ ] All radius sizes work (100m - 2km)
- [ ] Location services disabled handled
- [ ] Real-world test passed

---

## Performance Metrics

Track these during testing:

| Metric | Target | Actual | Pass/Fail |
|--------|--------|--------|-----------|
| Cold start time | < 2s | _____ | ⬜ |
| Geofence registration | < 1s | _____ | ⬜ |
| Entry detection delay | < 15s | _____ | ⬜ |
| Notification display | < 2s | _____ | ⬜ |
| Battery drain (1 hour) | < 5% | _____ | ⬜ |
| Memory usage | < 100MB | _____ | ⬜ |

---

## Sign-off

**Tester:** _______________
**Date:** _______________
**Device:** _______________
**OS Version:** _______________
**App Version:** _______________

**Overall Result:** PASS / FAIL

**Notes:**
_______________________________________
_______________________________________
_______________________________________
