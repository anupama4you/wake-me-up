# WakeMeUp - Subscription Integration Setup Guide

This guide will help you set up Firebase Authentication and RevenueCat subscriptions for the WakeMeUp app.

## Table of Contents
1. [Overview](#overview)
2. [Firebase Setup](#firebase-setup)
3. [RevenueCat Setup](#revenuecat-setup)
4. [Environment Configuration](#environment-configuration)
5. [iOS Configuration](#ios-configuration)
6. [Android Configuration](#android-configuration)
7. [Testing](#testing)
8. [Troubleshooting](#troubleshooting)

---

## Overview

The WakeMeUp app now includes:
- **Firebase Authentication** for user accounts (email/password + Google Sign-In)
- **RevenueCat** for managing in-app subscriptions
- **Three subscription tiers:**
  - **Free**: 20km max trip distance, 1 active alarm
  - **Commuter**: $4.99/month, 50km max trip distance, 5 active alarms
  - **Pro**: $9.99/month, unlimited distance & alarms

---

## Firebase Setup

### 1. Create a Firebase Project

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Click "Add project"
3. Enter project name: `wakemeup-app` (or your preferred name)
4. Disable Google Analytics (optional for this project)
5. Click "Create project"

### 2. Add iOS App to Firebase

1. In Firebase Console, click the iOS icon
2. **iOS bundle ID**: `com.yourcompany.wakemeup` (match your Xcode project)
3. Download `GoogleService-Info.plist`
4. Add it to your iOS project:
   ```
   wake-me-up/ios/Runner/GoogleService-Info.plist
   ```
5. In Xcode, right-click `Runner` folder → Add Files → Select `GoogleService-Info.plist`
   - ✅ Check "Copy items if needed"
   - ✅ Select `Runner` target

### 3. Add Android App to Firebase

1. In Firebase Console, click the Android icon
2. **Android package name**: `com.yourcompany.wakemeup` (match your `build.gradle`)
3. Download `google-services.json`
4. Place it in:
   ```
   wake-me-up/android/app/google-services.json
   ```

### 4. Enable Authentication Methods

1. In Firebase Console → **Authentication** → **Sign-in method**
2. Enable **Email/Password**:
   - Click "Email/Password" → Enable → Save
3. Enable **Google Sign-In**:
   - Click "Google" → Enable → Save
   - Add support email
   - Download OAuth client configuration

### 5. Update Android Configuration

Add to `wake-me-up/android/build.gradle` (project-level):

```gradle
buildscript {
    dependencies {
        // ... existing dependencies
        classpath 'com.google.gms:google-services:4.4.0'
    }
}
```

Add to `wake-me-up/android/app/build.gradle` (bottom of file):

```gradle
apply plugin: 'com.google.gms.google-services'
```

---

## RevenueCat Setup

### 1. Create RevenueCat Account

1. Go to [RevenueCat](https://app.revenuecat.com/)
2. Sign up for free account
3. Create new project: `WakeMeUp`

### 2. Configure App in RevenueCat

1. Click "Add app"
2. **App name**: WakeMeUp iOS
3. **Bundle ID**: `com.yourcompany.wakemeup`
4. **Platform**: iOS (or Android)
5. Get your **Public API Key** from Settings

### 3. Create Products in App Store Connect / Play Console

#### For iOS (App Store Connect):

1. Go to [App Store Connect](https://appstoreconnect.apple.com/)
2. Select your app
3. Go to **In-App Purchases** → **Manage**
4. Create two Auto-Renewable Subscriptions:

   **Product 1: Commuter Monthly**
   - Product ID: `wakemeup_commuter_monthly`
   - Price: $4.99/month
   - Subscription Group: WakeMeUp Subscriptions

   **Product 2: Pro Monthly**
   - Product ID: `wakemeup_pro_monthly`
   - Price: $9.99/month
   - Subscription Group: WakeMeUp Subscriptions

#### For Android (Google Play Console):

1. Go to [Google Play Console](https://play.google.com/console/)
2. Select your app
3. Go to **Monetize** → **Subscriptions**
4. Create subscriptions with same IDs as above

### 4. Configure Products in RevenueCat

1. In RevenueCat Dashboard → **Products**
2. Add new product:
   - **Identifier**: `wakemeup_commuter_monthly`
   - **Store**: App Store (or Google Play)
   - **Product ID**: `wakemeup_commuter_monthly` (from App Store Connect)
3. Repeat for `wakemeup_pro_monthly`

### 5. Create Entitlements

1. In RevenueCat → **Entitlements**
2. Create entitlement: `commuter`
   - Attach product: `wakemeup_commuter_monthly`
3. Create entitlement: `pro`
   - Attach product: `wakemeup_pro_monthly`

### 6. Create Offerings

1. In RevenueCat → **Offerings**
2. Create offering: `default`
3. Add packages:
   - Package 1: Monthly Commuter → `wakemeup_commuter_monthly`
   - Package 2: Monthly Pro → `wakemeup_pro_monthly`

---

## Environment Configuration

### 1. Update `.env` File

Edit `wake-me-up/.env`:

```env
# Google Maps API Key
GOOGLE_API_KEY=YOUR_GOOGLE_MAPS_API_KEY

# RevenueCat API Key
# Get from: https://app.revenuecat.com/ → Settings → API Keys
REVENUECAT_API_KEY=YOUR_REVENUECAT_PUBLIC_API_KEY_HERE
```

### 2. Create `.env.local` (for local development)

Create `wake-me-up/.env.local` (this file is gitignored):

```env
GOOGLE_API_KEY=AIza... (your actual key)
REVENUECAT_API_KEY=appl_... (your actual RevenueCat key)
```

---

## iOS Configuration

### 1. Update Info.plist

Add to `wake-me-up/ios/Runner/Info.plist`:

```xml
<!-- Google Sign-In -->
<key>CFBundleURLTypes</key>
<array>
  <dict>
    <key>CFBundleTypeRole</key>
    <string>Editor</string>
    <key>CFBundleURLSchemes</key>
    <array>
      <!-- Replace with your REVERSED_CLIENT_ID from GoogleService-Info.plist -->
      <string>com.googleusercontent.apps.YOUR-CLIENT-ID</string>
    </array>
  </dict>
</array>

<!-- In-App Purchase -->
<key>SKPaymentTransactionsEnabled</key>
<true/>
```

### 2. Enable In-App Purchase Capability

1. Open Xcode
2. Select `Runner` target
3. Go to **Signing & Capabilities**
4. Click **+ Capability**
5. Add **In-App Purchase**

### 3. Configure StoreKit Testing (for local testing)

1. In Xcode → Product → Scheme → Edit Scheme
2. Run → Options → StoreKit Configuration
3. Create new StoreKit configuration file:
   - Add subscriptions matching your product IDs
   - Set to active for testing

---

## Android Configuration

### 1. Update AndroidManifest.xml

The app already has necessary permissions. Verify `wake-me-up/android/app/src/main/AndroidManifest.xml` includes:

```xml
<uses-permission android:name="android.permission.INTERNET"/>
```

### 2. Configure Google Play Billing

Add to `wake-me-up/android/app/build.gradle`:

```gradle
dependencies {
    implementation 'com.android.billingclient:billing:6.0.1'
}
```

*(Already included via `purchases_flutter` package)*

---

## Testing

### 1. Test Firebase Authentication

1. Run the app: `flutter run`
2. Navigate to Settings
3. Try signing up with email/password
4. Try Google Sign-In
5. Check Firebase Console → Authentication → Users

### 2. Test RevenueCat Subscriptions

#### iOS Testing:

1. Add test account in App Store Connect:
   - Users and Access → Sandbox Testers
   - Create test account
2. On device: Settings → App Store → Sandbox Account → Sign in
3. In app:
   - Tap "Upgrade Plan"
   - Select Commuter or Pro
   - Complete purchase with sandbox account
4. Verify in RevenueCat Dashboard → Customers

#### Android Testing:

1. Add license testing account in Play Console
2. Upload APK to Internal Testing track
3. Install app via Play Store
4. Test purchases

### 3. Test Restore Purchases

1. Sign in with account that has active subscription
2. Go to Settings
3. Tap "Restore" button
4. Verify subscription is restored

---

## Troubleshooting

### Firebase Issues

**Problem**: "Firebase not initialized"
- **Solution**: Ensure `Firebase.initializeApp()` runs in `main.dart` before app starts
- Check `GoogleService-Info.plist` (iOS) or `google-services.json` (Android) is present

**Problem**: Google Sign-In not working
- **Solution**:
  - iOS: Verify `CFBundleURLSchemes` in Info.plist matches REVERSED_CLIENT_ID
  - Android: Ensure SHA-1 fingerprint is added to Firebase Console

### RevenueCat Issues

**Problem**: "Unable to load subscription options"
- **Solution**:
  - Verify `REVENUECAT_API_KEY` in `.env` file
  - Check RevenueCat Dashboard → Offerings are configured
  - Ensure products exist in App Store Connect/Play Console

**Problem**: Purchases not working
- **Solution**:
  - iOS: Verify StoreKit configuration OR use real device with sandbox account
  - Android: Must test on device (not emulator) with Play Store

**Problem**: "Entitlement not found"
- **Solution**:
  - Check product IDs in code match RevenueCat configuration:
    - `wakemeup_commuter_monthly` → entitlement `commuter`
    - `wakemeup_pro_monthly` → entitlement `pro`

### General Issues

**Problem**: App crashes on startup
- **Solution**:
  - Run `flutter pub get`
  - Check console logs for specific error
  - Ensure all API keys are set in `.env`

**Problem**: Subscription tier not updating
- **Solution**:
  - Force close and restart app
  - Check RevenueCat Dashboard → Customer status
  - Try "Restore Purchases" button

---

## Next Steps

1. **Set up webhook** in RevenueCat for server-side validation
2. **Add analytics** to track conversion rates
3. **A/B test** pricing and paywall copy
4. **Implement trial period** (optional)
5. **Add promotional offers** for returning users

---

## Resources

- [Firebase Auth Documentation](https://firebase.google.com/docs/auth)
- [RevenueCat Documentation](https://docs.revenuecat.com/)
- [Flutter In-App Purchase Guide](https://docs.flutter.dev/cookbook/plugins/in-app-purchases)
- [App Store Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)

---

## Support

For issues with:
- **Firebase**: Check [Firebase Support](https://firebase.google.com/support)
- **RevenueCat**: Contact support@revenuecat.com
- **WakeMeUp App**: Create issue on GitHub repository

---

**Last Updated**: 2025-12-01
