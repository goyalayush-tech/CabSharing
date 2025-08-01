import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:ridelink/screens/auth/splash_screen.dart';
import 'package:ridelink/providers/auth_provider.dart';
import 'package:ridelink/services/mock_auth_service.dart';

void main() {
  group('SplashScreen', () {
    late MockAuthService mockAuthService;
    late AuthProvider authProvider;

    setUp(() {
      mockAuthService = MockAuthService();
      authProvider = AuthProvider(mockAuthService);
    });

    tearDown(() {
      authProvider.dispose();
      mockAuthService.dispose();
    });

    Widget createTestWidget() {
      return MaterialApp(
        home: ChangeNotifierProvider<AuthProvider>.value(
          value: authProvider,
          child: const SplashScreen(),
        ),
      );
    }

    testWidgets('should display app logo and name', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());

      expect(find.text('RideLink'), findsOneWidget);
      expect(find.text('Share the journey, split the cost'), findsOneWidget);
      expect(find.byIcon(Icons.directions_car), findsOneWidget);
    });

    testWidgets('should display loading indicator', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('should have proper styling', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());

      // Check that the car icon has the expected size
      final carIcon = tester.widget<Icon>(find.byIcon(Icons.directions_car));
      expect(carIcon.size, 80);

      // Check that the title text exists
      expect(find.text('RideLink'), findsOneWidget);
      expect(find.text('Share the journey, split the cost'), findsOneWidget);
    });

    testWidgets('should be centered on screen', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());

      // Check that content is wrapped in Center widget
      expect(find.byType(Center), findsOneWidget);
      
      // Check that content is in a Column
      expect(find.byType(Column), findsOneWidget);
    });
  });
}