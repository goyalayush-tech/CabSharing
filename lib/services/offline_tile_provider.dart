import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import '../models/map_tile.dart';
import 'map_cache_service.dart';
import 'offline_service.dart';

/// Offline-aware tile provider that uses cached tiles when offline
class OfflineTileProvider extends TileProvider {
  final IMapCacheService cacheService;
  final IOfflineService offlineService;
  final String baseUrl;
  final Map<String, String> headers;
  final Duration timeout;

  OfflineTileProvider({
    required this.cacheService,
    required this.offlineService,
    required this.baseUrl,
    this.headers = const {'User-Agent': 'RideLink/1.0.0 (Flutter App)'},
    this.timeout = const Duration(seconds: 10),
  });

  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) {
    return OfflineTileImageProvider(
      coordinates: coordinates,
      options: options,
      cacheService: cacheService,
      offlineService: offlineService,
      baseUrl: baseUrl,
      headers: headers,
      timeout: timeout,
    );
  }
}

/// Image provider that handles offline tile loading
class OfflineTileImageProvider extends ImageProvider<OfflineTileImageProvider> {
  final TileCoordinates coordinates;
  final TileLayer options;
  final IMapCacheService cacheService;
  final IOfflineService offlineService;
  final String baseUrl;
  final Map<String, String> headers;
  final Duration timeout;

  const OfflineTileImageProvider({
    required this.coordinates,
    required this.options,
    required this.cacheService,
    required this.offlineService,
    required this.baseUrl,
    required this.headers,
    required this.timeout,
  });

  @override
  Future<OfflineTileImageProvider> obtainKey(ImageConfiguration configuration) {
    return SynchronousFuture<OfflineTileImageProvider>(this);
  }

  @override
  ImageStreamCompleter loadImage(OfflineTileImageProvider key, ImageDecoderCallback decode) {
    return MultiFrameImageStreamCompleter(
      codec: _loadTile(key, decode),
      scale: 1.0,
      debugLabel: 'OfflineTile(${coordinates.x}, ${coordinates.y}, ${coordinates.z})',
    );
  }

  Future<ui.Codec> _loadTile(OfflineTileImageProvider key, ImageDecoderCallback decode) async {
    try {
      final tileKey = 'tile_${coordinates.z}_${coordinates.x}_${coordinates.y}';
      
      // First, try to get from cache
      final cachedTile = await cacheService.getCachedTile(tileKey);
      if (cachedTile != null && cachedTile.hasValidData) {
        return await decode(await ui.ImmutableBuffer.fromUint8List(cachedTile.imageData!));
      }
      
      // If offline, use cached tile even if expired, or show placeholder
      if (!offlineService.isOnline) {
        if (cachedTile?.imageData != null) {
          // Use expired cached tile
          return await decode(await ui.ImmutableBuffer.fromUint8List(cachedTile!.imageData!));
        } else {
          // Return offline placeholder
          return await decode(await ui.ImmutableBuffer.fromUint8List(_createOfflinePlaceholder()));
        }
      }
      
      // Online: fetch from network
      final url = _buildTileUrl();
      final response = await http.get(Uri.parse(url), headers: headers)
          .timeout(timeout);
      
      if (response.statusCode == 200) {
        final imageData = response.bodyBytes;
        
        // Cache the tile
        final tile = MapTile.withData(
          url,
          coordinates.x,
          coordinates.y,
          coordinates.z,
          imageData,
        );
        
        // Cache asynchronously to avoid blocking UI
        cacheService.cacheTile(tile).catchError((error) {
          debugPrint('Failed to cache tile: $error');
        });
        
        return await decode(await ui.ImmutableBuffer.fromUint8List(imageData));
      } else {
        throw Exception('Failed to load tile: HTTP ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error loading tile: $e');
      
      // On error, try cached tile one more time
      final tileKey = 'tile_${coordinates.z}_${coordinates.x}_${coordinates.y}';
      final cachedTile = await cacheService.getCachedTile(tileKey);
      if (cachedTile?.imageData != null) {
        return await decode(await ui.ImmutableBuffer.fromUint8List(cachedTile!.imageData!));
      }
      
      // Return error placeholder
      return await decode(await ui.ImmutableBuffer.fromUint8List(_createErrorPlaceholder()));
    }
  }

  String _buildTileUrl() {
    return baseUrl
        .replaceAll('{x}', coordinates.x.toString())
        .replaceAll('{y}', coordinates.y.toString())
        .replaceAll('{z}', coordinates.z.toString());
  }

  /// Create a simple offline placeholder tile
  Uint8List _createOfflinePlaceholder() {
    // Simple 256x256 gray tile with "OFFLINE" text
    // This is a minimal PNG representation
    return Uint8List.fromList([
      0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, // PNG signature
      0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52, // IHDR chunk
      0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, 0x00, // 256x256
      0x08, 0x02, 0x00, 0x00, 0x00, 0x90, 0x91, 0x68, // RGB, no compression
      0x36, 0x00, 0x00, 0x00, 0x0C, 0x49, 0x44, 0x41, // IDAT chunk start
      0x54, 0x08, 0x1D, 0x01, 0x02, 0x00, 0xFD, 0xFF, // Minimal data
      0x00, 0x00, 0x00, 0x02, 0x00, 0x01, 0xE2, 0x21, // Gray color
      0xBC, 0x33, 0x00, 0x00, 0x00, 0x00, 0x49, 0x45, // IEND
      0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82
    ]);
  }

  /// Create a simple error placeholder tile
  Uint8List _createErrorPlaceholder() {
    // Simple 256x256 red tile for errors
    return Uint8List.fromList([
      0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, // PNG signature
      0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52, // IHDR chunk
      0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, 0x00, // 256x256
      0x08, 0x02, 0x00, 0x00, 0x00, 0x90, 0x91, 0x68, // RGB, no compression
      0x36, 0x00, 0x00, 0x00, 0x0C, 0x49, 0x44, 0x41, // IDAT chunk start
      0x54, 0x08, 0x1D, 0x01, 0x02, 0x00, 0xFD, 0xFF, // Minimal data
      0xFF, 0x00, 0x00, 0x02, 0x00, 0x01, 0xE2, 0x21, // Red color
      0xBC, 0x33, 0x00, 0x00, 0x00, 0x00, 0x49, 0x45, // IEND
      0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82
    ]);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is OfflineTileImageProvider &&
        other.coordinates == coordinates &&
        other.baseUrl == baseUrl;
  }

  @override
  int get hashCode => Object.hash(coordinates, baseUrl);
}