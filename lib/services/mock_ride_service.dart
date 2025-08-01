import 'dart:async';
import 'dart:math';
import '../models/ride_group.dart';
import '../services/ride_service.dart';

class MockRideService implements IRideService {
  final Map<String, RideGroup> _rides = {};
  final Map<String, Map<String, dynamic>> _joinRequests = {};
  final StreamController<RideGroup?> _rideStreamController = StreamController<RideGroup?>.broadcast();
  final StreamController<List<RideGroup>> _userRidesStreamController = StreamController<List<RideGroup>>.broadcast();

  MockRideService() {
    _initializeMockData();
  }

  void _initializeMockData() {
    final now = DateTime.now();
    
    // Create some mock rides
    final mockRides = [
      RideGroup(
        id: 'ride-1',
        leaderId: 'user-456',
        pickupLocation: 'Downtown Station',
        pickupCoordinates: LatLng(40.7128, -74.0060),
        destination: 'Airport Terminal',
        destinationCoordinates: LatLng(40.6892, -74.1745),
        scheduledTime: now.add(const Duration(hours: 2)),
        totalSeats: 4,
        availableSeats: 2,
        totalFare: 80.0,
        pricePerPerson: 40.0,
        notes: 'Comfortable ride with AC',
        createdAt: now.subtract(const Duration(hours: 1)),
      ),
      RideGroup(
        id: 'ride-2',
        leaderId: 'user-789',
        pickupLocation: 'Central Mall',
        pickupCoordinates: LatLng(40.7589, -73.9851),
        destination: 'University Campus',
        destinationCoordinates: LatLng(40.8176, -73.9782),
        scheduledTime: now.add(const Duration(hours: 4)),
        totalSeats: 3,
        availableSeats: 1,
        totalFare: 45.0,
        pricePerPerson: 22.5,
        femaleOnly: true,
        createdAt: now.subtract(const Duration(minutes: 30)),
      ),
      RideGroup(
        id: 'ride-3',
        leaderId: 'mock-user-123',
        pickupLocation: 'Business District',
        pickupCoordinates: LatLng(40.7505, -73.9934),
        destination: 'Residential Area',
        destinationCoordinates: LatLng(40.7282, -73.7949),
        scheduledTime: now.add(const Duration(days: 1)),
        totalSeats: 5,
        availableSeats: 3,
        totalFare: 120.0,
        pricePerPerson: 60.0,
        notes: 'Daily commute, very punctual',
        createdAt: now.subtract(const Duration(hours: 2)),
      ),
    ];

    for (final ride in mockRides) {
      _rides[ride.id] = ride;
    }
  }

  @override
  Future<String> createRide(RideGroup ride) async {
    await Future.delayed(const Duration(milliseconds: 500));
    
    final rideId = 'ride-${DateTime.now().millisecondsSinceEpoch}';
    
    // Create a new ride with the generated ID, bypassing validation
    final newRide = RideGroup(
      id: rideId,
      leaderId: ride.leaderId,
      pickupLocation: ride.pickupLocation,
      pickupCoordinates: ride.pickupCoordinates,
      destination: ride.destination,
      destinationCoordinates: ride.destinationCoordinates,
      scheduledTime: ride.scheduledTime,
      totalSeats: ride.totalSeats,
      availableSeats: ride.availableSeats,
      totalFare: ride.totalFare,
      pricePerPerson: ride.pricePerPerson,
      notes: ride.notes,
      femaleOnly: ride.femaleOnly,
      status: ride.status,
      memberIds: ride.memberIds,
      joinRequests: ride.joinRequests,
      createdAt: ride.createdAt,
    );
    
    _rides[rideId] = newRide;
    _rideStreamController.add(newRide);
    
    return rideId;
  }

  @override
  Future<RideGroup?> getRide(String rideId) async {
    await Future.delayed(const Duration(milliseconds: 200));
    return _rides[rideId];
  }

  @override
  Stream<RideGroup?> getRideStream(String rideId) {
    return Stream.periodic(const Duration(seconds: 1), (_) => _rides[rideId])
        .distinct();
  }

  @override
  Future<List<RideGroup>> searchRides(Map<String, dynamic> criteria) async {
    await Future.delayed(const Duration(milliseconds: 300));
    
    var results = _rides.values.where((ride) => 
        ride.status == RideStatus.created && 
        ride.availableSeats > 0).toList();
    
    // Apply filters
    if (criteria.containsKey('destination')) {
      final destination = criteria['destination'] as String;
      results = results.where((ride) => 
          ride.destination.toLowerCase().contains(destination.toLowerCase())).toList();
    }
    
    if (criteria.containsKey('femaleOnly')) {
      final femaleOnly = criteria['femaleOnly'] as bool;
      results = results.where((ride) => ride.femaleOnly == femaleOnly).toList();
    }
    
    if (criteria.containsKey('date')) {
      final date = criteria['date'] as DateTime;
      final startOfDay = DateTime(date.year, date.month, date.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));
      results = results.where((ride) => 
          ride.scheduledTime.isAfter(startOfDay) && 
          ride.scheduledTime.isBefore(endOfDay)).toList();
    }
    
    // Sort by scheduled time
    results.sort((a, b) => a.scheduledTime.compareTo(b.scheduledTime));
    
    return results;
  }

  @override
  Future<List<RideGroup>> getNearbyRides(double lat, double lng, {double radiusKm = 50}) async {
    await Future.delayed(const Duration(milliseconds: 400));
    
    final nearbyRides = <RideGroup>[];
    
    for (final ride in _rides.values) {
      if (ride.status == RideStatus.created && ride.availableSeats > 0) {
        final distance = await calculateDistance(
          LatLng(lat, lng),
          ride.pickupCoordinates,
        );
        
        if (distance <= radiusKm) {
          nearbyRides.add(ride);
        }
      }
    }
    
    nearbyRides.sort((a, b) => a.scheduledTime.compareTo(b.scheduledTime));
    return nearbyRides;
  }

  @override
  Future<List<RideGroup>> getUserRides(String userId) async {
    await Future.delayed(const Duration(milliseconds: 250));
    
    final userRides = _rides.values.where((ride) => 
        ride.leaderId == userId || ride.memberIds.contains(userId)).toList();
    
    userRides.sort((a, b) => b.scheduledTime.compareTo(a.scheduledTime));
    return userRides;
  }

  @override
  Stream<List<RideGroup>> getUserRidesStream(String userId) {
    return Stream.periodic(const Duration(seconds: 2), (_) {
      final userRides = _rides.values.where((ride) => 
          ride.leaderId == userId || ride.memberIds.contains(userId)).toList();
      
      userRides.sort((a, b) => b.scheduledTime.compareTo(a.scheduledTime));
      return userRides;
    }).distinct();
  }

  @override
  Future<void> updateRide(RideGroup ride) async {
    await Future.delayed(const Duration(milliseconds: 300));
    
    if (!_rides.containsKey(ride.id)) {
      throw Exception('Ride not found');
    }
    
    _rides[ride.id] = ride;
    _rideStreamController.add(ride);
  }

  @override
  Future<void> cancelRide(String rideId, String reason) async {
    await Future.delayed(const Duration(milliseconds: 300));
    
    final ride = _rides[rideId];
    if (ride == null) {
      throw Exception('Ride not found');
    }
    
    final cancelledRide = ride.copyWith(status: RideStatus.cancelled);
    _rides[rideId] = cancelledRide;
    _rideStreamController.add(cancelledRide);
  }

  @override
  Future<void> requestToJoin(String rideId, String userId) async {
    await Future.delayed(const Duration(milliseconds: 200));
    
    final requestId = '${rideId}_$userId';
    
    if (_joinRequests.containsKey(requestId)) {
      throw Exception('Join request already exists');
    }
    
    _joinRequests[requestId] = {
      'rideId': rideId,
      'userId': userId,
      'status': 'pending',
      'createdAt': DateTime.now(),
    };
  }

  @override
  Future<void> approveJoinRequest(String rideId, String requesterId) async {
    await Future.delayed(const Duration(milliseconds: 300));
    
    final requestId = '${rideId}_$requesterId';
    final request = _joinRequests[requestId];
    
    if (request == null || request['status'] != 'pending') {
      throw Exception('Join request not found or already processed');
    }
    
    final ride = _rides[rideId];
    if (ride == null) {
      throw Exception('Ride not found');
    }
    
    if (ride.availableSeats <= 0) {
      throw Exception('No available seats');
    }
    
    // Update join request
    _joinRequests[requestId]!['status'] = 'approved';
    
    // Add member to ride
    final updatedRide = ride.addMember(requesterId);
    _rides[rideId] = updatedRide;
    _rideStreamController.add(updatedRide);
  }

  @override
  Future<void> rejectJoinRequest(String rideId, String requesterId, String reason) async {
    await Future.delayed(const Duration(milliseconds: 200));
    
    final requestId = '${rideId}_$requesterId';
    final request = _joinRequests[requestId];
    
    if (request == null || request['status'] != 'pending') {
      throw Exception('Join request not found or already processed');
    }
    
    _joinRequests[requestId]!['status'] = 'rejected';
    _joinRequests[requestId]!['rejectionReason'] = reason;
  }

  @override
  Future<void> removeMember(String rideId, String memberId) async {
    await Future.delayed(const Duration(milliseconds: 300));
    
    final ride = _rides[rideId];
    if (ride == null) {
      throw Exception('Ride not found');
    }
    
    if (!ride.memberIds.contains(memberId)) {
      throw Exception('User is not a member of this ride');
    }
    
    final updatedRide = ride.removeMember(memberId);
    _rides[rideId] = updatedRide;
    _rideStreamController.add(updatedRide);
  }

  @override
  Future<void> startRide(String rideId) async {
    await Future.delayed(const Duration(milliseconds: 200));
    
    final ride = _rides[rideId];
    if (ride == null) {
      throw Exception('Ride not found');
    }
    
    final startedRide = ride.copyWith(status: RideStatus.active);
    _rides[rideId] = startedRide;
    _rideStreamController.add(startedRide);
  }

  @override
  Future<void> completeRide(String rideId) async {
    await Future.delayed(const Duration(milliseconds: 200));
    
    final ride = _rides[rideId];
    if (ride == null) {
      throw Exception('Ride not found');
    }
    
    final completedRide = ride.copyWith(status: RideStatus.completed);
    _rides[rideId] = completedRide;
    _rideStreamController.add(completedRide);
  }

  @override
  Future<double> calculateDistance(LatLng from, LatLng to) async {
    await Future.delayed(const Duration(milliseconds: 100));
    
    // Using Haversine formula
    const double earthRadius = 6371; // Earth's radius in kilometers
    
    final double lat1Rad = from.latitude * (pi / 180);
    final double lat2Rad = to.latitude * (pi / 180);
    final double deltaLatRad = (to.latitude - from.latitude) * (pi / 180);
    final double deltaLngRad = (to.longitude - from.longitude) * (pi / 180);
    
    final double a = sin(deltaLatRad / 2) * sin(deltaLatRad / 2) +
        cos(lat1Rad) * cos(lat2Rad) *
        sin(deltaLngRad / 2) * sin(deltaLngRad / 2);
    
    final double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    
    return earthRadius * c;
  }

  @override
  Future<double> calculateFare(LatLng from, LatLng to, int passengers) async {
    final distance = await calculateDistance(from, to);
    
    // Mock fare calculation
    const double baseFare = 5.0;
    const double perKmRate = 1.5;
    const double perPassengerMultiplier = 0.8;
    
    final double distanceFare = distance * perKmRate;
    final double totalFare = (baseFare + distanceFare) * passengers * perPassengerMultiplier;
    
    return double.parse(totalFare.toStringAsFixed(2));
  }

  void dispose() {
    _rideStreamController.close();
    _userRidesStreamController.close();
  }
}