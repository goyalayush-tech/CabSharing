import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:http/http.dart' as http;
import 'package:google_polyline_algorithm/google_polyline_algorithm.dart';
import '../models/ride_group.dart';
import '../models/place_models.dart';
import '../core/config/free_map_config.dart';
import '../services/map_cache_service.dart';

abstract class IFreeRoutingService {
  Future<RouteInfo> calculateRoute(LatLng origin, LatLng destination);
  Future<RouteInfo> getRouteWithWaypoints(LatLng origin, LatLng destination, List<LatLng> waypoints);
  Future<List<LatLng>> getOptimizedWaypoints(List<LatLng> locations);
  Future<double> estimateFare(RouteInfo route);
  Future<bool> isServiceAvailable();
  Future<int> getRemainingDailyRequests();
}

class OpenRouteService implements IFreeRoutingService {
  final FreeMapConfig config;
  final IMapCacheService cacheService;
  final http.Client httpClient;
  
  // Request tracking for daily limits
  int _dailyRequestCount = 0;
  DateTime? _lastResetDate;

  OpenRouteService({
    required this.config,
    required this.cacheService,
    http.Client? httpClient,
  }) : httpClient = httpClient ?? http.Client() {
    _initializeDailyTracking();
  }

  void _initializeDailyTracking() {
    final today = DateTime.now();
    if (_lastResetDate == null || 
        _lastResetDate!.day != today.day ||
        _lastResetDate!.month != today.month ||
        _lastResetDate!.year != today.year) {
      _dailyRequestCount = 0;
      _lastResetDate = today;
    }
  }

  @override
  Future<RouteInfo> calculateRoute(LatLng origin, LatLng destination) async {
    // Check cache first
    final routeKey = _generateRouteKey(origin, destination);
    final cachedRoute = await cacheService.getCachedRoute(routeKey);
    if (cachedRoute != null) {
      return cachedRoute;
    }

    // Check daily limit
    if (_dailyRequestCount >= config.openRouteServiceDailyLimit) {
      throw Exception('Daily request limit exceeded. Try again tomorrow or use fallback service.');
    }

    try {
      final coordinates = [
        [origin.longitude, origin.latitude],
        [destination.longitude, destination.latitude],
      ];

      final requestBody = {
        'coordinates': coordinates,
        'format': 'json',
        'profile': 'driving-car',
        'geometry': true,
        'instructions': true,
        'elevation': false,
        'extra_info': ['waytype', 'steepness'],
      };

      final uri = Uri.parse('${config.openRouteServiceBaseUrl}/directions/driving-car');
      
      final response = await httpClient.post(
        uri,
        headers: {
          'Authorization': config.openRouteServiceApiKey,
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: json.encode(requestBody),
      ).timeout(config.requestTimeout);

      _dailyRequestCount++;

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final route = _parseOpenRouteServiceResponse(data);
        
        // Calculate fare
        final estimatedFare = await estimateFare(route);
        final routeWithFare = RouteInfo(
          polylinePoints: route.polylinePoints,
          distanceKm: route.distanceKm,
          estimatedDuration: route.estimatedDuration,
          textInstructions: route.textInstructions,
          estimatedFare: estimatedFare,
          steps: route.steps,
        );

        // Cache the result
        await cacheService.cacheRoute(routeKey, routeWithFare);
        
        return routeWithFare;
      } else if (response.statusCode == 401) {
        throw Exception('Invalid OpenRouteService API key. Please check your configuration.');
      } else if (response.statusCode == 403) {
        throw Exception('OpenRouteService access forbidden. Check your API key permissions.');
      } else if (response.statusCode == 429) {
        throw Exception('OpenRouteService rate limit exceeded. Please try again later.');
      } else {
        throw Exception('OpenRouteService request failed: ${response.statusCode}');
      }
    } catch (e) {
      if (e is TimeoutException) {
        throw Exception('Route calculation timed out. Please try again.');
      }
      rethrow;
    }
  }

  @override
  Future<RouteInfo> getRouteWithWaypoints(
    LatLng origin, 
    LatLng destination, 
    List<LatLng> waypoints
  ) async {
    if (waypoints.isEmpty) {
      return calculateRoute(origin, destination);
    }

    // Check cache first
    final routeKey = _generateRouteKeyWithWaypoints(origin, destination, waypoints);
    final cachedRoute = await cacheService.getCachedRoute(routeKey);
    if (cachedRoute != null) {
      return cachedRoute;
    }

    // Check daily limit
    if (_dailyRequestCount >= config.openRouteServiceDailyLimit) {
      throw Exception('Daily request limit exceeded. Try again tomorrow or use fallback service.');
    }

    try {
      final coordinates = <List<double>>[];
      coordinates.add([origin.longitude, origin.latitude]);
      
      for (final waypoint in waypoints) {
        coordinates.add([waypoint.longitude, waypoint.latitude]);
      }
      
      coordinates.add([destination.longitude, destination.latitude]);

      final requestBody = {
        'coordinates': coordinates,
        'format': 'json',
        'profile': 'driving-car',
        'geometry': true,
        'instructions': true,
        'elevation': false,
        'optimize_waypoints': true,
      };

      final uri = Uri.parse('${config.openRouteServiceBaseUrl}/directions/driving-car');
      
      final response = await httpClient.post(
        uri,
        headers: {
          'Authorization': config.openRouteServiceApiKey,
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: json.encode(requestBody),
      ).timeout(config.requestTimeout);

      _dailyRequestCount++;

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final route = _parseOpenRouteServiceResponse(data);
        
        // Calculate fare
        final estimatedFare = await estimateFare(route);
        final routeWithFare = RouteInfo(
          polylinePoints: route.polylinePoints,
          distanceKm: route.distanceKm,
          estimatedDuration: route.estimatedDuration,
          textInstructions: route.textInstructions,
          estimatedFare: estimatedFare,
          steps: route.steps,
        );

        // Cache the result
        await cacheService.cacheRoute(routeKey, routeWithFare);
        
        return routeWithFare;
      } else {
        throw Exception('OpenRouteService waypoint routing failed: ${response.statusCode}');
      }
    } catch (e) {
      if (e is TimeoutException) {
        throw Exception('Waypoint route calculation timed out. Please try again.');
      }
      rethrow;
    }
  }

  @override
  Future<List<LatLng>> getOptimizedWaypoints(List<LatLng> locations) async {
    if (locations.length < 3) return locations;
    
    try {
      final origin = locations.first;
      final destination = locations.last;
      final waypoints = locations.sublist(1, locations.length - 1);
      
      // Call the route service to trigger optimization on the server side
      await getRouteWithWaypoints(origin, destination, waypoints);
      
      // For now, return original order since OpenRouteService optimization
      // is handled internally and we don't get the optimized order back easily
      return locations;
    } catch (e) {
      // Fallback to original order
      return locations;
    }
  }

  @override
  Future<double> estimateFare(RouteInfo route) async {
    // Configurable fare calculation - customize based on your pricing model
    const double baseFare = 50.0; // Base fare in your currency
    const double perKmRate = 15.0; // Rate per kilometer
    const double perMinuteRate = 2.0; // Rate per minute
    const double minimumFare = 25.0; // Minimum fare
    
    final distanceFare = route.distanceKm * perKmRate;
    final timeFare = route.estimatedDuration.inMinutes * perMinuteRate;
    final totalFare = baseFare + distanceFare + timeFare;
    
    return math.max(totalFare, minimumFare);
  }

  @override
  Future<bool> isServiceAvailable() async {
    try {
      final uri = Uri.parse('${config.openRouteServiceBaseUrl}/health');
      final response = await httpClient.get(
        uri,
        headers: {
          'Authorization': config.openRouteServiceApiKey,
        },
      ).timeout(const Duration(seconds: 5));
      
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<int> getRemainingDailyRequests() async {
    _initializeDailyTracking();
    return math.max(0, config.openRouteServiceDailyLimit - _dailyRequestCount);
  }

  RouteInfo _parseOpenRouteServiceResponse(Map<String, dynamic> data) {
    final routes = data['routes'] as List;
    if (routes.isEmpty) {
      throw Exception('No routes found in response');
    }

    final route = routes.first as Map<String, dynamic>;
    final summary = route['summary'] as Map<String, dynamic>;
    final geometry = route['geometry'] as String;
    final segments = route['segments'] as List;

    // Decode polyline
    final polylinePoints = decodePolyline(geometry)
        .map((point) => LatLng(point[0].toDouble(), point[1].toDouble()))
        .toList();

    // Extract distance and duration
    final distanceKm = (summary['distance'] as num).toDouble() / 1000.0;
    final durationSeconds = (summary['duration'] as num).toDouble();
    final estimatedDuration = Duration(seconds: durationSeconds.round());

    // Build text instructions
    final textInstructions = _buildTextInstructions(distanceKm, estimatedDuration);

    // Extract steps from segments
    final steps = <RouteStep>[];
    for (final segment in segments) {
      final segmentSteps = segment['steps'] as List? ?? [];
      for (final step in segmentSteps) {
        final routeStep = _parseRouteStep(step as Map<String, dynamic>);
        if (routeStep != null) {
          steps.add(routeStep);
        }
      }
    }

    return RouteInfo(
      polylinePoints: polylinePoints,
      distanceKm: distanceKm,
      estimatedDuration: estimatedDuration,
      textInstructions: textInstructions,
      estimatedFare: 0.0, // Will be calculated separately
      steps: steps,
    );
  }

  RouteStep? _parseRouteStep(Map<String, dynamic> stepData) {
    try {
      final instruction = stepData['instruction'] as String? ?? '';
      final distance = (stepData['distance'] as num?)?.toDouble() ?? 0.0;
      final duration = (stepData['duration'] as num?)?.toDouble() ?? 0.0;
      
      final wayPoints = stepData['way_points'] as List? ?? [];
      if (wayPoints.length < 2) return null;
      
      // Note: wayPoints contain indices into the geometry array
      // For simplicity, use approximate coordinates
      // In a real implementation, you'd extract from the geometry using these indices
      final startLocation = LatLng(0.0, 0.0); // Placeholder
      final endLocation = LatLng(0.0, 0.0); // Placeholder

      return RouteStep(
        instructions: instruction,
        distanceKm: distance / 1000.0,
        duration: Duration(seconds: duration.round()),
        startLocation: startLocation,
        endLocation: endLocation,
      );
    } catch (e) {
      return null;
    }
  }

  String _buildTextInstructions(double distanceKm, Duration duration) {
    final distanceText = distanceKm < 1.0 
        ? '${(distanceKm * 1000).round()} m'
        : '${distanceKm.toStringAsFixed(1)} km';
    
    final durationText = duration.inHours > 0
        ? '${duration.inHours}h ${duration.inMinutes % 60}min'
        : '${duration.inMinutes}min';
    
    return '$durationText ($distanceText)';
  }

  String _generateRouteKey(LatLng origin, LatLng destination) {
    final originKey = '${origin.latitude.toStringAsFixed(4)}_${origin.longitude.toStringAsFixed(4)}';
    final destKey = '${destination.latitude.toStringAsFixed(4)}_${destination.longitude.toStringAsFixed(4)}';
    return 'route_${originKey}_to_$destKey';
  }

  String _generateRouteKeyWithWaypoints(LatLng origin, LatLng destination, List<LatLng> waypoints) {
    final baseKey = _generateRouteKey(origin, destination);
    final waypointKeys = waypoints
        .map((w) => '${w.latitude.toStringAsFixed(4)}_${w.longitude.toStringAsFixed(4)}')
        .join('_');
    return '${baseKey}_via_$waypointKeys';
  }

  void dispose() {
    httpClient.close();
  }
}

// Mock implementation for development/testing
class MockFreeRoutingService implements IFreeRoutingService {
  final Duration delay;
  bool _isAvailable;
  int _remainingRequests;

  MockFreeRoutingService({
    this.delay = const Duration(milliseconds: 500),
    bool isAvailable = true,
    int remainingRequests = 2000,
  }) : _isAvailable = isAvailable,
       _remainingRequests = remainingRequests;

  void setAvailable(bool available) {
    _isAvailable = available;
  }

  void setRemainingRequests(int remaining) {
    _remainingRequests = remaining;
  }

  @override
  Future<RouteInfo> calculateRoute(LatLng origin, LatLng destination) async {
    await Future.delayed(delay);
    
    if (!_isAvailable) {
      throw Exception('Routing service unavailable');
    }

    if (_remainingRequests <= 0) {
      throw Exception('Daily request limit exceeded');
    }

    _remainingRequests--;

    // Generate mock polyline points (straight line with some variation)
    final points = <LatLng>[];
    const steps = 10;
    
    for (int i = 0; i <= steps; i++) {
      final ratio = i / steps;
      final lat = origin.latitude + (destination.latitude - origin.latitude) * ratio;
      final lng = origin.longitude + (destination.longitude - origin.longitude) * ratio;
      
      // Add some variation to make it look more realistic
      final variation = 0.001 * math.sin(i * math.pi / 5);
      points.add(LatLng(lat + variation, lng + variation));
    }
    
    // Calculate approximate distance using Haversine formula
    final distance = _calculateDistance(origin, destination);
    final duration = Duration(minutes: (distance * 2).round()); // Rough estimate: 30 km/h average
    final fare = await estimateFare(RouteInfo(
      polylinePoints: points,
      distanceKm: distance,
      estimatedDuration: duration,
      textInstructions: '',
      estimatedFare: 0,
    ));

    return RouteInfo(
      polylinePoints: points,
      distanceKm: distance,
      estimatedDuration: duration,
      textInstructions: '${duration.inMinutes} min (${distance.toStringAsFixed(1)} km)',
      estimatedFare: fare,
      steps: _generateMockSteps(origin, destination, distance, duration),
    );
  }

  @override
  Future<RouteInfo> getRouteWithWaypoints(
    LatLng origin, 
    LatLng destination, 
    List<LatLng> waypoints
  ) async {
    await Future.delayed(delay);
    
    if (!_isAvailable) {
      throw Exception('Routing service unavailable');
    }

    if (_remainingRequests <= 0) {
      throw Exception('Daily request limit exceeded');
    }

    _remainingRequests--;

    // For mock, just calculate route from origin to destination
    // In real implementation, this would include waypoints
    final baseRoute = await calculateRoute(origin, destination);
    
    // Add some extra distance and time for waypoints
    final extraDistance = waypoints.length * 2.0; // 2km per waypoint
    final extraTime = waypoints.length * 5; // 5 minutes per waypoint
    
    return RouteInfo(
      polylinePoints: baseRoute.polylinePoints,
      distanceKm: baseRoute.distanceKm + extraDistance,
      estimatedDuration: Duration(
        minutes: baseRoute.estimatedDuration.inMinutes + extraTime,
      ),
      textInstructions: '${baseRoute.estimatedDuration.inMinutes + extraTime} min '
                       '(${(baseRoute.distanceKm + extraDistance).toStringAsFixed(1)} km) '
                       'via ${waypoints.length} waypoints',
      estimatedFare: baseRoute.estimatedFare + (waypoints.length * 10), // Extra cost for waypoints
      steps: baseRoute.steps,
    );
  }

  @override
  Future<List<LatLng>> getOptimizedWaypoints(List<LatLng> locations) async {
    await Future.delayed(const Duration(milliseconds: 200));
    
    if (!_isAvailable) {
      throw Exception('Routing service unavailable');
    }

    // Mock optimization - just return original order
    return locations;
  }

  @override
  Future<double> estimateFare(RouteInfo route) async {
    const double baseFare = 50.0;
    const double perKmRate = 15.0;
    const double perMinuteRate = 2.0;
    const double minimumFare = 25.0;
    
    final distanceFare = route.distanceKm * perKmRate;
    final timeFare = route.estimatedDuration.inMinutes * perMinuteRate;
    final totalFare = baseFare + distanceFare + timeFare;
    
    return math.max(totalFare, minimumFare);
  }

  @override
  Future<bool> isServiceAvailable() async {
    await Future.delayed(const Duration(milliseconds: 100));
    return _isAvailable;
  }

  @override
  Future<int> getRemainingDailyRequests() async {
    await Future.delayed(const Duration(milliseconds: 50));
    return _remainingRequests;
  }

  double _calculateDistance(LatLng point1, LatLng point2) {
    // Haversine formula for distance calculation
    const double earthRadius = 6371; // Earth's radius in kilometers
    
    final lat1Rad = point1.latitude * (math.pi / 180);
    final lat2Rad = point2.latitude * (math.pi / 180);
    final deltaLatRad = (point2.latitude - point1.latitude) * (math.pi / 180);
    final deltaLngRad = (point2.longitude - point1.longitude) * (math.pi / 180);
    
    final a = math.pow(math.sin(deltaLatRad / 2), 2) +
        math.cos(lat1Rad) * math.cos(lat2Rad) *
        math.pow(math.sin(deltaLngRad / 2), 2);
    final c = 2 * math.asin(math.sqrt(a));
    
    return earthRadius * c;
  }

  List<RouteStep> _generateMockSteps(LatLng origin, LatLng destination, double distance, Duration duration) {
    return [
      RouteStep(
        instructions: 'Head towards destination',
        distanceKm: distance * 0.3,
        duration: Duration(minutes: (duration.inMinutes * 0.3).round()),
        startLocation: origin,
        endLocation: LatLng(
          origin.latitude + (destination.latitude - origin.latitude) * 0.3,
          origin.longitude + (destination.longitude - origin.longitude) * 0.3,
        ),
      ),
      RouteStep(
        instructions: 'Continue straight',
        distanceKm: distance * 0.4,
        duration: Duration(minutes: (duration.inMinutes * 0.4).round()),
        startLocation: LatLng(
          origin.latitude + (destination.latitude - origin.latitude) * 0.3,
          origin.longitude + (destination.longitude - origin.longitude) * 0.3,
        ),
        endLocation: LatLng(
          origin.latitude + (destination.latitude - origin.latitude) * 0.7,
          origin.longitude + (destination.longitude - origin.longitude) * 0.7,
        ),
      ),
      RouteStep(
        instructions: 'Arrive at destination',
        distanceKm: distance * 0.3,
        duration: Duration(minutes: (duration.inMinutes * 0.3).round()),
        startLocation: LatLng(
          origin.latitude + (destination.latitude - origin.latitude) * 0.7,
          origin.longitude + (destination.longitude - origin.longitude) * 0.7,
        ),
        endLocation: destination,
      ),
    ];
  }
}