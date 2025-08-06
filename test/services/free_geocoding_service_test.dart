import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:ridelink/core/config/free_map_config.dart';
import 'package:ridelink/models/place_models.dart';
import 'package:ridelink/models/ride_group.dart';
import 'package:ridelink/services/free_geocoding_service.dart';
import 'package:ridelink/services/map_cache_service.dart';

import 'free_geocoding_service_test.mocks.dart';

@GenerateMocks([http.Client, IMapCacheService])
void main() {
  group('NominatimGeocodingService', () {
    late MockClient mockHttpClient;
    late MockIMapCacheService mockCacheService;
    late NominatimGeocodingService geocodingService;
    late FreeMapConfig config;

    setUp(() {
      mockHttpClient = MockClient();
      mockCacheService = MockIMapCacheService();
      config = const FreeMapConfig();
      
      geocodingService = NominatimGeocodingService(
        config: config,
        cacheService: mockCacheService,
        httpClient: mockHttpClient,
      );
    });

    tearDown(() {
      geocodingService.dispose();
    });

    group('searchPlaces', () {
      test('should return empty list for empty query', () async {
        final results = await geocodingService.searchPlaces('');
        expect(results, isEmpty);
      });

      test('should return cached results when available', () async {
        const query = 'test location';
        final cachedResults = [
          PlaceSearchResult(
            placeId: 'cached_1',
            name: 'Cached Place',
            address: 'Cached Address',
            coordinates: LatLng(1.0, 2.0),
          ),
        ];

        when(mockCacheService.getCachedGeocodingResult(query))
            .thenAnswer((_) async => cachedResults);

        final results = await geocodingService.searchPlaces(query);

        expect(results, equals(cachedResults));
        verify(mockCacheService.getCachedGeocodingResult(query)).called(1);
        verifyNever(mockHttpClient.get(any));
      });

      test('should make HTTP request when no cached results', () async {
        const query = 'test location';
        final mockResponse = [
          {
            'place_id': '12345',
            'lat': '37.7749',
            'lon': '-122.4194',
            'display_name': 'Test Location, San Francisco, CA, USA',
            'name': 'Test Location',
            'type': 'amenity',
            'class': 'restaurant',
            'importance': 0.8,
          }
        ];

        when(mockCacheService.getCachedGeocodingResult(query))
            .thenAnswer((_) async => null);
        when(mockHttpClient.get(any))
            .thenAnswer((_) async => http.Response(json.encode(mockResponse), 200));
        when(mockCacheService.cacheGeocodingResult(any, any))
            .thenAnswer((_) async {});

        final results = await geocodingService.searchPlaces(query);

        expect(results, hasLength(1));
        expect(results.first.name, equals('Test Location'));
        expect(results.first.placeId, equals('12345'));
        expect(results.first.coordinates.latitude, equals(37.7749));
        expect(results.first.coordinates.longitude, equals(-122.4194));

        verify(mockCacheService.getCachedGeocodingResult(query)).called(1);
        verify(mockHttpClient.get(any)).called(1);
        verify(mockCacheService.cacheGeocodingResult(query, any)).called(1);
      });

      test('should handle HTTP errors gracefully', () async {
        const query = 'test location';

        when(mockCacheService.getCachedGeocodingResult(query))
            .thenAnswer((_) async => null);
        when(mockHttpClient.get(any))
            .thenAnswer((_) async => http.Response('Server Error', 500));

        expect(
          () => geocodingService.searchPlaces(query),
          throwsA(isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('Nominatim search failed: 500'),
          )),
        );
      });

      test('should handle rate limiting', () async {
        const query = 'test location';

        when(mockCacheService.getCachedGeocodingResult(query))
            .thenAnswer((_) async => null);
        when(mockHttpClient.get(any))
            .thenAnswer((_) async => http.Response('Rate Limited', 429));

        expect(
          () => geocodingService.searchPlaces(query),
          throwsA(isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('Rate limit exceeded'),
          )),
        );
      });

      test('should include location bias in request', () async {
        const query = 'test location';
        final location = LatLng(37.7749, -122.4194);
        const radius = 10000.0;

        when(mockCacheService.getCachedGeocodingResult(query))
            .thenAnswer((_) async => null);
        when(mockHttpClient.get(any))
            .thenAnswer((_) async => http.Response('[]', 200));

        await geocodingService.searchPlaces(
          query,
          location: location,
          radius: radius,
        );

        final captured = verify(mockHttpClient.get(captureAny)).captured;
        final uri = captured.first as Uri;
        
        expect(uri.queryParameters['lat'], equals('37.7749'));
        expect(uri.queryParameters['lon'], equals('-122.4194'));
        expect(uri.queryParameters['viewbox'], isNotNull);
        expect(uri.queryParameters['bounded'], equals('1'));
      });
    });

    group('reverseGeocode', () {
      test('should return cached result when available', () async {
        final coordinates = LatLng(37.7749, -122.4194);
        final cachedResult = PlaceSearchResult(
          placeId: 'cached_reverse',
          name: 'Cached Reverse',
          address: 'Cached Address',
          coordinates: coordinates,
        );

        when(mockCacheService.getCachedGeocodingResult(any))
            .thenAnswer((_) async => [cachedResult]);

        final result = await geocodingService.reverseGeocode(coordinates);

        expect(result, equals(cachedResult));
        verify(mockCacheService.getCachedGeocodingResult(any)).called(1);
        verifyNever(mockHttpClient.get(any));
      });

      test('should make HTTP request when no cached result', () async {
        final coordinates = LatLng(37.7749, -122.4194);
        final mockResponse = {
          'place_id': '54321',
          'lat': '37.7749',
          'lon': '-122.4194',
          'display_name': 'Reverse Location, San Francisco, CA, USA',
          'name': 'Reverse Location',
          'type': 'building',
          'class': 'building',
          'importance': 0.7,
        };

        when(mockCacheService.getCachedGeocodingResult(any))
            .thenAnswer((_) async => null);
        when(mockHttpClient.get(any))
            .thenAnswer((_) async => http.Response(json.encode(mockResponse), 200));
        when(mockCacheService.cacheGeocodingResult(any, any))
            .thenAnswer((_) async {});

        final result = await geocodingService.reverseGeocode(coordinates);

        expect(result, isNotNull);
        expect(result!.name, equals('Reverse Location'));
        expect(result.placeId, equals('54321'));

        verify(mockCacheService.getCachedGeocodingResult(any)).called(1);
        verify(mockHttpClient.get(any)).called(1);
        verify(mockCacheService.cacheGeocodingResult(any, any)).called(1);
      });

      test('should return null for HTTP errors', () async {
        final coordinates = LatLng(37.7749, -122.4194);

        when(mockCacheService.getCachedGeocodingResult(any))
            .thenAnswer((_) async => null);
        when(mockHttpClient.get(any))
            .thenAnswer((_) async => http.Response('Server Error', 500));

        final result = await geocodingService.reverseGeocode(coordinates);

        expect(result, isNull);
      });

      test('should include correct parameters in reverse request', () async {
        final coordinates = LatLng(37.7749, -122.4194);

        when(mockCacheService.getCachedGeocodingResult(any))
            .thenAnswer((_) async => null);
        when(mockHttpClient.get(any))
            .thenAnswer((_) async => http.Response('{}', 200));

        await geocodingService.reverseGeocode(coordinates);

        final captured = verify(mockHttpClient.get(captureAny)).captured;
        final uri = captured.first as Uri;
        
        expect(uri.path, contains('/reverse'));
        expect(uri.queryParameters['lat'], equals('37.7749'));
        expect(uri.queryParameters['lon'], equals('-122.4194'));
        expect(uri.queryParameters['format'], equals('json'));
        expect(uri.queryParameters['zoom'], equals('18'));
      });
    });

    group('getNearbyPlaces', () {
      test('should return nearby places', () async {
        final location = LatLng(37.7749, -122.4194);
        final mockResponse = [
          {
            'place_id': '11111',
            'lat': '37.7750',
            'lon': '-122.4195',
            'display_name': 'Nearby Place 1, San Francisco, CA, USA',
            'name': 'Nearby Place 1',
            'type': 'restaurant',
            'class': 'amenity',
            'importance': 0.6,
          },
          {
            'place_id': '22222',
            'lat': '37.7748',
            'lon': '-122.4193',
            'display_name': 'Nearby Place 2, San Francisco, CA, USA',
            'name': 'Nearby Place 2',
            'type': 'shop',
            'class': 'shop',
            'importance': 0.5,
          }
        ];

        when(mockHttpClient.get(any))
            .thenAnswer((_) async => http.Response(json.encode(mockResponse), 200));

        final results = await geocodingService.getNearbyPlaces(location);

        expect(results, hasLength(2));
        expect(results.first.name, equals('Nearby Place 1'));
        expect(results.last.name, equals('Nearby Place 2'));

        final captured = verify(mockHttpClient.get(captureAny)).captured;
        final uri = captured.first as Uri;
        expect(uri.queryParameters['viewbox'], isNotNull);
        expect(uri.queryParameters['bounded'], equals('1'));
      });

      test('should handle nearby search errors gracefully', () async {
        final location = LatLng(37.7749, -122.4194);

        when(mockHttpClient.get(any))
            .thenAnswer((_) async => http.Response('Server Error', 500));

        final results = await geocodingService.getNearbyPlaces(location);

        expect(results, isEmpty);
      });

      test('should include type parameter when provided', () async {
        final location = LatLng(37.7749, -122.4194);
        const type = 'restaurant';

        when(mockHttpClient.get(any))
            .thenAnswer((_) async => http.Response('[]', 200));

        await geocodingService.getNearbyPlaces(location, type: type);

        final captured = verify(mockHttpClient.get(captureAny)).captured;
        final uri = captured.first as Uri;
        expect(uri.queryParameters['q'], equals(type));
      });
    });

    group('isServiceAvailable', () {
      test('should return true when service is available', () async {
        when(mockHttpClient.get(any))
            .thenAnswer((_) async => http.Response('OK', 200));

        final isAvailable = await geocodingService.isServiceAvailable();

        expect(isAvailable, isTrue);
      });

      test('should return false when service is unavailable', () async {
        when(mockHttpClient.get(any))
            .thenAnswer((_) async => http.Response('Server Error', 500));

        final isAvailable = await geocodingService.isServiceAvailable();

        expect(isAvailable, isFalse);
      });

      test('should return false on network error', () async {
        when(mockHttpClient.get(any))
            .thenThrow(Exception('Network error'));

        final isAvailable = await geocodingService.isServiceAvailable();

        expect(isAvailable, isFalse);
      });
    });
  });

  group('MockFreeGeocodingService', () {
    late MockFreeGeocodingService mockService;

    setUp(() {
      mockService = MockFreeGeocodingService();
    });

    test('should return mock search results', () async {
      final results = await mockService.searchPlaces('test query');

      expect(results, hasLength(5));
      expect(results.first.name, contains('test query'));
      expect(results.first.placeId, contains('mock_place'));
    });

    test('should return mock reverse geocoding result', () async {
      final coordinates = LatLng(37.7749, -122.4194);
      final result = await mockService.reverseGeocode(coordinates);

      expect(result, isNotNull);
      expect(result!.coordinates, equals(coordinates));
      expect(result.name, equals('Mock Location'));
    });

    test('should return mock nearby places', () async {
      final location = LatLng(37.7749, -122.4194);
      final results = await mockService.getNearbyPlaces(location);

      expect(results, hasLength(3));
      expect(results.first.name, contains('Place 1'));
    });

    test('should respect availability setting', () async {
      mockService.setAvailable(false);

      expect(
        () => mockService.searchPlaces('test'),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('Service unavailable'),
        )),
      );

      final isAvailable = await mockService.isServiceAvailable();
      expect(isAvailable, isFalse);
    });

    test('should simulate delay', () async {
      final stopwatch = Stopwatch()..start();
      await mockService.searchPlaces('test');
      stopwatch.stop();

      expect(stopwatch.elapsedMilliseconds, greaterThanOrEqualTo(250));
    });
  });
}