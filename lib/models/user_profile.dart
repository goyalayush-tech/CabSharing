class UserProfile {
  final String id;
  final String name;
  final String email;
  final String? profileImageUrl;
  final String? bio;
  final String? phoneNumber;
  final double averageRating;
  final int totalRides;
  final bool isVerified;
  final DateTime createdAt;
  final DateTime updatedAt;

  UserProfile({
    required this.id,
    required this.name,
    required this.email,
    this.profileImageUrl,
    this.bio,
    this.phoneNumber,
    this.averageRating = 0.0,
    this.totalRides = 0,
    this.isVerified = false,
    required this.createdAt,
    required this.updatedAt,
  }) {
    _validate();
  }

  void _validate() {
    if (id.isEmpty) throw ArgumentError('User ID cannot be empty');
    if (name.isEmpty) throw ArgumentError('Name cannot be empty');
    if (!_isValidEmail(email)) throw ArgumentError('Invalid email format');
    if (averageRating < 0.0 || averageRating > 5.0) {
      throw ArgumentError('Average rating must be between 0.0 and 5.0');
    }
    if (totalRides < 0) throw ArgumentError('Total rides cannot be negative');
    if (phoneNumber != null && !_isValidPhoneNumber(phoneNumber!)) {
      throw ArgumentError('Invalid phone number format');
    }
    if (bio != null && bio!.length > 500) {
      throw ArgumentError('Bio cannot exceed 500 characters');
    }
  }

  bool _isValidEmail(String email) {
    return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
  }

  bool _isValidPhoneNumber(String phone) {
    return RegExp(r'^\+?[\d\s\-\(\)]{10,15}$').hasMatch(phone);
  }

  bool get isProfileComplete {
    return bio != null && phoneNumber != null;
  }

  bool get hasGoodRating {
    return averageRating >= 4.0 && totalRides >= 5;
  }

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String,
      name: json['name'] as String,
      email: json['email'] as String,
      profileImageUrl: json['profileImageUrl'] as String?,
      bio: json['bio'] as String?,
      phoneNumber: json['phoneNumber'] as String?,
      averageRating: (json['averageRating'] as num?)?.toDouble() ?? 0.0,
      totalRides: json['totalRides'] as int? ?? 0,
      isVerified: json['isVerified'] as bool? ?? false,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'profileImageUrl': profileImageUrl,
      'bio': bio,
      'phoneNumber': phoneNumber,
      'averageRating': averageRating,
      'totalRides': totalRides,
      'isVerified': isVerified,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  UserProfile copyWith({
    String? id,
    String? name,
    String? email,
    String? profileImageUrl,
    String? bio,
    String? phoneNumber,
    double? averageRating,
    int? totalRides,
    bool? isVerified,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      bio: bio ?? this.bio,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      averageRating: averageRating ?? this.averageRating,
      totalRides: totalRides ?? this.totalRides,
      isVerified: isVerified ?? this.isVerified,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}