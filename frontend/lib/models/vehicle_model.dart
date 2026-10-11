class VehicleModel {
  final String id;
  final String userId;
  final String make;
  final String model;
  final String year;
  final String color;
  final String licensePlate;
  final int seats;
  final DateTime createdAt;

  VehicleModel({
    required this.id,
    required this.userId,
    required this.make,
    required this.model,
    required this.year,
    required this.color,
    required this.licensePlate,
    required this.seats,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
    'id': id,
    'userId': userId,
    'make': make,
    'model': model,
    'year': year,
    'color': color,
    'licensePlate': licensePlate,
    'seats': seats,
    'createdAt': createdAt.toIso8601String(),
  };

  factory VehicleModel.fromJson(Map<String, dynamic> json) => VehicleModel(
    id: json['id'],
    userId: json['userId'],
    make: json['make'],
    model: json['model'],
    year: json['year'],
    color: json['color'],
    licensePlate: json['licensePlate'],
    seats: json['seats'],
    createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt']) : null,
  );

  String get displayName => '$make $model ($color)';
}
