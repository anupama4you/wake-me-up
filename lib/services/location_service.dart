import 'package:geolocator/geolocator.dart';

class LocationService {
  static Future<bool> requestPermission() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return false;

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return false;
    }
    if (permission == LocationPermission.deniedForever) return false;

    return true;
  }

  static Future<Position?> getCurrentPosition() async {
    try {
      return await Geolocator.getCurrentPosition();
    } catch (e) {
      // ignore: avoid_print
      print('Error getting position: $e');
      return null;
    }
  }

  static Stream<Position> getLocationStream() {
    return Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10, // Update every 10 meters
      ),
    );
  }
}
