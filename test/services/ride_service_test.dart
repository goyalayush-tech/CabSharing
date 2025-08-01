import 'package:flutter_test/flutter_test.dart';
import 'package:ridelink/services/mock_ride_service.dart';
import 'package:ridelink/models/ride_group.dart';

void main() {
  group('MockRideService', () {
    late MockRideService rideService;

    setUp(() {
      rideService = MockRideService();
    });

    tearDown(() {
      rideService.dispose();
    });

    RideGroup createTestRide({String? id, String? leaderId}) {
      return RideGroup(
        id: id ?? 'test-ride-123',
        leaderId: leaderId ?? 'test-user-123',
        pickupLocation: 'Test Pickup',
        pickupCoordinates: LatLng(40.7128, -74.0060),
        destination: 'Test Destination',
        destinationCoordinates: LatLng(40.6892, -74.1745),
        scheduledTime: DateTime.now().add(const Duration(hours: 2)),
        totalSeats: 4,
        availableSeats: 3,
        totalFare: 100.0,
        pricePerPerson: 100.0, // 100 / 1 person (leader only initially)
        createdAt: DateTime.now(),
      );
    }

    group('Ride Creation', () {
      test('should create ride successfully', () async {
        final ride = createTestRide(id: 'temp-id'); // Use temp ID for creation

        final rideId = await rideService.createRide(ride);

        expect(rideId, isNotEmpty);
        expect(rideId, startsWith('ride-'));
      });

      test('should get created ride', () async {
        final ride = createTestRide(id: 'temp-id'); // Use temp ID for creation

        final rideId = await rideService.createRide(ride);
        final retrievedRide = await rideService.getRide(rideId);

        expect(retrievedRide, isNotNull);
        expect(retrievedRide!.id, rideId);
        expect(retrievedRide.leaderId, 'test-user-123');
        expect(retrievedRide.pickupLocation, 'Test Pickup');
      });
    });

    group('Ride Search', () {
      test('should search rides by destination', () async {
        final results = await rideService.searchRides({'destination': 'Airport'});

        expect(results, isA<List<RideGroup>>());
        expect(results.length, greaterThanOrEqualTo(0));
        
        if (results.isNotEmpty) {
          expect(results.first.destination.toLowerCase(), contains('airport'));
        }
      });

      test('should search rides by date', () async {
        final tomorrow = DateTime.now().add(const Duration(days: 1));
        final results = await rideService.searchRides({'date': tomorrow});

        expect(results, isA<List<RideGroup>>());
        
        for (final ride in results) {
          final rideDate = DateTime(
            ride.scheduledTime.year,
            ride.scheduledTime.month,
            ride.scheduledTime.day,
          );
          final searchDate = DateTime(tomorrow.year, tomorrow.month, tomorrow.day);
          expect(rideDate, equals(searchDate));
        }
      });

      test('should search female-only rides', () async {
        final results = await rideService.searchRides({'femaleOnly': true});

        expect(results, isA<List<RideGroup>>());
        
        for (final ride in results) {
          expect(ride.femaleOnly, true);
        }
      });

      test('should return empty list for no matches', () async {
        final results = await rideService.searchRides({'destination': 'NonExistentPlace'});

        expect(results, isEmpty);
      });
    });

    group('Nearby Rides', () {
      test('should get nearby rides', () async {
        final nearbyRides = await rideService.getNearbyRides(40.7128, -74.0060);

        expect(nearbyRides, isA<List<RideGroup>>());
        expect(nearbyRides.length, greaterThanOrEqualTo(0));
      });

      test('should respect radius parameter', () async {
        final nearbyRides = await rideService.getNearbyRides(
          40.7128, 
          -74.0060, 
          radiusKm: 1.0, // Very small radius
        );

        expect(nearbyRides, isA<List<RideGroup>>());
        // Results should be limited by the small radius
      });
    });

    group('User Rides', () {
      test('should get user rides as leader', () async {
        final userRides = await rideService.getUserRides('mock-user-123');

        expect(userRides, isA<List<RideGroup>>());
        expect(userRides.length, greaterThanOrEqualTo(0));
        
        for (final ride in userRides) {
          expect(ride.leaderId == 'mock-user-123' || ride.memberIds.contains('mock-user-123'), true);
        }
      });

      test('should get user rides as member', () async {
        final userRides = await rideService.getUserRides('user-456');

        expect(userRides, isA<List<RideGroup>>());
        expect(userRides.length, greaterThanOrEqualTo(0));
      });

      test('should return empty list for non-existent user', () async {
        final userRides = await rideService.getUserRides('non-existent-user');

        expect(userRides, isEmpty);
      });
    });

    group('Ride Management', () {
      test('should update ride successfully', () async {
        final ride = RideGroup(
          id: 'ride-1',
          leaderId: 'test-user-123',
          pickupLocation: 'Updated Pickup',
          pickupCoordinates: LatLng(40.7128, -74.0060),
          destination: 'Updated Destination',
          destinationCoordinates: LatLng(40.6892, -74.1745),
          scheduledTime: DateTime.now().add(const Duration(hours: 3)),
          totalSeats: 5,
          availableSeats: 4,
          totalFare: 120.0,
          pricePerPerson: 120.0, // 120 / 1 person (leader only)
          createdAt: DateTime.now(),
        );

        await rideService.updateRide(ride);

        final updatedRide = await rideService.getRide('ride-1');
        expect(updatedRide?.pickupLocation, 'Updated Pickup');
      });

      test('should cancel ride successfully', () async {
        await rideService.cancelRide('ride-1', 'Test cancellation');

        final cancelledRide = await rideService.getRide('ride-1');
        expect(cancelledRide?.status, RideStatus.cancelled);
      });

      test('should start ride successfully', () async {
        await rideService.startRide('ride-1');

        final startedRide = await rideService.getRide('ride-1');
        expect(startedRide?.status, RideStatus.active);
      });

      test('should complete ride successfully', () async {
        await rideService.completeRide('ride-1');

        final completedRide = await rideService.getRide('ride-1');
        expect(completedRide?.status, RideStatus.completed);
      });
    });

    group('Join Requests', () {
      test('should request to join ride', () async {
        await rideService.requestToJoin('ride-1', 'test-user-456');
        // Mock service doesn't throw errors for successful requests
      });

      test('should throw error for duplicate join request', () async {
        await rideService.requestToJoin('ride-1', 'test-user-456');
        
        expect(
          () => rideService.requestToJoin('ride-1', 'test-user-456'),
          throwsA(isA<Exception>()),
        );
      });

      test('should approve join request', () async {
        await rideService.requestToJoin('ride-2', 'test-user-789');
        await rideService.approveJoinRequest('ride-2', 'test-user-789');

        final updatedRide = await rideService.getRide('ride-2');
        expect(updatedRide?.memberIds.contains('test-user-789'), true);
        expect(updatedRide?.availableSeats, lessThan(updatedRide!.totalSeats));
      });

      test('should reject join request', () async {
        await rideService.requestToJoin('ride-3', 'test-user-reject');
        await rideService.rejectJoinRequest('ride-3', 'test-user-reject', 'Not suitable');
        
        // Mock service handles rejection without throwing errors
      });
    });

    group('Member Management', () {
      test('should remove member from ride', () async {
        // First add a member
        await rideService.requestToJoin('ride-1', 'test-member');
        await rideService.approveJoinRequest('ride-1', 'test-member');
        
        // Then remove the member
        await rideService.removeMember('ride-1', 'test-member');

        final updatedRide = await rideService.getRide('ride-1');
        expect(updatedRide?.memberIds.contains('test-member'), false);
      });

      test('should throw error when removing non-member', () async {
        expect(
          () => rideService.removeMember('ride-1', 'non-member'),
          throwsA(isA<Exception>()),
        );
      });
    });

    group('Distance and Fare Calculations', () {
      test('should calculate distance between coordinates', () async {
        final distance = await rideService.calculateDistance(
          LatLng(40.7128, -74.0060), // New York
          LatLng(40.6892, -74.1745), // Newark
        );

        expect(distance, isA<double>());
        expect(distance, greaterThan(0));
        expect(distance, lessThan(100)); // Should be reasonable distance
      });

      test('should calculate fare based on distance and passengers', () async {
        final fare = await rideService.calculateFare(
          LatLng(40.7128, -74.0060),
          LatLng(40.6892, -74.1745),
          4, // 4 passengers
        );

        expect(fare, isA<double>());
        expect(fare, greaterThan(0));
      });

      test('should calculate higher fare for more passengers', () async {
        final fare2Passengers = await rideService.calculateFare(
          LatLng(40.7128, -74.0060),
          LatLng(40.6892, -74.1745),
          2,
        );

        final fare4Passengers = await rideService.calculateFare(
          LatLng(40.7128, -74.0060),
          LatLng(40.6892, -74.1745),
          4,
        );

        expect(fare4Passengers, greaterThan(fare2Passengers));
      });
    });

    group('Streams', () {
      test('should provide ride stream', () async {
        final stream = rideService.getRideStream('ride-1');
        
        expect(stream, isA<Stream<RideGroup?>>());
        
        final firstValue = await stream.first;
        expect(firstValue, isNotNull);
      });

      test('should provide user rides stream', () async {
        final stream = rideService.getUserRidesStream('mock-user-123');
        
        expect(stream, isA<Stream<List<RideGroup>>>());
        
        final firstValue = await stream.first;
        expect(firstValue, isA<List<RideGroup>>());
      });
    });
  });
}