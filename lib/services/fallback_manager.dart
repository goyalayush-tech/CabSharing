import 'dart:async';
import 'dart:math';
import '../models/service_health.dart';

/// Interface for managing fallback services and service health monitoring
abstract class IFallbackManager {
  /// Execute a primary service with automatic fallback to secondary service
  Future<T> executeWithFallback<T>(
    Future<T> Function() primaryService,
    Future<T> Function() fallbackService,
    String operationType,
  );

  /// Report a service failure for health monitoring
  void reportServiceFailure(String serviceName, String operation);

  /// Report a service success for health monitoring
  void reportServiceSuccess(String serviceName, String operation);

  /// Check if fallback should be used for a service
  bool shouldUseFallback(String serviceName);

  /// Get current health status of a service
  ServiceHealth getServiceHealth(String serviceName);

  /// Get health status of all monitored services
  Map<String, ServiceHealth> getAllServiceHealth();

  /// Reset service health statistics
  void resetServiceHealth(String serviceName);

  /// Set service availability manually (for testing or maintenance)
  void setServiceAvailability(String serviceName, bool isAvailable);
}

/// Implementation of fallback service manager with health monitoring
class FallbackManager implements IFallbackManager {
  static const int _maxFailureCount = 5;
  static const Duration _recoveryWindow = Duration(minutes: 5);
  static const Duration _defaultTimeout = Duration(seconds: 10);

  final Map<String, ServiceHealth> _serviceHealthMap = {};
  final Map<String, List<DateTime>> _recentFailures = {};
  final Map<String, List<Duration>> _recentResponseTimes = {};
  final Map<String, bool> _manualAvailability = {};

  @override
  Future<T> executeWithFallback<T>(
    Future<T> Function() primaryService,
    Future<T> Function() fallbackService,
    String operationType,
  ) async {
    final stopwatch = Stopwatch()..start();
    
    try {
      // Try primary service first if it's healthy
      if (!shouldUseFallback('primary_$operationType')) {
        final result = await primaryService().timeout(_defaultTimeout);
        stopwatch.stop();
        reportServiceSuccess('primary_$operationType', operationType);
        _recordResponseTime('primary_$operationType', stopwatch.elapsed);
        return result;
      }
    } catch (e) {
      stopwatch.stop();
      reportServiceFailure('primary_$operationType', operationType);
      // Continue to fallback service
    }

    // Try fallback service
    stopwatch.reset();
    stopwatch.start();
    
    try {
      final result = await fallbackService().timeout(_defaultTimeout);
      stopwatch.stop();
      reportServiceSuccess('fallback_$operationType', operationType);
      _recordResponseTime('fallback_$operationType', stopwatch.elapsed);
      return result;
    } catch (e) {
      stopwatch.stop();
      reportServiceFailure('fallback_$operationType', operationType);
      rethrow;
    }
  }

  @override
  void reportServiceFailure(String serviceName, String operation) {
    final now = DateTime.now();
    
    // Initialize if not exists
    _recentFailures.putIfAbsent(serviceName, () => []);
    
    // Add failure timestamp
    _recentFailures[serviceName]!.add(now);
    
    // Clean old failures outside recovery window
    _recentFailures[serviceName]!.removeWhere(
      (failure) => now.difference(failure) > _recoveryWindow,
    );
    
    // Update service health
    _updateServiceHealth(serviceName);
  }

  @override
  void reportServiceSuccess(String serviceName, String operation) {
    final now = DateTime.now();
    
    // Clean old failures on success
    _recentFailures.putIfAbsent(serviceName, () => []);
    _recentFailures[serviceName]!.removeWhere(
      (failure) => now.difference(failure) > _recoveryWindow,
    );
    
    // Record response time for success (using a default value for manual reports)
    _recordResponseTime(serviceName, Duration(milliseconds: 500));
    
    // Update service health
    _updateServiceHealth(serviceName);
  }

  @override
  bool shouldUseFallback(String serviceName) {
    // Check manual availability override
    if (_manualAvailability.containsKey(serviceName)) {
      return !_manualAvailability[serviceName]!;
    }
    
    final health = getServiceHealth(serviceName);
    
    // Use fallback if service has too many recent failures
    return health.failureCount >= _maxFailureCount || 
           health.successRate < 0.5;
  }

  @override
  ServiceHealth getServiceHealth(String serviceName) {
    if (_serviceHealthMap.containsKey(serviceName)) {
      return _serviceHealthMap[serviceName]!;
    }
    
    // Create default health status
    return ServiceHealth(
      serviceName: serviceName,
      isAvailable: true,
      averageResponseTime: Duration.zero,
      failureCount: 0,
      lastFailure: null,
      successRate: 1.0,
      lastChecked: DateTime.now(),
      totalRequests: 0,
      successfulRequests: 0,
    );
  }

  @override
  Map<String, ServiceHealth> getAllServiceHealth() {
    return Map.unmodifiable(_serviceHealthMap);
  }

  @override
  void resetServiceHealth(String serviceName) {
    _recentFailures.remove(serviceName);
    _recentResponseTimes.remove(serviceName);
    _serviceHealthMap.remove(serviceName);
    _manualAvailability.remove(serviceName);
  }

  @override
  void setServiceAvailability(String serviceName, bool isAvailable) {
    _manualAvailability[serviceName] = isAvailable;
    _updateServiceHealth(serviceName);
  }

  void _updateServiceHealth(String serviceName) {
    final now = DateTime.now();
    final failures = _recentFailures[serviceName] ?? [];
    final responseTimes = _recentResponseTimes[serviceName] ?? [];
    
    // Clean old failures outside recovery window
    failures.removeWhere((failure) => now.difference(failure) > _recoveryWindow);
    
    // Calculate average response time
    Duration averageResponseTime = Duration.zero;
    if (responseTimes.isNotEmpty) {
      final totalMs = responseTimes
          .map((d) => d.inMilliseconds)
          .reduce((a, b) => a + b);
      averageResponseTime = Duration(milliseconds: totalMs ~/ responseTimes.length);
    }
    
    // Calculate success rate (based on recent activity)
    double successRate = 1.0;
    final totalRequests = failures.length + responseTimes.length;
    if (totalRequests > 0) {
      successRate = responseTimes.length / totalRequests;
    }
    
    // Determine availability
    bool isAvailable = true;
    if (_manualAvailability.containsKey(serviceName)) {
      isAvailable = _manualAvailability[serviceName]!;
    } else {
      isAvailable = failures.length < _maxFailureCount && successRate >= 0.5;
    }
    
    // Get last failure
    DateTime? lastFailure;
    if (failures.isNotEmpty) {
      lastFailure = failures.last;
    }
    
    _serviceHealthMap[serviceName] = ServiceHealth(
      serviceName: serviceName,
      isAvailable: isAvailable,
      averageResponseTime: averageResponseTime,
      failureCount: failures.length,
      lastFailure: lastFailure,
      successRate: successRate,
      lastChecked: DateTime.now(),
      totalRequests: failures.length + responseTimes.length,
      successfulRequests: responseTimes.length,
    );
  }

  void _recordResponseTime(String serviceName, Duration responseTime) {
    _recentResponseTimes.putIfAbsent(serviceName, () => []);
    _recentResponseTimes[serviceName]!.add(responseTime);
    
    // Keep only recent response times (last 20 requests)
    if (_recentResponseTimes[serviceName]!.length > 20) {
      _recentResponseTimes[serviceName]!.removeAt(0);
    }
  }
}