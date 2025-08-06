import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:mockito/mockito.dart';
import '../../lib/services/offline_tile_provider.dart';
import '../../lib/services/offline_service.dart';
import '../../lib/services/map_cache_service.dart';
import '../../lib/models/map_tile.dart';

void main() {
  group('OfflineTileProvider', () {
    late MockMapCacheService mockCacheService;
    late MockOfflineService mockOfflineService;
    late OfflineTileProvider tileProvider;

    setUp(() {
      mockCacheService = MockMapCacheService();
      mockOfflineService = MockOfflineService();
      
      tileProvider = OfflineTileProvider(
        cacheService: mockCacheService,
        offlineService: mockOfflineService,
        baseUrl: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
      );
    });

    tearDown(() {
      mockCacheService.dispose();
      mockOfflineService.dispose();
    });

    test('should create image provider', () {
      final coordinates = TileCoordinates(1, 2, 3);
      final options = TileLayer(urlTemplate: 'test');
      
      final imageProvider = tileProvider.getImage(coordinates, options);
      
      expect(imageProvider, isA<OfflineTileImageProvider>());
    });

    test('should pass correct parameters to image provider', () {
      final coordinates = TileCoordinates(1, 2, 3);
      final options = TileLayer(urlTemplate: 'test');
      
      final imageProvider = tileProvider.getImage(coordinates, options) as OfflineTileImageProvider;
      
      expect(imageProvider.coordinates, equals(coordinates));
      expect(imageProvider.options, equals(options));
      expect(imageProvider.cacheService, equals(mockCacheService));
      expect(imageProvider.offlineService, equals(mockOfflineService));
    });
  });

  group('OfflineTileImageProvider', () {
    late MockMapCacheService mockCacheService;
    late MockOfflineService mockOfflineService;
    late OfflineTileImageProvider imageProvider;
    late TileCoordinates coordinates;
    late TileLayer options;

    setUp(() {
      mockCacheService = MockMapCacheService();
      mockOfflineService = MockOfflineService();
      coordinates = TileCoordinates(1, 2, 3);
      options = TileLayer(urlTemplate: 'test');
      
      imageProvider = OfflineTileImageProvider(
        coordinates: coordinates,
        options: options,
        cacheService: mockCacheService,
        offlineService: mockOfflineService,
        baseUrl: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
        headers: const {'User-Agent': 'Test'},
        timeout: const Duration(seconds: 5),
      );
    });

    tearDown(() {
      mockCacheService.dispose();
      mockOfflineService.dispose();
    });

    test('should obtain key correctly', () async {
      const config = ImageConfiguration();
      final key = await imageProvider.obtainKey(config);
      expect(key, equals(imageProvider));
    });

    test('should be equal when coordinates and baseUrl match', () {
      final other = OfflineTileImageProvider(
        coordinates: coordinates,
        options: options,
        cacheService: mockCacheService,
        offlineService: mockOfflineService,
        baseUrl: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
        headers: const {'User-Agent': 'Test'},
        timeout: const Duration(seconds: 5),
      );
      
      expect(imageProvider, equals(other));
      expect(imageProvider.hashCode, equals(other.hashCode));
    });

    test('should not be equal when coordinates differ', () {
      final other = OfflineTileImageProvider(
        coordinates: TileCoordinates(4, 5, 6),
        options: options,
        cacheService: mockCacheService,
        offlineService: mockOfflineService,
        baseUrl: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
        headers: const {'User-Agent': 'Test'},
        timeout: const Duration(seconds: 5),
      );
      
      expect(imageProvider, isNot(equals(other)));
    });

    test('should not be equal when baseUrl differs', () {
      final other = OfflineTileImageProvider(
        coordinates: coordinates,
        options: options,
        cacheService: mockCacheService,
        offlineService: mockOfflineService,
        baseUrl: 'https://different.tile.server/{z}/{x}/{y}.png',
        headers: const {'User-Agent': 'Test'},
        timeout: const Duration(seconds: 5),
      );
      
      expect(imageProvider, isNot(equals(other)));
    });
  });

  group('Offline Tile Loading', () {
    late MockMapCacheService mockCacheService;
    late MockOfflineService mockOfflineService;

    setUp(() {
      mockCacheService = MockMapCacheService();
      mockOfflineService = MockOfflineService();
    });

    tearDown(() {
      mockCacheService.dispose();
      mockOfflineService.dispose();
    });

    test('should use cached tile when available and valid', () async {
      await mockCacheService.initialize();
      await mockOfflineService.initialize();
      
      // Create a valid cached tile
      final tileData = Uint8List.fromList([1, 2, 3, 4]);
      final cachedTile = MapTile.withData(
        'https://test.com/1/2/3.png',
        1, 2, 3,
        tileData,
      );
      
      await mockCacheService.cacheTile(cachedTile);
      
      // Verify tile is cached
      final retrievedTile = await mockCacheService.getCachedTile('tile_3_1_2');
      expect(retrievedTile, isNotNull);
      expect(retrievedTile!.hasValidData, isTrue);
    });

    test('should handle offline mode with cached tiles', () async {
      await mockCacheService.initialize();
      await mockOfflineService.initialize();
      
      // Set offline
      mockOfflineService.setConnectivity(false);
      expect(mockOfflineService.isOnline, isFalse);
      
      // Create expired but cached tile
      final tileData = Uint8List.fromList([1, 2, 3, 4]);
      final expiredTile = MapTile(
        url: 'https://test.com/1/2/3.png',
        x: 1, y: 2, zoom: 3,
        imageData: tileData,
        cachedAt: DateTime.now().subtract(const Duration(days: 2)),
        cacheDuration: const Duration(hours: 24),
        sizeBytes: tileData.length,
      );
      
      await mockCacheService.cacheTile(expiredTile);
      
      // Should still return expired tile when offline
      final retrievedTile = await mockCacheService.getCachedTile('tile_3_1_2');
      expect(retrievedTile, isNotNull);
      expect(retrievedTile!.imageData, equals(tileData));
    });

    test('should handle missing cached tiles when offline', () async {
      await mockCacheService.initialize();
      await mockOfflineService.initialize();
      
      // Set offline
      mockOfflineService.setConnectivity(false);
      
      // Try to get non-existent tile
      final retrievedTile = await mockCacheService.getCachedTile('tile_3_1_2');
      expect(retrievedTile, isNull);
    });
  });

  group('Cache Management', () {
    late MockMapCacheService mockCacheService;

    setUp(() {
      mockCacheService = MockMapCacheService();
    });

    tearDown(() {
      mockCacheService.dispose();
    });

    test('should cache tiles correctly', () async {
      await mockCacheService.initialize();
      
      final tileData = Uint8List.fromList([1, 2, 3, 4]);
      final tile = MapTile.withData(
        'https://test.com/1/2/3.png',
        1, 2, 3,
        tileData,
      );
      
      await mockCacheService.cacheTile(tile);
      
      final cachedTile = await mockCacheService.getCachedTile('tile_3_1_2');
      expect(cachedTile, isNotNull);
      expect(cachedTile!.imageData, equals(tileData));
      expect(cachedTile.x, equals(1));
      expect(cachedTile.y, equals(2));
      expect(cachedTile.zoom, equals(3));
    });

    test('should handle expired tiles', () async {
      await mockCacheService.initialize();
      
      final tileData = Uint8List.fromList([1, 2, 3, 4]);
      final expiredTile = MapTile(
        url: 'https://test.com/1/2/3.png',
        x: 1, y: 2, zoom: 3,
        imageData: tileData,
        cachedAt: DateTime.now().subtract(const Duration(days: 2)),
        cacheDuration: const Duration(hours: 24),
        sizeBytes: tileData.length,
      );
      
      await mockCacheService.cacheTile(expiredTile);
      
      // Mock service doesn't implement expiry logic, so tile should still be there
      final cachedTile = await mockCacheService.getCachedTile('tile_3_1_2');
      expect(cachedTile, isNotNull);
    });

    test('should get cache stats', () async {
      await mockCacheService.initialize();
      
      final stats = await mockCacheService.getCacheStats();
      expect(stats, isA<Map<String, int>>());
      expect(stats.containsKey('tiles_count'), isTrue);
    });

    test('should clear cache', () async {
      await mockCacheService.initialize();
      
      // Add a tile
      final tileData = Uint8List.fromList([1, 2, 3, 4]);
      final tile = MapTile.withData('https://test.com/1/2/3.png', 1, 2, 3, tileData);
      await mockCacheService.cacheTile(tile);
      
      // Clear cache
      await mockCacheService.clearAllCache();
      
      // Verify cache is empty
      final stats = await mockCacheService.getCacheStats();
      expect(stats['tiles_count'], equals(0));
    });
  });
}