import 'package:flutter_test/flutter_test.dart';
import '../../lib/services/map_analytics_service.dart';

void main() {
  group('MapAnalyticsService', () {
    late MapAnalyticsService analytics;

    setUp(() {
      analytics = MapAnalyticsService();
      analytics.reset(); // Ensure clean state
    });

    group('Session Management', () {
      test('should start session and initialize counters', () {
        analytics.startSession();
        
        final summary = analytics.getAnalyticsSummary();
        expect(summary['totalRequests'], equals(0));
        expect(summary['totalErrors'], equals(0));
        expect(summary['cacheHits'], equals(0));
        expect(summary['cacheMisses'], equals(0));
      });
    });

    group('API Call Tracking', () {
      test('should track successful API calls', () async {
        analytics.startSession();
        
        final result = await analytics.trackApiCall(
          'nominatim',
          'search',
          () async {
            await Future.delayed(const Duration(milliseconds: 100));
            return 'success';
          },
        );
        
        expect(result, equals('success'));
        
        final stats = analytics.getServiceStats('nominatim');
        expect(stats['totalCalls'], equals(1));
        expect(stats['errorCount'], equals(0));
        expect(stats['successCount'], equals(1));
        expect(stats['successRate'], equals(1.0));
      });

      test('should track failed API calls', () async {
        analytics.startSession();
        
        try {
          await analytics.trackApiCall(
            'nominatim',
            'search',
            () async {
              await Future.delayed(const Duration(milliseconds: 100));
              throw Exception('API Error');
            },
          );
          fail('Should have thrown exception');
        } catch (e) {
          expect(e.toString(), contains('API Error'));
        }
        
        final stats = analytics.getServiceStats('nominatim');
        expect(stats['totalCalls'], equals(1));
        expect(stats['errorCount'], equals(1));
        expect(stats['successCount'], equals(0));
        expect(stats['successRate'], equals(0.0));
      });

      test('should calculate average response times', () async {
        analytics.startSession();
        
        // Make multiple calls with different response times
        await analytics.trackApiCall('nominatim', 'search', () async {
          await Future.delayed(const Duration(milliseconds: 100));
          return 'result1';
        });
        
        await analytics.trackApiCall('nominatim', 'search', () async {
          await Future.delayed(const Duration(milliseconds: 200));
          return 'result2';
        });
        
        final stats = analytics.getServiceStats('nominatim');
        expect(stats['averageResponseTime'], greaterThan(0.0));
        expect(stats['totalCalls'], equals(2));
      });
    });

    group('Rate Limiting', () {
      test('should allow requests within rate limits', () {
        expect(analytics.canMakeRequest('nominatim'), isTrue);
        expect(analytics.canMakeRequest('openrouteservice'), isTrue);
        expect(analytics.canMakeRequest('osm_tiles'), isTrue);
      });

      test('should track request history for rate limiting', () {
        analytics.recordRequest('nominatim');
        analytics.recordRequest('nominatim');
        
        final rateLimits = analytics.getRateLimitStatus();
        expect(rateLimits.containsKey('nominatim'), isTrue);
        
        final nominatimStatus = rateLimits['nominatim']!;
        expect(nominatimStatus['currentUsage'], greaterThan(0));
      });

      test('should enforce nominatim rate limit (1 req/sec)', () {
        // Record a request
        analytics.recordRequest('nominatim');
        
        // Should not allow another request immediately
        expect(analytics.canMakeRequest('nominatim'), isFalse);
      });

      test('should provide rate limit status', () {
        analytics.recordRequest('openrouteservice');
        
        final status = analytics.getRateLimitStatus();
        expect(status.containsKey('openrouteservice'), isTrue);
        
        final orsStatus = status['openrouteservice']!;
        expect(orsStatus['limit'], equals(40));
        expect(orsStatus['currentUsage'], greaterThan(0));
        expect(orsStatus['remainingRequests'], lessThan(40));
      });
    });

    group('Cache Tracking', () {
      test('should track cache hits and misses', () {
        analytics.startSession();
        
        analytics.trackCacheHit('nominatim');
        analytics.trackCacheHit('nominatim');
        analytics.trackCacheMiss('nominatim');
        
        final summary = analytics.getAnalyticsSummary();
        expect(summary['cacheHits'], equals(2));
        expect(summary['cacheMisses'], equals(1));
        expect(summary['cacheHitRate'], closeTo(66.67, 0.1));
      });

      test('should calculate cache hit rate correctly', () {
        analytics.startSession();
        
        // No cache activity
        var summary = analytics.getAnalyticsSummary();
        expect(summary['cacheHitRate'], equals(0.0));
        
        // All hits
        analytics.trackCacheHit('test');
        analytics.trackCacheHit('test');
        summary = analytics.getAnalyticsSummary();
        expect(summary['cacheHitRate'], equals(100.0));
        
        // Mixed hits and misses
        analytics.trackCacheMiss('test');
        analytics.trackCacheMiss('test');
        summary = analytics.getAnalyticsSummary();
        expect(summary['cacheHitRate'], equals(50.0));
      });
    });

    group('Analytics Summary', () {
      test('should provide comprehensive analytics summary', () async {
        analytics.startSession();
        
        // Simulate some activity
        await analytics.trackApiCall('nominatim', 'search', () async => 'result');
        analytics.trackCacheHit('nominatim');
        analytics.trackCacheMiss('nominatim');
        
        final summary = analytics.getAnalyticsSummary();
        
        expect(summary.containsKey('sessionDuration'), isTrue);
        expect(summary.containsKey('totalRequests'), isTrue);
        expect(summary.containsKey('totalErrors'), isTrue);
        expect(summary.containsKey('successRate'), isTrue);
        expect(summary.containsKey('cacheHits'), isTrue);
        expect(summary.containsKey('cacheMisses'), isTrue);
        expect(summary.containsKey('cacheHitRate'), isTrue);
        expect(summary.containsKey('services'), isTrue);
        
        expect(summary['totalRequests'], equals(1));
        expect(summary['successRate'], equals(1.0));
        expect(summary['cacheHits'], equals(1));
        expect(summary['cacheMisses'], equals(1));
      });

      test('should include service-specific statistics', () async {
        analytics.startSession();
        
        await analytics.trackApiCall('nominatim', 'search', () async => 'result1');
        await analytics.trackApiCall('openrouteservice', 'route', () async => 'result2');
        
        final summary = analytics.getAnalyticsSummary();
        final services = summary['services'] as List;
        
        expect(services.length, equals(2));
        
        final nominatimStats = services.firstWhere(
          (s) => s['serviceName'] == 'nominatim',
        );
        expect(nominatimStats['totalCalls'], equals(1));
        
        final orsStats = services.firstWhere(
          (s) => s['serviceName'] == 'openrouteservice',
        );
        expect(orsStats['totalCalls'], equals(1));
      });
    });

    group('Service Statistics', () {
      test('should provide detailed service statistics', () async {
        analytics.startSession();
        
        // Make successful call
        await analytics.trackApiCall('nominatim', 'search', () async => 'result');
        
        // Make failed call
        try {
          await analytics.trackApiCall('nominatim', 'search', () async {
            throw Exception('Error');
          });
        } catch (e) {
          // Expected
        }
        
        final stats = analytics.getServiceStats('nominatim');
        
        expect(stats['serviceName'], equals('nominatim'));
        expect(stats['totalCalls'], equals(2));
        expect(stats['errorCount'], equals(1));
        expect(stats['successCount'], equals(1));
        expect(stats['successRate'], equals(0.5));
        expect(stats['averageResponseTime'], greaterThan(0.0));
        expect(stats.containsKey('lastCall'), isTrue);
      });

      test('should handle services with no activity', () {
        final stats = analytics.getServiceStats('unknown_service');
        
        expect(stats['serviceName'], equals('unknown_service'));
        expect(stats['totalCalls'], equals(0));
        expect(stats['errorCount'], equals(0));
        expect(stats['successCount'], equals(0));
        expect(stats['successRate'], equals(1.0));
        expect(stats['averageResponseTime'], equals(0.0));
        expect(stats['lastCall'], isNull);
      });
    });

    group('Reset Functionality', () {
      test('should reset all analytics data', () async {
        analytics.startSession();
        
        // Generate some data
        await analytics.trackApiCall('nominatim', 'search', () async => 'result');
        analytics.trackCacheHit('nominatim');
        analytics.recordRequest('nominatim');
        
        // Verify data exists
        var summary = analytics.getAnalyticsSummary();
        expect(summary['totalRequests'], equals(1));
        
        // Reset
        analytics.reset();
        
        // Verify data is cleared
        summary = analytics.getAnalyticsSummary();
        expect(summary['totalRequests'], equals(0));
        expect(summary['totalErrors'], equals(0));
        expect(summary['cacheHits'], equals(0));
        expect(summary['cacheMisses'], equals(0));
        
        final stats = analytics.getServiceStats('nominatim');
        expect(stats['totalCalls'], equals(0));
      });
    });
  });
}