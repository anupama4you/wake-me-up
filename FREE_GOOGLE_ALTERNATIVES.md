# Free Alternatives to Google Maps/Places APIs

## Overview

Your app currently uses **two Google services**:

1. **Google Maps** - For displaying the map (✅ REQUIRED Google API Key)
2. **Google Places Autocomplete** - For location search (✅ REQUIRED Google API Key)

**Good News**: Geofencing uses native platform APIs (completely free, no API key needed!)

## What You Actually Need API Keys For

### Current Usage in Your App:

| Feature | Service | API Key Required? | Cost |
|---------|---------|-------------------|------|
| Geofencing (location monitoring) | Native iOS/Android | ❌ No | Free |
| Location Services | Native GPS | ❌ No | Free |
| Map Display | Google Maps | ✅ Yes | Free tier available |
| Location Search/Autocomplete | Google Places | ✅ Yes | Free tier available |
| Notifications | Native iOS/Android | ❌ No | Free |
| Alarm Sound/Vibration | Native iOS/Android | ❌ No | Free |

**Only the map display and search need API keys.**

## Free Alternatives

### Option 1: OpenStreetMap (OSM) - Completely Free! 🌟

**Best free alternative with NO API key required.**

#### Pros:
- ✅ Completely free (unlimited usage)
- ✅ No API key required
- ✅ Open source
- ✅ Good worldwide coverage
- ✅ Active community
- ✅ No billing setup needed

#### Cons:
- ⚠️ Less polished UI than Google Maps
- ⚠️ Search not as good as Google Places
- ⚠️ Requires manual tile server setup for heavy usage

#### Flutter Package:
```yaml
dependencies:
  flutter_map: ^7.0.2
  latlong2: ^0.9.0
```

#### Implementation:
```dart
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

FlutterMap(
  options: MapOptions(
    initialCenter: LatLng(51.5, -0.09),
    initialZoom: 13.0,
  ),
  children: [
    TileLayer(
      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
      userAgentPackageName: 'com.example.wakemeup',
    ),
  ],
)
```

#### Search: Nominatim (free geocoding)
```yaml
dependencies:
  nominatim_flutter: ^1.0.0
```

**Cost**: $0 forever

---

### Option 2: Mapbox - Free Tier Available

**Professional alternative with generous free tier.**

#### Pros:
- ✅ 50,000 free map loads/month
- ✅ Beautiful, customizable maps
- ✅ Good search/geocoding
- ✅ Professional support
- ✅ Better than OSM UI

#### Cons:
- ⚠️ Requires API key (but free tier)
- ⚠️ Need credit card for signup
- ⚠️ Costs after free tier

#### Flutter Package:
```yaml
dependencies:
  mapbox_maps_flutter: ^2.0.0
```

#### Free Tier:
- 50,000 map loads/month
- 100,000 geocoding requests/month

**Cost**: Free for small apps, $5-10/month if you exceed limits

---

### Option 3: Apple Maps (iOS) + Google Maps (Android)

**Use native platform maps - partially free.**

#### Pros:
- ✅ Apple Maps is FREE on iOS (no key needed)
- ✅ Best performance on each platform
- ✅ Native look and feel

#### Cons:
- ⚠️ Still need Google API key for Android
- ⚠️ More complex code (platform-specific)
- ⚠️ Apple Maps only works on iOS

#### Flutter Package:
```yaml
dependencies:
  apple_maps_flutter: ^1.0.0  # iOS only
  google_maps_flutter: ^2.0.0  # Android only
```

**Cost**: Free on iOS, Google pricing on Android

---

### Option 4: HERE Maps - Free Tier

**Enterprise mapping with free tier.**

#### Pros:
- ✅ 250,000 free transactions/month
- ✅ Good worldwide coverage
- ✅ Professional quality

#### Cons:
- ⚠️ Requires API key
- ⚠️ Smaller Flutter community
- ⚠️ Less documentation

**Cost**: Free tier up to 250k requests/month

---

## Recommended Solution for Your App

### 🏆 Best Choice: **OpenStreetMap (OSM) with flutter_map**

**Why?**
1. ✅ **Truly free** - No API key, no billing, no limits
2. ✅ **Privacy-friendly** - No tracking
3. ✅ **Your app is simple** - Just need to show location on map
4. ✅ **Search is optional** - Users can drop pins manually

### Implementation Plan

**Phase 1: Replace Google Maps with OpenStreetMap**
- Remove `google_maps_flutter` dependency
- Add `flutter_map` package
- Update map widgets to use flutter_map
- Keep your existing geofencing (it's already free!)

**Phase 2: Add Free Search (Optional)**
- Use Nominatim for address search
- Or keep manual pin dropping (no search needed)
- Or use simple address input (no autocomplete)

### Quick Comparison

| Feature | Google Maps | OpenStreetMap | Mapbox |
|---------|-------------|---------------|--------|
| **Map Display** | Requires key | ✅ No key | Requires key |
| **Search** | Requires key | Free (Nominatim) | Free tier |
| **Monthly Cost** | Free tier → paid | ✅ $0 forever | Free tier → paid |
| **Setup Complexity** | Easy | Medium | Easy |
| **Map Quality** | Excellent | Good | Excellent |
| **Flutter Support** | Excellent | Good | Good |

---

## Google Maps Free Tier (If You Keep It)

**You can stay with Google for free if:**

Your usage is under these limits (per month):
- **Maps**: 28,000 map loads (free)
- **Places Autocomplete**: 1,000 requests (free, then $2.83 per 1000)
- **Geocoding**: 40,000 requests (free)

**Monthly free usage**: ~$200 credit

### When Google Costs Money:

After free tier:
- Dynamic Maps: $7 per 1,000 loads
- Places Autocomplete: $2.83 per 1,000 requests
- If 100 users use your app 10 times/day = 30,000 loads = ~$7/month

---

## Migration Guide: Google Maps → OpenStreetMap

### Step 1: Update Dependencies

```yaml
# pubspec.yaml
dependencies:
  # Remove or comment out:
  # google_maps_flutter: ^2.0.0
  # google_place: ^0.4.7

  # Add:
  flutter_map: ^7.0.2
  latlong2: ^0.9.0
  http: ^1.5.0  # For search if needed
```

### Step 2: Update Map Widget

**Before (Google Maps):**
```dart
GoogleMap(
  initialCameraPosition: CameraPosition(
    target: LatLng(lat, lng),
    zoom: 14,
  ),
  onMapCreated: (controller) => _controller = controller,
  markers: _markers,
  circles: _circles,
)
```

**After (OpenStreetMap):**
```dart
FlutterMap(
  mapController: _mapController,
  options: MapOptions(
    initialCenter: LatLng(lat, lng),
    initialZoom: 14,
    onTap: (tapPosition, point) => _handleMapTap(point),
  ),
  children: [
    TileLayer(
      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
      userAgentPackageName: 'com.example.wakemeup',
    ),
    MarkerLayer(
      markers: _markers,
    ),
    CircleLayer(
      circles: _circles,
    ),
  ],
)
```

### Step 3: Simple Search (No Autocomplete)

Instead of Google Places Autocomplete, use:

**Option A: Manual Pin Drop** (simplest)
- User taps map to set location
- No API needed
- ✅ You already have this!

**Option B: Nominatim Search** (basic search)
```dart
Future<List<Location>> searchLocation(String query) async {
  final url = 'https://nominatim.openstreetmap.org/search?q=$query&format=json';
  final response = await http.get(Uri.parse(url));
  // Parse and return results
}
```

**Option C: Address Input** (no autocomplete)
- Simple text field
- User types full address
- Search on submit (not as-you-type)

---

## Recommendation Summary

### For Your Location Alarm App:

**✅ Use OpenStreetMap** because:

1. **Your app is private/personal use** → Free forever
2. **Geofencing works independently** → No API key needed for core feature
3. **Map is just UI** → Users can tap to set location
4. **No billing headaches** → Never worry about costs

### Keep Google Maps if:

1. ❌ You want the best search experience
2. ❌ You're building for many users (100k+)
3. ❌ You need advanced features (Street View, 3D, etc.)
4. ❌ You have a budget for API costs

### For a personal alarm app? **OpenStreetMap is perfect.** 🎯

---

## Next Steps

**Want to switch to OpenStreetMap?**

I can help you:
1. Remove Google Maps dependencies
2. Add flutter_map
3. Update all map widgets
4. Add simple search (optional)
5. Test everything works

**Want to stick with Google Maps?**

Just need to:
1. Enable Google Maps API in Google Cloud Console
2. Enable Places API
3. Add billing (won't be charged unless you exceed free tier)
4. Your API key is already in the app (`.env` file)

Let me know which direction you want to go! 🚀

---

## Cost Calculator

### Scenario: Personal use (just you)
- **Google Maps**: Free forever (well under limits)
- **OpenStreetMap**: Free forever

### Scenario: 10 friends use it
- **Google Maps**: Free forever (still under limits)
- **OpenStreetMap**: Free forever

### Scenario: 1000 users
- **Google Maps**: ~$50-200/month
- **OpenStreetMap**: Free forever (but may need your own tile server)

### Scenario: Published app on App Store
- **Google Maps**: Depends on downloads (could be $$$$)
- **OpenStreetMap**: Free forever

**Verdict**: For personal/small use → Both are free. For scaling → OSM is better.
