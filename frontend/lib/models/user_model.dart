class UserModel {
  final String id;
  final String name;
  final String phone;
  final String email;
  final String profilePic;
  final String emergencyContact;
  final bool isLicenseVerified;
  final bool isDriver;
  final bool isGuest;
  final DateTime createdAt;

  UserModel({
    required this.id,
    required this.name,
    required this.phone,
    this.email = '',
    this.profilePic = '',
    this.emergencyContact = '',
    this.isLicenseVerified = false,
    this.isDriver = false,
    this.isGuest = false,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'phone': phone,
        'email': email,
        'profilePic': profilePic,
        'emergencyContact': emergencyContact,
        'isLicenseVerified': isLicenseVerified,
        'isDriver': isDriver,
        'isGuest': isGuest,
        'createdAt': createdAt.toIso8601String(),
      };

  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
        id: json['id'],
        name: json['name'],
        phone: json['phone'],
        email: json['email'] ?? '',
        profilePic: json['profilePic'] ?? '',
        emergencyContact: json['emergencyContact'] ?? '',
        isLicenseVerified: json['isLicenseVerified'] ?? false,
        isDriver: json['isDriver'] ?? false,
        isGuest: json['isGuest'] ?? false,
        createdAt: json['createdAt'] != null
            ? DateTime.parse(json['createdAt'])
            : null,
      );

  UserModel copyWith({
    String? name,
    String? email,
    String? profilePic,
    String? emergencyContact,
    bool? isLicenseVerified,
    bool? isDriver,
    bool? isGuest,
  }) =>
      UserModel(
        id: id,
        phone: phone,
        name: name ?? this.name,
        email: email ?? this.email,
        profilePic: profilePic ?? this.profilePic,
        emergencyContact: emergencyContact ?? this.emergencyContact,
        isLicenseVerified: isLicenseVerified ?? this.isLicenseVerified,
        isDriver: isDriver ?? this.isDriver,
        isGuest: isGuest ?? this.isGuest,
        createdAt: createdAt,
      );
}
