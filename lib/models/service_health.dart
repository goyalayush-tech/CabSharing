import 'package:hive/hive.dart';

part 'service_health.g.dart';

@HiveType(typeId: 1)
class ServiceHealth extends HiveObject {
  @HiveField(0)
  final String serviceName;

  @HiveField(1)
  final bool isAvailable;

  @HiveField(2)
  final Duration averageResponseTime;

  @HiveField(3)
  final int failureCount;

  @HiveField(4)
  final DateTime? lastFailure;

  @HiveField(5)
  final double successRate;

  @HiveField(6)
  final DateTime lastChecked;

  @HiveField(7)
  final int totalRequests;

  @HiveField(8)
  final int successfulRequests;

  @HiveField(9)
  final String? lastError;

  ServiceHealth({
    required this.serviceName,
    required this.isAvailable,
    required this.averageResponseTime,
    required this.failureCount,
    this.lastFailure,
    required this.successRate,
    required this.lastChecked,
    required this.totalRequests,
    required this.successfulRequests,
    this.lastError,
  });

  /// Creates a new ServiceHealth with default healthy values
  factory ServiceHealth.healthy(String serviceName) {
    return ServiceHealth(
      serviceName: serviceName,
      isAvailable: true,
      averageResponseTime: const Duration(milliseconds: 500),
      failureCount: 0,
      successRate: 1.0,
      lastChecked: DateTime.now(),
      totalRequests: 0,
      successfulRequests: 0,
    );
  }

  /// Creates a new ServiceHealth with unhealthy values
  factory ServiceHealth.unhealthy(String serviceName, String error) {
    return ServiceHealth(
      serviceName: serviceName,
      isAvailable: false,
      averageResponseTime: const Duration(seconds: 30),
      failureCount: 1,
      lastFailure: DateTime.now(),
      successRate: 0.0,
      lastChecked: DateTime.now(),
      totalRequests: 1,
      successfulRequests: 0,
      lastError: error,
    );
  }

  /// Records a successful request
  ServiceHealth recordSuccess(Duration responseTime) {
    final newTotalRequests = totalRequests + 1;
    final newSuccessfulRequests = successfulRequests + 1;
    final newSuccessRate = newSuccessfulRequests / newTotalRequests;
    
    // Calculate new average response time
    final totalTime = averageResponseTime.inMilliseconds * successfulRequests;
    final newAverageTime = Duration(
      milliseconds: ((totalTime + responseTime.inMilliseconds) / newSuccessfulRequests).round(),
    );

    return copyWith(
      isAvailable: true,
      averageResponseTime: newAverageTime,
      successRate: newSuccessRate,
      lastChecked: DateTime.now(),
      totalRequests: newTotalRequests,
      successfulRequests: newSuccessfulRequests,
      lastError: null,
    );
  }

  /// Records a failed request
  ServiceHealth recordFailure(String error) {
    final newTotalRequests = totalRequests + 1;
    final newFailureCount = failureCount + 1;
    final newSuccessRate = successfulRequests / newTotalRequests;
    
    // Mark as unavailable if failure rate is too high
    final isStillAvailable = newSuccessRate > 0.5 && newFailureCount < 5;

    return copyWith(
      isAvailable: isStillAvailable,
      failureCount: newFailureCount,
      lastFailure: DateTime.now(),
      successRate: newSuccessRate,
      lastChecked: DateTime.now(),
      totalRequests: newTotalRequests,
      lastError: error,
    );
  }

  /// Checks if the service should be considered healthy
  bool get isHealthy {
    return isAvailable && 
           successRate > 0.8 && 
           averageResponseTime.inSeconds < 10 &&
           failureCount < 3;
  }

  /// Checks if the service data is stale
  bool get isStale {
    return DateTime.now().difference(lastChecked).inMinutes > 5;
  }

  /// Gets a health score from 0.0 to 1.0
  double get healthScore {
    if (!isAvailable) return 0.0;
    
    double score = successRate * 0.6; // 60% weight on success rate
    
    // Response time score (faster is better)
    final responseScore = 1.0 - (averageResponseTime.inMilliseconds / 10000).clamp(0.0, 1.0);
    score += responseScore * 0.3; // 30% weight on response time
    
    // Failure count score (fewer failures is better)
    final failureScore = 1.0 - (failureCount / 10).clamp(0.0, 1.0);
    score += failureScore * 0.1; // 10% weight on failure count
    
    return score.clamp(0.0, 1.0);
  }

  /// Gets a human-readable status
  String get status {
    if (!isAvailable) return 'Unavailable';
    if (healthScore > 0.8) return 'Healthy';
    if (healthScore > 0.5) return 'Degraded';
    return 'Poor';
  }

  ServiceHealth copyWith({
    String? serviceName,
    bool? isAvailable,
    Duration? averageResponseTime,
    int? failureCount,
    DateTime? lastFailure,
    double? successRate,
    DateTime? lastChecked,
    int? totalRequests,
    int? successfulRequests,
    String? lastError,
  }) {
    return ServiceHealth(
      serviceName: serviceName ?? this.serviceName,
      isAvailable: isAvailable ?? this.isAvailable,
      averageResponseTime: averageResponseTime ?? this.averageResponseTime,
      failureCount: failureCount ?? this.failureCount,
      lastFailure: lastFailure ?? this.lastFailure,
      successRate: successRate ?? this.successRate,
      lastChecked: lastChecked ?? this.lastChecked,
      totalRequests: totalRequests ?? this.totalRequests,
      successfulRequests: successfulRequests ?? this.successfulRequests,
      lastError: lastError,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'serviceName': serviceName,
      'isAvailable': isAvailable,
      'averageResponseTime': averageResponseTime.inMilliseconds,
      'failureCount': failureCount,
      'lastFailure': lastFailure?.toIso8601String(),
      'successRate': successRate,
      'lastChecked': lastChecked.toIso8601String(),
      'totalRequests': totalRequests,
      'successfulRequests': successfulRequests,
      'lastError': lastError,
      'healthScore': healthScore,
      'status': status,
    };
  }

  factory ServiceHealth.fromJson(Map<String, dynamic> json) {
    return ServiceHealth(
      serviceName: json['serviceName'] as String,
      isAvailable: json['isAvailable'] as bool,
      averageResponseTime: Duration(milliseconds: json['averageResponseTime'] as int),
      failureCount: json['failureCount'] as int,
      lastFailure: json['lastFailure'] != null 
          ? DateTime.parse(json['lastFailure'] as String)
          : null,
      successRate: (json['successRate'] as num).toDouble(),
      lastChecked: DateTime.parse(json['lastChecked'] as String),
      totalRequests: json['totalRequests'] as int,
      successfulRequests: json['successfulRequests'] as int,
      lastError: json['lastError'] as String?,
    );
  }

  @override
  String toString() {
    return 'ServiceHealth($serviceName: $status, '
           'success: ${(successRate * 100).toStringAsFixed(1)}%, '
           'avg: ${averageResponseTime.inMilliseconds}ms, '
           'failures: $failureCount)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ServiceHealth &&
        other.serviceName == serviceName &&
        other.isAvailable == isAvailable &&
        other.lastChecked == lastChecked;
  }

  @override
  int get hashCode {
    return Object.hash(serviceName, isAvailable, lastChecked);
  }
}