import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/ride_group.dart';
import '../models/place_models.dart';
import '../core/config/free_map_config.dart';
import '../services/map_cache_service.dart';
import '../services/map_analytics_service.dart';
import '../services/service_health_monitor.dart';

abstract class IFreeGeocodingService {
  Future<List<PlaceSearchResult>> searchPlaces(String query, {LatLng? location, double? radius});
  Future<PlaceSearchResult?> reverseGeocode(LatLng coordinates);
  Future<List<PlaceSearchResult>> getNearbyPlaces(LatLng location, {double radius = 5000, String? type});
  Future<bool> isServiceAvailable();
}

class NominatimGeocodingService implements IFreeGeocodingService {
  final FreeMapConfig config;
  final IMapCacheService cacheService;
  final http.Client httpClient;
  final MapAnalyticsService _analytics;
  final ServiceHealthMonitor _healthMonitor;
  
  // Rate limiting
  DateTime? _lastRequestTime;
  final Queue<Completer<void>> _requestQueue = Queue<Completer<void>>();
  bool _processingQueue = false;

  NominatimGeocodingService({
    required this.config,
    required this.cacheService,
    http.Client? httpClient,
    MapAnalyticsService? analytics,
    ServiceHealthMonitor? healthMonitor,
  }) : httpClient = httpClient ?? http.Client(),
       _analytics = analytics ?? MapAnalyticsService(),
       _healthMonitor = healthMonitor ?? ServiceHealthMonitor();

  @override
  Future<List<PlaceSearchResult>> searchPlaces(
    String query, {
    LatLng? location,
    double? radius,
  }) async {
    if (query.trim().isEmpty) return [];

    return await _analytics.trackApiCall(
      'nominatim',
      'searchPlaces',
      () async {
        try {
          // Check cache first
          final cachedResults = await cacheService.getCachedGeocodingResult(query);
          if (cachedResults != null) {
            _analytics.trackCacheHit('nominatim');
            return cachedResults;
          }
          
          _analytics.trackCacheMiss('nominatim');

          // Check rate limits
          if (!_analytics.canMakeRequest('nominatim')) {
            throw Exception('Rate limit exceeded. Please try again later.');
          }

          // Wait for rate limit
          await _waitForRateLimit();
          
          // Record request for rate limiting
          _analytics.recordRequest('nominatim');

          // Build search URL
          final uri = _buildSearchUri(query, location: location, radius: radius);
          
          // Make request
          final response = await httpClient.get(uri).timeout(config.requestTimeout);
          
          if (response.statusCode == 200) {
            final data = json.decode(response.body) as List;
            final results = data
                .map((item) => _parseNominatimResult(item as Map<String, dynamic>))
                .where((result) => result != null)
                .cast<PlaceSearchResult>()
                .toList();

            // Cache results
            if (results.isNotEmpty) {
              await cacheService.cacheGeocodingResult(query, results);
            }

            // Record successful response
            _healthMonitor.recordSuccess('nominatim', DateTime.now().difference(DateTime.now()));

            return results;
          } else if (response.statusCode == 429) {
            throw Exception('Rate limit exceeded. Please try again later.');
          } else {
            throw Exception('Nominatim search failed: ${response.statusCode}');
          }
        } catch (e) {
          // Record failure
          _healthMonitor.recordFailure('nominatim', DateTime.now().difference(DateTime.now()), e.toString());
          
          if (e is TimeoutException) {
            throw Exception('Search request timed out. Please try again.');
          }
          rethrow;
        }
      },
    );
  }

  @override
  Future<PlaceSearchResult?> reverseGeocode(LatLng coordinates) async {
    return await _analytics.trackApiCall(
      'nominatim',
      'reverseGeocode',
      () async {
        try {
          // Check cache first
          final cacheKey = 'reverse_${coordinates.latitude}_${coordinates.longitude}';
          final cachedResults = await cacheService.getCachedGeocodingResult(cacheKey);
          if (cachedResults != null && cachedResults.isNotEmpty) {
            _analytics.trackCacheHit('nominatim');
            return cachedResults.first;
          }
          
          _analytics.trackCacheMiss('nominatim');

          // Check rate limits
          if (!_analytics.canMakeRequest('nominatim')) {
            throw Exception('Rate limit exceeded. Please try again later.');
          }

          // Wait for rate limit
          await _waitForRateLimit();
          
          // Record request for rate limiting
          _analytics.recordRequest('nominatim');

          // Build reverse geocoding URL
          final uri = _buildReverseUri(coordinates);
          
          // Make request
          final response = await httpClient.get(uri).timeout(config.requestTimeout);
          
          if (response.statusCode == 200) {
            final data = json.decode(response.body) as Map<String, dynamic>;
            final result = _parseNominatimResult(data);
            
            if (result != null) {
              // Cache result
              await cacheService.cacheGeocodingResult(cacheKey, [result]);
              
              // Record successful response
              _healthMonitor.recordSuccess('nominatim', DateTime.now().difference(DateTime.now()));
              
              return result;
            }
          } else if (response.statusCode == 429) {
            throw Exception('Rate limit exceeded. Please try again later.');
          }
          
          return null;
        } catch (e) {
          // Record failure
          _healthMonitor.recordFailure('nominatim', DateTime.now().difference(DateTime.now()), e.toString());
          
          if (e is TimeoutException) {
            throw Exception('Reverse geocoding request timed out. Please try again.');
          }
          return null; // Return null for reverse geocoding errors
        }
      },
    );
  }

  @override
  Future<List<PlaceSearchResult>> getNearbyPlaces(
    LatLng location, {
    double radius = 5000,
    String? type,
  }) async {
    try {
      // For Nominatim, we'll search for places within a bounding box
      final radiusInDegrees = radius / 111000; // Rough conversion: 1 degree ≈ 111km
      
      final query = type ?? 'amenity';
      
      // Wait for rate limit
      await _waitForRateLimit();

      // Build nearby search URL
      final uri = _buildNearbyUri(location, radiusInDegrees, query);
      
      // Make request
      final response = await httpClient.get(uri).timeout(config.requestTimeout);
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body) as List;
        final results = data
            .map((item) => _parseNominatimResult(item as Map<String, dynamic>))
            .where((result) => result != null)
            .cast<PlaceSearchResult>()
            .take(20) // Limit results
            .toList();

        return results;
      } else if (response.statusCode == 429) {
        throw Exception('Rate limit exceeded. Please try again later.');
      }
      
      return [];
    } catch (e) {
      if (e is TimeoutException) {
        throw Exception('Nearby search request timed out. Please try again.');
      }
      return []; // Return empty list for nearby search errors
    }
  }

  @override
  Future<bool> isServiceAvailable() async {
    try {
      final uri = Uri.parse('${config.nominatimBaseUrl}/status');
      final response = await httpClient.get(uri).timeout(
        const Duration(seconds: 5),
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  Uri _buildSearchUri(String query, {LatLng? location, double? radius}) {
    final params = <String, String>{
      'q': query,
      'format': 'json',
      'addressdetails': '1',
      'limit': '10',
      'extratags': '1',
      'namedetails': '1',
    };

    // Add location bias if provided
    if (location != null) {
      params['lat'] = location.latitude.toString();
      params['lon'] = location.longitude.toString();
      
      if (radius != null) {
        // Convert radius to viewbox (rough approximation)
        final radiusInDegrees = radius / 111000;
        final minLat = location.latitude - radiusInDegrees;
        final maxLat = location.latitude + radiusInDegrees;
        final minLon = location.longitude - radiusInDegrees;
        final maxLon = location.longitude + radiusInDegrees;
        
        params['viewbox'] = '$minLon,$maxLat,$maxLon,$minLat';
        params['bounded'] = '1';
      }
    }

    return Uri.parse('${config.nominatimBaseUrl}/search').replace(
      queryParameters: params,
    );
  }

  Uri _buildReverseUri(LatLng coordinates) {
    final params = <String, String>{
      'lat': coordinates.latitude.toString(),
      'lon': coordinates.longitude.toString(),
      'format': 'json',
      'addressdetails': '1',
      'extratags': '1',
      'namedetails': '1',
      'zoom': '18',
    };

    return Uri.parse('${config.nominatimBaseUrl}/reverse').replace(
      queryParameters: params,
    );
  }

  Uri _buildNearbyUri(LatLng location, double radiusInDegrees, String query) {
    final minLat = location.latitude - radiusInDegrees;
    final maxLat = location.latitude + radiusInDegrees;
    final minLon = location.longitude - radiusInDegrees;
    final maxLon = location.longitude + radiusInDegrees;

    final params = <String, String>{
      'q': query,
      'format': 'json',
      'addressdetails': '1',
      'limit': '20',
      'viewbox': '$minLon,$maxLat,$maxLon,$minLat',
      'bounded': '1',
    };

    return Uri.parse('${config.nominatimBaseUrl}/search').replace(
      queryParameters: params,
    );
  }

  PlaceSearchResult? _parseNominatimResult(Map<String, dynamic> data) {
    try {
      final lat = double.tryParse(data['lat']?.toString() ?? '');
      final lon = double.tryParse(data['lon']?.toString() ?? '');
      
      if (lat == null || lon == null) return null;

      final displayName = data['display_name'] as String? ?? '';
      final name = data['name'] as String? ?? 
                   data['namedetails']?['name'] as String? ?? 
                   _extractNameFromDisplayName(displayName);
      
      final placeId = data['place_id']?.toString() ?? 
                      data['osm_id']?.toString() ?? 
                      '${lat}_${lon}';

      // Extract place types
      final types = <String>[];
      if (data['type'] != null) types.add(data['type'] as String);
      if (data['class'] != null) types.add(data['class'] as String);
      
      // Calculate relevance score based on importance
      final importance = double.tryParse(data['importance']?.toString() ?? '0') ?? 0.0;
      final relevanceScore = (importance * 100).clamp(0.0, 100.0);

      return PlaceSearchResult(
        placeId: placeId,
        name: name,
        address: displayName,
        coordinates: LatLng(lat, lon),
        description: _buildDescription(data),
        types: types,
        cachedAt: DateTime.now(),
        relevanceScore: relevanceScore,
      );
    } catch (e) {
      return null; // Skip invalid results
    }
  }

  String _extractNameFromDisplayName(String displayName) {
    // Extract the first part of the display name as the place name
    final parts = displayName.split(',');
    return parts.isNotEmpty ? parts.first.trim() : displayName;
  }

  String? _buildDescription(Map<String, dynamic> data) {
    final type = data['type'] as String?;
    final category = data['class'] as String?;
    
    if (type != null && category != null) {
      return '${type.replaceAll('_', ' ')} (${category.replaceAll('_', ' ')})';
    } else if (type != null) {
      return type.replaceAll('_', ' ');
    } else if (category != null) {
      return category.replaceAll('_', ' ');
    }
    
    return null;
  }

  Future<void> _waitForRateLimit() async {
    final completer = Completer<void>();
    _requestQueue.add(completer);
    
    if (!_processingQueue) {
      _processingQueue = true;
      _processRequestQueue();
    }
    
    return completer.future;
  }

  void _processRequestQueue() async {
    while (_requestQueue.isNotEmpty) {
      final completer = _requestQueue.removeFirst();
      
      // Ensure minimum time between requests (Nominatim rate limit: 1 req/sec)
      if (_lastRequestTime != null) {
        final timeSinceLastRequest = DateTime.now().difference(_lastRequestTime!);
        final minInterval = Duration(milliseconds: (1000 / config.nominatimRateLimit).round());
        
        if (timeSinceLastRequest < minInterval) {
          final waitTime = minInterval - timeSinceLastRequest;
          await Future.delayed(waitTime);
        }
      }
      
      _lastRequestTime = DateTime.now();
      completer.complete();
    }
    
    _processingQueue = false;
  }

  void dispose() {
    httpClient.close();
  }
}

// Mock implementation for development/testing
class MockFreeGeocodingService implements IFreeGeocodingService {
  final Duration delay;
  bool _isAvailable;

  MockFreeGeocodingService({
    this.delay = const Duration(milliseconds: 300),
    bool isAvailable = true,
  }) : _isAvailable = isAvailable;

  void setAvailable(bool available) {
    _isAvailable = available;
  }

  @override
  Future<List<PlaceSearchResult>> searchPlaces(
    String query, {
    LatLng? location,
    double? radius,
  }) async {
    await Future.delayed(delay);
    
    if (!_isAvailable) {
      throw Exception('Service unavailable');
    }

    if (query.trim().isEmpty) return [];

    final baseLocation = location ?? LatLng(37.7749, -122.4194);
    
    return List.generate(5, (index) {
      return PlaceSearchResult(
        placeId: 'mock_place_${index}_${query.hashCode}',
        name: '$query - Location ${index + 1}',
        address: '$query Street ${index + 1}, Mock City, Mock Country',
        coordinates: LatLng(
          baseLocation.latitude + (index * 0.001),
          baseLocation.longitude + (index * 0.001),
        ),
        description: 'Mock ${query.toLowerCase()} location ${index + 1}',
        types: ['establishment', 'point_of_interest'],
        cachedAt: DateTime.now(),
        relevanceScore: (100 - index * 10).toDouble(),
      );
    });
  }

  @override
  Future<PlaceSearchResult?> reverseGeocode(LatLng coordinates) async {
    await Future.delayed(delay);
    
    if (!_isAvailable) {
      throw Exception('Service unavailable');
    }

    return PlaceSearchResult(
      placeId: 'mock_reverse_${coordinates.latitude}_${coordinates.longitude}',
      name: 'Mock Location',
      address: '123 Mock Street, Mock City, Mock Country',
      coordinates: coordinates,
      description: 'Mock reverse geocoded location',
      types: ['address'],
      cachedAt: DateTime.now(),
      relevanceScore: 85.0,
    );
  }

  @override
  Future<List<PlaceSearchResult>> getNearbyPlaces(
    LatLng location, {
    double radius = 5000,
    String? type,
  }) async {
    await Future.delayed(delay);
    
    if (!_isAvailable) {
      throw Exception('Service unavailable');
    }

    return List.generate(3, (index) {
      return PlaceSearchResult(
        placeId: 'mock_nearby_${index}_${location.hashCode}',
        name: '${type ?? 'Place'} ${index + 1}',
        address: 'Nearby Street ${index + 1}, Mock City, Mock Country',
        coordinates: LatLng(
          location.latitude + (index * 0.002),
          location.longitude + (index * 0.002),
        ),
        description: 'Nearby ${type ?? 'place'} ${index + 1}',
        types: [type ?? 'establishment', 'point_of_interest'],
        cachedAt: DateTime.now(),
        relevanceScore: (90 - index * 5).toDouble(),
      );
    });
  }

  @override
  Future<bool> isServiceAvailable() async {
    await Future.delayed(const Duration(milliseconds: 100));
    return _isAvailable;
  }
}