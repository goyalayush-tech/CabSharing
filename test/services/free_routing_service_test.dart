import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:ridelink/core/config/free_map_config.dart';
import 'package:ridelink/models/place_models.dart';
import 'package:ridelink/models/ride_group.dart';
import 'package:ridelink/services/free_routing_service.dart';
import 'package:ridelink/services/map_cache_service.dart';

import 'free_routing_service_test.mocks.dart';

@GenerateMocks([http.Client, IMapCacheService])
void main() {
  group('OpenRouteService', () {
    late MockClient mockHttpClient;
    late MockIMapCacheService mockCacheService;
    late OpenRouteService routingService;
    late FreeMapConfig config;

    setUp(() {
      mockHttpClient = MockClient();
      mockCacheService = MockIMapCacheService();
      config = const FreeMapConfig(
        openRouteServiceApiKey: 'test_api_key',
        openRouteServiceDailyLimit: 100,
      );
      
      routingService = OpenRouteService(
        config: config,
        cacheService: mockCacheService,
        httpClient: mockHttpClient,
      );
    });

    tearDown(() {
      routingService.dispose();
    });

    group('calculateRoute', () {
      final origin = LatLng(37.7749, -122.4194);
      final destination = LatLng(37.7849, -122.4094);

      test('should return cached route when available', () async {
        final cachedRoute = RouteInfo(
          polylinePoints: [origin, destination],
          distanceKm: 10.5,
          estimatedDuration: const Duration(minutes: 15),
          textInstructions: 'Cached route',
          estimatedFare: 75.0,
        );

        when(mockCacheService.getCachedRoute(any))
            .thenAnswer((_) async => cachedRoute);

        final result = await routingService.calculateRoute(origin, destination);

        expect(result, equals(cachedRoute));
        verify(mockCacheService.getCachedRoute(any)).called(1);
        verifyNever(mockHttpClient.post(any, headers: anyNamed('headers'), body: anyNamed('body')));
      });

      test('should make HTTP request when no cached route', () async {
        final mockResponse = {
          'routes': [
            {
              'summary': {
                'distance': 10500.0, // 10.5 km in meters
                'duration': 900.0, // 15 minutes in seconds
              },
              'geometry': 'u{~vFvyys@fS]',
              'segments': [
                {
                  'steps': [
                    {
                      'instruction': 'Head north',
                      'distance': 5000.0,
                      'duration': 300.0,
                      'way_points': [0, 5],
                    },
                    {
                      'instruction': 'Turn right',
                      'distance': 5500.0,
                      'duration': 600.0,
                      'way_points': [5, 10],
                    }
                  ]
                }
              ]
            }
          ]
        };

        when(mockCacheService.getCachedRoute(any))
            .thenAnswer((_) async => null);
        when(mockHttpClient.post(any, headers: anyNamed('headers'), body: anyNamed('body')))
            .thenAnswer((_) async => http.Response(json.encode(mockResponse), 200));
        when(mockCacheService.cacheRoute(any, any))
            .thenAnswer((_) async {});

        final result = await routingService.calculateRoute(origin, destination);

        expect(result.distanceKm, equals(10.5));
        expect(result.estimatedDuration, equals(const Duration(minutes: 15)));
        expect(result.polylinePoints, isNotEmpty);
        expect(result.estimatedFare, greaterThan(0));
        expect(result.steps, hasLength(2));

        verify(mockCacheService.getCachedRoute(any)).called(1);
        verify(mockHttpClient.post(any, headers: anyNamed('headers'), body: anyNamed('body'))).called(1);
        verify(mockCacheService.cacheRoute(any, any)).called(1);
      });

      test('should handle API key errors', () async {
        when(mockCacheService.getCachedRoute(any))
            .thenAnswer((_) async => null);
        when(mockHttpClient.post(any, headers: anyNamed('headers'), body: anyNamed('body')))
            .thenAnswer((_) async => http.Response('Unauthorized', 401));

        expect(
          () => routingService.calculateRoute(origin, destination),
          throwsA(isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('Invalid OpenRouteService API key'),
          )),
        );
      });

      test('should handle rate limiting', () async {
        when(mockCacheService.getCachedRoute(any))
            .thenAnswer((_) async => null);
        when(mockHttpClient.post(any, headers: anyNamed('headers'), body: anyNamed('body')))
            .thenAnswer((_) async => http.Response('Rate Limited', 429));

        expect(
          () => routingService.calculateRoute(origin, destination),
          throwsA(isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('rate limit exceeded'),
          )),
        );
      });

      test('should handle daily limit exceeded', () async {
        // Create a service with 0 remaining requests
        final limitedConfig = config.copyWith(openRouteServiceDailyLimit: 0);
        final limitedService = OpenRouteService(
          config: limitedConfig,
          cacheService: mockCacheService,
          httpClient: mockHttpClient,
        );

        when(mockCacheService.getCachedRoute(any))
            .thenAnswer((_) async => null);

        expect(
          () => limitedService.calculateRoute(origin, destination),
          throwsA(isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('Daily request limit exceeded'),
          )),
        );

        limitedService.dispose();
      });

      test('should include correct headers and body in request', () async {
        when(mockCacheService.getCachedRoute(any))
            .thenAnswer((_) async => null);
        when(mockHttpClient.post(any, headers: anyNamed('headers'), body: anyNamed('body')))
            .thenAnswer((_) async => http.Response('{"routes": []}', 200));

        try {
          await routingService.calculateRoute(origin, destination);
        } catch (e) {
          // Ignore the error, we just want to verify the request
        }

        final captured = verify(mockHttpClient.post(
          captureAny,
          headers: captureAnyNamed('headers'),
          body: captureAnyNamed('body'),
        )).captured;

        final uri = captured[0] as Uri;
        final headers = captured[1] as Map<String, String>;
        final body = captured[2] as String;

        expect(uri.path, contains('/directions/driving-car'));
        expect(headers['Authorization'], equals('test_api_key'));
        expect(headers['Content-Type'], equals('application/json'));

        final requestData = json.decode(body) as Map<String, dynamic>;
        expect(requestData['coordinates'], hasLength(2));
        expect(requestData['profile'], equals('driving-car'));
        expect(requestData['geometry'], isTrue);
      });
    });

    group('getRouteWithWaypoints', () {
      final origin = LatLng(37.7749, -122.4194);
      final destination = LatLng(37.7849, -122.4094);
      final waypoints = [LatLng(37.7799, -122.4144)];

      test('should handle empty waypoints by calling calculateRoute', () async {
        final mockRoute = RouteInfo(
          polylinePoints: [origin, destination],
          distanceKm: 10.0,
          estimatedDuration: const Duration(minutes: 15),
          textInstructions: 'Direct route',
          estimatedFare: 70.0,
        );

        when(mockCacheService.getCachedRoute(any))
            .thenAnswer((_) async => mockRoute);

        final result = await routingService.getRouteWithWaypoints(origin, destination, []);

        expect(result, equals(mockRoute));
      });

      test('should include waypoints in request', () async {
        when(mockCacheService.getCachedRoute(any))
            .thenAnswer((_) async => null);
        when(mockHttpClient.post(any, headers: anyNamed('headers'), body: anyNamed('body')))
            .thenAnswer((_) async => http.Response('{"routes": []}', 200));

        try {
          await routingService.getRouteWithWaypoints(origin, destination, waypoints);
        } catch (e) {
          // Ignore the error, we just want to verify the request
        }

        final captured = verify(mockHttpClient.post(
          captureAny,
          headers: captureAnyNamed('headers'),
          body: captureAnyNamed('body'),
        )).captured;

        final body = captured[2] as String;
        final requestData = json.decode(body) as Map<String, dynamic>;
        
        expect(requestData['coordinates'], hasLength(3)); // origin + waypoint + destination
        expect(requestData['optimize_waypoints'], isTrue);
      });
    });

    group('getOptimizedWaypoints', () {
      test('should return original locations for less than 3 points', () async {
        final locations = [LatLng(1, 1), LatLng(2, 2)];
        final result = await routingService.getOptimizedWaypoints(locations);
        expect(result, equals(locations));
      });

      test('should return original locations on error', () async {
        final locations = [LatLng(1, 1), LatLng(2, 2), LatLng(3, 3)];
        
        when(mockCacheService.getCachedRoute(any))
            .thenAnswer((_) async => null);
        when(mockHttpClient.post(any, headers: anyNamed('headers'), body: anyNamed('body')))
            .thenThrow(Exception('Network error'));

        final result = await routingService.getOptimizedWaypoints(locations);
        expect(result, equals(locations));
      });
    });

    group('estimateFare', () {
      test('should calculate fare correctly', () async {
        final route = RouteInfo(
          polylinePoints: [],
          distanceKm: 10.0,
          estimatedDuration: const Duration(minutes: 20),
          textInstructions: '',
          estimatedFare: 0,
        );

        final fare = await routingService.estimateFare(route);

        // Base fare (50) + distance (10 * 15 = 150) + time (20 * 2 = 40) = 240
        expect(fare, equals(240.0));
      });

      test('should enforce minimum fare', () async {
        final route = RouteInfo(
          polylinePoints: [],
          distanceKm: 0.1, // Very short distance
          estimatedDuration: const Duration(minutes: 1),
          textInstructions: '',
          estimatedFare: 0,
        );

        final fare = await routingService.estimateFare(route);

        // Should be at least the minimum fare (25)
        expect(fare, greaterThanOrEqualTo(25.0));
      });
    });

    group('isServiceAvailable', () {
      test('should return true when service is available', () async {
        when(mockHttpClient.get(any, headers: anyNamed('headers')))
            .thenAnswer((_) async => http.Response('OK', 200));

        final isAvailable = await routingService.isServiceAvailable();

        expect(isAvailable, isTrue);
      });

      test('should return false when service is unavailable', () async {
        when(mockHttpClient.get(any, headers: anyNamed('headers')))
            .thenAnswer((_) async => http.Response('Server Error', 500));

        final isAvailable = await routingService.isServiceAvailable();

        expect(isAvailable, isFalse);
      });

      test('should return false on network error', () async {
        when(mockHttpClient.get(any, headers: anyNamed('headers')))
            .thenThrow(Exception('Network error'));

        final isAvailable = await routingService.isServiceAvailable();

        expect(isAvailable, isFalse);
      });
    });

    group('getRemainingDailyRequests', () {
      test('should return correct remaining requests', () async {
        final remaining = await routingService.getRemainingDailyRequests();
        expect(remaining, equals(100)); // Initial limit
      });

      test('should decrease after making requests', () async {
        final mockResponse = {
          'routes': [
            {
              'summary': {'distance': 1000.0, 'duration': 60.0},
              'geometry': 'u{~vFvyys@fS]',
              'segments': []
            }
          ]
        };

        when(mockCacheService.getCachedRoute(any))
            .thenAnswer((_) async => null);
        when(mockHttpClient.post(any, headers: anyNamed('headers'), body: anyNamed('body')))
            .thenAnswer((_) async => http.Response(json.encode(mockResponse), 200));
        when(mockCacheService.cacheRoute(any, any))
            .thenAnswer((_) async {});

        final origin = LatLng(37.7749, -122.4194);
        final destination = LatLng(37.7849, -122.4094);

        await routingService.calculateRoute(origin, destination);

        final remaining = await routingService.getRemainingDailyRequests();
        expect(remaining, equals(99)); // Should decrease by 1
      });
    });
  });

  group('MockFreeRoutingService', () {
    late MockFreeRoutingService mockService;

    setUp(() {
      mockService = MockFreeRoutingService();
    });

    test('should return mock route', () async {
      final origin = LatLng(37.7749, -122.4194);
      final destination = LatLng(37.7849, -122.4094);

      final result = await mockService.calculateRoute(origin, destination);

      expect(result.polylinePoints, isNotEmpty);
      expect(result.distanceKm, greaterThan(0));
      expect(result.estimatedDuration.inMinutes, greaterThan(0));
      expect(result.estimatedFare, greaterThan(0));
      expect(result.steps, hasLength(3));
    });

    test('should handle waypoints', () async {
      final origin = LatLng(37.7749, -122.4194);
      final destination = LatLng(37.7849, -122.4094);
      final waypoints = [LatLng(37.7799, -122.4144)];

      final result = await mockService.getRouteWithWaypoints(origin, destination, waypoints);

      expect(result.distanceKm, greaterThan(0));
      expect(result.textInstructions, contains('waypoints'));
      expect(result.estimatedFare, greaterThan(0));
    });

    test('should return optimized waypoints', () async {
      final locations = [
        LatLng(37.7749, -122.4194),
        LatLng(37.7799, -122.4144),
        LatLng(37.7849, -122.4094),
      ];

      final result = await mockService.getOptimizedWaypoints(locations);

      expect(result, equals(locations)); // Mock returns original order
    });

    test('should calculate fare', () async {
      final route = RouteInfo(
        polylinePoints: [],
        distanceKm: 10.0,
        estimatedDuration: const Duration(minutes: 20),
        textInstructions: '',
        estimatedFare: 0,
      );

      final fare = await mockService.estimateFare(route);

      expect(fare, equals(240.0)); // Same calculation as real service
    });

    test('should respect availability setting', () async {
      mockService.setAvailable(false);

      final origin = LatLng(37.7749, -122.4194);
      final destination = LatLng(37.7849, -122.4094);

      expect(
        () => mockService.calculateRoute(origin, destination),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('Routing service unavailable'),
        )),
      );

      final isAvailable = await mockService.isServiceAvailable();
      expect(isAvailable, isFalse);
    });

    test('should respect request limits', () async {
      mockService.setRemainingRequests(0);

      final origin = LatLng(37.7749, -122.4194);
      final destination = LatLng(37.7849, -122.4094);

      expect(
        () => mockService.calculateRoute(origin, destination),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('Daily request limit exceeded'),
        )),
      );

      final remaining = await mockService.getRemainingDailyRequests();
      expect(remaining, equals(0));
    });

    test('should decrease remaining requests', () async {
      final initialRemaining = await mockService.getRemainingDailyRequests();
      
      final origin = LatLng(37.7749, -122.4194);
      final destination = LatLng(37.7849, -122.4094);

      await mockService.calculateRoute(origin, destination);

      final finalRemaining = await mockService.getRemainingDailyRequests();
      expect(finalRemaining, equals(initialRemaining - 1));
    });

    test('should simulate delay', () async {
      final stopwatch = Stopwatch()..start();
      
      final origin = LatLng(37.7749, -122.4194);
      final destination = LatLng(37.7849, -122.4094);
      
      await mockService.calculateRoute(origin, destination);
      stopwatch.stop();

      expect(stopwatch.elapsedMilliseconds, greaterThanOrEqualTo(450));
    });
  });
}