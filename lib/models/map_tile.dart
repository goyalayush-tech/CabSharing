import 'dart:typed_data';
import 'package:hive/hive.dart';

part 'map_tile.g.dart';

@HiveType(typeId: 0)
class MapTile extends HiveObject {
  @HiveField(0)
  final String url;

  @HiveField(1)
  final int x;

  @HiveField(2)
  final int y;

  @HiveField(3)
  final int zoom;

  @HiveField(4)
  final Uint8List? imageData;

  @HiveField(5)
  final DateTime cachedAt;

  @HiveField(6)
  final Duration cacheDuration;

  @HiveField(7)
  final int sizeBytes;

  MapTile({
    required this.url,
    required this.x,
    required this.y,
    required this.zoom,
    this.imageData,
    required this.cachedAt,
    required this.cacheDuration,
    required this.sizeBytes,
  });

  /// Creates a unique key for this tile
  String get key => 'tile_${zoom}_${x}_$y';

  /// Checks if this tile is expired based on cache duration
  bool get isExpired {
    return DateTime.now().difference(cachedAt) > cacheDuration;
  }

  /// Checks if this tile has valid image data
  bool get hasValidData {
    return imageData != null && imageData!.isNotEmpty && !isExpired;
  }

  /// Gets the expiry date for this tile
  DateTime get expiresAt {
    return cachedAt.add(cacheDuration);
  }

  /// Creates a copy of this tile with updated data
  MapTile copyWith({
    String? url,
    int? x,
    int? y,
    int? zoom,
    Uint8List? imageData,
    DateTime? cachedAt,
    Duration? cacheDuration,
    int? sizeBytes,
  }) {
    return MapTile(
      url: url ?? this.url,
      x: x ?? this.x,
      y: y ?? this.y,
      zoom: zoom ?? this.zoom,
      imageData: imageData ?? this.imageData,
      cachedAt: cachedAt ?? this.cachedAt,
      cacheDuration: cacheDuration ?? this.cacheDuration,
      sizeBytes: sizeBytes ?? this.sizeBytes,
    );
  }

  /// Creates a MapTile from URL components
  factory MapTile.fromUrl(String baseUrl, int x, int y, int zoom, {
    Duration cacheDuration = const Duration(hours: 24),
  }) {
    final url = baseUrl
        .replaceAll('{x}', x.toString())
        .replaceAll('{y}', y.toString())
        .replaceAll('{z}', zoom.toString());
    
    return MapTile(
      url: url,
      x: x,
      y: y,
      zoom: zoom,
      cachedAt: DateTime.now(),
      cacheDuration: cacheDuration,
      sizeBytes: 0,
    );
  }

  /// Creates a MapTile with image data
  factory MapTile.withData(
    String url,
    int x,
    int y,
    int zoom,
    Uint8List imageData, {
    Duration cacheDuration = const Duration(hours: 24),
  }) {
    return MapTile(
      url: url,
      x: x,
      y: y,
      zoom: zoom,
      imageData: imageData,
      cachedAt: DateTime.now(),
      cacheDuration: cacheDuration,
      sizeBytes: imageData.length,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'url': url,
      'x': x,
      'y': y,
      'zoom': zoom,
      'cachedAt': cachedAt.toIso8601String(),
      'cacheDuration': cacheDuration.inMilliseconds,
      'sizeBytes': sizeBytes,
      'hasImageData': imageData != null,
    };
  }

  factory MapTile.fromJson(Map<String, dynamic> json) {
    return MapTile(
      url: json['url'] as String,
      x: json['x'] as int,
      y: json['y'] as int,
      zoom: json['zoom'] as int,
      cachedAt: DateTime.parse(json['cachedAt'] as String),
      cacheDuration: Duration(milliseconds: json['cacheDuration'] as int),
      sizeBytes: json['sizeBytes'] as int,
      // Note: imageData is not included in JSON serialization due to size
    );
  }

  @override
  String toString() {
    return 'MapTile(key: $key, url: $url, cached: $cachedAt, '
           'size: ${sizeBytes}B, expired: $isExpired)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MapTile &&
        other.x == x &&
        other.y == y &&
        other.zoom == zoom &&
        other.url == url;
  }

  @override
  int get hashCode {
    return Object.hash(x, y, zoom, url);
  }
}