class BookingModel {
  final String id;
  final String rideId;
  final String riderId;
  final String riderName;
  final int seatsBooked;
  final double totalFare;
  final String status; // confirmed, started, completed, cancelled
  final String otp;
  final DateTime otpExpiry;
  final int otpAttempts;
  final DateTime createdAt;

  BookingModel({
    required this.id,
    required this.rideId,
    required this.riderId,
    required this.riderName,
    required this.seatsBooked,
    required this.totalFare,
    this.status = 'confirmed',
    this.otp = '',
    DateTime? otpExpiry,
    this.otpAttempts = 0,
    DateTime? createdAt,
  })  : otpExpiry = otpExpiry ?? DateTime.now(),
        createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'rideId': rideId,
        'riderId': riderId,
        'riderName': riderName,
        'seatsBooked': seatsBooked,
        'totalFare': totalFare,
        'status': status,
        'otp': otp,
        'otpExpiry': otpExpiry.toIso8601String(),
        'otpAttempts': otpAttempts,
        'createdAt': createdAt.toIso8601String(),
      };

  factory BookingModel.fromJson(Map<String, dynamic> json) => BookingModel(
        id: json['id'],
        rideId: json['rideId'],
        riderId: json['riderId'],
        riderName: json['riderName'],
        seatsBooked: json['seatsBooked'],
        totalFare: (json['totalFare'] as num).toDouble(),
        status: json['status'] ?? 'confirmed',
        otp: json['otp'] ?? '',
        otpExpiry: json['otpExpiry'] != null
            ? DateTime.parse(json['otpExpiry'])
            : null,
        otpAttempts: json['otpAttempts'] ?? 0,
        createdAt: json['createdAt'] != null
            ? DateTime.parse(json['createdAt'])
            : null,
      );

  BookingModel copyWith({
    String? status,
    String? otp,
    DateTime? otpExpiry,
    int? otpAttempts,
  }) =>
      BookingModel(
        id: id,
        rideId: rideId,
        riderId: riderId,
        riderName: riderName,
        seatsBooked: seatsBooked,
        totalFare: totalFare,
        status: status ?? this.status,
        otp: otp ?? this.otp,
        otpExpiry: otpExpiry ?? this.otpExpiry,
        otpAttempts: otpAttempts ?? this.otpAttempts,
        createdAt: createdAt,
      );
}
