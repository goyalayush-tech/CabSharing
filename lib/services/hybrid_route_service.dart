import '../models/ride_group.dart';
import '../models/place_models.dart';
import '../core/config/free_map_config.dart';
import 'free_routing_service.dart';
import 'route_service.dart';

/// Hybrid routing service that uses free services as primary and Google Maps as fallback
class HybridRouteService implements IRouteService {
  final IFreeRoutingService freeRoutingService;
  final IRouteService? googleRouteService;
  final FreeMapConfig config;

  HybridRouteService({
    required this.freeRoutingService,
    this.googleRouteService,
    required this.config,
  });

  @override
  Future<RouteInfo> calculateRoute(LatLng origin, LatLng destination) async {
    try {
      // Try free service first
      return await freeRoutingService.calculateRoute(origin, destination);
    } catch (e) {
      // Fallback to Google Maps if enabled and available
      if (config.enableFallback && googleRouteService != null) {
        try {
          return await googleRouteService!.calculateRoute(origin, destination);
        } catch (fallbackError) {
          // If both services fail, throw the original error with context
          throw Exception('Primary routing service failed: $e. Fallback also failed: $fallbackError');
        }
      } else {
        // No fallback available, rethrow original error
        rethrow;
      }
    }
  }

  @override
  Future<RouteInfo> getRouteWithWaypoints(
    LatLng origin, 
    LatLng destination, 
    List<LatLng> waypoints
  ) async {
    try {
      // Try free service first
      return await freeRoutingService.getRouteWithWaypoints(origin, destination, waypoints);
    } catch (e) {
      // Fallback to Google Maps if enabled and available
      if (config.enableFallback && googleRouteService != null) {
        try {
          return await googleRouteService!.getRouteWithWaypoints(origin, destination, waypoints);
        } catch (fallbackError) {
          throw Exception('Primary routing service failed: $e. Fallback also failed: $fallbackError');
        }
      } else {
        rethrow;
      }
    }
  }

  @override
  Future<List<LatLng>> getOptimizedWaypoints(List<LatLng> locations) async {
    try {
      // Try free service first
      return await freeRoutingService.getOptimizedWaypoints(locations);
    } catch (e) {
      // Fallback to Google Maps if enabled and available
      if (config.enableFallback && googleRouteService != null) {
        try {
          return await googleRouteService!.getOptimizedWaypoints(locations);
        } catch (fallbackError) {
          // If both fail, return original locations as last resort
          return locations;
        }
      } else {
        // No fallback, return original locations
        return locations;
      }
    }
  }

  @override
  Future<double> estimateFare(RouteInfo route) async {
    try {
      // Try free service first
      return await freeRoutingService.estimateFare(route);
    } catch (e) {
      // Fallback to Google Maps if enabled and available
      if (config.enableFallback && googleRouteService != null) {
        try {
          return await googleRouteService!.estimateFare(route);
        } catch (fallbackError) {
          // If both fail, use a basic calculation
          return _basicFareEstimate(route);
        }
      } else {
        // No fallback, use basic calculation
        return _basicFareEstimate(route);
      }
    }
  }

  /// Basic fare estimation as last resort
  double _basicFareEstimate(RouteInfo route) {
    const double baseFare = 50.0;
    const double perKmRate = 15.0;
    const double perMinuteRate = 2.0;
    const double minimumFare = 25.0;
    
    final distanceFare = route.distanceKm * perKmRate;
    final timeFare = route.estimatedDuration.inMinutes * perMinuteRate;
    final totalFare = baseFare + distanceFare + timeFare;
    
    return totalFare < minimumFare ? minimumFare : totalFare;
  }

  /// Check if free routing service is available
  Future<bool> isFreeServiceAvailable() async {
    try {
      return await freeRoutingService.isServiceAvailable();
    } catch (e) {
      return false;
    }
  }

  /// Get remaining daily requests for free service
  Future<int> getRemainingFreeRequests() async {
    try {
      return await freeRoutingService.getRemainingDailyRequests();
    } catch (e) {
      return 0;
    }
  }

  /// Get service health information
  Future<Map<String, dynamic>> getServiceHealth() async {
    final freeServiceAvailable = await isFreeServiceAvailable();
    final remainingRequests = await getRemainingFreeRequests();
    
    return {
      'freeService': {
        'available': freeServiceAvailable,
        'remainingRequests': remainingRequests,
        'dailyLimit': config.openRouteServiceDailyLimit,
      },
      'fallbackEnabled': config.enableFallback,
      'googleServiceAvailable': googleRouteService != null,
    };
  }
}