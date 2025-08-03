enum RideStatus { created, active, completed, cancelled }

class LatLng {
  final double latitude;
  final double longitude;

  LatLng(this.latitude, this.longitude);

  factory LatLng.fromJson(Map<String, dynamic> json) {
    return LatLng(
      json['latitude'] as double,
      json['longitude'] as double,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'latitude': latitude,
      'longitude': longitude,
    };
  }
}

class JoinRequest {
  final String id;
  final String userId;
  final String status;
  final DateTime createdAt;

  JoinRequest({
    required this.id,
    required this.userId,
    required this.status,
    required this.createdAt,
  });

  factory JoinRequest.fromJson(Map<String, dynamic> json) {
    return JoinRequest(
      id: json['id'] as String,
      userId: json['userId'] as String,
      status: json['status'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'status': status,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}

class RideGroup {
  final String id;
  final String leaderId;
  final String pickupLocation;
  final LatLng pickupCoordinates;
  final String destination;
  final LatLng destinationCoordinates;
  final DateTime scheduledTime;
  final int totalSeats;
  final int availableSeats;
  final double totalFare;
  final double pricePerPerson;
  final String? notes;
  final bool femaleOnly;

  final RideStatus status;
  final List<String> memberIds;
  final List<JoinRequest> joinRequests;
  final DateTime createdAt;

  RideGroup({
    required this.id,
    required this.leaderId,
    required this.pickupLocation,
    required this.pickupCoordinates,
    required this.destination,
    required this.destinationCoordinates,
    required this.scheduledTime,
    required this.totalSeats,
    required this.availableSeats,
    required this.totalFare,
    required this.pricePerPerson,
    this.notes,
    this.femaleOnly = false,

    this.status = RideStatus.created,
    this.memberIds = const [],
    this.joinRequests = const [],
    required this.createdAt,
  }) {
    _validate();
  }

  void _validate() {
    if (id.isEmpty) throw ArgumentError('Ride ID cannot be empty');
    if (leaderId.isEmpty) throw ArgumentError('Leader ID cannot be empty');
    if (pickupLocation.isEmpty) throw ArgumentError('Pickup location cannot be empty');
    if (destination.isEmpty) throw ArgumentError('Destination cannot be empty');
    if (totalSeats <= 0 || totalSeats > 8) {
      throw ArgumentError('Total seats must be between 1 and 8');
    }
    if (availableSeats < 0 || availableSeats > totalSeats) {
      throw ArgumentError('Available seats must be between 0 and total seats');
    }
    if (totalFare <= 0) throw ArgumentError('Total fare must be positive');
    if (pricePerPerson <= 0) throw ArgumentError('Price per person must be positive');
    if (scheduledTime.isBefore(DateTime.now())) {
      throw ArgumentError('Scheduled time cannot be in the past');
    }
    if (notes != null && notes!.length > 500) {
      throw ArgumentError('Notes cannot exceed 500 characters');
    }
    
    // Validate price calculation - current members (including leader)
    final currentMembers = totalSeats - availableSeats;
    if (currentMembers <= 0) {
      throw ArgumentError('Must have at least one member (the leader)');
    }
    final expectedPricePerPerson = totalFare / currentMembers;
    if ((pricePerPerson - expectedPricePerPerson).abs() > 0.01) {
      throw ArgumentError('Price per person calculation is incorrect');
    }
  }

  bool get isFull {
    return availableSeats == 0;
  }

  bool get canAcceptMoreMembers {
    return availableSeats > 0 && status == RideStatus.created;
  }

  bool get isActive {
    return status == RideStatus.active;
  }

  bool get isCompleted {
    return status == RideStatus.completed;
  }

  bool get isCancelled {
    return status == RideStatus.cancelled;
  }

  int get currentMemberCount {
    return totalSeats - availableSeats;
  }

  bool canUserJoin(String userId) {
    return canAcceptMoreMembers && 
           !memberIds.contains(userId) && 
           userId != leaderId &&
           !joinRequests.any((request) => request.userId == userId);
  }

  RideGroup addMember(String userId) {
    if (!canAcceptMoreMembers) {
      throw StateError('Cannot add more members to this ride');
    }
    if (memberIds.contains(userId)) {
      throw StateError('User is already a member');
    }
    
    final newMemberIds = List<String>.from(memberIds)..add(userId);
    final newAvailableSeats = availableSeats - 1;
    final newCurrentMembers = totalSeats - newAvailableSeats;
    final newPricePerPerson = totalFare / newCurrentMembers;
    
    return copyWith(
      memberIds: newMemberIds,
      availableSeats: newAvailableSeats,
      pricePerPerson: newPricePerPerson,
    );
  }

  RideGroup removeMember(String userId) {
    if (!memberIds.contains(userId)) {
      throw StateError('User is not a member of this ride');
    }
    
    final newMemberIds = List<String>.from(memberIds)..remove(userId);
    final newAvailableSeats = availableSeats + 1;
    final newCurrentMembers = totalSeats - newAvailableSeats;
    final newPricePerPerson = totalFare / newCurrentMembers;
    
    return copyWith(
      memberIds: newMemberIds,
      availableSeats: newAvailableSeats,
      pricePerPerson: newPricePerPerson,
    );
  }

  RideGroup copyWith({
    String? id,
    String? leaderId,
    String? pickupLocation,
    LatLng? pickupCoordinates,
    String? destination,
    LatLng? destinationCoordinates,
    DateTime? scheduledTime,
    int? totalSeats,
    int? availableSeats,
    double? totalFare,
    double? pricePerPerson,
    String? notes,
    bool? femaleOnly,

    RideStatus? status,
    List<String>? memberIds,
    List<JoinRequest>? joinRequests,
    DateTime? createdAt,
  }) {
    return RideGroup(
      id: id ?? this.id,
      leaderId: leaderId ?? this.leaderId,
      pickupLocation: pickupLocation ?? this.pickupLocation,
      pickupCoordinates: pickupCoordinates ?? this.pickupCoordinates,
      destination: destination ?? this.destination,
      destinationCoordinates: destinationCoordinates ?? this.destinationCoordinates,
      scheduledTime: scheduledTime ?? this.scheduledTime,
      totalSeats: totalSeats ?? this.totalSeats,
      availableSeats: availableSeats ?? this.availableSeats,
      totalFare: totalFare ?? this.totalFare,
      pricePerPerson: pricePerPerson ?? this.pricePerPerson,
      notes: notes ?? this.notes,
      femaleOnly: femaleOnly ?? this.femaleOnly,

      status: status ?? this.status,
      memberIds: memberIds ?? this.memberIds,
      joinRequests: joinRequests ?? this.joinRequests,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  factory RideGroup.fromJson(Map<String, dynamic> json) {
    return RideGroup(
      id: json['id'] as String,
      leaderId: json['leaderId'] as String,
      pickupLocation: json['pickupLocation'] as String,
      pickupCoordinates: LatLng.fromJson(json['pickupCoordinates'] as Map<String, dynamic>),
      destination: json['destination'] as String,
      destinationCoordinates: LatLng.fromJson(json['destinationCoordinates'] as Map<String, dynamic>),
      scheduledTime: DateTime.parse(json['scheduledTime'] as String),
      totalSeats: json['totalSeats'] as int,
      availableSeats: json['availableSeats'] as int,
      totalFare: (json['totalFare'] as num).toDouble(),
      pricePerPerson: (json['pricePerPerson'] as num).toDouble(),
      notes: json['notes'] as String?,
      femaleOnly: json['femaleOnly'] as bool? ?? false,

      status: RideStatus.values.firstWhere(
        (e) => e.toString().split('.').last == json['status'],
        orElse: () => RideStatus.created,
      ),
      memberIds: List<String>.from(json['memberIds'] as List? ?? []),
      joinRequests: (json['joinRequests'] as List?)
          ?.map((e) => JoinRequest.fromJson(e as Map<String, dynamic>))
          .toList() ?? [],
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'leaderId': leaderId,
      'pickupLocation': pickupLocation,
      'pickupCoordinates': pickupCoordinates.toJson(),
      'destination': destination,
      'destinationCoordinates': destinationCoordinates.toJson(),
      'scheduledTime': scheduledTime.toIso8601String(),
      'totalSeats': totalSeats,
      'availableSeats': availableSeats,
      'totalFare': totalFare,
      'pricePerPerson': pricePerPerson,
      'notes': notes,
      'femaleOnly': femaleOnly,

      'status': status.toString().split('.').last,
      'memberIds': memberIds,
      'joinRequests': joinRequests.map((e) => e.toJson()).toList(),
      'createdAt': createdAt.toIso8601String(),
    };
  }
}