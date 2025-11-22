class Alarm {
  final String id;
  final String name;
  final String address;
  final double latitude;
  final double longitude;
  final double radius;
  final String soundLevel;
  bool isActive; // Changed from final to mutable
  bool isCompleted; // Marks alarm as completed when user reaches destination
  DateTime? completedAt; // Timestamp when alarm was triggered

  Alarm({
    required this.id,
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.radius,
    this.soundLevel = 'Medium',
    this.isActive = false,
    this.isCompleted = false,
    this.completedAt,
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
      'isCompleted': isCompleted,
      'completedAt': completedAt?.toIso8601String(),
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
      isCompleted: json['isCompleted'] ?? false,
      completedAt: json['completedAt'] != null
          ? DateTime.tryParse(json['completedAt'])
          : null,
    );
  }
}