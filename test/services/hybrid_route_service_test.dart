import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:ridelink/core/config/free_map_config.dart';
import 'package:ridelink/models/place_models.dart';
import 'package:ridelink/models/ride_group.dart';
import 'package:ridelink/services/free_routing_service.dart';
import 'package:ridelink/services/hybrid_route_service.dart';
import 'package:ridelink/services/route_service.dart';

import 'hybrid_route_service_test.mocks.dart';

@GenerateMocks([IFreeRoutingService, IRouteService])
void main() {
  group('HybridRouteService', () {
    late MockIFreeRoutingService mockFreeService;
    late MockIRouteService mockGoogleService;
    late HybridRouteService hybridService;
    late FreeMapConfig config;

    final origin = LatLng(37.7749, -122.4194);
    final destination = LatLng(37.7849, -122.4094);
    final mockRoute = RouteInfo(
      polylinePoints: [origin, destination],
      distanceKm: 10.0,
      estimatedDuration: const Duration(minutes: 15),
      textInstructions: 'Test route',
      estimatedFare: 75.0,
    );

    setUp(() {
      mockFreeService = MockIFreeRoutingService();
      mockGoogleService = MockIRouteService();
      config = const FreeMapConfig(enableFallback: true);
      
      hybridService = HybridRouteService(
        freeRoutingService: mockFreeService,
        googleRouteService: mockGoogleService,
        config: config,
      );
    });

    group('calculateRoute', () {
      test('should use free service when available', () async {
        when(mockFreeService.calculateRoute(origin, destination))
            .thenAnswer((_) async => mockRoute);

        final result = await hybridService.calculateRoute(origin, destination);

        expect(result, equals(mockRoute));
        verify(mockFreeService.calculateRoute(origin, destination)).called(1);
        verifyNever(mockGoogleService.calculateRoute(any, any));
      });

      test('should fallback to Google service when free service fails', () async {
        final googleRoute = mockRoute.copyWith(textInstructions: 'Google route');

        when(mockFreeService.calculateRoute(origin, destination))
            .thenThrow(Exception('Free service failed'));
        when(mockGoogleService.calculateRoute(origin, destination))
            .thenAnswer((_) async => googleRoute);

        final result = await hybridService.calculateRoute(origin, destination);

        expect(result, equals(googleRoute));
        verify(mockFreeService.calculateRoute(origin, destination)).called(1);
        verify(mockGoogleService.calculateRoute(origin, destination)).called(1);
      });

      test('should throw error when both services fail', () async {
        when(mockFreeService.calculateRoute(origin, destination))
            .thenThrow(Exception('Free service failed'));
        when(mockGoogleService.calculateRoute(origin, destination))
            .thenThrow(Exception('Google service failed'));

        expect(
          () => hybridService.calculateRoute(origin, destination),
          throwsA(isA<Exception>().having(
            (e) => e.toString(),
            'message',
            allOf(
              contains('Primary routing service failed'),
              contains('Fallback also failed'),
            ),
          )),
        );

        verify(mockFreeService.calculateRoute(origin, destination)).called(1);
        verify(mockGoogleService.calculateRoute(origin, destination)).called(1);
      });

      test('should not use fallback when disabled', () async {
        final noFallbackConfig = config.copyWith(enableFallback: false);
        final noFallbackService = HybridRouteService(
          freeRoutingService: mockFreeService,
          googleRouteService: mockGoogleService,
          config: noFallbackConfig,
        );

        when(mockFreeService.calculateRoute(origin, destination))
            .thenThrow(Exception('Free service failed'));

        expect(
          () => noFallbackService.calculateRoute(origin, destination),
          throwsA(isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('Free service failed'),
          )),
        );

        verify(mockFreeService.calculateRoute(origin, destination)).called(1);
        verifyNever(mockGoogleService.calculateRoute(any, any));
      });

      test('should not use fallback when Google service is null', () async {
        final noGoogleService = HybridRouteService(
          freeRoutingService: mockFreeService,
          googleRouteService: null,
          config: config,
        );

        when(mockFreeService.calculateRoute(origin, destination))
            .thenThrow(Exception('Free service failed'));

        expect(
          () => noGoogleService.calculateRoute(origin, destination),
          throwsA(isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('Free service failed'),
          )),
        );

        verify(mockFreeService.calculateRoute(origin, destination)).called(1);
      });
    });

    group('getRouteWithWaypoints', () {
      final waypoints = [LatLng(37.7799, -122.4144)];

      test('should use free service when available', () async {
        when(mockFreeService.getRouteWithWaypoints(origin, destination, waypoints))
            .thenAnswer((_) async => mockRoute);

        final result = await hybridService.getRouteWithWaypoints(origin, destination, waypoints);

        expect(result, equals(mockRoute));
        verify(mockFreeService.getRouteWithWaypoints(origin, destination, waypoints)).called(1);
        verifyNever(mockGoogleService.getRouteWithWaypoints(any, any, any));
      });

      test('should fallback to Google service when free service fails', () async {
        final googleRoute = mockRoute.copyWith(textInstructions: 'Google waypoint route');

        when(mockFreeService.getRouteWithWaypoints(origin, destination, waypoints))
            .thenThrow(Exception('Free service failed'));
        when(mockGoogleService.getRouteWithWaypoints(origin, destination, waypoints))
            .thenAnswer((_) async => googleRoute);

        final result = await hybridService.getRouteWithWaypoints(origin, destination, waypoints);

        expect(result, equals(googleRoute));
        verify(mockFreeService.getRouteWithWaypoints(origin, destination, waypoints)).called(1);
        verify(mockGoogleService.getRouteWithWaypoints(origin, destination, waypoints)).called(1);
      });
    });

    group('getOptimizedWaypoints', () {
      final locations = [origin, LatLng(37.7799, -122.4144), destination];

      test('should use free service when available', () async {
        when(mockFreeService.getOptimizedWaypoints(locations))
            .thenAnswer((_) async => locations);

        final result = await hybridService.getOptimizedWaypoints(locations);

        expect(result, equals(locations));
        verify(mockFreeService.getOptimizedWaypoints(locations)).called(1);
        verifyNever(mockGoogleService.getOptimizedWaypoints(any));
      });

      test('should fallback to Google service when free service fails', () async {
        final optimizedLocations = [locations[2], locations[1], locations[0]]; // Reversed

        when(mockFreeService.getOptimizedWaypoints(locations))
            .thenThrow(Exception('Free service failed'));
        when(mockGoogleService.getOptimizedWaypoints(locations))
            .thenAnswer((_) async => optimizedLocations);

        final result = await hybridService.getOptimizedWaypoints(locations);

        expect(result, equals(optimizedLocations));
        verify(mockFreeService.getOptimizedWaypoints(locations)).called(1);
        verify(mockGoogleService.getOptimizedWaypoints(locations)).called(1);
      });

      test('should return original locations when both services fail', () async {
        when(mockFreeService.getOptimizedWaypoints(locations))
            .thenThrow(Exception('Free service failed'));
        when(mockGoogleService.getOptimizedWaypoints(locations))
            .thenThrow(Exception('Google service failed'));

        final result = await hybridService.getOptimizedWaypoints(locations);

        expect(result, equals(locations));
        verify(mockFreeService.getOptimizedWaypoints(locations)).called(1);
        verify(mockGoogleService.getOptimizedWaypoints(locations)).called(1);
      });

      test('should return original locations when no fallback available', () async {
        final noFallbackService = HybridRouteService(
          freeRoutingService: mockFreeService,
          googleRouteService: null,
          config: config.copyWith(enableFallback: false),
        );

        when(mockFreeService.getOptimizedWaypoints(locations))
            .thenThrow(Exception('Free service failed'));

        final result = await noFallbackService.getOptimizedWaypoints(locations);

        expect(result, equals(locations));
        verify(mockFreeService.getOptimizedWaypoints(locations)).called(1);
      });
    });

    group('estimateFare', () {
      test('should use free service when available', () async {
        when(mockFreeService.estimateFare(mockRoute))
            .thenAnswer((_) async => 75.0);

        final result = await hybridService.estimateFare(mockRoute);

        expect(result, equals(75.0));
        verify(mockFreeService.estimateFare(mockRoute)).called(1);
        verifyNever(mockGoogleService.estimateFare(any));
      });

      test('should fallback to Google service when free service fails', () async {
        when(mockFreeService.estimateFare(mockRoute))
            .thenThrow(Exception('Free service failed'));
        when(mockGoogleService.estimateFare(mockRoute))
            .thenAnswer((_) async => 80.0);

        final result = await hybridService.estimateFare(mockRoute);

        expect(result, equals(80.0));
        verify(mockFreeService.estimateFare(mockRoute)).called(1);
        verify(mockGoogleService.estimateFare(mockRoute)).called(1);
      });

      test('should use basic calculation when both services fail', () async {
        when(mockFreeService.estimateFare(mockRoute))
            .thenThrow(Exception('Free service failed'));
        when(mockGoogleService.estimateFare(mockRoute))
            .thenThrow(Exception('Google service failed'));

        final result = await hybridService.estimateFare(mockRoute);

        // Basic calculation: 50 (base) + 10*15 (distance) + 15*2 (time) = 230
        expect(result, equals(230.0));
        verify(mockFreeService.estimateFare(mockRoute)).called(1);
        verify(mockGoogleService.estimateFare(mockRoute)).called(1);
      });

      test('should enforce minimum fare in basic calculation', () async {
        final shortRoute = RouteInfo(
          polylinePoints: [],
          distanceKm: 0.1,
          estimatedDuration: const Duration(minutes: 1),
          textInstructions: '',
          estimatedFare: 0,
        );

        when(mockFreeService.estimateFare(shortRoute))
            .thenThrow(Exception('Free service failed'));
        when(mockGoogleService.estimateFare(shortRoute))
            .thenThrow(Exception('Google service failed'));

        final result = await hybridService.estimateFare(shortRoute);

        // Should be at least minimum fare (25)
        expect(result, greaterThanOrEqualTo(25.0));
      });
    });

    group('service health methods', () {
      test('should check free service availability', () async {
        when(mockFreeService.isServiceAvailable())
            .thenAnswer((_) async => true);

        final isAvailable = await hybridService.isFreeServiceAvailable();

        expect(isAvailable, isTrue);
        verify(mockFreeService.isServiceAvailable()).called(1);
      });

      test('should handle free service availability check errors', () async {
        when(mockFreeService.isServiceAvailable())
            .thenThrow(Exception('Service check failed'));

        final isAvailable = await hybridService.isFreeServiceAvailable();

        expect(isAvailable, isFalse);
      });

      test('should get remaining free requests', () async {
        when(mockFreeService.getRemainingDailyRequests())
            .thenAnswer((_) async => 1500);

        final remaining = await hybridService.getRemainingFreeRequests();

        expect(remaining, equals(1500));
        verify(mockFreeService.getRemainingDailyRequests()).called(1);
      });

      test('should handle remaining requests check errors', () async {
        when(mockFreeService.getRemainingDailyRequests())
            .thenThrow(Exception('Request check failed'));

        final remaining = await hybridService.getRemainingFreeRequests();

        expect(remaining, equals(0));
      });

      test('should provide comprehensive service health', () async {
        when(mockFreeService.isServiceAvailable())
            .thenAnswer((_) async => true);
        when(mockFreeService.getRemainingDailyRequests())
            .thenAnswer((_) async => 1800);

        final health = await hybridService.getServiceHealth();

        expect(health['freeService']['available'], isTrue);
        expect(health['freeService']['remainingRequests'], equals(1800));
        expect(health['freeService']['dailyLimit'], equals(config.openRouteServiceDailyLimit));
        expect(health['fallbackEnabled'], isTrue);
        expect(health['googleServiceAvailable'], isTrue);
      });

      test('should handle service health when Google service is null', () async {
        final noGoogleService = HybridRouteService(
          freeRoutingService: mockFreeService,
          googleRouteService: null,
          config: config,
        );

        when(mockFreeService.isServiceAvailable())
            .thenAnswer((_) async => false);
        when(mockFreeService.getRemainingDailyRequests())
            .thenAnswer((_) async => 0);

        final health = await noGoogleService.getServiceHealth();

        expect(health['freeService']['available'], isFalse);
        expect(health['freeService']['remainingRequests'], equals(0));
        expect(health['fallbackEnabled'], isTrue);
        expect(health['googleServiceAvailable'], isFalse);
      });
    });
  });
}