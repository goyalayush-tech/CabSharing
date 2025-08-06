import 'package:flutter_test/flutter_test.dart';
import 'package:ridelink/core/config/free_map_config.dart';
import 'package:ridelink/models/place_models.dart';
import 'package:ridelink/models/ride_group.dart';
import 'package:ridelink/services/free_geocoding_service.dart';
import 'package:ridelink/services/free_routing_service.dart';
import 'package:ridelink/services/hybrid_route_service.dart';
import 'package:ridelink/services/map_cache_service.dart';

// Helper function to calculate distance between two points (simplified)
double _calculateDistance(LatLng point1, LatLng point2) {
  // Simplified distance calculation for testing
  final latDiff = (point2.latitude - point1.latitude).abs();
  final lngDiff = (point2.longitude - point1.longitude).abs();
  
  // Rough approximation: 1 degree ≈ 111 km
  return (latDiff + lngDiff) * 111;
}

void main() {
  group('Free Map Integration Tests', () {
    late MockMapCacheService cacheService;
    late MockFreeGeocodingService geocodingService;
    late MockFreeRoutingService routingService;
    late HybridRouteService hybridService;
    late FreeMapConfig config;

    setUp(() async {
      config = const FreeMapConfig();
      cacheService = MockMapCacheService();
      await cacheService.initialize();
      
      geocodingService = MockFreeGeocodingService();
      routingService = MockFreeRoutingService();
      
      hybridService = HybridRouteService(
        freeRoutingService: routingService,
        config: config,
      );
    });

    tearDown(() async {
      await cacheService.dispose();
    });

    test('should complete full location search and routing workflow', () async {
      // Step 1: Search for pickup location
      final pickupResults = await geocodingService.searchPlaces('San Francisco Airport');
      expect(pickupResults, isNotEmpty);
      
      final pickupLocation = pickupResults.first;
      expect(pickupLocation.name, contains('San Francisco Airport'));
      expect(pickupLocation.coordinates, isA<LatLng>());

      // Step 2: Search for destination
      final destResults = await geocodingService.searchPlaces('Downtown San Francisco');
      expect(destResults, isNotEmpty);
      
      final destination = destResults.first;
      expect(destination.name, contains('Downtown San Francisco'));

      // Step 3: Calculate route between locations
      // Use more realistic coordinates for testing
      final testOrigin = LatLng(37.7749, -122.4194); // San Francisco
      final testDestination = LatLng(37.6213, -122.3790); // SFO Airport
      
      final route = await hybridService.calculateRoute(
        testOrigin,
        testDestination,
      );

      expect(route.polylinePoints, isNotEmpty);
      expect(route.distanceKm, greaterThan(0));
      expect(route.estimatedDuration.inMinutes, greaterThan(0));
      expect(route.estimatedFare, greaterThan(0));
      expect(route.textInstructions, isNotEmpty);

      // Step 4: Verify route has realistic values
      expect(route.distanceKm, lessThan(100)); // Reasonable distance
      expect(route.estimatedDuration.inHours, lessThan(2)); // Reasonable time
      expect(route.estimatedFare, lessThan(500)); // Reasonable fare
    });

    test('should handle reverse geocoding workflow', () async {
      // Step 1: Get coordinates from user's current location
      final coordinates = LatLng(37.7749, -122.4194); // San Francisco
      
      // Step 2: Reverse geocode to get address
      final result = await geocodingService.reverseGeocode(coordinates);
      
      expect(result, isNotNull);
      expect(result!.address, isNotEmpty);
      expect(result.coordinates.latitude, closeTo(coordinates.latitude, 0.001));
      expect(result.coordinates.longitude, closeTo(coordinates.longitude, 0.001));
    });

    test('should handle nearby places search', () async {
      final location = LatLng(37.7749, -122.4194); // San Francisco
      
      final nearbyPlaces = await geocodingService.getNearbyPlaces(
        location,
        radius: 1000, // 1km radius
        type: 'restaurant',
      );

      expect(nearbyPlaces, isNotEmpty);
      expect(nearbyPlaces.length, lessThanOrEqualTo(3)); // Mock returns max 3
      
      for (final place in nearbyPlaces) {
        expect(place.name, isNotEmpty);
        expect(place.address, isNotEmpty);
        expect(place.types, contains('restaurant'));
        
        // Verify places are reasonably close to search location
        final distance = _calculateDistance(location, place.coordinates);
        expect(distance, lessThan(5.0)); // Within 5km (mock data tolerance)
      }
    });

    test('should handle multi-waypoint routing', () async {
      final origin = LatLng(37.7749, -122.4194); // San Francisco
      final destination = LatLng(37.7849, -122.4094); // Nearby location
      final waypoints = [
        LatLng(37.7799, -122.4144), // Waypoint 1
        LatLng(37.7779, -122.4174), // Waypoint 2
      ];

      final route = await hybridService.getRouteWithWaypoints(
        origin,
        destination,
        waypoints,
      );

      expect(route.polylinePoints, isNotEmpty);
      expect(route.distanceKm, greaterThan(0));
      expect(route.textInstructions, contains('waypoints'));
      
      // Multi-waypoint routes should be longer and more expensive
      final directRoute = await hybridService.calculateRoute(origin, destination);
      expect(route.distanceKm, greaterThan(directRoute.distanceKm));
      expect(route.estimatedFare, greaterThan(directRoute.estimatedFare));
    });

    test('should provide service health information', () async {
      final health = await hybridService.getServiceHealth();

      expect(health, containsPair('freeService', isA<Map>()));
      expect(health, containsPair('fallbackEnabled', isA<bool>()));
      expect(health, containsPair('googleServiceAvailable', isA<bool>()));

      final freeServiceHealth = health['freeService'] as Map;
      expect(freeServiceHealth, containsPair('available', isA<bool>()));
      expect(freeServiceHealth, containsPair('remainingRequests', isA<int>()));
      expect(freeServiceHealth, containsPair('dailyLimit', isA<int>()));
    });

    test('should handle service availability changes', () async {
      // Initially available
      expect(await geocodingService.isServiceAvailable(), isTrue);
      expect(await routingService.isServiceAvailable(), isTrue);

      // Make service unavailable
      geocodingService.setAvailable(false);
      routingService.setAvailable(false);

      expect(await geocodingService.isServiceAvailable(), isFalse);
      expect(await routingService.isServiceAvailable(), isFalse);

      // Verify services throw appropriate errors
      expect(
        () => geocodingService.searchPlaces('test'),
        throwsA(isA<Exception>()),
      );
      
      expect(
        () => routingService.calculateRoute(
          LatLng(0, 0),
          LatLng(1, 1),
        ),
        throwsA(isA<Exception>()),
      );
    });

    test('should track and respect daily limits', () async {
      final initialRemaining = await routingService.getRemainingDailyRequests();
      expect(initialRemaining, greaterThan(0));

      // Make a routing request
      await routingService.calculateRoute(
        LatLng(37.7749, -122.4194),
        LatLng(37.7849, -122.4094),
      );

      final afterRequestRemaining = await routingService.getRemainingDailyRequests();
      expect(afterRequestRemaining, equals(initialRemaining - 1));

      // Set limit to 0 and verify it's respected
      routingService.setRemainingRequests(0);
      
      expect(
        () => routingService.calculateRoute(
          LatLng(0, 0),
          LatLng(1, 1),
        ),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('Daily request limit exceeded'),
        )),
      );
    });

    test('should demonstrate complete ride creation workflow', () async {
      // Simulate creating a ride with free map services
      
      // Step 1: User searches for pickup location
      final pickupSearch = await geocodingService.searchPlaces('Union Square San Francisco');
      final pickup = pickupSearch.first;

      // Step 2: User searches for destination
      final destSearch = await geocodingService.searchPlaces('San Francisco Airport');
      final destination = destSearch.first;

      // Step 3: Calculate route and fare
      final route = await hybridService.calculateRoute(
        pickup.coordinates,
        destination.coordinates,
      );

      // Step 4: Create ride with calculated information
      final ride = RideGroup(
        id: 'test_ride_123',
        leaderId: 'user_123',
        pickupLocation: pickup.address,
        pickupCoordinates: pickup.coordinates,
        destination: destination.address,
        destinationCoordinates: destination.coordinates,
        scheduledTime: DateTime.now().add(const Duration(hours: 2)),
        totalSeats: 4,
        availableSeats: 3, // Leader takes 1 seat
        totalFare: route.estimatedFare,
        pricePerPerson: route.estimatedFare / 1, // Only leader initially
        createdAt: DateTime.now(),
      );

      // Verify ride was created successfully
      expect(ride.id, equals('test_ride_123'));
      expect(ride.pickupLocation, equals(pickup.address));
      expect(ride.destination, equals(destination.address));
      expect(ride.totalFare, equals(route.estimatedFare));
      expect(ride.pricePerPerson, equals(route.estimatedFare));
      expect(ride.currentMemberCount, equals(1));
      expect(ride.canAcceptMoreMembers, isTrue);

      // Step 5: Simulate another user joining
      final updatedRide = ride.addMember('user_456');
      expect(updatedRide.currentMemberCount, equals(2));
      expect(updatedRide.pricePerPerson, equals(route.estimatedFare / 2));
      expect(updatedRide.availableSeats, equals(2));
    });
  });
}