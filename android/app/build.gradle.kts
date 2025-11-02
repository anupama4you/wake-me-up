plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Load properties from local.properties
val localProperties = java.util.Properties()
val localPropertiesFile = rootProject.file("local.properties")
if (localPropertiesFile.exists()) {
    localPropertiesFile.inputStream().use { localProperties.load(it) }
}

// Load API key from .env.local (preferred) or .env file
val envLocalFile = rootProject.file("../../.env.local")
val envFile = rootProject.file("../../.env")
var googleMapsApiKey = ""

// Try .env.local first (gitignored, contains real keys)
if (envLocalFile.exists()) {
    envLocalFile.readLines().forEach { line ->
        if (line.startsWith("GOOGLE_API_KEY=")) {
            googleMapsApiKey = line.substringAfter("GOOGLE_API_KEY=").trim()
        }
    }
}

// Fallback to .env if .env.local doesn't exist or doesn't have the key
if (googleMapsApiKey.isEmpty() && envFile.exists()) {
    envFile.readLines().forEach { line ->
        if (line.startsWith("GOOGLE_API_KEY=") && !line.startsWith("#")) {
            googleMapsApiKey = line.substringAfter("GOOGLE_API_KEY=").trim()
        }
    }
}

// Final fallback to local.properties or environment variable
if (googleMapsApiKey.isEmpty()) {
    googleMapsApiKey = localProperties.getProperty("GOOGLE_MAPS_API_KEY")
        ?: System.getenv("GOOGLE_MAPS_API_KEY")
        ?: ""
}

android {
    namespace = "com.example.wakemeup"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.wakemeup"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = 26  // Required for geofencing and foreground services
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        multiDexEnabled = true  // Required for geofence_foreground_service

        // Inject Google Maps API key into AndroidManifest
        manifestPlaceholders["GOOGLE_MAPS_API_KEY"] = googleMapsApiKey
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}
