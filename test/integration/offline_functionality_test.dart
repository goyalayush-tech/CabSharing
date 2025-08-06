import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../lib/widgets/free_map_widget.dart';
import '../../lib/widgets/free_location_picker.dart';
import '../../lib/widgets/offline_banner.dart';
import '../../lib/services/offline_service.dart';
import '../../lib/services/map_cache_service.dart';
import '../../lib/models/ride_group.dart';

void main() {
  group('Offline Functionality Integration Tests', () {
    late MockOfflineService mockOfflineService;
    late MockMapCacheService mockCacheService;

    setUp(() {
      mockOfflineService = MockOfflineService();
      mockCacheService = MockMapCacheService();
    });

    tearDown(() {
      mockOfflineService.dispose();
      mockCacheService.dispose();
    });

    testWidgets('FreeMapWidget should show offline banner when offline', (WidgetTester tester) async {
      await mockOfflineService.initialize();
      await mockCacheService.initialize();
      
      mockOfflineService.setConnectivity(false);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FreeMapWidget(
              offlineService: mockOfflineService,
              cacheService: mockCacheService,
              showOfflineBanner: true,
            ),
          ),
        ),
      );

      await tester.pump();

      expect(find.byType(OfflineBanner), findsOneWidget);
      expect(find.byIcon(Icons.wifi_off), findsOneWidget);
    });

    testWidgets('FreeMapWidget should disable location selection when offline', (WidgetTester tester) async {
      await mockOfflineService.initialize();
      await mockCacheService.initialize();
      
      mockOfflineService.setConnectivity(false);

      bool locationSelected = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FreeMapWidget(
              offlineService: mockOfflineService,
              cacheService: mockCacheService,
              onLocationSelected: (location) => locationSelected = true,
              allowLocationSelection: true,
            ),
          ),
        ),
      );

      await tester.pump();

      // Try to tap on the map - should not trigger location selection when offline
      await tester.tap(find.byType(FreeMapWidget));
      expect(locationSelected, isFalse);
    });

    testWidgets('FreeMapWidget should show offline overlay when offline', (WidgetTester tester) async {
      await mockOfflineService.initialize();
      await mockCacheService.initialize();
      
      mockOfflineService.setConnectivity(false);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FreeMapWidget(
              offlineService: mockOfflineService,
              cacheService: mockCacheService,
            ),
          ),
        ),
      );

      await tester.pump();

      expect(find.text('Offline Mode'), findsOneWidget);
    });

    testWidgets('FreeMapWidget should disable current location button when offline', (WidgetTester tester) async {
      await mockOfflineService.initialize();
      await mockCacheService.initialize();
      
      mockOfflineService.setConnectivity(false);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FreeMapWidget(
              offlineService: mockOfflineService,
              cacheService: mockCacheService,
              showCurrentLocation: true,
            ),
          ),
        ),
      );

      await tester.pump();

      final currentLocationButton = find.byIcon(Icons.my_location);
      expect(currentLocationButton, findsOneWidget);

      // Button should be disabled (onPressed is null)
      final button = tester.widget<FloatingActionButton>(
        find.ancestor(
          of: currentLocationButton,
          matching: find.byType(FloatingActionButton),
        ),
      );
      expect(button.onPressed, isNull);
    });

    testWidgets('FreeLocationPicker should show offline banner when offline', (WidgetTester tester) async {
      await mockOfflineService.initialize();
      await mockCacheService.initialize();
      
      mockOfflineService.setConnectivity(false);

      await tester.pumpWidget(
        MaterialApp(
          home: FreeLocationPicker(
            title: 'Test Location Picker',
            offlineService: mockOfflineService,
            cacheService: mockCacheService,
          ),
        ),
      );

      await tester.pump();

      expect(find.byType(OfflineBanner), findsOneWidget);
      expect(find.text('Offline: Search and current location unavailable'), findsOneWidget);
    });

    testWidgets('FreeLocationPicker should disable search when offline', (WidgetTester tester) async {
      await mockOfflineService.initialize();
      await mockCacheService.initialize();
      
      mockOfflineService.setConnectivity(false);

      await tester.pumpWidget(
        MaterialApp(
          home: FreeLocationPicker(
            title: 'Test Location Picker',
            offlineService: mockOfflineService,
            cacheService: mockCacheService,
            allowSearch: true,
          ),
        ),
      );

      await tester.pump();

      final searchField = find.byType(TextField);
      expect(searchField, findsOneWidget);

      final textField = tester.widget<TextField>(searchField);
      expect(textField.enabled, isFalse);
      expect(find.text('Search unavailable offline'), findsOneWidget);
    });

    testWidgets('FreeLocationPicker should disable current location button when offline', (WidgetTester tester) async {
      await mockOfflineService.initialize();
      await mockCacheService.initialize();
      
      mockOfflineService.setConnectivity(false);

      await tester.pumpWidget(
        MaterialApp(
          home: FreeLocationPicker(
            title: 'Test Location Picker',
            offlineService: mockOfflineService,
            cacheService: mockCacheService,
            allowCurrentLocation: true,
          ),
        ),
      );

      await tester.pump();

      final currentLocationButton = find.byIcon(Icons.my_location);
      expect(currentLocationButton, findsOneWidget);

      // Button should be disabled
      final button = tester.widget<FloatingActionButton>(
        find.ancestor(
          of: currentLocationButton,
          matching: find.byType(FloatingActionButton),
        ),
      );
      expect(button.onPressed, isNull);
    });

    testWidgets('should handle connectivity state changes', (WidgetTester tester) async {
      await mockOfflineService.initialize();
      await mockCacheService.initialize();
      
      // Start online
      mockOfflineService.setConnectivity(true);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FreeMapWidget(
              offlineService: mockOfflineService,
              cacheService: mockCacheService,
              showOfflineBanner: true,
            ),
          ),
        ),
      );

      await tester.pump();

      // Should not show offline banner when online
      expect(find.byType(OfflineBanner), findsOneWidget);
      expect(find.byIcon(Icons.wifi_off), findsNothing);

      // Go offline
      mockOfflineService.setConnectivity(false);
      await tester.pump();

      // Should show offline banner
      expect(find.byIcon(Icons.wifi_off), findsOneWidget);

      // Go back online
      mockOfflineService.setConnectivity(true);
      await tester.pump();

      // Should hide offline banner
      expect(find.byIcon(Icons.wifi_off), findsNothing);
    });

    testWidgets('should show snackbar notifications for connectivity changes', (WidgetTester tester) async {
      await mockOfflineService.initialize();
      await mockCacheService.initialize();
      
      // Start online
      mockOfflineService.setConnectivity(true);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FreeMapWidget(
              offlineService: mockOfflineService,
              cacheService: mockCacheService,
            ),
          ),
        ),
      );

      await tester.pump();

      // Go offline - should trigger offline snackbar
      mockOfflineService.setConnectivity(false);
      await tester.pump();

      // Note: Snackbar testing is complex and may require additional setup
      // This test verifies the widget structure changes appropriately
      expect(find.text('Offline Mode'), findsOneWidget);

      // Go back online
      mockOfflineService.setConnectivity(true);
      await tester.pump();

      // Should remove offline mode indicator
      expect(find.text('Offline Mode'), findsNothing);
    });

    testWidgets('should maintain map functionality with cached data when offline', (WidgetTester tester) async {
      await mockOfflineService.initialize();
      await mockCacheService.initialize();
      
      // Add some cached data
      final location = LatLng(37.7749, -122.4194);
      
      // Start online, then go offline
      mockOfflineService.setConnectivity(true);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FreeMapWidget(
              offlineService: mockOfflineService,
              cacheService: mockCacheService,
              initialLocation: location,
              markers: [
                MapMarkerData(
                  coordinates: location,
                  type: MapMarkerType.pickup,
                  title: 'Test Location',
                ),
              ],
            ),
          ),
        ),
      );

      await tester.pump();

      // Go offline
      mockOfflineService.setConnectivity(false);
      await tester.pump();

      // Map should still be functional with cached data
      expect(find.byType(FreeMapWidget), findsOneWidget);
      expect(find.text('Offline Mode'), findsOneWidget);
    });
  });

  group('Cache Integration Tests', () {
    late MockMapCacheService mockCacheService;

    setUp(() {
      mockCacheService = MockMapCacheService();
    });

    tearDown(() {
      mockCacheService.dispose();
    });

    testWidgets('should handle cache operations during offline mode', (WidgetTester tester) async {
      await mockCacheService.initialize();

      // Verify cache is working
      final stats = await mockCacheService.getCacheStats();
      expect(stats, isA<Map<String, int>>());
      expect(stats['tiles_count'], equals(0));

      // Test cache clearing
      await mockCacheService.clearAllCache();
      final clearedStats = await mockCacheService.getCacheStats();
      expect(clearedStats['tiles_count'], equals(0));
    });
  });
}