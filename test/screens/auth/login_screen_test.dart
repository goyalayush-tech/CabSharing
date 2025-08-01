import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:ridelink/screens/auth/login_screen.dart';
import 'package:ridelink/providers/auth_provider.dart';
import 'package:ridelink/services/mock_auth_service.dart';

void main() {
  group('LoginScreen', () {
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
          child: const LoginScreen(),
        ),
      );
    }

    testWidgets('should display app title and description', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Welcome to RideLink'), findsOneWidget);
      expect(find.text('Connect with fellow travelers and share your journey'), findsOneWidget);
    });

    testWidgets('should display car icon', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.directions_car), findsOneWidget);
    });

    testWidgets('should display sign in button', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Sign in with Google'), findsOneWidget);
      expect(find.byIcon(Icons.login), findsOneWidget);
    });

    testWidgets('should display terms and privacy text', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.textContaining('Terms of Service'), findsOneWidget);
      expect(find.textContaining('Privacy Policy'), findsOneWidget);
    });

    testWidgets('should show loading state when signing in', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Tap the sign in button
      await tester.tap(find.text('Sign in with Google'));
      await tester.pump(); // Trigger the loading state

      expect(find.text('Signing in...'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('should disable button when loading', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      final button = find.byType(ElevatedButton);
      expect(tester.widget<ElevatedButton>(button).onPressed, isNotNull);

      // Tap the sign in button to start loading
      await tester.tap(button);
      await tester.pump();

      // Button should be disabled during loading
      expect(tester.widget<ElevatedButton>(button).onPressed, isNull);
    });
  });
}