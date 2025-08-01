class Rating {
  final String id;
  final String rideId;
  final String raterId;
  final String ratedUserId;
  final int stars;
  final String? comment;
  final DateTime createdAt;

  Rating({
    required this.id,
    required this.rideId,
    required this.raterId,
    required this.ratedUserId,
    required this.stars,
    this.comment,
    required this.createdAt,
  }) {
    _validate();
  }

  void _validate() {
    if (id.isEmpty) throw ArgumentError('Rating ID cannot be empty');
    if (rideId.isEmpty) throw ArgumentError('Ride ID cannot be empty');
    if (raterId.isEmpty) throw ArgumentError('Rater ID cannot be empty');
    if (ratedUserId.isEmpty) throw ArgumentError('Rated user ID cannot be empty');
    if (raterId == ratedUserId) {
      throw ArgumentError('User cannot rate themselves');
    }
    if (!isValid()) {
      throw ArgumentError('Rating stars must be between 1 and 5');
    }
    if (comment != null && comment!.length > 500) {
      throw ArgumentError('Comment cannot exceed 500 characters');
    }
    if (createdAt.isAfter(DateTime.now())) {
      throw ArgumentError('Rating creation date cannot be in the future');
    }
  }

  bool get isPositive {
    return stars >= 4;
  }

  bool get isNegative {
    return stars <= 2;
  }

  bool get hasComment {
    return comment != null && comment!.isNotEmpty;
  }

  factory Rating.fromJson(Map<String, dynamic> json) {
    return Rating(
      id: json['id'] as String,
      rideId: json['rideId'] as String,
      raterId: json['raterId'] as String,
      ratedUserId: json['ratedUserId'] as String,
      stars: json['stars'] as int,
      comment: json['comment'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'rideId': rideId,
      'raterId': raterId,
      'ratedUserId': ratedUserId,
      'stars': stars,
      'comment': comment,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  Rating copyWith({
    String? id,
    String? rideId,
    String? raterId,
    String? ratedUserId,
    int? stars,
    String? comment,
    DateTime? createdAt,
  }) {
    return Rating(
      id: id ?? this.id,
      rideId: rideId ?? this.rideId,
      raterId: raterId ?? this.raterId,
      ratedUserId: ratedUserId ?? this.ratedUserId,
      stars: stars ?? this.stars,
      comment: comment ?? this.comment,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  bool isValid() {
    return stars >= 1 && stars <= 5;
  }
}