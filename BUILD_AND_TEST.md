# Build and Test Guide

## 🚀 Quick Start - Build on Your Phone

### Step 1: Prepare Your Device

**For iOS:**
1. Connect your iPhone via USB
2. Trust the computer on your phone
3. Open Xcode and sign the app with your Apple ID

**For Android:**
1. Enable Developer Options on your phone:
   - Settings → About Phone → Tap "Build Number" 7 times
2. Enable USB Debugging:
   - Settings → Developer Options → USB Debugging
3. Connect phone via USB and approve USB debugging prompt

### Step 2: Verify Device Connection

```bash
flutter devices
```

You should see your device listed. Example output:
```
iPhone 14 Pro (mobile) • 00008110-001234567890 • ios • iOS 16.4
```

### Step 3: Build and Run

**For the first build after integration:**
```bash
# Clean previous builds
flutter clean

# Get dependencies
flutter pub get

# For iOS, run the API key injection script
./ios/scripts/inject_api_key.sh

# Build and run on connected device
flutter run
```

**For subsequent builds:**
```bash
flutter run
```

### Step 4: For Release Build (Optional)

**Android (APK):**
```bash
flutter build apk --release
# APK will be at: build/app/outputs/flutter-apk/app-release.apk
```

**iOS (Archive):**
```bash
flutter build ios --release
# Then archive in Xcode: Product → Archive
```

---

## 🧪 Testing the Improvements

### 1. Test Adaptive Location Tracking (Battery Optimization)

**What to Test:**
- Battery-efficient location polling based on distance

**Steps:**
1. Create a new alarm for a location 5+ km away
2. Activate the alarm
3. Tap on the alarm to view tracking screen
4. Watch the console logs:
   ```
   📍 Position updated: 37.7749, -122.4194
   📏 Distance to target: 5234m
   🔋 Next update in: 30s (battery optimized)
   ```

**Expected Behavior:**
- Far away (>5km): Updates every 30 seconds
- Medium (1-5km): Updates every 15 seconds
- Close (500m-1km): Updates every 10 seconds
- Very close (100-500m): Updates every 5 seconds
- Critical (<100m): Updates every 3 seconds

**How to Verify:**
- Check console timestamps between updates
- Should see longer intervals when far away
- Intervals should shorten as you approach

---

### 2. Test Permission Error Handling

**What to Test:**
- User-friendly error messages for location permission issues

**Test 2A: Denied Permission**

**Steps:**
1. Deny location permission when prompted
2. Try to create an alarm

**Expected:**
- Red snackbar appears: "Location permission denied. Please grant permission to create location-based alarms."

**Test 2B: Permanently Denied**

**Steps:**
1. Go to Settings → WakeMeUp → Location → Never
2. Open app and try to create alarm

**Expected:**
- Error dialog appears with:
  - Title: "Location Permission Required"
  - Message explaining how to enable
  - "Open Settings" button
- Clicking button opens app settings

**Test 2C: Background Permission Warning**

**Steps:**
1. Grant "While Using App" permission only
2. Try to activate an alarm

**Expected:**
- Yellow/amber warning snackbar:
  - "Background location not granted. Alarms may not work when app is closed..."
  - "Settings" button to open app settings
- Alarm still saves (basic location is sufficient for testing)

---

### 3. Test Alarm Operations with Error Handling

**Test 3A: Create and Save Alarm**

**Steps:**
1. Tap "+" button
2. Search for a location or drop a pin
3. Adjust radius and settings
4. Tap "Save for Later"

**Expected:**
- Green success snackbar: "Alarm saved successfully"
- Returns to home screen
- Alarm appears in list (inactive)

**Test 3B: Activate Alarm**

**Steps:**
1. Toggle an alarm from inactive → active

**Expected:**
- Green success snackbar: "Alarm '[name]' activated"
- Alarm card changes to active styling (gradient background)
- Progress indicators appear

**Test 3C: Activation Failure**

**Steps:**
1. Disable location services in device settings
2. Try to activate an alarm

**Expected:**
- Error dialog appears:
  - Title: "Failed to Activate Alarm"
  - Bullet points explaining what to check
  - Location services
  - Background permission
  - App permissions
- Alarm reverts to inactive state

**Test 3D: Deactivate Alarm**

**Steps:**
1. Toggle active alarm off

**Expected:**
- Green success snackbar: "Alarm '[name]' deactivated"
- Alarm card changes to inactive styling
- Progress indicators disappear

**Test 3E: Delete Alarm**

**Steps:**
1. Swipe alarm card right
2. Confirm deletion

**Expected:**
- Success snackbar: "Alarm '[name]' deleted"
- Alarm removed from list
- Geofencing stopped

**Test 3F: Delete with Error**

**Steps:**
1. Enable airplane mode
2. Try to delete an alarm

**Expected:**
- Error snackbar: "Failed to delete alarm. Please try again."
- Alarm restored to list (rollback)

---

### 4. Test Geofencing Errors

**Test 4A: Service Disabled**

**Steps:**
1. Create alarm
2. Disable location services
3. Try to activate

**Expected:**
- Error dialog with clear troubleshooting:
  - "Failed to activate alarm"
  - "• Location services are enabled"
  - "• Background location permission is granted"

**Test 4B: Permission Issues**

**Steps:**
1. Remove background location permission
2. Activate alarm

**Expected:**
- Warning about background permission
- Option to open settings
- Clear explanation of impact

---

### 5. Test Real-World Scenario

**Complete User Flow:**

**Steps:**
1. Open app (first time)
2. Grant location permission ("Always Allow")
3. Create alarm for nearby location (~500m away)
4. Name it "Coffee Shop"
5. Set radius to 200m
6. Activate alarm
7. Walk away from location (>500m)
8. Open tracking screen
9. Observe adaptive polling (should update every 10-15s)
10. Walk toward location
11. Observe polling frequency increase
12. Enter geofence
13. Receive notification with alarm sound

**Expected Throughout:**
- Smooth UI with success confirmations
- Clear error messages if anything fails
- Battery-efficient tracking
- Notification when entering geofence

---

## 📊 Monitoring and Logs

### Console Logs to Watch For

**Adaptive Tracking:**
```
🔋 Starting adaptive location tracking for alarm: Coffee Shop
📍 Position updated: 37.7749, -122.4194
📏 Distance to target: 1234m
🔋 Next update in: 15s (battery optimized)
```

**Permission Handling:**
```
🔍 Starting location permission request...
✅ Location services are enabled
✅ Basic location permission granted: whileInUse
✅ Background location granted
```

**Geofencing:**
```
📍 CREATING GEOFENCE ZONE
   - Alarm ID: 1234567890
   - Location: 37.7749, -122.4194
   - Radius: 200m
✅ GEOFENCE ZONE ADDED SUCCESSFULLY
```

**Error Handling:**
```
❌ Error toggling alarm: GeofenceException
   Reverting state and showing user error dialog
```

---

## 🐛 Troubleshooting

### Issue: "Maps not loading"

**Solution:**
1. Check that `.env.local` exists with valid API key
2. For iOS: Run `./ios/scripts/inject_api_key.sh`
3. Run `flutter clean && flutter pub get`
4. Rebuild app

### Issue: "Location permission not requesting"

**Solution:**
1. Uninstall app from device
2. Reinstall: `flutter run`
3. Should prompt for permission on first launch

### Issue: "Geofencing not triggering"

**Checklist:**
- [ ] Location services enabled
- [ ] "Always Allow" permission granted
- [ ] Actually moved into/out of geofence (don't just stand at boundary)
- [ ] Wait 1-2 minutes after crossing boundary (iOS delay)
- [ ] App has foreground service notification (Android)

### Issue: "Build errors after integration"

**Solution:**
```bash
flutter clean
flutter pub get
rm -rf ios/Pods ios/Podfile.lock
cd ios && pod install && cd ..
flutter run
```

---

## ✅ Verification Checklist

Before submitting/deploying, verify:

- [ ] App builds without errors on both iOS and Android
- [ ] Permission requests appear correctly
- [ ] Error dialogs show helpful messages
- [ ] Success confirmations appear for all actions
- [ ] Adaptive tracking shows varying update intervals
- [ ] Alarms can be created, edited, deleted
- [ ] Alarms can be activated/deactivated
- [ ] Geofencing triggers notifications
- [ ] No memory leaks (streams properly disposed)
- [ ] Console shows appropriate logs
- [ ] No crashes on error conditions

---

## 📱 Performance Testing

### Battery Usage Test

1. Fully charge phone
2. Activate alarm 10km away
3. Let it run for 2 hours
4. Check battery usage in Settings → Battery
5. Compare with old version (if available)

**Expected:** Significant reduction in battery usage due to adaptive polling

### Memory Usage Test

1. Open app
2. Create 5 alarms
3. Activate all 5
4. Open/close tracking screens multiple times
5. Monitor memory in Xcode Instruments or Android Profiler

**Expected:** No memory leaks, stable memory usage

---

## 🎉 Success Criteria

The integration is successful if:

1. ✅ App builds and runs on device
2. ✅ All tests pass
3. ✅ Error messages are user-friendly
4. ✅ Success confirmations appear
5. ✅ Adaptive tracking works (variable update intervals)
6. ✅ No crashes or major bugs
7. ✅ Better battery life than before
8. ✅ Better user experience overall

---

**Ready to test?** Start with Step 1 and work through the test scenarios! 🚀
