import 'package:flutter_test/flutter_test.dart';
import '../../lib/services/service_health_monitor.dart';
import '../../lib/models/service_health.dart';

void main() {
  group('ServiceHealthMonitor', () {
    late ServiceHealthMonitor monitor;

    setUp(() {
      monitor = ServiceHealthMonitor();
    });

    tearDown(() {
      monitor.stopMonitoring();
    });

    group('Initialization', () {
      test('should initialize with default services', () {
        monitor.startMonitoring();
        
        final allHealth = monitor.getAllServiceHealth();
        expect(allHealth.isNotEmpty, isTrue);
        
        // Check that default services are initialized
        expect(allHealth.containsKey('nominatim'), isTrue);
        expect(allHealth.containsKey('openrouteservice'), isTrue);
        expect(allHealth.containsKey('osm_tiles'), isTrue);
        expect(allHealth.containsKey('google_maps'), isTrue);
        
        // All services should start as available
        for (final health in allHealth.values) {
          expect(health.isAvailable, isTrue);
          expect(health.successRate, equals(1.0));
          expect(health.failureCount, equals(0));
        }
      });
    });

    group('Success Recording', () {
      test('should record successful service calls', () {
        monitor.startMonitoring();
        
        final responseTime = const Duration(milliseconds: 500);
        monitor.recordSuccess('nominatim', responseTime);
        
        final health = monitor.getServiceHealth('nominatim');
        expect(health, isNotNull);
        expect(health!.isAvailable, isTrue);
        expect(health.successRate, equals(100.0));
        expect(health.failureCount, equals(0));
      });

      test('should update average response time', () {
        monitor.startMonitoring();
        
        // Record multiple successful calls with different response times
        monitor.recordSuccess('nominatim', const Duration(milliseconds: 100));
        monitor.recordSuccess('nominatim', const Duration(milliseconds: 300));
        monitor.recordSuccess('nominatim', const Duration(milliseconds: 200));
        
        final health = monitor.getServiceHealth('nominatim');
        expect(health, isNotNull);
        expect(health!.averageResponseTime.inMilliseconds, equals(200));
      });
    });

    group('Failure Recording', () {
      test('should record failed service calls', () {
        monitor.startMonitoring();
        
        final responseTime = const Duration(milliseconds: 1000);
        monitor.recordFailure('nominatim', responseTime, 'Connection timeout');
        
        final health = monitor.getServiceHealth('nominatim');
        expect(health, isNotNull);
        expect(health!.failureCount, equals(1));
        expect(health.lastFailure, isNotNull);
      });

      test('should update success rate after failures', () {
        monitor.startMonitoring();
        
        // Record some successes and failures
        monitor.recordSuccess('nominatim', const Duration(milliseconds: 200));
        monitor.recordSuccess('nominatim', const Duration(milliseconds: 300));
        monitor.recordFailure('nominatim', const Duration(milliseconds: 1000), 'Error');
        monitor.recordFailure('nominatim', const Duration(milliseconds: 1000), 'Error');
        
        final health = monitor.getServiceHealth('nominatim');
        expect(health, isNotNull);
        expect(health!.successRate, equals(50.0)); // 2 successes out of 4 total
        expect(health.failureCount, equals(2));
      });

      test('should mark service as unavailable after many failures', () {
        monitor.startMonitoring();
        
        // Record many consecutive failures
        for (int i = 0; i < 10; i++) {
          monitor.recordFailure('nominatim', const Duration(seconds: 30), 'Error $i');
        }
        
        final health = monitor.getServiceHealth('nominatim');
        expect(health, isNotNull);
        expect(health!.isAvailable, isFalse);
        expect(health.successRate, equals(0.0));
      });
    });

    group('Service Health Status', () {
      test('should identify healthy services', () {
        monitor.startMonitoring();
        
        // Record successful calls
        monitor.recordSuccess('nominatim', const Duration(milliseconds: 500));
        monitor.recordSuccess('nominatim', const Duration(milliseconds: 600));
        
        expect(monitor.isServiceHealthy('nominatim'), isTrue);
      });

      test('should identify unhealthy services', () {
        monitor.startMonitoring();
        
        // Record many failures
        for (int i = 0; i < 5; i++) {
          monitor.recordFailure('nominatim', const Duration(seconds: 30), 'Error');
        }
        
        expect(monitor.isServiceHealthy('nominatim'), isFalse);
      });

      test('should identify services with slow response times as unhealthy', () {
        monitor.startMonitoring();
        
        // Record successful but very slow calls
        monitor.recordSuccess('nominatim', const Duration(seconds: 15));
        monitor.recordSuccess('nominatim', const Duration(seconds: 20));
        
        expect(monitor.isServiceHealthy('nominatim'), isFalse);
      });
    });

    group('Best Service Selection', () {
      test('should select best available service', () {
        monitor.startMonitoring();
        
        // Make nominatim perform better than openrouteservice
        monitor.recordSuccess('nominatim', const Duration(milliseconds: 200));
        monitor.recordSuccess('nominatim', const Duration(milliseconds: 300));
        
        monitor.recordSuccess('openrouteservice', const Duration(milliseconds: 800));
        monitor.recordFailure('openrouteservice', const Duration(seconds: 5), 'Error');
        
        final bestService = monitor.getBestService(['nominatim', 'openrouteservice']);
        expect(bestService, equals('nominatim'));
      });

      test('should return null if no services are available', () {
        monitor.startMonitoring();
        
        // Make all services unavailable
        for (int i = 0; i < 10; i++) {
          monitor.recordFailure('nominatim', const Duration(seconds: 30), 'Error');
          monitor.recordFailure('openrouteservice', const Duration(seconds: 30), 'Error');
        }
        
        final bestService = monitor.getBestService(['nominatim', 'openrouteservice']);
        expect(bestService, isNull);
      });

      test('should handle empty service list', () {
        monitor.startMonitoring();
        
        final bestService = monitor.getBestService([]);
        expect(bestService, isNull);
      });
    });

    group('Unhealthy Services', () {
      test('should identify unhealthy services', () {
        monitor.startMonitoring();
        
        // Make nominatim unhealthy
        for (int i = 0; i < 8; i++) {
          monitor.recordFailure('nominatim', const Duration(seconds: 30), 'Error');
        }
        
        // Keep openrouteservice healthy
        monitor.recordSuccess('openrouteservice', const Duration(milliseconds: 500));
        
        final unhealthyServices = monitor.getUnhealthyServices();
        expect(unhealthyServices.length, greaterThan(0));
        
        final unhealthyNames = unhealthyServices.map((s) => s.serviceName).toList();
        expect(unhealthyNames.contains('nominatim'), isTrue);
        expect(unhealthyNames.contains('openrouteservice'), isFalse);
      });

      test('should return empty list when all services are healthy', () {
        monitor.startMonitoring();
        
        // Make all services healthy
        final services = ['nominatim', 'openrouteservice', 'osm_tiles'];
        for (final service in services) {
          monitor.recordSuccess(service, const Duration(milliseconds: 500));
        }
        
        final unhealthyServices = monitor.getUnhealthyServices();
        expect(unhealthyServices.isEmpty, isTrue);
      });
    });

    group('Overall Health Score', () {
      test('should calculate overall health score', () {
        monitor.startMonitoring();
        
        // Make some services healthy, others not
        monitor.recordSuccess('nominatim', const Duration(milliseconds: 500));
        monitor.recordSuccess('openrouteservice', const Duration(milliseconds: 600));
        
        // Make osm_tiles unhealthy
        for (int i = 0; i < 10; i++) {
          monitor.recordFailure('osm_tiles', const Duration(seconds: 30), 'Error');
        }
        
        final overallScore = monitor.getOverallHealthScore();
        expect(overallScore, greaterThan(0.0));
        expect(overallScore, lessThan(100.0)); // Should be less than 100 due to osm_tiles failures
      });

      test('should return 100 when all services are healthy', () {
        monitor.startMonitoring();
        
        // Make all services healthy
        final services = ['nominatim', 'openrouteservice', 'osm_tiles', 'google_maps'];
        for (final service in services) {
          monitor.recordSuccess(service, const Duration(milliseconds: 500));
        }
        
        final overallScore = monitor.getOverallHealthScore();
        expect(overallScore, equals(100.0));
      });

      test('should return 0 when no services are initialized', () {
        // Don't start monitoring
        final overallScore = monitor.getOverallHealthScore();
        expect(overallScore, equals(0.0));
      });
    });

    group('Service Health Retrieval', () {
      test('should return null for unknown service', () {
        monitor.startMonitoring();
        
        final health = monitor.getServiceHealth('unknown_service');
        expect(health, isNull);
      });

      test('should return all service health data', () {
        monitor.startMonitoring();
        
        final allHealth = monitor.getAllServiceHealth();
        expect(allHealth.isNotEmpty, isTrue);
        
        // Verify structure
        for (final entry in allHealth.entries) {
          expect(entry.key, isA<String>());
          expect(entry.value, isA<ServiceHealth>());
          expect(entry.value.serviceName, equals(entry.key));
        }
      });
    });

    group('Monitoring Lifecycle', () {
      test('should start and stop monitoring', () {
        expect(() => monitor.startMonitoring(), returnsNormally);
        expect(() => monitor.stopMonitoring(), returnsNormally);
      });

      test('should handle multiple start/stop calls', () {
        monitor.startMonitoring();
        monitor.startMonitoring(); // Should not cause issues
        
        monitor.stopMonitoring();
        monitor.stopMonitoring(); // Should not cause issues
      });
    });
  });
}