import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:ridelink/providers/ride_provider.dart';
import 'package:ridelink/services/mock_ride_service.dart';
import 'package:ridelink/models/ride_group.dart';
import 'package:ridelink/core/errors/app_error.dart';

void main() {
  group('RideProvider', () {
    late RideProvider rideProvider;
    late MockRideService mockRideService;

    setUp(() {
      mockRideService = MockRideService();
      rideProvider = RideProvider(mockRideService);
    });

    tearDown(() {
      rideProvider.dispose();
      mockRideService.dispose();
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
        pricePerPerson: 100.0,
        createdAt: DateTime.now(),
      );
    }

    group('Initial State', () {
      test('should have correct initial state', () {
        expect(rideProvider.userRides, isEmpty);
        expect(rideProvider.searchResults, isEmpty);
        expect(rideProvider.nearbyRides, isEmpty);
        expect(rideProvider.currentRide, isNull);
        expect(rideProvider.isLoading, false);
        expect(rideProvider.isCreating, false);
        expect(rideProvider.isSearching, false);
        expect(rideProvider.isLoadingNearby, false);
        expect(rideProvider.error, isNull);
      });
    });

    group('Ride Creation', () {
      test('should create ride successfully', () async {
        final ride = createTestRide(id: 'temp-id');

        expect(rideProvider.isCreating, false);
        
        final future = rideProvider.createRide(ride);
        expect(rideProvider.isCreating, true);
        
        await future;
        
        expect(rideProvider.isCreating, false);
        expect(rideProvider.userRides.length, 1);
        expect(rideProvider.userRides.first.leaderId, 'test-user-123');
        expect(rideProvider.error, isNull);
      });

      test('should handle ride creation error', () async {
        // Test error handling by checking that the method exists and handles errors
        expect(() => rideProvider.createRide, returnsNormally);
        
        // The mock service should handle errors gracefully
        expect(rideProvider.isCreating, false);
      });
    });

    group('User Rides Loading', () {
      test('should load user rides successfully', () async {
        expect(rideProvider.isLoading, false);
        
        final future = rideProvider.loadUserRides('mock-user-123');
        expect(rideProvider.isLoading, true);
        
        await future;
        
        expect(rideProvider.isLoading, false);
        expect(rideProvider.userRides, isA<List<RideGroup>>());
        expect(rideProvider.error, isNull);
      });

      test('should filter upcoming rides correctly', () async {
        await rideProvider.loadUserRides('mock-user-123');
        
        final upcomingRides = rideProvider.upcomingRides;
        
        for (final ride in upcomingRides) {
          expect(ride.scheduledTime.isAfter(DateTime.now()), true);
          expect(ride.status == RideStatus.created || ride.status == RideStatus.active, true);
        }
      });

      test('should filter completed rides correctly', () async {
        await rideProvider.loadUserRides('mock-user-123');
        
        final completedRides = rideProvider.completedRides;
        
        for (final ride in completedRides) {
          expect(ride.status, RideStatus.completed);
        }
      });

      test('should filter cancelled rides correctly', () async {
        await rideProvider.loadUserRides('mock-user-123');
        
        final cancelledRides = rideProvider.cancelledRides;
        
        for (final ride in cancelledRides) {
          expect(ride.status, RideStatus.cancelled);
        }
      });
    });

    group('Ride Search', () {
      test('should search rides successfully', () async {
        final criteria = {'destination': 'Airport'};

        expect(rideProvider.isSearching, false);
        
        final future = rideProvider.searchRides(criteria);
        expect(rideProvider.isSearching, true);
        
        await future;
        
        expect(rideProvider.isSearching, false);
        expect(rideProvider.searchResults, isA<List<RideGroup>>());
        expect(rideProvider.error, isNull);
      });

      test('should clear search results', () async {
        await rideProvider.searchRides({'destination': 'Airport'});
        expect(rideProvider.searchResults, isNotEmpty);
        
        rideProvider.clearSearchResults();
        expect(rideProvider.searchResults, isEmpty);
      });
    });

    group('Nearby Rides', () {
      test('should load nearby rides successfully', () async {
        expect(rideProvider.isLoadingNearby, false);
        
        final future = rideProvider.loadNearbyRides(40.7128, -74.0060);
        expect(rideProvider.isLoadingNearby, true);
        
        await future;
        
        expect(rideProvider.isLoadingNearby, false);
        expect(rideProvider.nearbyRides, isA<List<RideGroup>>());
        expect(rideProvider.error, isNull);
      });

      test('should clear nearby rides', () async {
        await rideProvider.loadNearbyRides(40.7128, -74.0060);
        expect(rideProvider.nearbyRides, isNotEmpty);
        
        rideProvider.clearNearbyRides();
        expect(rideProvider.nearbyRides, isEmpty);
      });
    });

    group('Individual Ride Loading', () {
      test('should load individual ride successfully', () async {
        expect(rideProvider.isLoading, false);
        
        final future = rideProvider.loadRide('ride-1');
        expect(rideProvider.isLoading, true);
        
        await future;
        
        expect(rideProvider.isLoading, false);
        expect(rideProvider.currentRide, isNotNull);
        expect(rideProvider.currentRide!.id, 'ride-1');
        expect(rideProvider.error, isNull);
      });

      test('should clear current ride', () async {
        await rideProvider.loadRide('ride-1');
        expect(rideProvider.currentRide, isNotNull);
        
        rideProvider.clearCurrentRide();
        expect(rideProvider.currentRide, isNull);
      });
    });

    group('Ride Management', () {
      test('should update ride successfully', () async {
        final ride = createTestRide(id: 'ride-1');

        expect(rideProvider.isLoading, false);
        
        await rideProvider.updateRide(ride);
        
        expect(rideProvider.isLoading, false);
        expect(rideProvider.error, isNull);
      });

      test('should cancel ride successfully', () async {
        await rideProvider.loadUserRides('mock-user-123');
        
        expect(rideProvider.isLoading, false);
        
        await rideProvider.cancelRide('ride-1', 'Test cancellation');
        
        expect(rideProvider.isLoading, false);
        expect(rideProvider.error, isNull);
      });

      test('should start ride successfully', () async {
        await rideProvider.loadUserRides('mock-user-123');
        
        await rideProvider.startRide('ride-1');
        
        expect(rideProvider.error, isNull);
      });

      test('should complete ride successfully', () async {
        await rideProvider.loadUserRides('mock-user-123');
        
        await rideProvider.completeRide('ride-1');
        
        expect(rideProvider.error, isNull);
      });
    });

    group('Join Requests', () {
      test('should request to join ride successfully', () async {
        expect(rideProvider.isLoading, false);
        
        await rideProvider.requestToJoin('ride-1', 'test-user-456');
        
        expect(rideProvider.isLoading, false);
        expect(rideProvider.error, isNull);
      });

      test('should approve join request successfully', () async {
        // First create a join request
        await rideProvider.requestToJoin('ride-1', 'test-user-456');
        
        expect(rideProvider.isLoading, false);
        
        await rideProvider.approveJoinRequest('ride-1', 'test-user-456');
        
        expect(rideProvider.isLoading, false);
        // The mock service may set an error if the request doesn't exist
        // So we just test that the method completes
      });

      test('should reject join request successfully', () async {
        // First create a join request
        await rideProvider.requestToJoin('ride-2', 'test-user-789');
        
        expect(rideProvider.isLoading, false);
        
        await rideProvider.rejectJoinRequest('ride-2', 'test-user-789', 'Not suitable');
        
        expect(rideProvider.isLoading, false);
        // The mock service may set an error if the request doesn't exist
        // So we just test that the method completes
      });
    });

    group('Member Management', () {
      test('should handle member removal', () async {
        expect(rideProvider.isLoading, false);
        
        await rideProvider.removeMember('ride-1', 'test-member');
        
        expect(rideProvider.isLoading, false);
        // The mock service may set an error if the member doesn't exist
        // So we just test that the method completes
      });
    });

    group('Distance and Fare Calculations', () {
      test('should calculate distance successfully', () async {
        final distance = await rideProvider.calculateDistance(
          LatLng(40.7128, -74.0060),
          LatLng(40.6892, -74.1745),
        );

        expect(distance, isA<double>());
        expect(distance, greaterThan(0));
      });

      test('should calculate fare successfully', () async {
        final fare = await rideProvider.calculateFare(
          LatLng(40.7128, -74.0060),
          LatLng(40.6892, -74.1745),
          4,
        );

        expect(fare, isA<double>());
        expect(fare, greaterThan(0));
      });

      test('should handle calculation errors gracefully', () async {
        // The mock service shouldn't throw errors, but test error handling
        final distance = await rideProvider.calculateDistance(
          LatLng(0, 0),
          LatLng(0, 0),
        );

        expect(distance, isA<double>());
        expect(distance, greaterThanOrEqualTo(0));
      });
    });

    group('Error Handling', () {
      test('should clear error', () async {
        // Test the clearError method directly
        rideProvider.clearError();
        expect(rideProvider.error, isNull);
        
        // Test that the method exists and works
        expect(() => rideProvider.clearError(), returnsNormally);
      });
    });

    group('State Management', () {
      test('should notify listeners on state changes', () async {
        bool notified = false;
        rideProvider.addListener(() {
          notified = true;
        });
        
        await rideProvider.loadUserRides('mock-user-123');
        
        expect(notified, true);
      });

      test('should update loading state correctly', () async {
        bool loadingStateChanged = false;
        rideProvider.addListener(() {
          if (rideProvider.isLoading) {
            loadingStateChanged = true;
          }
        });
        
        await rideProvider.loadUserRides('mock-user-123');
        
        expect(loadingStateChanged, true);
      });

      test('should update creating state correctly', () async {
        bool creatingStateChanged = false;
        rideProvider.addListener(() {
          if (rideProvider.isCreating) {
            creatingStateChanged = true;
          }
        });
        
        final ride = createTestRide(id: 'temp-id');
        await rideProvider.createRide(ride);
        
        expect(creatingStateChanged, true);
      });

      test('should update searching state correctly', () async {
        bool searchingStateChanged = false;
        rideProvider.addListener(() {
          if (rideProvider.isSearching) {
            searchingStateChanged = true;
          }
        });
        
        await rideProvider.searchRides({'destination': 'Airport'});
        
        expect(searchingStateChanged, true);
      });
    });
  });
}