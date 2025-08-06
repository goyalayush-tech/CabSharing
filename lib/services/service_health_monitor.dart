import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import '../models/service_health.dart';

/// Monitors the health and availability of map services
class ServiceHealthMonitor extends ChangeNotifier {
  static final ServiceHealthMonitor _instance = ServiceHealthMonitor._internal();
  factory ServiceHealthMonitor() => _instance;
  ServiceHealthMonitor._internal();

  final Map<String, ServiceHealth> _serviceHealth = {};
  final Map<String, List<Duration>> _recentResponseTimes = {};
  final Map<String, List<bool>> _recentResults = {};
  Timer? _healthCheckTimer;

  /// Initialize health monitoring
  void startMonitoring() {
    // Initialize default services
    _initializeServices();
    
    // Start periodic health checks every 5 minutes
    _healthCheckTimer?.cancel();
    _healthCheckTimer = Timer.periodic(
      const Duration(minutes: 5),
      (_) => _performHealthChecks(),
    );
  }

  /// Stop health monitoring
  void stopMonitoring() {
    _healthCheckTimer?.cancel();
    _healthCheckTimer = null;
  }

  /// Record a successful service call
  void recordSuccess(String serviceName, Duration responseTime) {
    _updateServiceHealth(serviceName, true, responseTime);
  }

  /// Record a failed service call
  void recordFailure(String serviceName, Duration responseTime, String error) {
    _updateServiceHealth(serviceName, false, responseTime);
    
    if (kDebugMode) {
      print('Service failure recorded: $serviceName - $error');
    }
  }

  /// Get health status for a specific service
  ServiceHealth? getServiceHealth(String serviceName) {
    return _serviceHealth[serviceName];
  }

  /// Get health status for all services
  Map<String, ServiceHealth> getAllServiceHealth() {
    return Map.unmodifiable(_serviceHealth);
  }

  /// Check if a service is considered healthy
  bool isServiceHealthy(String serviceName) {
    final health = _serviceHealth[serviceName];
    if (health == null) return false;
    
    return health.isAvailable && 
           health.successRate >= 80.0 && 
           health.averageResponseTime.inSeconds < 10;
  }

  /// Get the best available service for a given operation
  String? getBestService(List<String> serviceOptions) {
    String? bestService;
    double bestScore = -1;
    
    for (final serviceName in serviceOptions) {
      final health = _serviceHealth[serviceName];
      if (health == null || !health.isAvailable) continue;
      
      // Calculate service score based on success rate and response time
      final successScore = health.successRate / 100.0;
      final responseScore = max(0.0, 1.0 - (health.averageResponseTime.inSeconds / 10.0));
      final score = (successScore * 0.7) + (responseScore * 0.3);
      
      if (score > bestScore) {
        bestScore = score;
        bestService = serviceName;
      }
    }
    
    return bestService;
  }

  /// Get services that need attention (poor health)
  List<ServiceHealth> getUnhealthyServices() {
    return _serviceHealth.values
        .where((health) => !isServiceHealthy(health.serviceName))
        .toList();
  }

  /// Get overall system health score (0-100)
  double getOverallHealthScore() {
    if (_serviceHealth.isEmpty) return 0.0;
    
    final totalScore = _serviceHealth.values.fold<double>(
      0.0,
      (sum, health) => sum + (health.isAvailable ? health.successRate : 0.0),
    );
    
    return totalScore / _serviceHealth.length;
  }

  void _initializeServices() {
    final services = [
      'nominatim',
      'openrouteservice', 
      'osm_tiles',
      'google_maps',
      'google_geocoding',
      'google_directions',
    ];
    
    for (final serviceName in services) {
      _serviceHealth[serviceName] = ServiceHealth.healthy(serviceName);
      _recentResponseTimes[serviceName] = [];
      _recentResults[serviceName] = [];
    }
    
    notifyListeners();
  }

  void _updateServiceHealth(String serviceName, bool success, Duration responseTime) {
    // Initialize if not exists
    if (!_serviceHealth.containsKey(serviceName)) {
      _serviceHealth[serviceName] = ServiceHealth.healthy(serviceName);
      _recentResponseTimes[serviceName] = [];
      _recentResults[serviceName] = [];
    }
    
    final currentHealth = _serviceHealth[serviceName]!;
    
    // Update service health based on success/failure
    if (success) {
      _serviceHealth[serviceName] = currentHealth.recordSuccess(responseTime);
    } else {
      _serviceHealth[serviceName] = currentHealth.recordFailure('Request failed');
    }
    
    notifyListeners();
  }

  Duration _calculateAverageResponseTime(List<Duration> responseTimes) {
    if (responseTimes.isEmpty) return Duration.zero;
    
    final totalMs = responseTimes.fold<int>(
      0, 
      (sum, duration) => sum + duration.inMilliseconds,
    );
    
    return Duration(milliseconds: totalMs ~/ responseTimes.length);
  }

  double _calculateSuccessRate(List<bool> results) {
    if (results.isEmpty) return 100.0;
    
    final successCount = results.where((result) => result).length;
    return (successCount / results.length) * 100.0;
  }

  bool _determineAvailability(List<bool> results, Duration avgResponseTime) {
    if (results.isEmpty) return true;
    
    // Service is unavailable if:
    // - Success rate is below 50% in recent calls
    // - Average response time is above 30 seconds
    // - Last 5 calls all failed
    
    final successRate = _calculateSuccessRate(results);
    if (successRate < 50.0) return false;
    
    if (avgResponseTime.inSeconds > 30) return false;
    
    if (results.length >= 5) {
      final lastFive = results.sublist(results.length - 5);
      if (lastFive.every((result) => !result)) return false;
    }
    
    return true;
  }

  Future<void> _performHealthChecks() async {
    // Perform lightweight health checks for each service
    // This is a simplified version - in production, you might want to make actual test requests
    
    for (final serviceName in _serviceHealth.keys) {
      try {
        // Simulate health check based on service type
        await _performServiceHealthCheck(serviceName);
      } catch (e) {
        // Health check failed
        recordFailure(serviceName, const Duration(seconds: 30), e.toString());
      }
    }
  }

  Future<void> _performServiceHealthCheck(String serviceName) async {
    // This is a placeholder for actual health checks
    // In a real implementation, you would make lightweight requests to each service
    
    switch (serviceName) {
      case 'nominatim':
        // Could make a simple geocoding request
        await Future.delayed(const Duration(milliseconds: 500));
        break;
      case 'openrouteservice':
        // Could check API status endpoint
        await Future.delayed(const Duration(milliseconds: 800));
        break;
      case 'osm_tiles':
        // Could request a single tile
        await Future.delayed(const Duration(milliseconds: 300));
        break;
      default:
        await Future.delayed(const Duration(milliseconds: 1000));
    }
    
    // Simulate occasional failures for testing
    if (DateTime.now().millisecond % 20 == 0) {
      throw Exception('Simulated health check failure');
    }
    
    recordSuccess(serviceName, const Duration(milliseconds: 500));
  }

  @override
  void dispose() {
    stopMonitoring();
    super.dispose();
  }
}