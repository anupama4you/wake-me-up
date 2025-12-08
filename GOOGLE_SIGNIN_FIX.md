# Google Sign-In Fix Guide

**Status:** 🔴 **CRITICAL ISSUE FOUND**

## Issues Identified

### ✅ FIXED: iOS URL Scheme Missing
**Problem:** iOS [Info.plist](ios/Runner/Info.plist:70) was missing the `CFBundleURLSchemes` configuration required for Google Sign-In callback.

**Solution:** Added the following to `ios/Runner/Info.plist`:
```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleTypeRole</key>
        <string>Editor</string>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>com.googleusercontent.apps.515288351370-270oc4j3behuph3d2krjbvnf07p3ll7r</string>
        </array>
    </dict>
</array>
```

---

### 🔴 CRITICAL: Android OAuth Client Missing

**Problem:** Your Firebase project `google-services.json` only has a **Web OAuth client** (client_type: 3) but **NO Android OAuth client** (client_type: 1).

**Current Configuration in `android/google-services.json`:**
```json
"oauth_client": [
  {
    "client_id": "515288351370-2leqepkqfo64e3agrrekaft445r1f509.apps.googleusercontent.com",
    "client_type": 3  // <-- This is a WEB client, not Android!
  }
]
```

**What's Missing:** An Android OAuth client like this:
```json
{
  "client_id": "XXXXXX.apps.googleusercontent.com",
  "client_type": 1,
  "android_info": {
    "package_name": "com.example.wakemeup",
    "certificate_hash": "YOUR_SHA1_FINGERPRINT"
  }
}
```

---

## How to Fix Android Google Sign-In

### Step 1: Get Your SHA-1 Certificate Fingerprint

**For Debug Build (Development):**
```bash
# Windows (using Git Bash or PowerShell):
cd android
./gradlew signingReport

# Look for the "SHA1" under "Variant: debug"
# It will look like: SHA1: AA:BB:CC:DD:EE:FF:00:11:22:33:44:55:66:77:88:99:AA:BB:CC:DD
```

**For Release Build (Production):**
You'll need the SHA-1 from your release keystore (when you create one for production).

### Step 2: Add Android OAuth Client in Firebase Console

1. **Go to Firebase Console:**
   - Visit: https://console.firebase.google.com/
   - Select your project: `wake-me-up-664eb`

2. **Navigate to Project Settings:**
   - Click the ⚙️ gear icon (top left)
   - Select "Project Settings"

3. **Find Your Android App:**
   - Scroll down to "Your apps"
   - Find the Android app with package: `com.example.wakemeup`

4. **Add SHA-1 Fingerprint:**
   - Click on your Android app
   - Scroll to "SHA certificate fingerprints"
   - Click "Add fingerprint"
   - Paste your SHA-1 from Step 1
   - Click "Save"

5. **Download New google-services.json:**
   - After adding SHA-1, Firebase will regenerate the config
   - Click "Download google-services.json"
   - **IMPORTANT:** Replace your existing file at `android/google-services.json`

### Step 3: Enable Google Sign-In Method in Firebase Authentication

1. **Go to Firebase Console > Authentication:**
   - In the Firebase Console, click "Authentication" in the left menu
   - Click "Sign-in method" tab

2. **Enable Google Sign-In:**
   - Find "Google" in the list
   - Click the edit icon (pencil)
   - Toggle "Enable"
   - Set a project support email (your email)
   - Click "Save"

### Step 4: Clean and Rebuild

After replacing `google-services.json`:
```bash
flutter clean
flutter pub get
flutter run
```

---

## How Google Sign-In Works (Technical Overview)

### Current Flow (What SHOULD Happen):

1. **User taps "Continue with Google"** in your app
2. **GoogleSignIn plugin** opens Google's OAuth screen
3. **User selects Google account** and grants permission
4. **Google redirects back** to your app with authorization code
5. **Plugin exchanges code** for access token
6. **Firebase Auth** uses token to create user session

### Where It's Failing Now:

**On Android:**
- ❌ Step 2 fails because Firebase doesn't recognize your app (missing SHA-1)
- Without SHA-1, Firebase can't generate Android OAuth client
- Google Sign-In SDK can't complete authentication

**On iOS (NOW FIXED):**
- ✅ URL scheme added, can receive callback from Google
- Should work after rebuilding the app

---

## Verification Checklist

After applying all fixes:

### iOS Verification:
- [x] `ios/Runner/Info.plist` has `CFBundleURLSchemes` with REVERSED_CLIENT_ID
- [x] `ios/GoogleService-Info.plist` exists and has correct `REVERSED_CLIENT_ID`
- [ ] Rebuild iOS app: `flutter run` on iOS device/simulator
- [ ] Test Google Sign-In on iOS

### Android Verification:
- [ ] Run `cd android && ./gradlew signingReport` to get SHA-1
- [ ] Add SHA-1 to Firebase Console
- [ ] Download new `google-services.json`
- [ ] Replace `android/google-services.json` with new file
- [ ] Verify new file has `"client_type": 1` (Android OAuth client)
- [ ] Enable Google Sign-In in Firebase Authentication settings
- [ ] Run `flutter clean && flutter pub get`
- [ ] Rebuild Android app: `flutter run` on Android device/emulator
- [ ] Test Google Sign-In on Android

---

## Common Errors and Solutions

### Error: "PlatformException(sign_in_failed)"
**Cause:** Missing SHA-1 fingerprint in Firebase Console
**Fix:** Follow Step 2 above to add SHA-1

### Error: "10: Developer console is not set up correctly"
**Cause:** OAuth client not configured in Firebase
**Fix:** Download new google-services.json after adding SHA-1

### Error: "User cancelled sign-in"
**Cause:** This is normal - user dismissed Google picker
**Fix:** No fix needed - this is expected behavior

### Error: "Network error"
**Cause:** Device has no internet connection
**Fix:** Check device connectivity

### iOS: Sign-in opens Safari but doesn't return to app
**Cause:** Missing URL scheme (ALREADY FIXED)
**Fix:** Already applied - rebuild iOS app

---

## Testing the Fix

### Test on Android:
```bash
# 1. Get SHA-1 fingerprint
cd android
./gradlew signingReport
# Copy the SHA1 value

# 2. Add SHA-1 to Firebase Console (see Step 2 above)

# 3. Download new google-services.json and replace existing file

# 4. Clean and rebuild
cd ..
flutter clean
flutter pub get
flutter run --debug

# 5. Test Google Sign-In
# - Tap "Continue with Google"
# - Select Google account
# - Should successfully sign in and return to app
```

### Test on iOS:
```bash
# 1. Clean and rebuild (URL scheme already added)
flutter clean
flutter pub get
flutter run --debug

# 2. Test Google Sign-In
# - Tap "Continue with Google"
# - Select Google account
# - Should successfully sign in and return to app
```

---

## What to Do Next

### IMMEDIATE ACTION REQUIRED:

1. **Run this command to get your SHA-1:**
   ```bash
   cd android
   ./gradlew signingReport
   ```

2. **Copy the SHA1 value** (format: AA:BB:CC:DD:...)

3. **Go to Firebase Console:**
   - https://console.firebase.google.com/project/wake-me-up-664eb/settings/general
   - Scroll to "Your apps" → Android app
   - Click "Add fingerprint"
   - Paste SHA-1
   - Save

4. **Download new google-services.json** and replace the file

5. **Enable Google Sign-In** in Firebase Authentication

6. **Rebuild:**
   ```bash
   flutter clean
   flutter pub get
   flutter run
   ```

---

## Package Configurations (Already Correct)

✅ `pubspec.yaml` has correct packages:
- `firebase_core: ^3.8.1`
- `firebase_auth: ^5.3.4`
- `google_sign_in: ^6.2.2`

✅ `android/app/build.gradle.kts` has Firebase plugin:
- `id("com.google.gms.google-services")`

✅ Code implementation is correct:
- [lib/services/auth_service.dart](lib/services/auth_service.dart:53-80) properly implements Google Sign-In
- [lib/screens/auth_screen.dart](lib/screens/auth_screen.dart:69-93) correctly handles the flow

---

## Production Considerations

### Before App Store/Play Store Release:

1. **Create Release Keystore** (Android):
   ```bash
   keytool -genkey -v -keystore release-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias wakemeup
   ```

2. **Get Release SHA-1:**
   ```bash
   keytool -list -v -keystore release-keystore.jks -alias wakemeup
   ```

3. **Add Release SHA-1 to Firebase Console**

4. **Download FINAL google-services.json** with both debug and release SHA-1s

5. **Configure Release Signing** in `android/app/build.gradle.kts`

---

## Need More Help?

If Google Sign-In still doesn't work after following all steps:

1. **Check Firebase Console Logs:**
   - Firebase Console > Authentication > Users
   - Look for failed sign-in attempts

2. **Enable Detailed Logging:**
   ```dart
   // Add to auth_service.dart signInWithGoogle()
   debugPrint('🔍 Starting Google Sign-In...');
   final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
   debugPrint('🔍 Google User: ${googleUser?.email}');
   ```

3. **Verify Package Versions:**
   ```bash
   flutter pub outdated
   ```

4. **Check Device Logs:**
   ```bash
   # Android
   flutter logs | grep -i "google"

   # iOS
   flutter logs
   ```

---

**Created:** December 8, 2024
**Status:** iOS Fixed ✅ | Android Needs Configuration 🔴
**Next Step:** Get SHA-1 and update Firebase Console
