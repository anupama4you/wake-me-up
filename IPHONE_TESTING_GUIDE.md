# iPhone Testing Guide

## How to Install and Test on Your iPhone

### Prerequisites

1. **Mac computer** (which you have ✅)
2. **iPhone** with USB cable
3. **Xcode** installed (required for iOS development)
4. **Apple ID** (free - no paid developer account needed for testing)

### Step 1: Install/Update Xcode

```bash
# Check if Xcode is installed
xcode-select -p

# If not installed, install from App Store:
# 1. Open App Store
# 2. Search for "Xcode"
# 3. Click "Install" (it's free, but ~12GB download)
```

**Or update if already installed:**
```bash
# Check Xcode version
xcodebuild -version

# Update via App Store if needed (Xcode 15+ recommended)
```

After installing/updating Xcode:
```bash
# Accept Xcode license
sudo xcodebuild -license accept

# Install command line tools
sudo xcode-select --install
```

### Step 2: Connect Your iPhone

1. **Connect iPhone to Mac** via USB cable
2. **Unlock your iPhone**
3. **Trust this computer** (popup will appear on iPhone)
   - Tap "Trust"
   - Enter your iPhone passcode

### Step 3: Enable Developer Mode on iPhone

**For iOS 16+:**

1. On your iPhone, go to: **Settings → Privacy & Security → Developer Mode**
2. Toggle **Developer Mode ON**
3. iPhone will **restart**
4. After restart, confirm "Turn On Developer Mode"

### Step 4: Configure Xcode Signing

Open the iOS project in Xcode:

```bash
cd /Users/anupama4you/projects/wakemeup
open ios/Runner.xcworkspace
```

**In Xcode:**

1. Click on **"Runner"** in the left sidebar (blue icon)
2. Select **"Runner"** under TARGETS
3. Go to **"Signing & Capabilities"** tab
4. **Uncheck** "Automatically manage signing" (temporarily)
5. **Check** "Automatically manage signing" again
6. Select your **Team**:
   - If no team appears, click "Add Account..."
   - Sign in with your Apple ID
   - Select your Apple ID as the team
7. **Bundle Identifier** should auto-populate (e.g., `com.example.wakemeup`)
   - If there's a conflict, change it to something unique like: `com.yourname.wakemeup`

**You should see**: "Signing for 'Runner' requires a development team..."
- This is normal for free accounts
- Xcode will create a free provisioning profile

### Step 5: Trust Developer Certificate on iPhone

**First time only:**

1. On your iPhone: **Settings → General → VPN & Device Management**
2. Under "Developer App", tap your **Apple ID**
3. Tap **"Trust [Your Apple ID]"**
4. Confirm **"Trust"**

### Step 6: Run on iPhone via Flutter

Close Xcode and return to terminal:

```bash
# Make sure iPhone is connected
flutter devices

# You should see something like:
# iPhone 15 (mobile) • 00008xxx-xxxxx • ios • iOS 17.0

# Run the app on your iPhone
flutter run
```

**Or specify the device if you have multiple:**

```bash
# List all devices
flutter devices

# Run on specific device
flutter run -d 00008xxx-xxxxx
```

### Alternative: Run from Xcode

If Flutter command doesn't work, use Xcode:

1. Open project: `open ios/Runner.xcworkspace`
2. Select your **iPhone** from device dropdown (top left)
3. Click **▶️ Play button** (or press ⌘R)
4. Wait for build and installation

### Step 7: Grant Permissions on iPhone

When the app launches for the first time:

1. **Location Permission**:
   - Tap **"Allow While Using App"** or **"Allow Once"**
   - Then go to: **Settings → Privacy & Security → Location Services → wakemeup**
   - Change to **"Always"** (required for background geofencing)

2. **Notifications Permission**:
   - Tap **"Allow"** when prompted

3. **Motion & Fitness** (if prompted):
   - Tap **"Allow"**

### Step 8: Test the Geofencing Alarm

#### Test 1: Quick Indoor Test

1. **Create an alarm**:
   - Open the app
   - Tap the map to drop a pin at your current location
   - Set radius to **500 meters**
   - Set sound level to **"Loud"**
   - Name it "Test Alarm"
   - Tap **"Save Alarm"**
   - Tap **"Activate Alarm"**

2. **The tracking screen should appear** with animated geofence

3. **Simulate location change** (while staying indoors):
   - In Xcode, go to: **Debug → Simulate Location**
   - Choose **"City Run"** or **"Freeway Drive"**
   - This simulates movement

4. **Expected result**:
   - When simulated location enters your geofence
   - Notification appears
   - iPhone vibrates
   - (Sound plays if you added alarm.mp3)

#### Test 2: Real-World Test

1. **Create an alarm at a nearby location**:
   - Set a location 5-10 minutes walk away
   - Set radius to **300 meters**
   - Activate alarm

2. **Lock your iPhone and put it in your pocket**

3. **Walk towards the location**

4. **Expected result**:
   - When you get within 300m of the location
   - Notification appears (even with phone locked)
   - Phone vibrates continuously
   - (Sound plays if you added alarm.mp3)

5. **Unlock phone and open app**

6. **Tap "Finish & Return Home"** to stop alarm

### Troubleshooting

#### Issue: "Developer Mode" not appearing in Settings

**Solution**: Only iOS 16+ has this setting. If you have iOS 15 or earlier, skip this step.

#### Issue: "Failed to verify code signature"

**Solution**:
```bash
# Clean and rebuild
cd /Users/anupama4you/projects/wakemeup
flutter clean
flutter pub get
rm -rf ios/Pods ios/Podfile.lock
cd ios && pod install && cd ..
flutter run
```

#### Issue: "iPhone is not available. Please reconnect the device."

**Solution**:
1. Unplug iPhone
2. Restart iPhone
3. Restart Mac (if issue persists)
4. Reconnect iPhone
5. Trust computer again
6. Try `flutter run` again

#### Issue: "iPhone has denied the launch request"

**Solution**:
1. On iPhone: **Settings → General → VPN & Device Management**
2. Trust your developer certificate
3. Try running again

#### Issue: "No valid code signing certificates were found"

**Solution**:
1. Open Xcode: `open ios/Runner.xcworkspace`
2. Go to **Signing & Capabilities**
3. Click "Add Account" and sign in with Apple ID
4. Select your Apple ID as team
5. Change Bundle Identifier to something unique

#### Issue: App installs but location not working

**Solution**:
1. Check location permissions: **Settings → Privacy & Security → Location Services → wakemeup**
2. Must be set to **"Always"** (not "While Using")
3. If not available, delete app and reinstall
4. Grant "Always" permission when first prompted

#### Issue: Geofencing not triggering

**Solution**:
1. Make sure location is set to "Always"
2. Check **Settings → Privacy & Security → Location Services** is ON (top level)
3. Make sure "Low Power Mode" is OFF (it limits background location)
4. Make sure WiFi and Bluetooth are ON (helps location accuracy)
5. Go outside if testing indoors (GPS signal better outside)

#### Issue: Vibration not working

**Solution**:
1. Check iPhone is not in silent mode (vibration may be disabled)
2. Go to: **Settings → Sounds & Haptics**
3. Enable "Vibrate on Ring" and "Vibrate on Silent"

#### Issue: Build takes very long time

**Solution**: First iOS build can take 10-20 minutes. Subsequent builds are faster (1-2 minutes).

### iOS-Specific Notes

#### Background Location Restrictions

iOS is more restrictive than Android for background location:

1. **Battery impact**: iOS will throttle background location if battery is low
2. **Low Power Mode**: Disables most background location updates
3. **User notifications**: iOS may ask users periodically if they want to keep allowing "Always" location
4. **Time limits**: iOS may limit continuous background location tracking

#### Testing Best Practices

1. **Keep iPhone plugged in** during initial testing
2. **Turn off Low Power Mode**: **Settings → Battery → Low Power Mode OFF**
3. **Keep WiFi ON** for better location accuracy
4. **Test outdoors** for best GPS signal
5. **Set larger radius** (500m+) for initial tests

### iOS Info.plist Check

Let me verify your iOS permissions are properly configured:

```bash
# Check if location permissions are set
cat ios/Runner/Info.plist | grep -A 2 "Location"
```

The app should already have these, but if testing doesn't work, we may need to add more detailed permission descriptions.

### Quick Command Reference

```bash
# Check connected devices
flutter devices

# Run on iPhone
flutter run

# Run with verbose logging
flutter run -v

# Run in release mode (faster, no debugging)
flutter run --release

# Check iOS build
cd ios && pod install && cd ..

# Clean and rebuild everything
flutter clean && flutter pub get && flutter run

# View live logs while app is running
flutter logs
```

### Expected First Run Experience

1. **Install time**: 2-5 minutes first time
2. **Permission prompts**: Location, Notifications
3. **App opens**: Main screen with "No alarms yet"
4. **Create alarm**: Tap to add location
5. **Activate**: Start tracking
6. **Test**: Simulate location or walk to location
7. **Alarm triggers**: Notification + Vibration + (Sound if added)

### Video Recording (for debugging)

If something doesn't work, you can record your iPhone screen:

1. **Add Screen Recording** to Control Center:
   - **Settings → Control Center**
   - Add "Screen Recording"

2. **Record**:
   - Swipe down from top-right
   - Tap Record button
   - Test your alarm
   - Stop recording

3. This helps see exactly what's happening

### Performance Monitoring

While testing, watch for:

```bash
# Run with performance overlay
flutter run --profile

# View memory and CPU usage
flutter run --observatory-port=8888
```

### Next Steps After Successful Install

1. ✅ Grant "Always" location permission
2. ✅ Create test alarm nearby
3. ✅ Activate alarm
4. ✅ Test by walking (or simulating location)
5. ✅ Verify notification appears
6. ✅ Verify vibration works
7. ✅ Dismiss alarm successfully
8. ⚠️ Add alarm.mp3 sound file (optional)
9. ✅ Test real-world scenarios

### Apple Developer Account (Optional)

**Free Account** (what you're using):
- ✅ Test on your own devices
- ✅ Up to 3 devices
- ✅ Apps expire after 7 days (need to reinstall)
- ✅ Good for testing

**Paid Account** ($99/year):
- ✅ Distribute to others via TestFlight
- ✅ Publish to App Store
- ✅ No 7-day expiration
- ✅ More devices

For testing, **free account is perfect**!

### Summary - Quick Start

```bash
# 1. Connect iPhone via USB, unlock, trust computer
# 2. Enable Developer Mode on iPhone (iOS 16+)
# 3. Open Xcode and configure signing
open ios/Runner.xcworkspace
# 4. Close Xcode and run via Flutter
flutter run
# 5. Grant permissions on iPhone (Location: Always)
# 6. Create and test alarm
```

**That's it!** Your alarm app should now be running on your iPhone. 🎉

---

**Need help?** If you encounter any issues, let me know the exact error message you see!
