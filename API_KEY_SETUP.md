# API Key Security Setup

This project uses environment variables to securely manage API keys.

## Setup Instructions

### 1. Environment File (.env)

Your Google Maps API key should be stored in the `.env` file at the root of the project:

```bash
GOOGLE_API_KEY=your_api_key_here
```

**Important:** The `.env` file is already in `.gitignore` and should **NEVER** be committed to version control.

### 2. Android Setup

The API key is automatically injected into `AndroidManifest.xml` at build time.

**How it works:**
- The API key is read from `android/local.properties`
- It's injected into the manifest via `manifestPlaceholders`
- The file `android/local.properties` is ignored by git

**Manual setup (if needed):**
```bash
# Add to android/local.properties
echo "GOOGLE_MAPS_API_KEY=your_api_key_here" >> android/local.properties
```

### 3. iOS Setup

The API key is read from `Info.plist` at runtime.

**Automatic setup:**
Run the injection script before building:
```bash
./ios/scripts/inject_api_key.sh
```

**How it works:**
- The script reads the API key from `.env`
- It updates `ios/Runner/Info.plist` with the key
- The app reads it from `Info.plist` at runtime

**To add to Xcode build phase:**
1. Open `ios/Runner.xcworkspace` in Xcode
2. Select the Runner target
3. Go to Build Phases
4. Click "+" → New Run Script Phase
5. Add: `"${SRCROOT}/scripts/inject_api_key.sh"`
6. Move it before "Compile Sources"

## Security Best Practices

✅ **DO:**
- Keep API key in `.env` file
- Add `.env` to `.gitignore`
- Use environment variables for CI/CD
- Restrict API key usage in Google Cloud Console

❌ **DON'T:**
- Commit `.env` file to git
- Hardcode API keys in source files
- Share API keys publicly
- Use the same key for dev and production

## Files That Use API Key

### Secure (Environment-based):
- `.env` - Source of truth (not committed)
- `android/local.properties` - Android (not committed)
- `ios/Runner/Info.plist` - iOS (API key injected at build time)

### Implementation Files:
- `android/app/build.gradle.kts` - Reads from local.properties
- `android/app/src/main/AndroidManifest.xml` - Uses placeholder `${GOOGLE_MAPS_API_KEY}`
- `ios/Runner/AppDelegate.swift` - Reads from Info.plist
- `lib/services/google_places_service.dart` - Uses dotenv package

## For Team Members

When cloning this repository:

1. Copy `.env.example` to `.env` (if provided)
2. Add your Google Maps API key to `.env`
3. For Android: Run `echo "GOOGLE_MAPS_API_KEY=your_key" >> android/local.properties`
4. For iOS: Run `./ios/scripts/inject_api_key.sh` before building

## Verification

To verify the setup is correct:

```bash
# Check that API key is NOT in git
git grep "AIzaSy" # Should only find placeholders, not actual keys

# Check .env exists
cat .env | grep GOOGLE_API_KEY

# Check Android local.properties
cat android/local.properties | grep GOOGLE_MAPS_API_KEY

# Check iOS Info.plist (after running script)
grep -A1 "GOOGLE_MAPS_API_KEY" ios/Runner/Info.plist
```

## CI/CD Setup

For GitHub Actions, CircleCI, etc.:

```yaml
# Add GOOGLE_API_KEY as a secret in your CI/CD platform
# Then inject it during build:

- name: Setup API Key
  run: |
    echo "GOOGLE_API_KEY=${{ secrets.GOOGLE_API_KEY }}" > .env
    echo "GOOGLE_MAPS_API_KEY=${{ secrets.GOOGLE_API_KEY }}" >> android/local.properties
    ./ios/scripts/inject_api_key.sh
```
