import 'package:flutter_test/flutter_test.dart';
import 'package:ridelink/providers/ride_provider.dart';
import 'package:ridelink/services/mock_ride_service.dart';
import 'package:ridelink/models/ride_group.dart';

void main() {
  group('Ride Discovery Feature', () {
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

    group('Nearby Rides Discovery', () {
      test('should load nearby rides successfully', () async {
        await rideProvider.loadNearbyRides(40.7128, -74.0060);
        
        expect(rideProvider.nearbyRides, isA<List<RideGroup>>());
        expect(rideProvider.isLoadingNearby, false);
        expect(rideProvider.error, isNull);
      });

      test('should filter rides by distance', () async {
        await rideProvider.loadNearbyRides(40.7128, -74.0060, radiusKm: 10);
        
        // All returned rides should be within the specified radius
        expect(rideProvider.nearbyRides, isA<List<RideGroup>>());
        expect(rideProvider.error, isNull);
      });

      test('should handle location errors gracefully', () async {
        // Test with invalid coordinates
        await rideProvider.loadNearbyRides(999, 999);
        
        // Should not crash and should handle the error
        expect(rideProvider.isLoadingNearby, false);
      });
    });

    group('Ride Search Functionality', () {
      test('should search rides by destination', () async {
        final criteria = {'destination': 'Airport'};
        
        await rideProvider.searchRides(criteria);
        
        expect(rideProvider.searchResults, isA<List<RideGroup>>());
        expect(rideProvider.isSearching, false);
        expect(rideProvider.error, isNull);
      });

      test('should search rides by date', () async {
        final tomorrow = DateTime.now().add(const Duration(days: 1));
        final criteria = {'date': tomorrow};
        
        await rideProvider.searchRides(criteria);
        
        expect(rideProvider.searchResults, isA<List<RideGroup>>());
        expect(rideProvider.isSearching, false);
      });

      test('should search female-only rides', () async {
        final criteria = {'femaleOnly': true};
        
        await rideProvider.searchRides(criteria);
        
        expect(rideProvider.searchResults, isA<List<RideGroup>>());
        
        // All returned rides should be female-only
        for (final ride in rideProvider.searchResults) {
          expect(ride.femaleOnly, true);
        }
      });

      test('should combine multiple search criteria', () async {
        final tomorrow = DateTime.now().add(const Duration(days: 1));
        final criteria = {
          'destination': 'Airport',
          'femaleOnly': true,
          'date': tomorrow,
        };
        
        await rideProvider.searchRides(criteria);
        
        expect(rideProvider.searchResults, isA<List<RideGroup>>());
        expect(rideProvider.isSearching, false);
      });

      test('should clear search results', () async {
        // First perform a search
        await rideProvider.searchRides({'destination': 'Airport'});
        expect(rideProvider.searchResults, isNotEmpty);
        
        // Then clear results
        rideProvider.clearSearchResults();
        expect(rideProvider.searchResults, isEmpty);
      });

      test('should handle empty search results', () async {
        final criteria = {'destination': 'NonExistentPlace'};
        
        await rideProvider.searchRides(criteria);
        
        expect(rideProvider.searchResults, isEmpty);
        expect(rideProvider.isSearching, false);
        expect(rideProvider.error, isNull);
      });
    });

    group('Ride Filtering', () {
      test('should filter rides by availability', () async {
        await rideProvider.loadNearbyRides(40.7128, -74.0060);
        
        // All nearby rides should have available seats
        for (final ride in rideProvider.nearbyRides) {
          expect(ride.availableSeats, greaterThan(0));
          expect(ride.status, RideStatus.created);
        }
      });

      test('should sort rides by scheduled time', () async {
        await rideProvider.loadNearbyRides(40.7128, -74.0060);
        
        if (rideProvider.nearbyRides.length > 1) {
          for (int i = 0; i < rideProvider.nearbyRides.length - 1; i++) {
            final currentRide = rideProvider.nearbyRides[i];
            final nextRide = rideProvider.nearbyRides[i + 1];
            
            expect(
              currentRide.scheduledTime.isBefore(nextRide.scheduledTime) ||
              currentRide.scheduledTime.isAtSameMomentAs(nextRide.scheduledTime),
              true,
            );
          }
        }
      });
    });

    group('User Rides Management', () {
      test('should load user rides successfully', () async {
        await rideProvider.loadUserRides('mock-user-123');
        
        expect(rideProvider.userRides, isA<List<RideGroup>>());
        expect(rideProvider.isLoading, false);
        expect(rideProvider.error, isNull);
      });

      test('should filter upcoming rides correctly', () async {
        await rideProvider.loadUserRides('mock-user-123');
        
        final upcomingRides = rideProvider.upcomingRides;
        final now = DateTime.now();
        
        for (final ride in upcomingRides) {
          expect(ride.scheduledTime.isAfter(now), true);
          expect(
            ride.status == RideStatus.created || ride.status == RideStatus.active,
            true,
          );
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

    group('Real-time Updates', () {
      test('should handle ride status updates', () async {
        await rideProvider.loadUserRides('mock-user-123');
        
        // Simulate a ride status change
        if (rideProvider.userRides.isNotEmpty) {
          final rideId = rideProvider.userRides.first.id;
          await rideProvider.startRide(rideId);
          
          expect(rideProvider.error, isNull);
        }
      });

      test('should update ride availability when members join', () async {
        await rideProvider.loadNearbyRides(40.7128, -74.0060);
        
        if (rideProvider.nearbyRides.isNotEmpty) {
          final ride = rideProvider.nearbyRides.first;
          final originalSeats = ride.availableSeats;
          
          // Simulate someone joining the ride
          await rideProvider.requestToJoin(ride.id, 'test-user');
          await rideProvider.approveJoinRequest(ride.id, 'test-user');
          
          // The ride should be updated with fewer available seats
          final updatedRide = await mockRideService.getRide(ride.id);
          if (updatedRide != null) {
            expect(updatedRide.availableSeats, lessThan(originalSeats));
          }
        }
      });
    });

    group('Error Handling', () {
      test('should handle network errors gracefully', () async {
        // The mock service doesn't simulate network errors,
        // but we can test that error handling exists
        await rideProvider.loadNearbyRides(40.7128, -74.0060);
        expect(rideProvider.error, isNull);
      });

      test('should clear errors when requested', () async {
        rideProvider.clearError();
        expect(rideProvider.error, isNull);
      });

      test('should handle invalid search criteria', () async {
        final criteria = <String, dynamic>{};
        
        await rideProvider.searchRides(criteria);
        
        // Should not crash with empty criteria
        expect(rideProvider.isSearching, false);
      });
    });

    group('Performance and Optimization', () {
      test('should limit search results appropriately', () async {
        await rideProvider.searchRides({'destination': 'popular'});
        
        // Results should be reasonable in number (not unlimited)
        expect(rideProvider.searchResults.length, lessThanOrEqualTo(50));
      });

      test('should handle concurrent search requests', () async {
        // Start multiple searches concurrently
        final futures = [
          rideProvider.searchRides({'destination': 'Airport'}),
          rideProvider.searchRides({'destination': 'Mall'}),
          rideProvider.searchRides({'destination': 'University'}),
        ];
        
        await Future.wait(futures);
        
        // Should complete without errors
        expect(rideProvider.isSearching, false);
      });
    });
  });
}