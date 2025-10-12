import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Check if two LatLng coordinates are roughly equal within an epsilon
bool latLngRoughEqual(LatLng a, LatLng b, {double epsilon = 1e-4}) {
  return (a.latitude - b.latitude).abs() < epsilon &&
      (a.longitude - b.longitude).abs() < epsilon;
}

/// Get marker hue for location types
double getMarkerHueForTypes(List<String> types) {
  if (types.contains('bus_station')) return BitmapDescriptor.hueOrange;
  if (types.contains('train_station')) return BitmapDescriptor.hueGreen;
  if (types.contains('light_rail_station')) return BitmapDescriptor.hueViolet;
  if (types.contains('subway_station')) return BitmapDescriptor.hueRose;
  if (types.contains('transit_station')) return BitmapDescriptor.hueCyan;
  if (types.contains('airport')) return BitmapDescriptor.hueAzure;
  if (types.contains('university')) return BitmapDescriptor.hueYellow;
  if (types.contains('hospital')) return BitmapDescriptor.hueMagenta;
  if (types.contains('shopping_mall')) return BitmapDescriptor.hueOrange;
  if (types.contains('park')) return BitmapDescriptor.hueGreen;
  return BitmapDescriptor.hueRed;
}

/// Extension to convert a list of LatLng points to LatLngBounds
extension LatLngListExtension on List<LatLng> {
  LatLngBounds toBounds() {
    if (isEmpty) {
      throw Exception('Cannot create bounds from empty list');
    }

    double minLat = first.latitude;
    double maxLat = first.latitude;
    double minLng = first.longitude;
    double maxLng = first.longitude;

    for (var point in this) {
      minLat = min(minLat, point.latitude);
      maxLat = max(maxLat, point.latitude);
      minLng = min(minLng, point.longitude);
      maxLng = max(maxLng, point.longitude);
    }

    return LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );
  }
}

/// Calculate the distance between two coordinates using the Haversine formula
double calculateDistance(LatLng point1, LatLng point2) {
  const double earthRadius = 6371000; // meters
  final dLat = _degreesToRadians(point2.latitude - point1.latitude);
  final dLng = _degreesToRadians(point2.longitude - point1.longitude);

  final a = sin(dLat / 2) * sin(dLat / 2) +
      cos(_degreesToRadians(point1.latitude)) *
          cos(_degreesToRadians(point2.latitude)) *
          sin(dLng / 2) *
          sin(dLng / 2);

  final c = 2 * atan2(sqrt(a), sqrt(1 - a));
  return earthRadius * c;
}

double _degreesToRadians(double degrees) {
  return degrees * pi / 180;
}

/// Get icon for location types
IconData getIconForTypes(List<String> types) {
  if (types.contains('bus_station')) return Icons.directions_bus;
  if (types.contains('train_station')) return Icons.train;
  if (types.contains('light_rail_station')) return Icons.tram;
  if (types.contains('subway_station')) return Icons.subway;
  if (types.contains('transit_station')) return Icons.commute;
  if (types.contains('airport')) return Icons.local_airport;
  if (types.contains('university')) return Icons.school;
  if (types.contains('hospital')) return Icons.local_hospital;
  if (types.contains('shopping_mall')) return Icons.shopping_bag;
  if (types.contains('park')) return Icons.park;
  return Icons.place;
}

/// Get color for location types
Color getColorForTypes(List<String> types) {
  if (types.contains('bus_station')) return Colors.orange;
  if (types.contains('train_station')) return Colors.green;
  if (types.contains('light_rail_station')) return Colors.purple;
  if (types.contains('subway_station')) return Colors.red;
  if (types.contains('transit_station')) return Colors.teal;
  if (types.contains('airport')) return Colors.indigo;
  if (types.contains('university')) return Colors.amber;
  if (types.contains('hospital')) return Colors.pink;
  if (types.contains('shopping_mall')) return Colors.deepOrange;
  if (types.contains('park')) return Colors.lightGreen;
  return Colors.blue;
}
