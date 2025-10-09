# WakeMeUp - Location-Based Alarm App

A Flutter mobile application that triggers alarms when you approach a specific location. Perfect for commuters who want to nap on public transport without missing their stop.

## Features

- 📍 **Location-Based Alarms**: Set alarms that trigger when you're near your destination
- 🗺️ **Google Maps Integration**: Select locations using an interactive map interface
- 🔍 **Place Search**: Search for destinations by name or address using Google Places
- 🔔 **Multiple Alarms**: Create and manage multiple location-based alarms
- ⚙️ **Customizable Settings**: Adjust trigger radius (50m - 1km) and sound levels
- 📊 **Real-Time Tracking**: Monitor your position and active alarms on the map
- 💾 **Persistent Storage**: Alarms are saved and persist across app restarts

## Screenshots

<!-- Add screenshots here when available -->

## Getting Started

### Prerequisites

- Flutter SDK (3.9.2 or higher)
- Dart SDK (3.9.2 or higher)
- Google Maps API Key
- Android Studio / Xcode (for mobile development)

### Installation

1. Clone the repository:
```bash
git clone https://github.com/yourusername/wakemeup.git
cd wakemeup
```

2. Install dependencies:
```bash
flutter pub get
```

3. Configure Google Maps API:

   **For Android:**
   - Add your API key to `android/app/src/main/AndroidManifest.xml`:
   ```xml
   <meta-data
       android:name="com.google.android.geo.API_KEY"
       android:value="YOUR_API_KEY_HERE"/>
   ```

   **For iOS:**
   - Add your API key to `ios/Runner/AppDelegate.swift`:
   ```swift
   GMSServices.provideAPIKey("YOUR_API_KEY_HERE")
   ```

4. Run the app:
```bash
flutter run
```

## Usage

1. **Create an Alarm**:
   - Tap the '+' button on the home screen
   - Search for a location or tap on the map to select
   - Adjust the trigger radius using the slider
   - Set the alarm name and sound level
   - Choose "Start Now" or "Save for Later"

2. **Manage Alarms**:
   - View all alarms on the home screen
   - Toggle alarms on/off with the switch
   - Delete alarms by tapping the delete icon
   - View all alarms on the map screen

3. **Active Alarm**:
   - Monitor your distance from the destination
   - See real-time updates on the map
   - Receive alerts when approaching your destination

## Permissions

The app requires the following permissions:

- **Location**: To track your position and trigger alarms
- **Location (Always)**: For background location tracking when alarm is active

## Dependencies

- `geolocator: ^10.1.0` - Location services and GPS tracking
- `permission_handler: ^11.0.1` - Permission management
- `google_maps_flutter: ^2.7.0` - Google Maps integration
- `google_place: ^0.4.7` - Google Places API for location search

## Platform Support

- ✅ Android
- ✅ iOS
- ⚠️ Web (limited functionality)
- ⚠️ macOS (limited functionality)
- ⚠️ Linux (limited functionality)
- ⚠️ Windows (limited functionality)

*Note: Full functionality is available on Android and iOS. Other platforms have limited support due to location services constraints.*

## Architecture

```
lib/
├── main.dart                 # App entry point
├── models/
│   └── alarm.dart           # Alarm data model
├── screens/
│   ├── main_screen.dart     # Bottom navigation container
│   ├── home_screen.dart     # Alarm list view
│   ├── map_screen.dart      # Alarm creation screen
│   ├── map_view_screen.dart # All alarms on map
│   ├── active_alarm_screen.dart # Active alarm tracking
│   └── settings_screen.dart # App settings
├── services/
│   └── location_service.dart # Location utilities
└── widgets/
    └── alarm_card.dart      # Alarm list item widget
```

## Roadmap

- [ ] Background alarm monitoring
- [ ] Custom alarm sounds
- [ ] Notification system
- [ ] Alarm history
- [ ] Widget support
- [ ] Route-based alarms
- [ ] Snooze functionality
- [ ] Multiple destination alarms

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Acknowledgments

- Flutter team for the amazing framework
- Google Maps Platform for location services
- Community contributors and testers

## Support

For issues, questions, or suggestions, please open an issue on GitHub.
