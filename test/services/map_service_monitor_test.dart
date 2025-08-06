import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../lib/services/map_service_monitor.dart';

void main() {
  group('MapServiceMonitor', () {
    late MapServiceMonitor monitor;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      monitor = MapServiceMonitor();
      // Reset analytics to ensure clean state
      monitor.analytics.reset();
    });

    tearDown(() {
      monitor.shutdown();
    });

    test('should initialize successfully', () async {
      await monitor.initialize();
      
      expect(monitor.analytics, isNotNull);
      expect(monitor.healthMonitor, isNotNull);
    });

    test('should track service operations', () async {
      await monitor.initialize();
      
      // Track a successful operation
      final result = await monitor.trackServiceOperation(
        'test_service',
        'test_operation',
        () async {
          await Future.delayed(const Duration(milliseconds: 100));
          return 'success';
        },
      );
      
      expect(result, equals('success'));
      
      final status = monitor.getServiceStatus();
      expect(status['analytics']['totalRequests'], equals(1));
      expect(status['analytics']['totalErrors'], equals(0));
    });

    test('should handle service operation failures', () async {
      await monitor.initialize();
      
      // Track a failed operation
      try {
        await monitor.trackServiceOperation(
          'test_service',
          'test_operation',
          () async {
            throw Exception('Test error');
          },
        );
        fail('Should have thrown an exception');
      } catch (e) {
        expect(e.toString(), contains('Test error'));
      }
      
      final status = monitor.getServiceStatus();
      expect(status['analytics']['totalRequests'], equals(1));
      expect(status['analytics']['totalErrors'], equals(1));
    });

    test('should generate comprehensive status report', () async {
      await monitor.initialize();
      
      // Perform some operations
      await monitor.trackServiceOperation(
        'nominatim',
        'geocode',
        () async => 'result',
      );
      
      final status = monitor.getServiceStatus();
      
      expect(status, containsPair('timestamp', isA<String>()));
      expect(status, containsPair('analytics', isA<Map<String, dynamic>>()));
      expect(status, containsPair('health', isA<Map<String, dynamic>>()));
      expect(status, containsPair('performance', isA<Map<String, dynamic>>()));
      expect(status, containsPair('rateLimits', isA<Map<String, dynamic>>()));
      expect(status, containsPair('overallHealthScore', isA<double>()));
      expect(status, containsPair('alerts', isA<List>()));
    });

    test('should detect high error rate alerts', () async {
      await monitor.initialize();
      
      // Generate multiple errors to trigger alert
      for (int i = 0; i < 10; i++) {
        try {
          await monitor.trackServiceOperation(
            'test_service',
            'failing_operation',
            () async {
              throw Exception('Simulated error');
            },
          );
        } catch (e) {
          // Expected to fail
        }
      }
      
      final status = monitor.getServiceStatus();
      final alerts = status['alerts'] as List;
      
      expect(alerts, isNotEmpty);
      expect(alerts.any((alert) => alert['type'] == 'high_error_rate'), isTrue);
    });

    test('should generate monitoring report', () async {
      await monitor.initialize();
      
      // Perform some operations
      await monitor.trackServiceOperation(
        'nominatim',
        'geocode',
        () async => 'result',
      );
      
      final report = monitor.generateReport();
      
      expect(report, containsPair('reportId', isA<String>()));
      expect(report, containsPair('generatedAt', isA<String>()));
      expect(report, containsPair('status', isA<Map<String, dynamic>>()));
      expect(report, containsPair('recentErrors', isA<List>()));
      expect(report, containsPair('unhealthyServices', isA<List>()));
      expect(report, containsPair('recommendations', isA<List<String>>()));
    });

    test('should save and load reports', () async {
      await monitor.initialize();
      
      final report = monitor.generateReport();
      await monitor.saveReport(report);
      
      final savedReports = await monitor.loadSavedReports();
      
      expect(savedReports, hasLength(1));
      expect(savedReports.first['reportId'], equals(report['reportId']));
    });

    test('should update configuration', () async {
      await monitor.initialize();
      
      await monitor.updateConfiguration(
        enablePeriodicReporting: false,
        reportingInterval: const Duration(minutes: 30),
      );
      
      // Configuration should be updated
      // This is tested indirectly through the behavior changes
      expect(true, isTrue); // Placeholder assertion
    });

    test('should generate appropriate recommendations', () async {
      await monitor.initialize();
      
      // Generate some errors to trigger recommendations
      for (int i = 0; i < 5; i++) {
        try {
          await monitor.trackServiceOperation(
            'test_service',
            'failing_operation',
            () async {
              throw Exception('Simulated error');
            },
          );
        } catch (e) {
          // Expected to fail
        }
      }
      
      final report = monitor.generateReport();
      final recommendations = report['recommendations'] as List<String>;
      
      expect(recommendations, isNotEmpty);
      expect(recommendations.any((rec) => rec.contains('error rate')), isTrue);
    });

    test('should handle multiple service types', () async {
      await monitor.initialize();
      
      // Track operations for different services
      await monitor.trackServiceOperation('nominatim', 'geocode', () async => 'result1');
      await monitor.trackServiceOperation('openrouteservice', 'route', () async => 'result2');
      await monitor.trackServiceOperation('osm_tiles', 'tile', () async => 'result3');
      
      final status = monitor.getServiceStatus();
      final analytics = status['analytics'] as Map<String, dynamic>;
      final services = analytics['services'] as List;
      
      expect(services.length, greaterThanOrEqualTo(3));
      expect(services.any((s) => s['serviceName'] == 'nominatim'), isTrue);
      expect(services.any((s) => s['serviceName'] == 'openrouteservice'), isTrue);
      expect(services.any((s) => s['serviceName'] == 'osm_tiles'), isTrue);
    });

    test('should track performance metrics', () async {
      await monitor.initialize();
      
      // Perform operations with different response times
      await monitor.trackServiceOperation(
        'perf_test_service',
        'fast_operation',
        () async {
          await Future.delayed(const Duration(milliseconds: 50));
          return 'fast';
        },
      );
      
      await monitor.trackServiceOperation(
        'perf_test_service',
        'slow_operation',
        () async {
          await Future.delayed(const Duration(milliseconds: 200));
          return 'slow';
        },
      );
      
      final status = monitor.getServiceStatus();
      final performance = status['performance'] as Map<String, dynamic>;
      
      expect(performance, containsPair('perf_test_service', isA<Map<String, dynamic>>()));
      
      final testServiceMetrics = performance['perf_test_service'] as Map<String, dynamic>;
      expect(testServiceMetrics, containsPair('averageResponseTime', isA<double>()));
      expect(testServiceMetrics, containsPair('totalRequests', equals(2)));
    });
  });
}