import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../lib/widgets/offline_banner.dart';
import '../../lib/services/offline_service.dart';

void main() {
  group('OfflineBanner', () {
    late MockOfflineService mockOfflineService;

    setUp(() {
      mockOfflineService = MockOfflineService();
    });

    tearDown(() {
      mockOfflineService.dispose();
    });

    testWidgets('should not show when online', (WidgetTester tester) async {
      await mockOfflineService.initialize();
      mockOfflineService.setConnectivity(true);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OfflineBanner(
              offlineService: mockOfflineService,
            ),
          ),
        ),
      );

      expect(find.byType(OfflineBanner), findsOneWidget);
      expect(find.byIcon(Icons.wifi_off), findsNothing);
      expect(find.text('You\'re offline. Some features may be limited.'), findsNothing);
    });

    testWidgets('should show when offline', (WidgetTester tester) async {
      await mockOfflineService.initialize();
      mockOfflineService.setConnectivity(false);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OfflineBanner(
              offlineService: mockOfflineService,
            ),
          ),
        ),
      );

      await tester.pump();

      expect(find.byIcon(Icons.wifi_off), findsOneWidget);
      expect(find.text('You\'re offline. Some features may be limited.'), findsOneWidget);
    });

    testWidgets('should show custom message when provided', (WidgetTester tester) async {
      await mockOfflineService.initialize();
      mockOfflineService.setConnectivity(false);

      const customMessage = 'Custom offline message';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OfflineBanner(
              offlineService: mockOfflineService,
              customMessage: customMessage,
            ),
          ),
        ),
      );

      await tester.pump();

      expect(find.text(customMessage), findsOneWidget);
    });

    testWidgets('should show retry button when enabled', (WidgetTester tester) async {
      await mockOfflineService.initialize();
      mockOfflineService.setConnectivity(false);

      bool retryPressed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OfflineBanner(
              offlineService: mockOfflineService,
              onRetry: () => retryPressed = true,
              showRetryButton: true,
            ),
          ),
        ),
      );

      await tester.pump();

      expect(find.text('Retry'), findsOneWidget);

      await tester.tap(find.text('Retry'));
      expect(retryPressed, isTrue);
    });

    testWidgets('should not show retry button when disabled', (WidgetTester tester) async {
      await mockOfflineService.initialize();
      mockOfflineService.setConnectivity(false);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OfflineBanner(
              offlineService: mockOfflineService,
              showRetryButton: false,
            ),
          ),
        ),
      );

      await tester.pump();

      expect(find.text('Retry'), findsNothing);
    });

    testWidgets('should react to connectivity changes', (WidgetTester tester) async {
      await mockOfflineService.initialize();
      mockOfflineService.setConnectivity(true);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OfflineBanner(
              offlineService: mockOfflineService,
            ),
          ),
        ),
      );

      // Initially online - no banner content
      expect(find.byIcon(Icons.wifi_off), findsNothing);

      // Go offline
      mockOfflineService.setConnectivity(false);
      await tester.pump();

      // Should show offline banner
      expect(find.byIcon(Icons.wifi_off), findsOneWidget);

      // Go back online
      mockOfflineService.setConnectivity(true);
      await tester.pump();

      // Should hide banner again
      expect(find.byIcon(Icons.wifi_off), findsNothing);
    });
  });

  group('OfflineWrapper', () {
    late MockOfflineService mockOfflineService;

    setUp(() {
      mockOfflineService = MockOfflineService();
    });

    tearDown(() {
      mockOfflineService.dispose();
    });

    testWidgets('should show child when online', (WidgetTester tester) async {
      await mockOfflineService.initialize();
      mockOfflineService.setConnectivity(true);

      const childText = 'Online Content';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OfflineWrapper(
              offlineService: mockOfflineService,
              child: const Text(childText),
            ),
          ),
        ),
      );

      expect(find.text(childText), findsOneWidget);
      expect(find.byIcon(Icons.wifi_off), findsNothing);
    });

    testWidgets('should show default offline widget when offline', (WidgetTester tester) async {
      await mockOfflineService.initialize();
      mockOfflineService.setConnectivity(false);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OfflineWrapper(
              offlineService: mockOfflineService,
              child: const Text('Online Content'),
            ),
          ),
        ),
      );

      await tester.pump();

      expect(find.byIcon(Icons.wifi_off), findsOneWidget);
      expect(find.text('You\'re currently offline'), findsOneWidget);
      expect(find.text('Online Content'), findsNothing);
    });

    testWidgets('should show custom offline widget when provided', (WidgetTester tester) async {
      await mockOfflineService.initialize();
      mockOfflineService.setConnectivity(false);

      const offlineText = 'Custom Offline Widget';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OfflineWrapper(
              offlineService: mockOfflineService,
              child: const Text('Online Content'),
              offlineChild: const Text(offlineText),
            ),
          ),
        ),
      );

      await tester.pump();

      expect(find.text(offlineText), findsOneWidget);
      expect(find.text('Online Content'), findsNothing);
    });

    testWidgets('should show custom offline message', (WidgetTester tester) async {
      await mockOfflineService.initialize();
      mockOfflineService.setConnectivity(false);

      const customMessage = 'Custom offline message';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OfflineWrapper(
              offlineService: mockOfflineService,
              child: const Text('Online Content'),
              offlineMessage: customMessage,
            ),
          ),
        ),
      );

      await tester.pump();

      expect(find.text(customMessage), findsOneWidget);
    });

    testWidgets('should show retry button when callback provided', (WidgetTester tester) async {
      await mockOfflineService.initialize();
      mockOfflineService.setConnectivity(false);

      bool retryPressed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OfflineWrapper(
              offlineService: mockOfflineService,
              child: const Text('Online Content'),
              onRetry: () => retryPressed = true,
            ),
          ),
        ),
      );

      await tester.pump();

      expect(find.text('Try Again'), findsOneWidget);

      await tester.tap(find.text('Try Again'));
      expect(retryPressed, isTrue);
    });

    testWidgets('should react to connectivity changes', (WidgetTester tester) async {
      await mockOfflineService.initialize();
      mockOfflineService.setConnectivity(true);

      const onlineText = 'Online Content';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OfflineWrapper(
              offlineService: mockOfflineService,
              child: const Text(onlineText),
            ),
          ),
        ),
      );

      // Initially online
      expect(find.text(onlineText), findsOneWidget);
      expect(find.byIcon(Icons.wifi_off), findsNothing);

      // Go offline
      mockOfflineService.setConnectivity(false);
      await tester.pump();

      // Should show offline widget
      expect(find.text(onlineText), findsNothing);
      expect(find.byIcon(Icons.wifi_off), findsOneWidget);

      // Go back online
      mockOfflineService.setConnectivity(true);
      await tester.pump();

      // Should show online content again
      expect(find.text(onlineText), findsOneWidget);
      expect(find.byIcon(Icons.wifi_off), findsNothing);
    });
  });
}