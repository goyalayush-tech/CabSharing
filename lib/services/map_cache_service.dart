import 'dart:convert';
import 'dart:typed_data';
import 'package:hive/hive.dart';
import '../models/map_tile.dart';
import '../models/place_models.dart';
import '../models/ride_group.dart';

abstract class IMapCacheService {
  Future<void> initialize();
  Future<void> dispose();
  
  // Tile caching
  Future<void> cacheTile(MapTile tile);
  Future<MapTile?> getCachedTile(String tileKey);
  Future<void> clearExpiredTiles();
  Future<int> getTileCacheSize();
  Future<void> clearTileCache();
  
  // Geocoding result caching
  Future<void> cacheGeocodingResult(String query, List<PlaceSearchResult> results);
  Future<List<PlaceSearchResult>?> getCachedGeocodingResult(String query);
  Future<void> clearExpiredGeocodingResults();
  
  // Route caching
  Future<void> cacheRoute(String routeKey, RouteInfo route);
  Future<RouteInfo?> getCachedRoute(String routeKey);
  Future<void> clearExpiredRoutes();
  
  // Cache management
  Future<void> clearExpiredCache();
  Future<Map<String, int>> getCacheStats();
  Future<void> clearAllCache();
}

class HiveMapCacheService implements IMapCacheService {
  static const String _tilesBoxName = 'map_tiles';
  static const String _geocodingBoxName = 'geocoding_results';
  static const String _routesBoxName = 'route_cache';
  static const String _metadataBoxName = 'cache_metadata';
  
  Box<MapTile>? _tilesBox;
  Box<String>? _geocodingBox;
  Box<String>? _routesBox;
  Box<String>? _metadataBox;
  
  final Map<String, PlaceSearchResult> _memoryGeocodingCache = {};
  final Map<String, RouteInfo> _memoryRouteCache = {};
  final int _maxMemoryCacheSize = 100;

  @override
  Future<void> initialize() async {
    try {
      _tilesBox = await Hive.openBox<MapTile>(_tilesBoxName);
      _geocodingBox = await Hive.openBox<String>(_geocodingBoxName);
      _routesBox = await Hive.openBox<String>(_routesBoxName);
      _metadataBox = await Hive.openBox<String>(_metadataBoxName);
      
      // Clean up expired cache on startup
      await clearExpiredCache();
    } catch (e) {
      throw Exception('Failed to initialize cache service: $e');
    }
  }

  @override
  Future<void> dispose() async {
    await _tilesBox?.close();
    await _geocodingBox?.close();
    await _routesBox?.close();
    await _metadataBox?.close();
    
    _memoryGeocodingCache.clear();
    _memoryRouteCache.clear();
  }

  @override
  Future<void> cacheTile(MapTile tile) async {
    if (_tilesBox == null) throw StateError('Cache service not initialized');
    
    try {
      await _tilesBox!.put(tile.key, tile);
      
      // Update metadata
      await _updateCacheMetadata('tiles_count', (_tilesBox!.length).toString());
      await _updateCacheMetadata('tiles_last_updated', DateTime.now().toIso8601String());
    } catch (e) {
      throw Exception('Failed to cache tile: $e');
    }
  }

  @override
  Future<MapTile?> getCachedTile(String tileKey) async {
    if (_tilesBox == null) throw StateError('Cache service not initialized');
    
    try {
      final tile = _tilesBox!.get(tileKey);
      
      if (tile != null && tile.isExpired) {
        // Remove expired tile
        await _tilesBox!.delete(tileKey);
        return null;
      }
      
      return tile;
    } catch (e) {
      return null; // Return null on error rather than throwing
    }
  }

  @override
  Future<void> clearExpiredTiles() async {
    if (_tilesBox == null) return;
    
    try {
      final expiredKeys = <String>[];
      
      for (final key in _tilesBox!.keys) {
        final tile = _tilesBox!.get(key);
        if (tile != null && tile.isExpired) {
          expiredKeys.add(key);
        }
      }
      
      await _tilesBox!.deleteAll(expiredKeys);
      
      if (expiredKeys.isNotEmpty) {
        await _updateCacheMetadata('tiles_count', (_tilesBox!.length).toString());
        await _updateCacheMetadata('tiles_last_cleanup', DateTime.now().toIso8601String());
      }
    } catch (e) {
      // Log error but don't throw - cleanup should be non-critical
    }
  }

  @override
  Future<int> getTileCacheSize() async {
    if (_tilesBox == null) return 0;
    
    try {
      int totalSize = 0;
      for (final tile in _tilesBox!.values) {
        totalSize += tile.sizeBytes;
      }
      return totalSize;
    } catch (e) {
      return 0;
    }
  }

  @override
  Future<void> clearTileCache() async {
    if (_tilesBox == null) return;
    
    try {
      await _tilesBox!.clear();
      await _updateCacheMetadata('tiles_count', '0');
      await _updateCacheMetadata('tiles_cleared_at', DateTime.now().toIso8601String());
    } catch (e) {
      throw Exception('Failed to clear tile cache: $e');
    }
  }

  @override
  Future<void> cacheGeocodingResult(String query, List<PlaceSearchResult> results) async {
    if (_geocodingBox == null) throw StateError('Cache service not initialized');
    
    try {
      final cacheKey = _generateGeocodingKey(query);
      final cacheData = {
        'query': query,
        'results': results.map((r) => r.toJson()).toList(),
        'cachedAt': DateTime.now().toIso8601String(),
        'expiresAt': DateTime.now().add(const Duration(hours: 24)).toIso8601String(),
      };
      
      await _geocodingBox!.put(cacheKey, json.encode(cacheData));
      
      // Also cache in memory for faster access
      if (_memoryGeocodingCache.length >= _maxMemoryCacheSize) {
        _memoryGeocodingCache.remove(_memoryGeocodingCache.keys.first);
      }
      
      for (final result in results) {
        _memoryGeocodingCache[cacheKey] = result;
      }
      
      await _updateCacheMetadata('geocoding_count', (_geocodingBox!.length).toString());
    } catch (e) {
      throw Exception('Failed to cache geocoding result: $e');
    }
  }

  @override
  Future<List<PlaceSearchResult>?> getCachedGeocodingResult(String query) async {
    if (_geocodingBox == null) throw StateError('Cache service not initialized');
    
    try {
      final cacheKey = _generateGeocodingKey(query);
      
      // Check memory cache first
      if (_memoryGeocodingCache.containsKey(cacheKey)) {
        return [_memoryGeocodingCache[cacheKey]!];
      }
      
      // Check disk cache
      final cachedData = _geocodingBox!.get(cacheKey);
      if (cachedData == null) return null;
      
      final data = json.decode(cachedData) as Map<String, dynamic>;
      final expiresAt = DateTime.parse(data['expiresAt'] as String);
      
      if (DateTime.now().isAfter(expiresAt)) {
        // Expired - remove from cache
        await _geocodingBox!.delete(cacheKey);
        return null;
      }
      
      final resultsJson = data['results'] as List;
      final results = resultsJson
          .map((r) => PlaceSearchResult.fromJson(r as Map<String, dynamic>))
          .toList();
      
      // Update memory cache
      if (results.isNotEmpty && _memoryGeocodingCache.length < _maxMemoryCacheSize) {
        _memoryGeocodingCache[cacheKey] = results.first;
      }
      
      return results;
    } catch (e) {
      return null; // Return null on error
    }
  }

  @override
  Future<void> clearExpiredGeocodingResults() async {
    if (_geocodingBox == null) return;
    
    try {
      final expiredKeys = <String>[];
      final now = DateTime.now();
      
      for (final key in _geocodingBox!.keys) {
        final cachedData = _geocodingBox!.get(key);
        if (cachedData != null) {
          try {
            final data = json.decode(cachedData) as Map<String, dynamic>;
            final expiresAt = DateTime.parse(data['expiresAt'] as String);
            
            if (now.isAfter(expiresAt)) {
              expiredKeys.add(key);
            }
          } catch (e) {
            // Invalid data - mark for deletion
            expiredKeys.add(key);
          }
        }
      }
      
      await _geocodingBox!.deleteAll(expiredKeys);
      
      // Clear expired items from memory cache
      _memoryGeocodingCache.removeWhere((key, value) => expiredKeys.contains(key));
      
      if (expiredKeys.isNotEmpty) {
        await _updateCacheMetadata('geocoding_count', (_geocodingBox!.length).toString());
        await _updateCacheMetadata('geocoding_last_cleanup', DateTime.now().toIso8601String());
      }
    } catch (e) {
      // Log error but don't throw
    }
  }

  @override
  Future<void> cacheRoute(String routeKey, RouteInfo route) async {
    if (_routesBox == null) throw StateError('Cache service not initialized');
    
    try {
      final cacheData = {
        'route': route.toJson(),
        'cachedAt': DateTime.now().toIso8601String(),
        'expiresAt': DateTime.now().add(const Duration(hours: 6)).toIso8601String(),
      };
      
      await _routesBox!.put(routeKey, json.encode(cacheData));
      
      // Cache in memory
      if (_memoryRouteCache.length >= _maxMemoryCacheSize) {
        _memoryRouteCache.remove(_memoryRouteCache.keys.first);
      }
      _memoryRouteCache[routeKey] = route;
      
      await _updateCacheMetadata('routes_count', (_routesBox!.length).toString());
    } catch (e) {
      throw Exception('Failed to cache route: $e');
    }
  }

  @override
  Future<RouteInfo?> getCachedRoute(String routeKey) async {
    if (_routesBox == null) throw StateError('Cache service not initialized');
    
    try {
      // Check memory cache first
      if (_memoryRouteCache.containsKey(routeKey)) {
        return _memoryRouteCache[routeKey];
      }
      
      // Check disk cache
      final cachedData = _routesBox!.get(routeKey);
      if (cachedData == null) return null;
      
      final data = json.decode(cachedData) as Map<String, dynamic>;
      final expiresAt = DateTime.parse(data['expiresAt'] as String);
      
      if (DateTime.now().isAfter(expiresAt)) {
        await _routesBox!.delete(routeKey);
        return null;
      }
      
      final route = RouteInfo.fromJson(data['route'] as Map<String, dynamic>);
      
      // Update memory cache
      if (_memoryRouteCache.length < _maxMemoryCacheSize) {
        _memoryRouteCache[routeKey] = route;
      }
      
      return route;
    } catch (e) {
      return null;
    }
  }

  @override
  Future<void> clearExpiredRoutes() async {
    if (_routesBox == null) return;
    
    try {
      final expiredKeys = <String>[];
      final now = DateTime.now();
      
      for (final key in _routesBox!.keys) {
        final cachedData = _routesBox!.get(key);
        if (cachedData != null) {
          try {
            final data = json.decode(cachedData) as Map<String, dynamic>;
            final expiresAt = DateTime.parse(data['expiresAt'] as String);
            
            if (now.isAfter(expiresAt)) {
              expiredKeys.add(key);
            }
          } catch (e) {
            expiredKeys.add(key);
          }
        }
      }
      
      await _routesBox!.deleteAll(expiredKeys);
      _memoryRouteCache.removeWhere((key, value) => expiredKeys.contains(key));
      
      if (expiredKeys.isNotEmpty) {
        await _updateCacheMetadata('routes_count', (_routesBox!.length).toString());
        await _updateCacheMetadata('routes_last_cleanup', DateTime.now().toIso8601String());
      }
    } catch (e) {
      // Log error but don't throw
    }
  }

  @override
  Future<void> clearExpiredCache() async {
    await Future.wait([
      clearExpiredTiles(),
      clearExpiredGeocodingResults(),
      clearExpiredRoutes(),
    ]);
  }

  @override
  Future<Map<String, int>> getCacheStats() async {
    try {
      final stats = <String, int>{};
      
      stats['tiles_count'] = _tilesBox?.length ?? 0;
      stats['geocoding_count'] = _geocodingBox?.length ?? 0;
      stats['routes_count'] = _routesBox?.length ?? 0;
      stats['memory_geocoding_count'] = _memoryGeocodingCache.length;
      stats['memory_routes_count'] = _memoryRouteCache.length;
      stats['tiles_size_bytes'] = await getTileCacheSize();
      
      return stats;
    } catch (e) {
      return {};
    }
  }

  @override
  Future<void> clearAllCache() async {
    try {
      await Future.wait([
        _tilesBox?.clear() ?? Future.value(),
        _geocodingBox?.clear() ?? Future.value(),
        _routesBox?.clear() ?? Future.value(),
      ]);
      
      _memoryGeocodingCache.clear();
      _memoryRouteCache.clear();
      
      await _updateCacheMetadata('all_cleared_at', DateTime.now().toIso8601String());
    } catch (e) {
      throw Exception('Failed to clear all cache: $e');
    }
  }

  String _generateGeocodingKey(String query) {
    return 'geocode_${query.toLowerCase().replaceAll(RegExp(r'\s+'), '_').hashCode}';
  }

  Future<void> _updateCacheMetadata(String key, String value) async {
    try {
      await _metadataBox?.put(key, value);
    } catch (e) {
      // Ignore metadata update errors
    }
  }
}

// Mock implementation for testing
class MockMapCacheService implements IMapCacheService {
  final Map<String, MapTile> _tiles = {};
  final Map<String, List<PlaceSearchResult>> _geocoding = {};
  final Map<String, RouteInfo> _routes = {};
  bool _initialized = false;

  @override
  Future<void> initialize() async {
    await Future.delayed(const Duration(milliseconds: 10));
    _initialized = true;
  }

  @override
  Future<void> dispose() async {
    _tiles.clear();
    _geocoding.clear();
    _routes.clear();
    _initialized = false;
  }

  @override
  Future<void> cacheTile(MapTile tile) async {
    if (!_initialized) throw StateError('Cache service not initialized');
    _tiles[tile.key] = tile;
  }

  @override
  Future<MapTile?> getCachedTile(String tileKey) async {
    if (!_initialized) throw StateError('Cache service not initialized');
    final tile = _tiles[tileKey];
    return tile?.isExpired == true ? null : tile;
  }

  @override
  Future<void> clearExpiredTiles() async {
    _tiles.removeWhere((key, tile) => tile.isExpired);
  }

  @override
  Future<int> getTileCacheSize() async {
    return _tiles.values.fold<int>(0, (sum, tile) => sum + tile.sizeBytes);
  }

  @override
  Future<void> clearTileCache() async {
    _tiles.clear();
  }

  @override
  Future<void> cacheGeocodingResult(String query, List<PlaceSearchResult> results) async {
    if (!_initialized) throw StateError('Cache service not initialized');
    _geocoding[query] = results;
  }

  @override
  Future<List<PlaceSearchResult>?> getCachedGeocodingResult(String query) async {
    if (!_initialized) throw StateError('Cache service not initialized');
    return _geocoding[query];
  }

  @override
  Future<void> clearExpiredGeocodingResults() async {
    // Mock implementation - no expiry logic
  }

  @override
  Future<void> cacheRoute(String routeKey, RouteInfo route) async {
    if (!_initialized) throw StateError('Cache service not initialized');
    _routes[routeKey] = route;
  }

  @override
  Future<RouteInfo?> getCachedRoute(String routeKey) async {
    if (!_initialized) throw StateError('Cache service not initialized');
    return _routes[routeKey];
  }

  @override
  Future<void> clearExpiredRoutes() async {
    // Mock implementation - no expiry logic
  }

  @override
  Future<void> clearExpiredCache() async {
    await clearExpiredTiles();
    await clearExpiredGeocodingResults();
    await clearExpiredRoutes();
  }

  @override
  Future<Map<String, int>> getCacheStats() async {
    return {
      'tiles_count': _tiles.length,
      'geocoding_count': _geocoding.length,
      'routes_count': _routes.length,
      'tiles_size_bytes': await getTileCacheSize(),
    };
  }

  @override
  Future<void> clearAllCache() async {
    _tiles.clear();
    _geocoding.clear();
    _routes.clear();
  }
}