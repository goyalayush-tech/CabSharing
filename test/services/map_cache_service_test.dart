import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:ridelink/models/map_tile.dart';
import 'package:ridelink/models/place_models.dart';
import 'package:ridelink/models/ride_group.dart';
import 'package:ridelink/services/map_cache_service.dart';

void main() {
  group('MockMapCacheService', () {
    late MockMapCacheService cacheService;

    setUp(() {
      cacheService = MockMapCacheService();
    });

    tearDown(() async {
      await cacheService.dispose();
    });

    test('should initialize and dispose correctly', () async {
      expect(() => cacheService.cacheTile(MapTile.fromUrl('test', 1, 1, 1)), 
             throwsStateError);
      
      await cacheService.initialize();
      
      // Should not throw after initialization
      await cacheService.cacheTile(MapTile.fromUrl('test', 1, 1, 1));
      
      await cacheService.dispose();
      
      // Should throw after disposal
      expect(() => cacheService.cacheTile(MapTile.fromUrl('test', 1, 1, 1)), 
             throwsStateError);
    });

    group('Tile Caching', () {
      setUp(() async {
        await cacheService.initialize();
      });

      test('should cache and retrieve tiles', () async {
        final tile = MapTile.withData(
          'https://example.com/tile.png',
          1, 2, 3,
          Uint8List.fromList([1, 2, 3, 4, 5]),
        );

        await cacheService.cacheTile(tile);
        final retrieved = await cacheService.getCachedTile(tile.key);

        expect(retrieved, isNotNull);
        expect(retrieved!.x, equals(tile.x));
        expect(retrieved.y, equals(tile.y));
        expect(retrieved.zoom, equals(tile.zoom));
        expect(retrieved.url, equals(tile.url));
      });

      test('should return null for non-existent tiles', () async {
        final retrieved = await cacheService.getCachedTile('non_existent_key');
        expect(retrieved, isNull);
      });

      test('should return null for expired tiles', () async {
        final expiredTile = MapTile(
          url: 'https://example.com/tile.png',
          x: 1, y: 2, zoom: 3,
          cachedAt: DateTime.now().subtract(const Duration(hours: 25)),
          cacheDuration: const Duration(hours: 24),
          sizeBytes: 100,
        );

        await cacheService.cacheTile(expiredTile);
        final retrieved = await cacheService.getCachedTile(expiredTile.key);

        expect(retrieved, isNull);
      });

      test('should calculate cache size correctly', () async {
        final tile1 = MapTile.withData('url1', 1, 1, 1, Uint8List(100));
        final tile2 = MapTile.withData('url2', 2, 2, 2, Uint8List(200));

        await cacheService.cacheTile(tile1);
        await cacheService.cacheTile(tile2);

        final size = await cacheService.getTileCacheSize();
        expect(size, equals(300));
      });

      test('should clear tile cache', () async {
        final tile = MapTile.fromUrl('test', 1, 1, 1);
        await cacheService.cacheTile(tile);

        await cacheService.clearTileCache();

        final retrieved = await cacheService.getCachedTile(tile.key);
        expect(retrieved, isNull);
      });
    });

    group('Geocoding Caching', () {
      setUp(() async {
        await cacheService.initialize();
      });

      test('should cache and retrieve geocoding results', () async {
        const query = 'test location';
        final results = [
          PlaceSearchResult(
            placeId: 'place1',
            name: 'Test Place',
            address: 'Test Address',
            coordinates: LatLng(1.0, 2.0),
          ),
        ];

        await cacheService.cacheGeocodingResult(query, results);
        final retrieved = await cacheService.getCachedGeocodingResult(query);

        expect(retrieved, isNotNull);
        expect(retrieved!.length, equals(1));
        expect(retrieved.first.name, equals('Test Place'));
      });

      test('should return null for non-existent geocoding results', () async {
        final retrieved = await cacheService.getCachedGeocodingResult('non_existent');
        expect(retrieved, isNull);
      });
    });

    group('Route Caching', () {
      setUp(() async {
        await cacheService.initialize();
      });

      test('should cache and retrieve routes', () async {
        const routeKey = 'route_1_2';
        final route = RouteInfo(
          polylinePoints: [LatLng(1.0, 2.0), LatLng(3.0, 4.0)],
          distanceKm: 10.5,
          estimatedDuration: const Duration(minutes: 15),
          textInstructions: 'Test route',
          estimatedFare: 25.0,
        );

        await cacheService.cacheRoute(routeKey, route);
        final retrieved = await cacheService.getCachedRoute(routeKey);

        expect(retrieved, isNotNull);
        expect(retrieved!.distanceKm, equals(10.5));
        expect(retrieved.estimatedFare, equals(25.0));
      });

      test('should return null for non-existent routes', () async {
        final retrieved = await cacheService.getCachedRoute('non_existent');
        expect(retrieved, isNull);
      });
    });

    group('Cache Management', () {
      setUp(() async {
        await cacheService.initialize();
      });

      test('should provide cache statistics', () async {
        // Add some test data
        await cacheService.cacheTile(MapTile.fromUrl('test', 1, 1, 1));
        await cacheService.cacheGeocodingResult('test', []);
        await cacheService.cacheRoute('test', RouteInfo(
          polylinePoints: [],
          distanceKm: 0,
          estimatedDuration: Duration.zero,
          textInstructions: '',
          estimatedFare: 0,
        ));

        final stats = await cacheService.getCacheStats();

        expect(stats['tiles_count'], equals(1));
        expect(stats['geocoding_count'], equals(1));
        expect(stats['routes_count'], equals(1));
        expect(stats['tiles_size_bytes'], isA<int>());
      });

      test('should clear all cache', () async {
        // Add test data
        await cacheService.cacheTile(MapTile.fromUrl('test', 1, 1, 1));
        await cacheService.cacheGeocodingResult('test', []);
        await cacheService.cacheRoute('test', RouteInfo(
          polylinePoints: [],
          distanceKm: 0,
          estimatedDuration: Duration.zero,
          textInstructions: '',
          estimatedFare: 0,
        ));

        await cacheService.clearAllCache();

        final stats = await cacheService.getCacheStats();
        expect(stats['tiles_count'], equals(0));
        expect(stats['geocoding_count'], equals(0));
        expect(stats['routes_count'], equals(0));
      });

      test('should clear expired cache', () async {
        // This is a no-op in the mock implementation
        await cacheService.clearExpiredCache();
        // Test passes if no exception is thrown
      });
    });
  });
}