class Alarm {
  final String id;
  final String name;
  final String address;
  final double latitude;
  final double longitude;
  final double radius;
  final String soundLevel;
  final String ringtone;
  bool isActive;
  bool isCompleted;
  DateTime? completedAt;
  final List<int> repeatDays; // 0=Mon, 1=Tue, 2=Wed, 3=Thu, 4=Fri, 5=Sat, 6=Sun

  Alarm({
    required this.id,
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.radius,
    this.soundLevel = 'Medium',
    this.ringtone = 'alarm',
    this.isActive = false,
    this.isCompleted = false,
    this.completedAt,
    this.repeatDays = const [],
  });

  bool get isRepeating => repeatDays.isNotEmpty;

  String get repeatLabel {
    if (repeatDays.isEmpty) return '';
    const abbr = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final sorted = List<int>.from(repeatDays)..sort();

    // Common patterns
    if (sorted.length == 5 && !sorted.contains(5) && !sorted.contains(6)) {
      return 'Weekdays';
    }
    if (sorted.length == 2 && sorted.contains(5) && sorted.contains(6)) {
      return 'Weekends';
    }
    if (sorted.length == 7) return 'Every day';

    return sorted.map((d) => abbr[d]).join(' · ');
  }

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
      'repeatDays': repeatDays,
    };
  }

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
      repeatDays: (json['repeatDays'] as List<dynamic>?)
              ?.map((e) => e as int)
              .toList() ??
          [],
    );
  }

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
    List<int>? repeatDays,
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
      repeatDays: repeatDays ?? this.repeatDays,
    );
  }
}
