import 'dart:io';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/ride_group.dart';
import '../core/errors/app_error.dart';

abstract class IRideService {
  Future<String> createRide(RideGroup ride);
  Future<RideGroup?> getRide(String rideId);
  Future<List<RideGroup>> searchRides(Map<String, dynamic> criteria);
  Future<List<RideGroup>> getNearbyRides(double lat, double lng, {double radiusKm = 50});
  Future<List<RideGroup>> getUserRides(String userId);
  Future<void> updateRide(RideGroup ride);
  Future<void> cancelRide(String rideId, String reason);
  Future<void> requestToJoin(String rideId, String userId);
  Future<void> approveJoinRequest(String rideId, String requesterId);
  Future<void> rejectJoinRequest(String rideId, String requesterId, String reason);
  Future<void> removeMember(String rideId, String memberId);
  Future<void> startRide(String rideId);
  Future<void> completeRide(String rideId);
  Stream<RideGroup?> getRideStream(String rideId);
  Stream<List<RideGroup>> getUserRidesStream(String userId);
  Future<double> calculateDistance(LatLng from, LatLng to);
  Future<double> calculateFare(LatLng from, LatLng to, int passengers);
}

class RideService implements IRideService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _ridesCollection = 'rides';
  final String _joinRequestsCollection = 'joinRequests';

  @override
  Future<String> createRide(RideGroup ride) async {
    try {
      await _checkNetworkConnectivity();
      
      // Validate ride data
      _validateRideData(ride);
      
      final rideData = ride.toJson();
      rideData['createdAt'] = FieldValue.serverTimestamp();
      rideData['updatedAt'] = FieldValue.serverTimestamp();
      
      final docRef = await _firestore.collection(_ridesCollection).add(rideData);
      return docRef.id;
    } on FirebaseException catch (e) {
      throw _handleFirebaseException(e, 'create ride');
    } catch (e) {
      if (e is AppError) rethrow;
      throw AppError.unknown('Failed to create ride: ${e.toString()}');
    }
  }

  @override
  Future<RideGroup?> getRide(String rideId) async {
    try {
      await _checkNetworkConnectivity();
      
      if (rideId.isEmpty) {
        throw AppError.validation('Ride ID cannot be empty');
      }
      
      final doc = await _firestore.collection(_ridesCollection).doc(rideId).get();
      
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        data['id'] = doc.id;
        return RideGroup.fromJson(data);
      }
      return null;
    } on FirebaseException catch (e) {
      throw _handleFirebaseException(e, 'get ride');
    } catch (e) {
      if (e is AppError) rethrow;
      throw AppError.unknown('Failed to get ride: ${e.toString()}');
    }
  }

  @override
  Stream<RideGroup?> getRideStream(String rideId) {
    if (rideId.isEmpty) {
      return Stream.error(AppError.validation('Ride ID cannot be empty'));
    }
    
    return _firestore
        .collection(_ridesCollection)
        .doc(rideId)
        .snapshots()
        .map((doc) {
          if (doc.exists && doc.data() != null) {
            final data = doc.data()!;
            data['id'] = doc.id;
            return RideGroup.fromJson(data);
          }
          return null;
        })
        .handleError((error) {
          if (error is FirebaseException) {
            throw _handleFirebaseException(error, 'stream ride');
          }
          throw AppError.unknown('Failed to stream ride: ${error.toString()}');
        });
  }

  @override
  Future<List<RideGroup>> searchRides(Map<String, dynamic> criteria) async {
    try {
      await _checkNetworkConnectivity();
      
      Query query = _firestore.collection(_ridesCollection)
          .where('status', isEqualTo: 'created')
          .where('availableSeats', isGreaterThan: 0);
      
      // Add filters based on criteria
      if (criteria.containsKey('destination')) {
        query = query.where('destination', isEqualTo: criteria['destination']);
      }
      
      if (criteria.containsKey('femaleOnly')) {
        query = query.where('femaleOnly', isEqualTo: criteria['femaleOnly']);
      }
      
      if (criteria.containsKey('date')) {
        final date = criteria['date'] as DateTime;
        final startOfDay = DateTime(date.year, date.month, date.day);
        final endOfDay = startOfDay.add(const Duration(days: 1));
        query = query
            .where('scheduledTime', isGreaterThanOrEqualTo: startOfDay)
            .where('scheduledTime', isLessThan: endOfDay);
      }
      
      // Order by scheduled time
      query = query.orderBy('scheduledTime');
      
      final querySnapshot = await query.limit(50).get();
      
      return querySnapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return RideGroup.fromJson(data);
      }).toList();
    } on FirebaseException catch (e) {
      throw _handleFirebaseException(e, 'search rides');
    } catch (e) {
      if (e is AppError) rethrow;
      throw AppError.unknown('Failed to search rides: ${e.toString()}');
    }
  }

  @override
  Future<List<RideGroup>> getNearbyRides(double lat, double lng, {double radiusKm = 50}) async {
    try {
      await _checkNetworkConnectivity();
      
      // Calculate bounding box for the search area
      final boundingBox = _calculateBoundingBox(lat, lng, radiusKm);
      
      final query = _firestore.collection(_ridesCollection)
          .where('status', isEqualTo: 'created')
          .where('availableSeats', isGreaterThan: 0)
          .where('pickupCoordinates.latitude', isGreaterThanOrEqualTo: boundingBox['minLat'])
          .where('pickupCoordinates.latitude', isLessThanOrEqualTo: boundingBox['maxLat']);
      
      final querySnapshot = await query.get();
      
      final rides = querySnapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return RideGroup.fromJson(data);
      }).toList();
      
      // Filter by actual distance and sort by distance
      final nearbyRides = <RideGroup>[];
      for (final ride in rides) {
        final distance = await calculateDistance(
          LatLng(lat, lng),
          ride.pickupCoordinates,
        );
        
        if (distance <= radiusKm) {
          nearbyRides.add(ride);
        }
      }
      
      // Sort by scheduled time
      nearbyRides.sort((a, b) => a.scheduledTime.compareTo(b.scheduledTime));
      
      return nearbyRides;
    } on FirebaseException catch (e) {
      throw _handleFirebaseException(e, 'get nearby rides');
    } catch (e) {
      if (e is AppError) rethrow;
      throw AppError.unknown('Failed to get nearby rides: ${e.toString()}');
    }
  }

  @override
  Future<List<RideGroup>> getUserRides(String userId) async {
    try {
      await _checkNetworkConnectivity();
      
      if (userId.isEmpty) {
        throw AppError.validation('User ID cannot be empty');
      }
      
      // Get rides where user is leader
      final leaderQuery = _firestore.collection(_ridesCollection)
          .where('leaderId', isEqualTo: userId)
          .orderBy('scheduledTime', descending: true);
      
      // Get rides where user is member
      final memberQuery = _firestore.collection(_ridesCollection)
          .where('memberIds', arrayContains: userId)
          .orderBy('scheduledTime', descending: true);
      
      final results = await Future.wait([
        leaderQuery.get(),
        memberQuery.get(),
      ]);
      
      final rides = <String, RideGroup>{};
      
      // Process leader rides
      for (final doc in results[0].docs) {
        final data = doc.data();
        data['id'] = doc.id;
        rides[doc.id] = RideGroup.fromJson(data);
      }
      
      // Process member rides
      for (final doc in results[1].docs) {
        final data = doc.data();
        data['id'] = doc.id;
        rides[doc.id] = RideGroup.fromJson(data);
      }
      
      final rideList = rides.values.toList();
      rideList.sort((a, b) => b.scheduledTime.compareTo(a.scheduledTime));
      
      return rideList;
    } on FirebaseException catch (e) {
      throw _handleFirebaseException(e, 'get user rides');
    } catch (e) {
      if (e is AppError) rethrow;
      throw AppError.unknown('Failed to get user rides: ${e.toString()}');
    }
  }

  @override
  Stream<List<RideGroup>> getUserRidesStream(String userId) {
    if (userId.isEmpty) {
      return Stream.error(AppError.validation('User ID cannot be empty'));
    }
    
    // Combine leader and member rides streams
    final leaderStream = _firestore.collection(_ridesCollection)
        .where('leaderId', isEqualTo: userId)
        .orderBy('scheduledTime', descending: true)
        .snapshots();
    
    final memberStream = _firestore.collection(_ridesCollection)
        .where('memberIds', arrayContains: userId)
        .orderBy('scheduledTime', descending: true)
        .snapshots();
    
    return leaderStream.asyncMap((leaderSnapshot) async {
      final memberSnapshot = await memberStream.first;
      
      final rides = <String, RideGroup>{};
      
      // Process leader rides
      for (final doc in leaderSnapshot.docs) {
        final data = doc.data();
        data['id'] = doc.id;
        rides[doc.id] = RideGroup.fromJson(data);
      }
      
      // Process member rides
      for (final doc in memberSnapshot.docs) {
        final data = doc.data();
        data['id'] = doc.id;
        rides[doc.id] = RideGroup.fromJson(data);
      }
      
      final rideList = rides.values.toList();
      rideList.sort((a, b) => b.scheduledTime.compareTo(a.scheduledTime));
      
      return rideList;
    }).handleError((error) {
      if (error is FirebaseException) {
        throw _handleFirebaseException(error, 'stream user rides');
      }
      throw AppError.unknown('Failed to stream user rides: ${error.toString()}');
    });
  }

  @override
  Future<void> updateRide(RideGroup ride) async {
    try {
      await _checkNetworkConnectivity();
      
      _validateRideData(ride);
      
      final rideData = ride.toJson();
      rideData['updatedAt'] = FieldValue.serverTimestamp();
      
      await _firestore.collection(_ridesCollection).doc(ride.id).update(rideData);
    } on FirebaseException catch (e) {
      throw _handleFirebaseException(e, 'update ride');
    } catch (e) {
      if (e is AppError) rethrow;
      throw AppError.unknown('Failed to update ride: ${e.toString()}');
    }
  }

  @override
  Future<void> cancelRide(String rideId, String reason) async {
    try {
      await _checkNetworkConnectivity();
      
      if (rideId.isEmpty) {
        throw AppError.validation('Ride ID cannot be empty');
      }
      
      await _firestore.collection(_ridesCollection).doc(rideId).update({
        'status': 'cancelled',
        'cancelledAt': FieldValue.serverTimestamp(),
        'cancellationReason': reason,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (e) {
      throw _handleFirebaseException(e, 'cancel ride');
    } catch (e) {
      if (e is AppError) rethrow;
      throw AppError.unknown('Failed to cancel ride: ${e.toString()}');
    }
  }

  @override
  Future<void> requestToJoin(String rideId, String userId) async {
    try {
      await _checkNetworkConnectivity();
      
      if (rideId.isEmpty || userId.isEmpty) {
        throw AppError.validation('Ride ID and User ID cannot be empty');
      }
      
      // Check if request already exists
      final existingRequest = await _firestore
          .collection(_joinRequestsCollection)
          .where('rideId', isEqualTo: rideId)
          .where('userId', isEqualTo: userId)
          .where('status', isEqualTo: 'pending')
          .get();
      
      if (existingRequest.docs.isNotEmpty) {
        throw AppError.validation('Join request already exists');
      }
      
      // Get ride details for notification
      final rideDoc = await _firestore.collection(_ridesCollection).doc(rideId).get();
      if (!rideDoc.exists) {
        throw AppError.validation('Ride not found');
      }
      
      final rideData = rideDoc.data()!;
      final leaderId = rideData['leaderId'] as String;
      final destination = rideData['destination'] as String;
      
      await _firestore.collection(_joinRequestsCollection).add({
        'rideId': rideId,
        'userId': userId,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });
      
      // Note: In a real implementation, you would send a notification to the leader here
      // This would typically be done through a Cloud Function or your backend API
      debugPrint('Join request created for ride $rideId by user $userId. Leader $leaderId should be notified.');
      
    } on FirebaseException catch (e) {
      throw _handleFirebaseException(e, 'request to join ride');
    } catch (e) {
      if (e is AppError) rethrow;
      throw AppError.unknown('Failed to request to join ride: ${e.toString()}');
    }
  }

  @override
  Future<void> approveJoinRequest(String rideId, String requesterId) async {
    try {
      await _checkNetworkConnectivity();
      
      await _firestore.runTransaction((transaction) async {
        // Get the ride
        final rideRef = _firestore.collection(_ridesCollection).doc(rideId);
        final rideDoc = await transaction.get(rideRef);
        
        if (!rideDoc.exists) {
          throw AppError.validation('Ride not found');
        }
        
        final rideData = rideDoc.data()!;
        final availableSeats = rideData['availableSeats'] as int;
        
        if (availableSeats <= 0) {
          throw AppError.validation('No available seats');
        }
        
        // Update join request status
        final joinRequestQuery = await _firestore
            .collection(_joinRequestsCollection)
            .where('rideId', isEqualTo: rideId)
            .where('userId', isEqualTo: requesterId)
            .where('status', isEqualTo: 'pending')
            .get();
        
        if (joinRequestQuery.docs.isEmpty) {
          throw AppError.validation('Join request not found');
        }
        
        transaction.update(joinRequestQuery.docs.first.reference, {
          'status': 'approved',
          'approvedAt': FieldValue.serverTimestamp(),
        });
        
        // Add user to ride group and update price
        final memberIds = List<String>.from(rideData['memberIds'] ?? []);
        memberIds.add(requesterId);
        
        final totalSeats = rideData['totalSeats'] as int;
        final totalFare = (rideData['totalFare'] as num).toDouble();
        final newAvailableSeats = availableSeats - 1;
        final newCurrentMembers = totalSeats - newAvailableSeats;
        final newPricePerPerson = totalFare / newCurrentMembers;
        
        transaction.update(rideRef, {
          'memberIds': memberIds,
          'availableSeats': newAvailableSeats,
          'pricePerPerson': newPricePerPerson,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });
    } on FirebaseException catch (e) {
      throw _handleFirebaseException(e, 'approve join request');
    } catch (e) {
      if (e is AppError) rethrow;
      throw AppError.unknown('Failed to approve join request: ${e.toString()}');
    }
  }

  @override
  Future<void> rejectJoinRequest(String rideId, String requesterId, String reason) async {
    try {
      await _checkNetworkConnectivity();
      
      final joinRequestQuery = await _firestore
          .collection(_joinRequestsCollection)
          .where('rideId', isEqualTo: rideId)
          .where('userId', isEqualTo: requesterId)
          .where('status', isEqualTo: 'pending')
          .get();
      
      if (joinRequestQuery.docs.isEmpty) {
        throw AppError.validation('Join request not found');
      }
      
      await joinRequestQuery.docs.first.reference.update({
        'status': 'rejected',
        'rejectedAt': FieldValue.serverTimestamp(),
        'rejectionReason': reason,
      });
    } on FirebaseException catch (e) {
      throw _handleFirebaseException(e, 'reject join request');
    } catch (e) {
      if (e is AppError) rethrow;
      throw AppError.unknown('Failed to reject join request: ${e.toString()}');
    }
  }

  @override
  Future<void> removeMember(String rideId, String memberId) async {
    try {
      await _checkNetworkConnectivity();
      
      await _firestore.runTransaction((transaction) async {
        final rideRef = _firestore.collection(_ridesCollection).doc(rideId);
        final rideDoc = await transaction.get(rideRef);
        
        if (!rideDoc.exists) {
          throw AppError.validation('Ride not found');
        }
        
        final rideData = rideDoc.data()!;
        final memberIds = List<String>.from(rideData['memberIds'] ?? []);
        
        if (!memberIds.contains(memberId)) {
          throw AppError.validation('User is not a member of this ride');
        }
        
        memberIds.remove(memberId);
        
        final totalSeats = rideData['totalSeats'] as int;
        final totalFare = (rideData['totalFare'] as num).toDouble();
        final newAvailableSeats = (rideData['availableSeats'] as int) + 1;
        final newCurrentMembers = totalSeats - newAvailableSeats;
        final newPricePerPerson = newCurrentMembers > 0 ? totalFare / newCurrentMembers : totalFare;
        
        transaction.update(rideRef, {
          'memberIds': memberIds,
          'availableSeats': newAvailableSeats,
          'pricePerPerson': newPricePerPerson,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });
    } on FirebaseException catch (e) {
      throw _handleFirebaseException(e, 'remove member');
    } catch (e) {
      if (e is AppError) rethrow;
      throw AppError.unknown('Failed to remove member: ${e.toString()}');
    }
  }

  @override
  Future<void> startRide(String rideId) async {
    try {
      await _checkNetworkConnectivity();
      
      await _firestore.collection(_ridesCollection).doc(rideId).update({
        'status': 'active',
        'startedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (e) {
      throw _handleFirebaseException(e, 'start ride');
    } catch (e) {
      if (e is AppError) rethrow;
      throw AppError.unknown('Failed to start ride: ${e.toString()}');
    }
  }

  @override
  Future<void> completeRide(String rideId) async {
    try {
      await _checkNetworkConnectivity();
      
      await _firestore.collection(_ridesCollection).doc(rideId).update({
        'status': 'completed',
        'completedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (e) {
      throw _handleFirebaseException(e, 'complete ride');
    } catch (e) {
      if (e is AppError) rethrow;
      throw AppError.unknown('Failed to complete ride: ${e.toString()}');
    }
  }

  @override
  Future<double> calculateDistance(LatLng from, LatLng to) async {
    // Using Haversine formula to calculate distance
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
    
    // Base fare calculation (this would typically use real pricing data)
    const double baseFare = 5.0;
    const double perKmRate = 1.5;
    const double perPassengerMultiplier = 0.8;
    
    final double distanceFare = distance * perKmRate;
    final double totalFare = (baseFare + distanceFare) * passengers * perPassengerMultiplier;
    
    return double.parse(totalFare.toStringAsFixed(2));
  }

  void _validateRideData(RideGroup ride) {
    if (ride.leaderId.isEmpty) {
      throw AppError.validation('Leader ID cannot be empty');
    }
    
    if (ride.pickupLocation.isEmpty) {
      throw AppError.validation('Pickup location cannot be empty');
    }
    
    if (ride.destination.isEmpty) {
      throw AppError.validation('Destination cannot be empty');
    }
    
    if (ride.scheduledTime.isBefore(DateTime.now())) {
      throw AppError.validation('Scheduled time cannot be in the past');
    }
    
    if (ride.totalSeats <= 0 || ride.totalSeats > 8) {
      throw AppError.validation('Total seats must be between 1 and 8');
    }
    
    if (ride.totalFare <= 0) {
      throw AppError.validation('Total fare must be positive');
    }
  }

  Map<String, double> _calculateBoundingBox(double lat, double lng, double radiusKm) {
    const double earthRadius = 6371; // Earth's radius in kilometers
    
    final double latRad = lat * (pi / 180);
    final double deltaLat = radiusKm / earthRadius;
    final double deltaLng = radiusKm / (earthRadius * cos(latRad));
    
    return {
      'minLat': lat - (deltaLat * 180 / pi),
      'maxLat': lat + (deltaLat * 180 / pi),
      'minLng': lng - (deltaLng * 180 / pi),
      'maxLng': lng + (deltaLng * 180 / pi),
    };
  }

  Future<void> _checkNetworkConnectivity() async {
    try {
      final result = await InternetAddress.lookup('google.com');
      if (result.isEmpty || result[0].rawAddress.isEmpty) {
        throw const SocketException('No internet connection');
      }
    } on SocketException {
      throw AppError.network('No internet connection. Please check your network and try again.');
    }
  }

  AppError _handleFirebaseException(FirebaseException e, String operation) {
    switch (e.code) {
      case 'permission-denied':
        return AppError.auth('Permission denied to $operation', e.code);
      case 'not-found':
        return AppError.validation('Resource not found while trying to $operation');
      case 'already-exists':
        return AppError.validation('Resource already exists');
      case 'resource-exhausted':
        return AppError.network('Service temporarily unavailable. Please try again later.');
      case 'unauthenticated':
        return AppError.auth('Authentication required to $operation', e.code);
      case 'unavailable':
        return AppError.network('Service temporarily unavailable. Please try again later.');
      case 'deadline-exceeded':
        return AppError.network('Request timed out. Please try again.');
      default:
        return AppError.unknown('Failed to $operation: ${e.message ?? e.code}');
    }
  }
}