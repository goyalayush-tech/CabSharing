import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:ridelink/screens/home/home_screen.dart';
import 'package:ridelink/providers/auth_provider.dart';
import 'package:ridelink/providers/ride_provider.dart';
import 'package:ridelink/providers/user_provider.dart';
import 'package:ridelink/services/mock_auth_service.dart';
import 'package:ridelink/services/mock_ride_service.dart';
import 'package:ridelink/services/mock_user_service.dart';
import 'package:ridelink/models/ride_group.dart';

void main() {
  group('HomeScreen', () {
    late MockAuthService mockAuthService;
    late MockRideService mockRideService;
    late MockUserService mockUserService;
    late AuthProvider authProvider;
    late RideProvider rideProvider;
    late UserProvider userProvider;

    setUp(() {
      mockAuthService = MockAuthService();
      mockRideService = MockRideService();
      mockUserService = MockUserService();
      authProvider = AuthProvider(mockAuthService);
      rideProvider = RideProvider(mockRideService);
      userProvider = UserProvider(mockUserService);
    });

    tearDown(() {
      authProvider.dispose();
      rideProvider.dispose();
      userProvider.dispose();
      mockAuthService.dispose();
      mockRideService.dispose();
      mockUserService.dispose();
    });

    Widget createTestWidget() {
      return MaterialApp(
        home: MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
            ChangeNotifierProvider<RideProvider>.value(value: rideProvider),
            ChangeNotifierProvider<UserProvider>.value(value: userProvider),
          ],
          child: const HomeScreen(),
        ),
      );
    }

    testWidgets('should display bottom navigation with three tabs', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());

      expect(find.byType(BottomNavigationBar), findsOneWidget);
      expect(find.text('Home'), findsOneWidget);
      expect(find.text('My Rides'), findsOneWidget);
      expect(find.text('Profile'), findsOneWidget);
    });

    testWidgets('should show floating action button on home tab', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());

      expect(find.byType(FloatingActionButton), findsOneWidget);
      expect(find.byIcon(Icons.add), findsOneWidget);
    });

    testWidgets('should hide floating action button on other tabs', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());

      // Switch to My Rides tab
      await tester.tap(find.text('My Rides'));
      await tester.pump();

      expect(find.byType(FloatingActionButton), findsNothing);

      // Switch to Profile tab
      await tester.tap(find.text('Profile'));
      await tester.pump();

      expect(find.byType(FloatingActionButton), findsNothing);
    });

    testWidgets('should display search bar on home tab', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());

      expect(find.text('Find Rides'), findsOneWidget);
      expect(find.text('Where are you going?'), findsOneWidget);
      expect(find.byIcon(Icons.search), findsOneWidget);
    });

    testWidgets('should display filter button', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());

      expect(find.byIcon(Icons.filter_list), findsOneWidget);
    });

    testWidgets('should show filters when filter button is tapped', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());

      // Tap filter button
      await tester.tap(find.byIcon(Icons.filter_list));
      await tester.pump();

      expect(find.text('Filters'), findsOneWidget);
      expect(find.text('Female Only'), findsOneWidget);
      expect(find.text('Date'), findsOneWidget);
    });

    testWidgets('should display loading indicator when loading nearby rides', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      
      // The provider should be loading initially
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('should display rides when loaded', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Should show ride cards or empty state
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('should switch between tabs correctly', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());

      // Initially on Home tab
      expect(find.text('Find Rides'), findsOneWidget);

      // Switch to My Rides tab
      await tester.tap(find.text('My Rides'));
      await tester.pump();

      expect(find.text('My Rides'), findsOneWidget);
      expect(find.text('Upcoming'), findsOneWidget);
      expect(find.text('Completed'), findsOneWidget);
      expect(find.text('Cancelled'), findsOneWidget);

      // Switch to Profile tab
      await tester.tap(find.text('Profile'));
      await tester.pump();

      expect(find.text('Profile'), findsOneWidget);
    });

    testWidgets('should display search functionality', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());

      final searchField = find.widgetWithText(TextField, 'Where are you going?');
      expect(searchField, findsOneWidget);

      // Enter search text
      await tester.enterText(searchField, 'Airport');
      await tester.pump();

      // Should show clear button
      expect(find.byIcon(Icons.clear), findsOneWidget);
    });

    testWidgets('should clear search when clear button is tapped', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());

      final searchField = find.widgetWithText(TextField, 'Where are you going?');
      
      // Enter search text
      await tester.enterText(searchField, 'Airport');
      await tester.pump();

      // Tap clear button
      await tester.tap(find.byIcon(Icons.clear));
      await tester.pump();

      // Search field should be empty
      expect(find.text('Airport'), findsNothing);
    });

    testWidgets('should display My Rides tabs', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());

      // Switch to My Rides tab
      await tester.tap(find.text('My Rides'));
      await tester.pump();

      expect(find.text('Upcoming'), findsOneWidget);
      expect(find.text('Completed'), findsOneWidget);
      expect(find.text('Cancelled'), findsOneWidget);
    });

    testWidgets('should show empty state for no rides', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Should show empty state message
      expect(find.textContaining('No nearby rides'), findsOneWidget);
    });

    testWidgets('should support pull to refresh', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Find RefreshIndicator
      expect(find.byType(RefreshIndicator), findsOneWidget);
    });

    testWidgets('should toggle female only filter', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());

      // Show filters
      await tester.tap(find.byIcon(Icons.filter_list));
      await tester.pump();

      // Find and tap female only checkbox
      final checkbox = find.byType(Checkbox);
      expect(checkbox, findsOneWidget);

      await tester.tap(checkbox);
      await tester.pump();

      // Checkbox should be checked
      final checkboxWidget = tester.widget<Checkbox>(checkbox);
      expect(checkboxWidget.value, true);
    });
  });
}