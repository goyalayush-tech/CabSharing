import 'dart:async';
import 'dart:collection';
import 'package:flutter/foundation.dart';

/// Service for tracking and analyzing map service usage and performance
class MapAnalyticsService extends ChangeNotifier {
  static final MapAnalyticsService _instance = MapAnalyticsService._internal();
  factory MapAnalyticsService() => _instance;
  MapAnalyticsService._internal();

  // Usage tracking
  final Map<String, int> _apiCallCounts = {};
  final Map<String, List<Duration>> _responseTimes = {};
  final Map<String, int> _errorCounts = {};
  final Map<String, DateTime> _lastApiCall = {};
  
  // Rate limiting
  final Map<String, Queue<DateTime>> _requestHistory = {};
  final Map<String, int> _rateLimits = {
    'nominatim': 1, // 1 request per second
    'openrouteservice': 40, // 40 requests per minute
    'osm_tiles': 2, // 2 requests per second
  };
  
  // Performance metrics
  final Map<String, double> _averageResponseTimes = {};
  final Map<String, double> _successRates = {};
  
  // Analytics data
  DateTime? _sessionStart;
  int _totalRequests = 0;
  int _totalErrors = 0;
  int _cacheHits = 0;
  int _cacheMisses = 0;
  
  // Error logging
  final List<Map<String, dynamic>> _errorLog = [];

  /// Initialize analytics session
  void startSession() {
    _sessionStart = DateTime.now();
    _totalRequests = 0;
    _totalErrors = 0;
    _cacheHits = 0;
    _cacheMisses = 0;
    notifyListeners();
  }

  /// Track an API call with timing
  Future<T> trackApiCall<T>(
    String serviceName,
    String operation,
    Future<T> Function() apiCall,
  ) async {
    final startTime = DateTime.now();
    _totalRequests++;
    
    // Update API call count
    _apiCallCounts[serviceName] = (_apiCallCounts[serviceName] ?? 0) + 1;
    _lastApiCall[serviceName] = startTime;
    
    try {
      final result = await apiCall();
      
      // Track successful response time
      final responseTime = DateTime.now().difference(startTime);
      _recordResponseTime(serviceName, responseTime);
      
      notifyListeners();
      return result;
    } catch (error) {
      // Track error
      _totalErrors++;
      _errorCounts[serviceName] = (_errorCounts[serviceName] ?? 0) + 1;
      _recordError(serviceName, operation, error);
      
      notifyListeners();
      rethrow;
    }
  }

  /// Check if request is within rate limits
  bool canMakeRequest(String serviceName) {
    final limit = _rateLimits[serviceName];
    if (limit == null) return true;
    
    final now = DateTime.now();
    final history = _requestHistory[serviceName] ??= Queue<DateTime>();
    
    // Clean old requests (older than 1 minute)
    while (history.isNotEmpty && 
           now.difference(history.first).inMinutes >= 1) {
      history.removeFirst();
    }
    
    // Check rate limit
    if (serviceName == 'nominatim') {
      // 1 request per second
      return history.isEmpty || 
             now.difference(history.last).inSeconds >= 1;
    } else if (serviceName == 'openrouteservice') {
      // 40 requests per minute
      return history.length < 40;
    } else if (serviceName == 'osm_tiles') {
      // 2 requests per second
      final recentRequests = history.where(
        (time) => now.difference(time).inSeconds < 1
      ).length;
      return recentRequests < 2;
    }
    
    return true;
  }

  /// Record a request for rate limiting
  void recordRequest(String serviceName) {
    final history = _requestHistory[serviceName] ??= Queue<DateTime>();
    history.add(DateTime.now());
  }

  /// Track cache hit
  void trackCacheHit(String serviceName) {
    _cacheHits++;
    notifyListeners();
  }

  /// Track cache miss
  void trackCacheMiss(String serviceName) {
    _cacheMisses++;
    notifyListeners();
  }

  /// Get usage statistics for a service
  Map<String, dynamic> getServiceStats(String serviceName) {
    final callCount = _apiCallCounts[serviceName] ?? 0;
    final errorCount = _errorCounts[serviceName] ?? 0;
    final avgResponseTime = _averageResponseTimes[serviceName] ?? 0.0;
    final successRate = _successRates[serviceName] ?? 1.0;
    
    return {
      'serviceName': serviceName,
      'totalCalls': callCount,
      'errorCount': errorCount,
      'successCount': callCount - errorCount,
      'averageResponseTime': avgResponseTime,
      'successRate': successRate,
      'lastCall': _lastApiCall[serviceName],
    };
  }

  /// Get overall analytics summary
  Map<String, dynamic> getAnalyticsSummary() {
    final sessionDuration = _sessionStart != null 
        ? DateTime.now().difference(_sessionStart!)
        : Duration.zero;
    
    final cacheHitRate = (_cacheHits + _cacheMisses) > 0 
        ? (_cacheHits / (_cacheHits + _cacheMisses)) * 100 
        : 0.0;
    
    return {
      'sessionDuration': sessionDuration,
      'totalRequests': _totalRequests,
      'totalErrors': _totalErrors,
      'successRate': _totalRequests > 0 
          ? (_totalRequests - _totalErrors) / _totalRequests 
          : 1.0,
      'cacheHits': _cacheHits,
      'cacheMisses': _cacheMisses,
      'cacheHitRate': cacheHitRate,
      'services': _apiCallCounts.keys.map((service) => getServiceStats(service)).toList(),
      'recentErrors': _errorLog.take(10).toList(),
      'errorsByService': _getErrorsByService(),
    };
  }

  /// Get error logs for debugging and monitoring
  List<Map<String, dynamic>> getErrorLog({int? limit}) {
    if (limit != null && limit < _errorLog.length) {
      return _errorLog.sublist(_errorLog.length - limit);
    }
    return List.from(_errorLog);
  }

  /// Get errors grouped by service
  Map<String, List<Map<String, dynamic>>> _getErrorsByService() {
    final errorsByService = <String, List<Map<String, dynamic>>>{};
    
    for (final error in _errorLog) {
      final serviceName = error['serviceName'] as String;
      errorsByService.putIfAbsent(serviceName, () => []).add(error);
    }
    
    return errorsByService;
  }

  /// Get rate limit status for all services
  Map<String, Map<String, dynamic>> getRateLimitStatus() {
    final status = <String, Map<String, dynamic>>{};
    
    for (final serviceName in _rateLimits.keys) {
      final limit = _rateLimits[serviceName]!;
      final history = _requestHistory[serviceName] ?? Queue<DateTime>();
      final now = DateTime.now();
      
      int currentUsage = 0;
      Duration resetTime = Duration.zero;
      
      if (serviceName == 'nominatim') {
        currentUsage = history.isNotEmpty && 
                      now.difference(history.last).inSeconds < 1 ? 1 : 0;
        resetTime = currentUsage > 0 
            ? Duration(seconds: 1 - now.difference(history.last).inSeconds)
            : Duration.zero;
      } else if (serviceName == 'openrouteservice') {
        currentUsage = history.where(
          (time) => now.difference(time).inMinutes < 1
        ).length;
        resetTime = history.isNotEmpty 
            ? const Duration(minutes: 1) - now.difference(history.first)
            : Duration.zero;
      } else if (serviceName == 'osm_tiles') {
        currentUsage = history.where(
          (time) => now.difference(time).inSeconds < 1
        ).length;
        resetTime = currentUsage > 0 
            ? const Duration(seconds: 1) - now.difference(
                history.where((time) => now.difference(time).inSeconds < 1).first
              )
            : Duration.zero;
      }
      
      status[serviceName] = {
        'limit': limit,
        'currentUsage': currentUsage,
        'remainingRequests': limit - currentUsage,
        'resetTime': resetTime,
        'isThrottled': currentUsage >= limit,
      };
    }
    
    return status;
  }

  void _recordResponseTime(String serviceName, Duration responseTime) {
    final times = _responseTimes[serviceName] ??= [];
    times.add(responseTime);
    
    // Keep only last 100 response times
    if (times.length > 100) {
      times.removeAt(0);
    }
    
    // Calculate average
    final totalMs = times.fold<int>(0, (sum, time) => sum + time.inMilliseconds);
    _averageResponseTimes[serviceName] = totalMs / times.length;
    
    // Calculate success rate
    final totalCalls = _apiCallCounts[serviceName] ?? 0;
    final errors = _errorCounts[serviceName] ?? 0;
    _successRates[serviceName] = totalCalls > 0 
        ? (totalCalls - errors) / totalCalls 
        : 1.0;
  }

  void _recordError(String serviceName, String operation, dynamic error) {
    // Log error for debugging
    if (kDebugMode) {
      print('Map Service Error - $serviceName.$operation: $error');
    }
    
    // Store detailed error information
    final errorDetails = {
      'serviceName': serviceName,
      'operation': operation,
      'error': error.toString(),
      'timestamp': DateTime.now().toIso8601String(),
      'stackTrace': StackTrace.current.toString(),
    };
    
    // Add to error log (keep last 100 errors)
    _errorLog.add(errorDetails);
    if (_errorLog.length > 100) {
      _errorLog.removeAt(0);
    }
    
    // Could integrate with crash reporting service here
    // FirebaseCrashlytics.instance.recordError(error, stackTrace, fatal: false);
  }

  /// Get performance metrics for all services
  Map<String, Map<String, dynamic>> getPerformanceMetrics() {
    final metrics = <String, Map<String, dynamic>>{};
    
    for (final serviceName in _apiCallCounts.keys) {
      final responseTimes = _responseTimes[serviceName] ?? [];
      
      if (responseTimes.isNotEmpty) {
        final sortedTimes = List<Duration>.from(responseTimes)..sort();
        final p50Index = (sortedTimes.length * 0.5).floor();
        final p95Index = (sortedTimes.length * 0.95).floor();
        final p99Index = (sortedTimes.length * 0.99).floor();
        
        metrics[serviceName] = {
          'averageResponseTime': _averageResponseTimes[serviceName] ?? 0.0,
          'p50ResponseTime': sortedTimes[p50Index].inMilliseconds,
          'p95ResponseTime': sortedTimes[p95Index].inMilliseconds,
          'p99ResponseTime': sortedTimes[p99Index].inMilliseconds,
          'minResponseTime': sortedTimes.first.inMilliseconds,
          'maxResponseTime': sortedTimes.last.inMilliseconds,
          'totalRequests': _apiCallCounts[serviceName] ?? 0,
          'errorRate': _calculateErrorRate(serviceName),
          'requestsPerMinute': _calculateRequestsPerMinute(serviceName),
        };
      }
    }
    
    return metrics;
  }

  double _calculateErrorRate(String serviceName) {
    final totalCalls = _apiCallCounts[serviceName] ?? 0;
    final errors = _errorCounts[serviceName] ?? 0;
    return totalCalls > 0 ? (errors / totalCalls) * 100 : 0.0; // Keep as percentage for display
  }

  double _calculateRequestsPerMinute(String serviceName) {
    if (_sessionStart == null) return 0.0;
    
    final sessionMinutes = DateTime.now().difference(_sessionStart!).inMinutes;
    final totalCalls = _apiCallCounts[serviceName] ?? 0;
    
    return sessionMinutes > 0 ? totalCalls / sessionMinutes : 0.0;
  }

  /// Export analytics data for external analysis
  Map<String, dynamic> exportAnalyticsData() {
    return {
      'summary': getAnalyticsSummary(),
      'serviceStats': _apiCallCounts.keys.map((service) => getServiceStats(service)).toList(),
      'performanceMetrics': getPerformanceMetrics(),
      'rateLimitStatus': getRateLimitStatus(),
      'errorLog': getErrorLog(),
      'exportedAt': DateTime.now().toIso8601String(),
    };
  }

  /// Reset all analytics data
  void reset() {
    _apiCallCounts.clear();
    _responseTimes.clear();
    _errorCounts.clear();
    _lastApiCall.clear();
    _requestHistory.clear();
    _averageResponseTimes.clear();
    _successRates.clear();
    _errorLog.clear();
    _sessionStart = null;
    _totalRequests = 0;
    _totalErrors = 0;
    _cacheHits = 0;
    _cacheMisses = 0;
    notifyListeners();
  }
}