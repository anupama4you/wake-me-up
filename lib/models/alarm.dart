class Alarm {
  final String id;
  final String name;
  final String address;
  final double latitude;
  final double longitude;
  final double radius;
  final String soundLevel;
  bool isActive; // Changed from final to mutable

  Alarm({
    required this.id,
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.radius,
    this.soundLevel = 'Medium',
    this.isActive = false,
  });

  // Convert Alarm to JSON for persistence
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'address': address,
      'latitude': latitude,
      'longitude': longitude,
      'radius': radius,
      'soundLevel': soundLevel,
      'isActive': isActive,
    };
  }

  // Create Alarm from JSON
  factory Alarm.fromJson(Map<String, dynamic> json) {
    return Alarm(
      id: json['id'],
      name: json['name'],
      address: json['address'],
      latitude: json['latitude'],
      longitude: json['longitude'],
      radius: json['radius'],
      soundLevel: json['soundLevel'] ?? 'Medium',
      isActive: json['isActive'] ?? false,
    );
  }
}