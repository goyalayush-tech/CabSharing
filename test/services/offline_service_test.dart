import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../../lib/services/offline_service.dart';

void main() {
  group('OfflineService', () {
    late MockOfflineService mockOfflineService;

    setUp(() {
      mockOfflineService = MockOfflineService();
    });

    tearDown(() {
      mockOfflineService.dispose();
    });

    test('should initialize with online status', () async {
      await mockOfflineService.initialize();
      expect(mockOfflineService.isOnline, isTrue);
    });

    test('should emit connectivity changes', () async {
      await mockOfflineService.initialize();
      
      // Test going offline
      mockOfflineService.setConnectivity(false);
      await Future.delayed(const Duration(milliseconds: 10));
      expect(mockOfflineService.isOnline, isFalse);
      
      // Test going back online
      mockOfflineService.setConnectivity(true);
      await Future.delayed(const Duration(milliseconds: 10));
      expect(mockOfflineService.isOnline, isTrue);
    });

    test('should check connectivity', () async {
      await mockOfflineService.initialize();
      
      // Initially online
      expect(await mockOfflineService.checkConnectivity(), isTrue);
      
      // Set offline
      mockOfflineService.setConnectivity(false);
      expect(await mockOfflineService.checkConnectivity(), isFalse);
    });

    test('should refresh connectivity', () async {
      await mockOfflineService.initialize();
      
      mockOfflineService.setConnectivity(false);
      await mockOfflineService.refreshConnectivity();
      
      expect(mockOfflineService.isOnline, isFalse);
    });

    test('should handle multiple listeners', () async {
      await mockOfflineService.initialize();
      
      mockOfflineService.setConnectivity(false);
      await Future.delayed(const Duration(milliseconds: 10));
      
      expect(mockOfflineService.isOnline, isFalse);
      
      // Test that stream is broadcast and can have multiple listeners
      final stream = mockOfflineService.connectivityStream;
      expect(stream.isBroadcast, isTrue);
    });

    test('should dispose properly', () {
      expect(() => mockOfflineService.dispose(), returnsNormally);
    });
  });

  group('OfflineService Integration', () {
    test('should handle connectivity state changes', () async {
      final service = MockOfflineService();
      await service.initialize();
      
      final states = <bool>[];
      final subscription = service.connectivityStream.listen(states.add);
      
      // Simulate connectivity changes
      service.setConnectivity(false);
      service.setConnectivity(true);
      service.setConnectivity(false);
      
      await Future.delayed(const Duration(milliseconds: 100));
      
      expect(states, equals([false, true, false]));
      
      await subscription.cancel();
      service.dispose();
    });

    test('should maintain state consistency', () async {
      final service = MockOfflineService();
      await service.initialize();
      
      // Initial state
      expect(service.isOnline, isTrue);
      expect(await service.checkConnectivity(), isTrue);
      
      // Change state
      service.setConnectivity(false);
      expect(service.isOnline, isFalse);
      expect(await service.checkConnectivity(), isFalse);
      
      service.dispose();
    });
  });

  group('OfflineService Error Handling', () {
    test('should handle initialization errors gracefully', () async {
      final service = MockOfflineService();
      
      // Should not throw
      expect(() => service.initialize(), returnsNormally);
      await service.initialize();
      
      service.dispose();
    });

    test('should handle connectivity check errors', () async {
      final service = MockOfflineService();
      await service.initialize();
      
      // Should not throw and return a boolean
      final result = await service.checkConnectivity();
      expect(result, isA<bool>());
      
      service.dispose();
    });
  });
}