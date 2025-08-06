import 'dart:async';
import 'fallback_manager.dart';
import 'free_geocoding_service.dart';
import '../models/place_models.dart';

/// Example of how to integrate FallbackManager with existing services
class FallbackGeocodingService {
  final IFallbackManager _fallbackManager;
  final FreeGeocodingService _primaryService;
  final FreeGeocodingService _fallbackService;

  FallbackGeocodingService({
    required IFallbackManager fallbackManager,
    required FreeGeocodingService primaryService,
    required FreeGeocodingService fallbackService,
  }) : _fallbackManager = fallbackManager,
       _primaryService = primaryService,
       _fallbackService = fallbackService;

  /// Search for places with automatic fallback
  Future<List<PlaceSearchResult>> searchPlaces(
    String query, {
    LatLng? location,
    int limit = 5,
  }) async {
    return await _fallbackManager.executeWithFallback<List<PlaceSearchResult>>(
      () => _primaryService.searchPlaces(query, location: location, limit: limit),
      () => _fallbackService.searchPlaces(query, location: location, limit: limit),
      'geocoding_search',
    );
  }

  /// Reverse geocode coordinates with automatic fallback
  Future<PlaceDetails?> reverseGeocode(LatLng coordinates) async {
    return await _fallbackManager.executeWithFallback<PlaceDetails?>(
      () => _primaryService.reverseGeocode(coordinates),
      () => _fallbackService.reverseGeocode(coordinates),
      'reverse_geocoding',
    );
  }

  /// Get service health information
  Map<String, dynamic> getHealthStatus() {
    final primaryHealth = _fallbackManager.getServiceHealth('primary_geocoding_search');
    final fallbackHealth = _fallbackManager.getServiceHealth('fallback_geocoding_search');
    
    return {
      'primary': primaryHealth.toJson(),
      'fallback': fallbackHealth.toJson(),
      'shouldUseFallback': _fallbackManager.shouldUseFallback('primary_geocoding_search'),
    };
  }

  /// Manually report service issues (for external monitoring)
  void reportServiceIssue(String serviceName, String error) {
    _fallbackManager.reportServiceFailure(serviceName, 'external_monitoring');
  }

  /// Reset service health (for testing or maintenance)
  void resetHealth() {
    _fallbackManager.resetServiceHealth('primary_geocoding_search');
    _fallbackManager.resetServiceHealth('fallback_geocoding_search');
    _fallbackManager.resetServiceHealth('primary_reverse_geocoding');
    _fallbackManager.resetServiceHealth('fallback_reverse_geocoding');
  }
}