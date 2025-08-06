import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'map_analytics_service.dart';
import 'service_health_monitor.dart';

/// Comprehensive monitoring service that coordinates analytics and health monitoring
class MapServiceMonitor extends ChangeNotifier {
  static final MapServiceMonitor _instance = MapServiceMonitor._internal();
  factory MapServiceMonitor() => _instance;
  MapServiceMonitor._internal();

  final MapAnalyticsService _analytics = MapAnalyticsService();
  final ServiceHealthMonitor _healthMonitor = ServiceHealthMonitor();
  
  Timer? _reportingTimer;
  Timer? _alertTimer;
  
  // Alert thresholds
  static const double _errorRateThreshold = 10.0; // 10% error rate
  static const double _responseTimeThreshold = 5000.0; // 5 seconds
  static const double _healthScoreThreshold = 70.0; // 70% health score
  
  // Reporting configuration
  bool _enablePeriodicReporting = true;
  Duration _reportingInterval = const Duration(minutes: 15);
  
  /// Initialize the monitoring system
  Future<void> initialize() async {
    await _loadConfiguration();
    
    _analytics.startSession();
    _healthMonitor.startMonitoring();
    
    if (_enablePeriodicReporting) {
      _startPeriodicReporting();
    }
    
    _startAlertMonitoring();
    
    if (kDebugMode) {
      print('Map Service Monitor initialized');
    }
  }

  /// Stop all monitoring activities
  void shutdown() {
    _reportingTimer?.cancel();
    _alertTimer?.cancel();
    _healthMonitor.stopMonitoring();
    
    if (kDebugMode) {
      print('Map Service Monitor shutdown');
    }
  }

  /// Track a service operation with comprehensive monitoring
  Future<T> trackServiceOperation<T>(
    String serviceName,
    String operation,
    Future<T> Function() serviceCall,
  ) async {
    final startTime = DateTime.now();
    
    try {
      // Execute the service call with analytics tracking
      final result = await _analytics.trackApiCall(
        serviceName,
        operation,
        serviceCall,
      );
      
      // Record success in health monitor
      final responseTime = DateTime.now().difference(startTime);
      _healthMonitor.recordSuccess(serviceName, responseTime);
      
      return result;
    } catch (error) {
      // Record failure in health monitor
      final responseTime = DateTime.now().difference(startTime);
      _healthMonitor.recordFailure(serviceName, responseTime, error.toString());
      
      rethrow;
    }
  }

  /// Get comprehensive service status
  Map<String, dynamic> getServiceStatus() {
    final analyticsSummary = _analytics.getAnalyticsSummary();
    final healthStatus = _healthMonitor.getAllServiceHealth();
    final performanceMetrics = _analytics.getPerformanceMetrics();
    final rateLimitStatus = _analytics.getRateLimitStatus();
    
    return {
      'timestamp': DateTime.now().toIso8601String(),
      'analytics': analyticsSummary,
      'health': healthStatus.map((key, value) => MapEntry(key, value.toJson())),
      'performance': performanceMetrics,
      'rateLimits': rateLimitStatus,
      'overallHealthScore': _healthMonitor.getOverallHealthScore(),
      'alerts': _checkForAlerts(),
    };
  }

  /// Check for service alerts based on thresholds
  List<Map<String, dynamic>> _checkForAlerts() {
    final alerts = <Map<String, dynamic>>[];
    final summary = _analytics.getAnalyticsSummary();
    final healthStatus = _healthMonitor.getAllServiceHealth();
    final performanceMetrics = _analytics.getPerformanceMetrics();
    
    // Check overall error rate
    final overallSuccessRate = summary['successRate'] as double;
    final overallErrorRate = (1.0 - overallSuccessRate) * 100;
    
    if (overallErrorRate > _errorRateThreshold) {
      alerts.add({
        'type': 'high_error_rate',
        'severity': 'warning',
        'message': 'Overall error rate is ${overallErrorRate.toStringAsFixed(1)}%',
        'threshold': _errorRateThreshold,
        'currentValue': overallErrorRate,
        'timestamp': DateTime.now().toIso8601String(),
      });
    }
    
    // Check individual service health
    for (final entry in healthStatus.entries) {
      final serviceName = entry.key;
      final health = entry.value;
      
      if (!health.isHealthy) {
        alerts.add({
          'type': 'unhealthy_service',
          'severity': health.isAvailable ? 'warning' : 'critical',
          'message': 'Service $serviceName is ${health.status.toLowerCase()}',
          'serviceName': serviceName,
          'healthScore': health.healthScore,
          'timestamp': DateTime.now().toIso8601String(),
        });
      }
      
      // Check response time
      final metrics = performanceMetrics[serviceName];
      if (metrics != null) {
        final avgResponseTime = metrics['averageResponseTime'] as double;
        if (avgResponseTime > _responseTimeThreshold) {
          alerts.add({
            'type': 'slow_response',
            'severity': 'warning',
            'message': 'Service $serviceName has slow response time: ${avgResponseTime.toStringAsFixed(0)}ms',
            'serviceName': serviceName,
            'threshold': _responseTimeThreshold,
            'currentValue': avgResponseTime,
            'timestamp': DateTime.now().toIso8601String(),
          });
        }
      }
    }
    
    // Check overall system health
    final overallHealth = _healthMonitor.getOverallHealthScore();
    if (overallHealth < _healthScoreThreshold) {
      alerts.add({
        'type': 'low_system_health',
        'severity': 'critical',
        'message': 'Overall system health is low: ${overallHealth.toStringAsFixed(1)}%',
        'threshold': _healthScoreThreshold,
        'currentValue': overallHealth,
        'timestamp': DateTime.now().toIso8601String(),
      });
    }
    
    return alerts;
  }

  /// Generate a comprehensive monitoring report
  Map<String, dynamic> generateReport() {
    final status = getServiceStatus();
    final errorLog = _analytics.getErrorLog(limit: 20);
    final unhealthyServices = _healthMonitor.getUnhealthyServices();
    
    return {
      'reportId': DateTime.now().millisecondsSinceEpoch.toString(),
      'generatedAt': DateTime.now().toIso8601String(),
      'status': status,
      'recentErrors': errorLog,
      'unhealthyServices': unhealthyServices.map((s) => s.toJson()).toList(),
      'recommendations': _generateRecommendations(status, unhealthyServices),
    };
  }

  /// Generate recommendations based on current status
  List<String> _generateRecommendations(
    Map<String, dynamic> status,
    List<dynamic> unhealthyServices,
  ) {
    final recommendations = <String>[];
    final analytics = status['analytics'] as Map<String, dynamic>;
    final overallHealth = status['overallHealthScore'] as double;
    
    // Cache hit rate recommendations
    final cacheHitRate = analytics['cacheHitRate'] as double;
    if (cacheHitRate < 70.0) {
      recommendations.add('Consider increasing cache size or duration to improve cache hit rate (currently ${cacheHitRate.toStringAsFixed(1)}%)');
    }
    
    // Error rate recommendations
    final successRate = analytics['successRate'] as double;
    final errorRate = (1.0 - successRate) * 100;
    if (errorRate > 5.0) {
      recommendations.add('High error rate detected (${errorRate.toStringAsFixed(1)}%). Review error logs and consider implementing fallback services');
    }
    
    // Health recommendations
    if (overallHealth < 80.0) {
      recommendations.add('System health is below optimal (${overallHealth.toStringAsFixed(1)}%). Check individual service health and consider service rotation');
    }
    
    // Service-specific recommendations
    if (unhealthyServices.isNotEmpty) {
      recommendations.add('${unhealthyServices.length} service(s) are unhealthy. Consider implementing circuit breakers or switching to backup services');
    }
    
    // Rate limiting recommendations
    final rateLimits = status['rateLimits'] as Map<String, dynamic>;
    for (final entry in rateLimits.entries) {
      final serviceName = entry.key;
      final limitStatus = entry.value as Map<String, dynamic>;
      final isThrottled = limitStatus['isThrottled'] as bool;
      
      if (isThrottled) {
        recommendations.add('Service $serviceName is being rate limited. Consider implementing request queuing or using multiple API keys');
      }
    }
    
    if (recommendations.isEmpty) {
      recommendations.add('All services are operating within normal parameters');
    }
    
    return recommendations;
  }

  /// Save monitoring report to local storage
  Future<void> saveReport(Map<String, dynamic> report) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final reportsKey = 'map_service_reports';
      final existingReports = prefs.getStringList(reportsKey) ?? [];
      
      // Convert report to JSON-safe format
      final jsonSafeReport = _makeJsonSafe(report);
      
      // Add new report
      existingReports.add(jsonEncode(jsonSafeReport));
      
      // Keep only last 10 reports
      if (existingReports.length > 10) {
        existingReports.removeAt(0);
      }
      
      await prefs.setStringList(reportsKey, existingReports);
      
      if (kDebugMode) {
        print('Monitoring report saved: ${report['reportId']}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Failed to save monitoring report: $e');
      }
    }
  }

  /// Convert complex objects to JSON-safe format
  Map<String, dynamic> _makeJsonSafe(Map<String, dynamic> data) {
    final result = <String, dynamic>{};
    
    for (final entry in data.entries) {
      final key = entry.key;
      final value = entry.value;
      
      if (value is Duration) {
        result[key] = value.inMilliseconds;
      } else if (value is DateTime) {
        result[key] = value.toIso8601String();
      } else if (value is Map<String, dynamic>) {
        result[key] = _makeJsonSafe(value);
      } else if (value is List) {
        result[key] = value.map((item) {
          if (item is Map<String, dynamic>) {
            return _makeJsonSafe(item);
          }
          return item;
        }).toList();
      } else {
        result[key] = value;
      }
    }
    
    return result;
  }

  /// Load saved monitoring reports
  Future<List<Map<String, dynamic>>> loadSavedReports() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final reportsKey = 'map_service_reports';
      final reportStrings = prefs.getStringList(reportsKey) ?? [];
      
      return reportStrings
          .map((reportString) => jsonDecode(reportString) as Map<String, dynamic>)
          .toList();
    } catch (e) {
      if (kDebugMode) {
        print('Failed to load monitoring reports: $e');
      }
      return [];
    }
  }

  void _startPeriodicReporting() {
    _reportingTimer?.cancel();
    _reportingTimer = Timer.periodic(_reportingInterval, (_) async {
      final report = generateReport();
      await saveReport(report);
      
      if (kDebugMode) {
        print('Periodic monitoring report generated');
      }
    });
  }

  void _startAlertMonitoring() {
    _alertTimer?.cancel();
    _alertTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      final alerts = _checkForAlerts();
      
      if (alerts.isNotEmpty) {
        _handleAlerts(alerts);
      }
    });
  }

  void _handleAlerts(List<Map<String, dynamic>> alerts) {
    for (final alert in alerts) {
      if (kDebugMode) {
        print('ALERT [${alert['severity']}]: ${alert['message']}');
      }
      
      // Could integrate with notification system here
      // NotificationService.showAlert(alert);
    }
    
    notifyListeners(); // Notify UI about alerts
  }

  Future<void> _loadConfiguration() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _enablePeriodicReporting = prefs.getBool('enable_periodic_reporting') ?? true;
      
      final intervalMinutes = prefs.getInt('reporting_interval_minutes') ?? 15;
      _reportingInterval = Duration(minutes: intervalMinutes);
    } catch (e) {
      if (kDebugMode) {
        print('Failed to load monitoring configuration: $e');
      }
    }
  }

  /// Update monitoring configuration
  Future<void> updateConfiguration({
    bool? enablePeriodicReporting,
    Duration? reportingInterval,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      if (enablePeriodicReporting != null) {
        _enablePeriodicReporting = enablePeriodicReporting;
        await prefs.setBool('enable_periodic_reporting', enablePeriodicReporting);
        
        if (enablePeriodicReporting) {
          _startPeriodicReporting();
        } else {
          _reportingTimer?.cancel();
        }
      }
      
      if (reportingInterval != null) {
        _reportingInterval = reportingInterval;
        await prefs.setInt('reporting_interval_minutes', reportingInterval.inMinutes);
        
        if (_enablePeriodicReporting) {
          _startPeriodicReporting();
        }
      }
      
      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        print('Failed to update monitoring configuration: $e');
      }
    }
  }

  // Getters for accessing individual services
  MapAnalyticsService get analytics => _analytics;
  ServiceHealthMonitor get healthMonitor => _healthMonitor;
  
  @override
  void dispose() {
    shutdown();
    super.dispose();
  }
}