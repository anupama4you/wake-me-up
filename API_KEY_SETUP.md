# API Key Setup Guide

## Security Notice

This project uses Google Maps API which requires an API key. **Never commit your actual API key to version control.**

## Setup Instructions

### 1. Get Your Google Maps API Key

1. Go to [Google Cloud Console](https://console.cloud.google.com/google/maps-apis/)
2. Create a new project or select an existing one
3. Enable the following APIs:
   - Maps SDK for Android
   - Maps SDK for iOS
   - Places API
   - Geocoding API
4. Create an API key (Credentials → Create Credentials → API Key)
5. **Restrict your API key** for security:
   - Android: Restrict by package name (`com.example.wakemeup`)
   - iOS: Restrict by bundle identifier

### 2. Configure API Key Locally

**Option A: Using .env.local (Recommended)**

1. Create a file named `.env.local` in the project root (this file is gitignored)
2. Add your API key:
```
GOOGLE_API_KEY=YOUR_ACTUAL_API_KEY_HERE
```

**Option B: Using local.properties (Android only)**

Add to `android/local.properties`:
```
GOOGLE_MAPS_API_KEY=YOUR_ACTUAL_API_KEY_HERE
```

**Option C: Using Environment Variables**

Set environment variable:
```bash
export GOOGLE_MAPS_API_KEY=YOUR_ACTUAL_API_KEY_HERE
```

### 3. Build Priority

The app checks for API keys in this order:

1. `.env.local` (gitignored, for local development)
2. `.env` (committed with placeholder)
3. `local.properties` (Android only)
4. Environment variables

### 4. iOS Additional Step

For iOS builds, run the injection script before building:
```bash
./ios/scripts/inject_api_key.sh
```

This script reads from `.env.local` or `.env` and injects the key into `Info.plist`.

## Files in Version Control

✅ **Committed to Git:**
- `.env` - Contains placeholder `YOUR_API_KEY_HERE`
- `API_KEY_SETUP.md` - This file
- `ios/scripts/inject_api_key.sh` - Key injection script

❌ **NOT Committed (Gitignored):**
- `.env.local` - Your actual API keys
- `.env.*.local` - Environment-specific keys
- `android/local.properties` - Local Android config

## CI/CD Setup

For automated builds, set the `GOOGLE_MAPS_API_KEY` environment variable in your CI/CD platform:

- **GitHub Actions**: Repository Secrets
- **Codemagic**: Environment variables
- **Fastlane**: Use `.env.secret` or CI environment

## Troubleshooting

### Map not loading
- Check that your API key is correctly set
- Verify API key restrictions match your app's package/bundle ID
- Ensure required APIs are enabled in Google Cloud Console

### Build errors
- Run `flutter clean`
- For iOS: Run `./ios/scripts/inject_api_key.sh`
- For Android: Rebuild with `flutter build apk`

### iOS build can't find key
- Make sure `.env.local` exists with valid key
- Run the injection script manually
- Check that `Info.plist` has `$(GOOGLE_MAPS_API_KEY)` not a hardcoded value

## Security Best Practices

1. ✅ Never commit actual API keys
2. ✅ Use `.env.local` for local development
3. ✅ Restrict API keys by platform (Android/iOS)
4. ✅ Set usage quotas in Google Cloud Console
5. ✅ Rotate keys if accidentally exposed
6. ✅ Use different keys for dev/staging/production
