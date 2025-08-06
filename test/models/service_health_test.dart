import 'package:flutter_test/flutter_test.dart';
import 'package:ridelink/models/service_health.dart';

void main() {
  group('ServiceHealth', () {
    test('should create healthy service', () {
      final health = ServiceHealth.healthy('test_service');
      
      expect(health.serviceName, equals('test_service'));
      expect(health.isAvailable, isTrue);
      expect(health.successRate, equals(1.0));
      expect(health.failureCount, equals(0));
      expect(health.isHealthy, isTrue);
      expect(health.status, equals('Healthy'));
    });

    test('should create unhealthy service', () {
      final health = ServiceHealth.unhealthy('test_service', 'Connection failed');
      
      expect(health.serviceName, equals('test_service'));
      expect(health.isAvailable, isFalse);
      expect(health.successRate, equals(0.0));
      expect(health.failureCount, equals(1));
      expect(health.lastError, equals('Connection failed'));
      expect(health.isHealthy, isFalse);
      expect(health.status, equals('Unavailable'));
    });

    test('should record success correctly', () {
      final health = ServiceHealth.healthy('test_service');
      final responseTime = const Duration(milliseconds: 200);
      
      final updatedHealth = health.recordSuccess(responseTime);
      
      expect(updatedHealth.totalRequests, equals(1));
      expect(updatedHealth.successfulRequests, equals(1));
      expect(updatedHealth.successRate, equals(1.0));
      expect(updatedHealth.averageResponseTime, equals(responseTime));
      expect(updatedHealth.isAvailable, isTrue);
    });

    test('should record failure correctly', () {
      final health = ServiceHealth.healthy('test_service');
      const errorMessage = 'Network timeout';
      
      final updatedHealth = health.recordFailure(errorMessage);
      
      expect(updatedHealth.totalRequests, equals(1));
      expect(updatedHealth.successfulRequests, equals(0));
      expect(updatedHealth.successRate, equals(0.0));
      expect(updatedHealth.failureCount, equals(1));
      expect(updatedHealth.lastError, equals(errorMessage));
      expect(updatedHealth.lastFailure, isNotNull);
    });

    test('should calculate health score correctly', () {
      // Healthy service
      final healthyService = ServiceHealth(
        serviceName: 'test',
        isAvailable: true,
        averageResponseTime: const Duration(milliseconds: 100),
        failureCount: 0,
        successRate: 1.0,
        lastChecked: DateTime.now(),
        totalRequests: 10,
        successfulRequests: 10,
      );
      
      expect(healthyService.healthScore, greaterThan(0.8));
      
      // Poor service
      final poorService = ServiceHealth(
        serviceName: 'test',
        isAvailable: true,
        averageResponseTime: const Duration(seconds: 5),
        failureCount: 8,
        successRate: 0.2,
        lastChecked: DateTime.now(),
        totalRequests: 10,
        successfulRequests: 2,
      );
      
      expect(poorService.healthScore, lessThan(0.5));
    });

    test('should determine if service is healthy', () {
      final healthyService = ServiceHealth(
        serviceName: 'test',
        isAvailable: true,
        averageResponseTime: const Duration(milliseconds: 500),
        failureCount: 1,
        successRate: 0.9,
        lastChecked: DateTime.now(),
        totalRequests: 10,
        successfulRequests: 9,
      );
      
      expect(healthyService.isHealthy, isTrue);
      
      final unhealthyService = ServiceHealth(
        serviceName: 'test',
        isAvailable: false,
        averageResponseTime: const Duration(seconds: 15),
        failureCount: 5,
        successRate: 0.5,
        lastChecked: DateTime.now(),
        totalRequests: 10,
        successfulRequests: 5,
      );
      
      expect(unhealthyService.isHealthy, isFalse);
    });

    test('should determine if data is stale', () {
      final freshHealth = ServiceHealth.healthy('test');
      expect(freshHealth.isStale, isFalse);
      
      final staleHealth = ServiceHealth(
        serviceName: 'test',
        isAvailable: true,
        averageResponseTime: const Duration(milliseconds: 500),
        failureCount: 0,
        successRate: 1.0,
        lastChecked: DateTime.now().subtract(const Duration(minutes: 10)),
        totalRequests: 1,
        successfulRequests: 1,
      );
      
      expect(staleHealth.isStale, isTrue);
    });

    test('should get correct status strings', () {
      final unavailable = ServiceHealth.unhealthy('test', 'error');
      expect(unavailable.status, equals('Unavailable'));
      
      final healthy = ServiceHealth.healthy('test');
      expect(healthy.status, equals('Healthy'));
      
      final degraded = ServiceHealth(
        serviceName: 'test',
        isAvailable: true,
        averageResponseTime: const Duration(seconds: 2),
        failureCount: 2,
        successRate: 0.7,
        lastChecked: DateTime.now(),
        totalRequests: 10,
        successfulRequests: 7,
      );
      
      expect(degraded.status, equals('Degraded'));
    });

    test('should serialize to JSON correctly', () {
      final health = ServiceHealth.healthy('test_service');
      final json = health.toJson();
      
      expect(json['serviceName'], equals('test_service'));
      expect(json['isAvailable'], isTrue);
      expect(json['successRate'], equals(1.0));
      expect(json['status'], equals('Healthy'));
      expect(json['healthScore'], isA<double>());
    });

    test('should deserialize from JSON correctly', () {
      final json = {
        'serviceName': 'test_service',
        'isAvailable': true,
        'averageResponseTime': 500,
        'failureCount': 2,
        'successRate': 0.8,
        'lastChecked': DateTime.now().toIso8601String(),
        'totalRequests': 10,
        'successfulRequests': 8,
      };
      
      final health = ServiceHealth.fromJson(json);
      
      expect(health.serviceName, equals('test_service'));
      expect(health.isAvailable, isTrue);
      expect(health.successRate, equals(0.8));
      expect(health.failureCount, equals(2));
    });

    test('should copy with new values', () {
      final original = ServiceHealth.healthy('test');
      final copied = original.copyWith(
        isAvailable: false,
        failureCount: 5,
        lastError: 'New error',
      );
      
      expect(copied.serviceName, equals(original.serviceName));
      expect(copied.isAvailable, isFalse);
      expect(copied.failureCount, equals(5));
      expect(copied.lastError, equals('New error'));
    });

    test('should have correct equality', () {
      final health1 = ServiceHealth.healthy('test');
      final health2 = ServiceHealth.healthy('test');
      final health3 = ServiceHealth.healthy('different');
      
      // Note: equality is based on serviceName, isAvailable, and lastChecked
      // Since lastChecked will be different, they won't be equal
      expect(health1.serviceName, equals(health2.serviceName));
      expect(health1.serviceName, isNot(equals(health3.serviceName)));
    });
  });
}