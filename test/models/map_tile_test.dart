import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:ridelink/models/map_tile.dart';

void main() {
  group('MapTile', () {
    late MapTile mapTile;
    late Uint8List testImageData;

    setUp(() {
      testImageData = Uint8List.fromList([1, 2, 3, 4, 5]);
      mapTile = MapTile(
        url: 'https://tile.openstreetmap.org/1/2/3.png',
        x: 2,
        y: 3,
        zoom: 1,
        imageData: testImageData,
        cachedAt: DateTime.now(),
        cacheDuration: const Duration(hours: 24),
        sizeBytes: testImageData.length,
      );
    });

    test('should create MapTile with correct properties', () {
      expect(mapTile.url, equals('https://tile.openstreetmap.org/1/2/3.png'));
      expect(mapTile.x, equals(2));
      expect(mapTile.y, equals(3));
      expect(mapTile.zoom, equals(1));
      expect(mapTile.imageData, equals(testImageData));
      expect(mapTile.sizeBytes, equals(5));
    });

    test('should generate correct tile key', () {
      expect(mapTile.key, equals('tile_1_2_3'));
    });

    test('should not be expired when recently cached', () {
      expect(mapTile.isExpired, isFalse);
    });

    test('should be expired when cache duration exceeded', () {
      final expiredTile = MapTile(
        url: 'test.png',
        x: 1,
        y: 1,
        zoom: 1,
        cachedAt: DateTime.now().subtract(const Duration(hours: 25)),
        cacheDuration: const Duration(hours: 24),
        sizeBytes: 0,
      );
      expect(expiredTile.isExpired, isTrue);
    });

    test('should have valid data when not expired and has image data', () {
      expect(mapTile.hasValidData, isTrue);
    });

    test('should not have valid data when expired', () {
      final expiredTile = MapTile(
        url: 'test.png',
        x: 1,
        y: 1,
        zoom: 1,
        imageData: testImageData,
        cachedAt: DateTime.now().subtract(const Duration(hours: 25)),
        cacheDuration: const Duration(hours: 24),
        sizeBytes: testImageData.length,
      );
      expect(expiredTile.hasValidData, isFalse);
    });

    test('should not have valid data when no image data', () {
      final noDataTile = MapTile(
        url: 'test.png',
        x: 1,
        y: 1,
        zoom: 1,
        cachedAt: DateTime.now(),
        cacheDuration: const Duration(hours: 24),
        sizeBytes: 0,
      );
      expect(noDataTile.hasValidData, isFalse);
    });

    test('should create from URL correctly', () {
      const baseUrl = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
      final tile = MapTile.fromUrl(baseUrl, 5, 10, 15);
      
      expect(tile.url, equals('https://tile.openstreetmap.org/15/5/10.png'));
      expect(tile.x, equals(5));
      expect(tile.y, equals(10));
      expect(tile.zoom, equals(15));
      expect(tile.imageData, isNull);
    });

    test('should create with data correctly', () {
      const url = 'https://example.com/tile.png';
      final tile = MapTile.withData(url, 1, 2, 3, testImageData);
      
      expect(tile.url, equals(url));
      expect(tile.x, equals(1));
      expect(tile.y, equals(2));
      expect(tile.zoom, equals(3));
      expect(tile.imageData, equals(testImageData));
      expect(tile.sizeBytes, equals(testImageData.length));
    });

    test('should copy with new values', () {
      final newImageData = Uint8List.fromList([6, 7, 8]);
      final copiedTile = mapTile.copyWith(
        x: 10,
        imageData: newImageData,
        sizeBytes: newImageData.length,
      );
      
      expect(copiedTile.x, equals(10));
      expect(copiedTile.y, equals(mapTile.y)); // unchanged
      expect(copiedTile.imageData, equals(newImageData));
      expect(copiedTile.sizeBytes, equals(3));
    });

    test('should serialize to JSON correctly', () {
      final json = mapTile.toJson();
      
      expect(json['url'], equals(mapTile.url));
      expect(json['x'], equals(mapTile.x));
      expect(json['y'], equals(mapTile.y));
      expect(json['zoom'], equals(mapTile.zoom));
      expect(json['sizeBytes'], equals(mapTile.sizeBytes));
      expect(json['hasImageData'], isTrue);
    });

    test('should deserialize from JSON correctly', () {
      final json = {
        'url': 'https://example.com/tile.png',
        'x': 5,
        'y': 10,
        'zoom': 15,
        'cachedAt': DateTime.now().toIso8601String(),
        'cacheDuration': const Duration(hours: 12).inMilliseconds,
        'sizeBytes': 1024,
      };
      
      final tile = MapTile.fromJson(json);
      
      expect(tile.url, equals(json['url']));
      expect(tile.x, equals(json['x']));
      expect(tile.y, equals(json['y']));
      expect(tile.zoom, equals(json['zoom']));
      expect(tile.sizeBytes, equals(json['sizeBytes']));
    });

    test('should have correct equality', () {
      final tile1 = MapTile.fromUrl('https://example.com/{z}/{x}/{y}.png', 1, 2, 3);
      final tile2 = MapTile.fromUrl('https://example.com/{z}/{x}/{y}.png', 1, 2, 3);
      final tile3 = MapTile.fromUrl('https://example.com/{z}/{x}/{y}.png', 1, 2, 4);
      
      expect(tile1, equals(tile2));
      expect(tile1, isNot(equals(tile3)));
    });

    test('should have correct hash code', () {
      final tile1 = MapTile.fromUrl('https://example.com/{z}/{x}/{y}.png', 1, 2, 3);
      final tile2 = MapTile.fromUrl('https://example.com/{z}/{x}/{y}.png', 1, 2, 3);
      
      expect(tile1.hashCode, equals(tile2.hashCode));
    });
  });
}