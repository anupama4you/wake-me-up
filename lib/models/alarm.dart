class Alarm {
  final String id;
  final String name;
  final String address;
  final double latitude;
  final double longitude;
  final double radius;
  final String soundLevel;
  final String ringtone; // Custom ringtone selection
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
    this.ringtone = 'alarm', // Default to alarm.mp3
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
      'ringtone': ringtone,
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
      ringtone: json['ringtone'] ?? 'alarm',
      isActive: json['isActive'] ?? false,
      isCompleted: json['isCompleted'] ?? false,
      completedAt: json['completedAt'] != null
          ? DateTime.tryParse(json['completedAt'])
          : null,
    );
  }

  /// Create a copy of this alarm with updated fields
  Alarm copyWith({
    String? id,
    String? name,
    String? address,
    double? latitude,
    double? longitude,
    double? radius,
    String? soundLevel,
    String? ringtone,
    bool? isActive,
    bool? isCompleted,
    DateTime? completedAt,
  }) {
    return Alarm(
      id: id ?? this.id,
      name: name ?? this.name,
      address: address ?? this.address,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      radius: radius ?? this.radius,
      soundLevel: soundLevel ?? this.soundLevel,
      ringtone: ringtone ?? this.ringtone,
      isActive: isActive ?? this.isActive,
      isCompleted: isCompleted ?? this.isCompleted,
      completedAt: completedAt ?? this.completedAt,
    );
  }
}