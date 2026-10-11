class RideModel {
  final String id;
  final String driverId;
  final String driverName;
  final String vehicleId;
  final String vehicleInfo;
  final String source;
  final String destination;
  final List<String> intermediateStops;
  final DateTime dateTime;
  final int availableSeats;
  final int totalSeats;
  final double farePerSeat;
  final String status; // active, booked, started, completed, cancelled
  final String petPolicy; // allowed, not_allowed, not_preferred
  final DateTime createdAt;

  int get seats => availableSeats;

  RideModel({
    required this.id,
    required this.driverId,
    required this.driverName,
    required this.vehicleId,
    this.vehicleInfo = '',
    required this.source,
    required this.destination,
    this.intermediateStops = const [],
    required this.dateTime,
    required this.availableSeats,
    required this.totalSeats,
    required this.farePerSeat,
    this.status = 'active',
    this.petPolicy = 'not_allowed',
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
    'id': id,
    'driverId': driverId,
    'driverName': driverName,
    'vehicleId': vehicleId,
    'vehicleInfo': vehicleInfo,
    'source': source,
    'destination': destination,
    'intermediateStops': intermediateStops,
    'dateTime': dateTime.toIso8601String(),
    'availableSeats': availableSeats,
    'totalSeats': totalSeats,
    'farePerSeat': farePerSeat,
    'status': status,
    'petPolicy': petPolicy,
    'createdAt': createdAt.toIso8601String(),
  };

  factory RideModel.fromJson(Map<String, dynamic> json) => RideModel(
    id: json['id'],
    driverId: json['driverId'],
    driverName: json['driverName'],
    vehicleId: json['vehicleId'],
    vehicleInfo: json['vehicleInfo'] ?? '',
    source: json['source'],
    destination: json['destination'],
    intermediateStops: List<String>.from(json['intermediateStops'] ?? []),
    dateTime: DateTime.parse(json['dateTime']),
    availableSeats: json['availableSeats'],
    totalSeats: json['totalSeats'],
    farePerSeat: (json['farePerSeat'] as num).toDouble(),
    status: json['status'] ?? 'active',
    petPolicy: json['petPolicy'] ?? 'not_allowed',
    createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt']) : null,
  );

  RideModel copyWith({int? availableSeats, String? status}) => RideModel(
    id: id,
    driverId: driverId,
    driverName: driverName,
    vehicleId: vehicleId,
    vehicleInfo: vehicleInfo,
    source: source,
    destination: destination,
    intermediateStops: intermediateStops,
    dateTime: dateTime,
    availableSeats: availableSeats ?? this.availableSeats,
    totalSeats: totalSeats,
    farePerSeat: farePerSeat,
    status: status ?? this.status,
    petPolicy: petPolicy,
    createdAt: createdAt,
  );
}
