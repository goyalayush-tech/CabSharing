import 'package:flutter_test/flutter_test.dart';
import '../../lib/services/fallback_manager.dart';
import '../../lib/models/service_health.dart';

void main() {
  group('FallbackManager', () {
    late FallbackManager fallbackManager;

    setUp(() {
      fallbackManager = FallbackManager();
    });

    group('executeWithFallback', () {
      test('should execute primary service when healthy', () async {
        // Arrange
        const expectedResult = 'primary_result';
        Future<String> primaryService() async => expectedResult;
        Future<String> fallbackService() async => 'fallback_result';

        // Act
        final result = await fallbackManager.executeWithFallback(
          primaryService,
          fallbackService,
          'test_operation',
        );

        // Assert
        expect(result, equals(expectedResult));
        final health = fallbackManager.getServiceHealth('primary_test_operation');
        expect(health.successRate, equals(1.0));
      });

      test('should use fallback when primary service fails', () async {
        // Arrange
        const expectedResult = 'fallback_result';
        Future<String> primaryService() async => throw Exception('Primary failed');
        Future<String> fallbackService() async => expectedResult;

        // Act
        final result = await fallbackManager.executeWithFallback(
          primaryService,
          fallbackService,
          'test_operation',
        );

        // Assert
        expect(result, equals(expectedResult));
        final primaryHealth = fallbackManager.getServiceHealth('primary_test_operation');
        final fallbackHealth = fallbackManager.getServiceHealth('fallback_test_operation');
        expect(primaryHealth.failureCount, equals(1));
        expect(fallbackHealth.successRate, equals(1.0));
      });

      test('should throw when both services fail', () async {
        // Arrange
        Future<String> primaryService() async => throw Exception('Primary failed');
        Future<String> fallbackService() async => throw Exception('Fallback failed');

        // Act & Assert
        expect(
          () => fallbackManager.executeWithFallback(
            primaryService,
            fallbackService,
            'test_operation',
          ),
          throwsException,
        );
      });

      test('should timeout services after default timeout', () async {
        // Arrange
        Future<String> slowPrimaryService() async {
          await Future.delayed(Duration(seconds: 15));
          return 'primary_result';
        }
        Future<String> fastFallbackService() async => 'fallback_result';

        // Act
        final result = await fallbackManager.executeWithFallback(
          slowPrimaryService,
          fastFallbackService,
          'timeout_test',
        );

        // Assert
        expect(result, equals('fallback_result'));
      });
    });

    group('service health monitoring', () {
      test('should track service failures', () {
        // Arrange
        const serviceName = 'test_service';

        // Act
        fallbackManager.reportServiceFailure(serviceName, 'test_op');
        fallbackManager.reportServiceFailure(serviceName, 'test_op');

        // Assert
        final health = fallbackManager.getServiceHealth(serviceName);
        expect(health.failureCount, equals(2));
        expect(health.successRate, lessThan(1.0));
        expect(health.lastFailure, isNotNull);
      });

      test('should track service successes', () {
        // Arrange
        const serviceName = 'test_service';

        // Act
        fallbackManager.reportServiceFailure(serviceName, 'test_op');
        fallbackManager.reportServiceSuccess(serviceName, 'test_op');

        // Assert
        final health = fallbackManager.getServiceHealth(serviceName);
        expect(health.failureCount, equals(1)); // Failure still counted
        expect(health.successRate, equals(0.5)); // 1 success out of 2 total
        expect(health.successfulRequests, equals(1));
      });

      test('should calculate correct success rate', () {
        // Arrange
        const serviceName = 'test_service';

        // Act - 3 failures, 2 successes
        for (int i = 0; i < 3; i++) {
          fallbackManager.reportServiceFailure(serviceName, 'test_op');
        }
        for (int i = 0; i < 2; i++) {
          fallbackManager.reportServiceSuccess(serviceName, 'test_op');
        }

        // Assert
        final health = fallbackManager.getServiceHealth(serviceName);
        expect(health.successRate, closeTo(0.4, 0.1)); // 2/(3+2) = 0.4
        expect(health.totalRequests, equals(5));
        expect(health.successfulRequests, equals(2));
      });

      test('should return default health for unknown service', () {
        // Act
        final health = fallbackManager.getServiceHealth('unknown_service');

        // Assert
        expect(health.serviceName, equals('unknown_service'));
        expect(health.isAvailable, isTrue);
        expect(health.failureCount, equals(0));
        expect(health.successRate, equals(1.0));
        expect(health.lastFailure, isNull);
      });
    });

    group('fallback decision logic', () {
      test('should use fallback when failure count exceeds threshold', () {
        // Arrange
        const serviceName = 'failing_service';

        // Act - Report 6 failures (threshold is 5)
        for (int i = 0; i < 6; i++) {
          fallbackManager.reportServiceFailure(serviceName, 'test_op');
        }

        // Assert
        expect(fallbackManager.shouldUseFallback(serviceName), isTrue);
      });

      test('should use fallback when success rate is too low', () {
        // Arrange
        const serviceName = 'unreliable_service';

        // Act - Create low success rate (1 success, 3 failures = 25% success rate)
        fallbackManager.reportServiceSuccess(serviceName, 'test_op');
        for (int i = 0; i < 3; i++) {
          fallbackManager.reportServiceFailure(serviceName, 'test_op');
        }

        // Assert
        expect(fallbackManager.shouldUseFallback(serviceName), isTrue);
      });

      test('should not use fallback for healthy service', () {
        // Arrange
        const serviceName = 'healthy_service';

        // Act - Report mostly successes (5 successes, 1 failure = 83% success rate)
        for (int i = 0; i < 5; i++) {
          fallbackManager.reportServiceSuccess(serviceName, 'test_op');
        }
        fallbackManager.reportServiceFailure(serviceName, 'test_op');

        // Assert
        final health = fallbackManager.getServiceHealth(serviceName);
        expect(health.successRate, greaterThan(0.8)); // Should be ~83%
        expect(fallbackManager.shouldUseFallback(serviceName), isFalse);
      });
    });

    group('manual service availability', () {
      test('should respect manual availability override', () {
        // Arrange
        const serviceName = 'manual_service';

        // Act
        fallbackManager.setServiceAvailability(serviceName, false);

        // Assert
        expect(fallbackManager.shouldUseFallback(serviceName), isTrue);
        final health = fallbackManager.getServiceHealth(serviceName);
        expect(health.isAvailable, isFalse);
      });

      test('should override health-based availability', () {
        // Arrange
        const serviceName = 'override_service';

        // Act - Make service unhealthy, then manually set available
        for (int i = 0; i < 6; i++) {
          fallbackManager.reportServiceFailure(serviceName, 'test_op');
        }
        fallbackManager.setServiceAvailability(serviceName, true);

        // Assert
        expect(fallbackManager.shouldUseFallback(serviceName), isFalse);
        final health = fallbackManager.getServiceHealth(serviceName);
        expect(health.isAvailable, isTrue);
      });
    });

    group('service health management', () {
      test('should return all service health statuses', () {
        // Arrange
        fallbackManager.reportServiceFailure('service1', 'op1');
        fallbackManager.reportServiceSuccess('service2', 'op2');

        // Act
        final allHealth = fallbackManager.getAllServiceHealth();

        // Assert
        expect(allHealth.keys, contains('service1'));
        expect(allHealth.keys, contains('service2'));
        expect(allHealth['service1']!.failureCount, equals(1));
        expect(allHealth['service2']!.successRate, equals(1.0));
      });

      test('should reset service health', () {
        // Arrange
        const serviceName = 'reset_service';
        fallbackManager.reportServiceFailure(serviceName, 'test_op');
        fallbackManager.setServiceAvailability(serviceName, false);

        // Act
        fallbackManager.resetServiceHealth(serviceName);

        // Assert
        final health = fallbackManager.getServiceHealth(serviceName);
        expect(health.failureCount, equals(0));
        expect(health.isAvailable, isTrue);
        expect(fallbackManager.shouldUseFallback(serviceName), isFalse);
      });
    });

    group('response time tracking', () {
      test('should calculate average response time', () async {
        // Arrange
        const serviceName = 'timed_service';
        Future<String> fastService() async {
          await Future.delayed(Duration(milliseconds: 100));
          return 'result';
        };
        Future<String> fallbackService() async => 'fallback';

        // Act - Execute multiple times to build response time history
        for (int i = 0; i < 3; i++) {
          await fallbackManager.executeWithFallback(
            fastService,
            fallbackService,
            'timed_operation',
          );
        }

        // Assert
        final health = fallbackManager.getServiceHealth('primary_timed_operation');
        expect(health.averageResponseTime.inMilliseconds, greaterThan(50));
        expect(health.averageResponseTime.inMilliseconds, lessThan(500)); // More realistic upper bound
      });
    });

    group('recovery behavior', () {
      test('should recover service health after recovery window', () async {
        // Arrange
        const serviceName = 'recovery_service';

        // Act - Report failures, then report successes to improve health
        for (int i = 0; i < 3; i++) {
          fallbackManager.reportServiceFailure(serviceName, 'test_op');
        }
        
        // Report more successes to improve success rate
        for (int i = 0; i < 4; i++) {
          fallbackManager.reportServiceSuccess(serviceName, 'test_op');
        }

        // Assert
        final health = fallbackManager.getServiceHealth(serviceName);
        expect(health.successRate, greaterThan(0.5)); // Should be 4/7 = ~57%
        expect(health.successfulRequests, equals(4));
        expect(fallbackManager.shouldUseFallback(serviceName), isFalse);
      });
    });

    group('edge cases', () {
      test('should handle empty service name', () {
        // Act & Assert
        expect(() => fallbackManager.getServiceHealth(''), returnsNormally);
        expect(() => fallbackManager.shouldUseFallback(''), returnsNormally);
      });

      test('should handle concurrent operations', () async {
        // Arrange
        Future<String> service() async => 'result';
        Future<String> fallback() async => 'fallback';

        // Act - Execute multiple concurrent operations
        final futures = List.generate(10, (index) =>
          fallbackManager.executeWithFallback(
            service,
            fallback,
            'concurrent_$index',
          ),
        );

        final results = await Future.wait(futures);

        // Assert
        expect(results.length, equals(10));
        expect(results.every((r) => r == 'result'), isTrue);
      });
    });
  });
}