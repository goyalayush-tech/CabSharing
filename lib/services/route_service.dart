import 'dart:convert';
import 'dart:math' as math;
import 'package:http/http.dart' as http;
import '../models/ride_group.dart';
import '../models/place_models.dart';
import '../core/constants/app_constants.dart';

abstract class IRouteService {
  Future<RouteInfo> calculateRoute(LatLng origin, LatLng destination);
  Future<List<LatLng>> getOptimizedWaypoints(List<LatLng> locations);
  Future<double> estimateFare(RouteInfo route);
  Future<RouteInfo> getRouteWithWaypoints(LatLng origin, LatLng destination, List<LatLng> waypoints);
}

class RouteService implements IRouteService {
  static const String _baseUrl = 'https://maps.googleapis.com/maps/api/directions/json';
  
  @override
  Future<RouteInfo> calculateRoute(LatLng origin, LatLng destination) async {
    try {
      final url = Uri.parse('$_baseUrl?'
          'origin=${origin.latitude},${origin.longitude}&'
          'destination=${destination.latitude},${destination.longitude}&'
          'key=${AppConstants.googleMapsApiKey}');

      final response = await http.get(url);
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data['status'] == 'OK' && data['routes'].isNotEmpty) {
          final routeInfo = RouteInfo.fromJson(data);
          final estimatedFare = await estimateFare(routeInfo);
          
          return RouteInfo(
            polylinePoints: routeInfo.polylinePoints,
            distanceKm: routeInfo.distanceKm,
            estimatedDuration: routeInfo.estimatedDuration,
            textInstructions: routeInfo.textInstructions,
            estimatedFare: estimatedFare,
            steps: routeInfo.steps,
          );
        } else {
          throw Exception('No route found: ${data['status']}');
        }
      } else {
        throw Exception('Failed to get route: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Route calculation failed: $e');
    }
  }

  @override
  Future<RouteInfo> getRouteWithWaypoints(
    LatLng origin, 
    LatLng destination, 
    List<LatLng> waypoints
  ) async {
    try {
      String waypointsStr = '';
      if (waypoints.isNotEmpty) {
        waypointsStr = '&waypoints=' + 
            waypoints.map((w) => '${w.latitude},${w.longitude}').join('|');
      }

      final url = Uri.parse('$_baseUrl?'
          'origin=${origin.latitude},${origin.longitude}&'
          'destination=${destination.latitude},${destination.longitude}'
          '$waypointsStr&'
          'optimize:true&'
          'key=${AppConstants.googleMapsApiKey}');

      final response = await http.get(url);
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data['status'] == 'OK' && data['routes'].isNotEmpty) {
          final routeInfo = RouteInfo.fromJson(data);
          final estimatedFare = await estimateFare(routeInfo);
          
          return RouteInfo(
            polylinePoints: routeInfo.polylinePoints,
            distanceKm: routeInfo.distanceKm,
            estimatedDuration: routeInfo.estimatedDuration,
            textInstructions: routeInfo.textInstructions,
            estimatedFare: estimatedFare,
            steps: routeInfo.steps,
          );
        } else {
          throw Exception('No route found: ${data['status']}');
        }
      } else {
        throw Exception('Failed to get route: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Route calculation with waypoints failed: $e');
    }
  }

  @override
  Future<List<LatLng>> getOptimizedWaypoints(List<LatLng> locations) async {
    if (locations.length < 3) return locations;
    
    try {
      final origin = locations.first;
      final destination = locations.last;
      final waypoints = locations.sublist(1, locations.length - 1);
      
      final route = await getRouteWithWaypoints(origin, destination, waypoints);
      
      // Return optimized order based on route response
      // For now, return original order - in production, parse waypoint_order from response
      return locations;
    } catch (e) {
      // Fallback to original order
      return locations;
    }
  }

  @override
  Future<double> estimateFare(RouteInfo route) async {
    // Basic fare calculation - customize based on your pricing model
    const double baseFare = 50.0; // Base fare in your currency
    const double perKmRate = 15.0; // Rate per kilometer
    const double perMinuteRate = 2.0; // Rate per minute
    
    final distanceFare = route.distanceKm * perKmRate;
    final timeFare = route.estimatedDuration.inMinutes * perMinuteRate;
    
    return baseFare + distanceFare + timeFare;
  }
}

// Mock implementation for development/testing
class MockRouteService implements IRouteService {
  @override
  Future<RouteInfo> calculateRoute(LatLng origin, LatLng destination) async {
    await Future.delayed(const Duration(milliseconds: 500));
    
    // Generate mock polyline points (straight line with some variation)
    final points = <LatLng>[];
    const steps = 10;
    
    for (int i = 0; i <= steps; i++) {
      final ratio = i / steps;
      final lat = origin.latitude + (destination.latitude - origin.latitude) * ratio;
      final lng = origin.longitude + (destination.longitude - origin.longitude) * ratio;
      points.add(LatLng(lat, lng));
    }
    
    // Calculate approximate distance
    final distance = _calculateDistance(origin, destination);
    final duration = Duration(minutes: (distance * 2).round()); // Rough estimate
    
    return RouteInfo(
      polylinePoints: points,
      distanceKm: distance,
      estimatedDuration: duration,
      textInstructions: '${duration.inMinutes} min (${distance.toStringAsFixed(1)} km)',
      estimatedFare: await estimateFare(RouteInfo(
        polylinePoints: points,
        distanceKm: distance,
        estimatedDuration: duration,
        textInstructions: '',
        estimatedFare: 0,
      )),
    );
  }

  @override
  Future<RouteInfo> getRouteWithWaypoints(
    LatLng origin, 
    LatLng destination, 
    List<LatLng> waypoints
  ) async {
    // For mock, just calculate route from origin to destination
    return calculateRoute(origin, destination);
  }

  @override
  Future<List<LatLng>> getOptimizedWaypoints(List<LatLng> locations) async {
    await Future.delayed(const Duration(milliseconds: 300));
    return locations; // Return as-is for mock
  }

  @override
  Future<double> estimateFare(RouteInfo route) async {
    const double baseFare = 50.0;
    const double perKmRate = 15.0;
    const double perMinuteRate = 2.0;
    
    final distanceFare = route.distanceKm * perKmRate;
    final timeFare = route.estimatedDuration.inMinutes * perMinuteRate;
    
    return baseFare + distanceFare + timeFare;
  }

  double _calculateDistance(LatLng point1, LatLng point2) {
    // Haversine formula for distance calculation
    const double earthRadius = 6371; // Earth's radius in kilometers
    
    final lat1Rad = point1.latitude * (3.14159 / 180);
    final lat2Rad = point2.latitude * (3.14159 / 180);
    final deltaLatRad = (point2.latitude - point1.latitude) * (3.14159 / 180);
    final deltaLngRad = (point2.longitude - point1.longitude) * (3.14159 / 180);
    
    final a = math.pow(math.sin(deltaLatRad / 2), 2) +
        math.cos(lat1Rad) * math.cos(lat2Rad) *
        math.pow(math.sin(deltaLngRad / 2), 2);
    final c = 2 * math.asin(math.sqrt(a));
    
    return earthRadius * c;
  }
}