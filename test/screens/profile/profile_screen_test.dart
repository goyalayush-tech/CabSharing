import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:ridelink/screens/profile/profile_screen.dart';
import 'package:ridelink/providers/user_provider.dart';
import 'package:ridelink/providers/auth_provider.dart';
import 'package:ridelink/services/mock_user_service.dart';
import 'package:ridelink/services/mock_auth_service.dart';
import 'package:ridelink/models/user_profile.dart';

void main() {
  group('ProfileScreen', () {
    late MockUserService mockUserService;
    late MockAuthService mockAuthService;
    late UserProvider userProvider;
    late AuthProvider authProvider;

    setUp(() {
      mockUserService = MockUserService();
      mockAuthService = MockAuthService();
      userProvider = UserProvider(mockUserService);
      authProvider = AuthProvider(mockAuthService);
    });

    tearDown(() {
      userProvider.dispose();
      authProvider.dispose();
      mockUserService.dispose();
      mockAuthService.dispose();
    });

    Widget createTestWidget() {
      return MaterialApp(
        home: MultiProvider(
          providers: [
            ChangeNotifierProvider<UserProvider>.value(value: userProvider),
            ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
          ],
          child: const ProfileScreen(),
        ),
      );
    }

    testWidgets('should display loading indicator when loading profile', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('should display create profile prompt when no profile exists', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Complete Your Profile'), findsOneWidget);
      expect(find.text('Add your details to start connecting with other riders'), findsOneWidget);
      expect(find.text('Create Profile'), findsOneWidget);
      expect(find.byIcon(Icons.person_add), findsOneWidget);
    });

    testWidgets('should display profile content when profile exists', (WidgetTester tester) async {
      // First sign in a user
      await authProvider.signInWithGoogle();
      await tester.pump();

      // Create a profile for the signed-in user
      final profile = UserProfile(
        id: 'mock-user-123',
        name: 'Test User',
        email: 'test@example.com',
        bio: 'Test bio',
        phoneNumber: '+1234567890',
        averageRating: 4.5,
        totalRides: 10,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await userProvider.createProfile(profile);

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Test User'), findsOneWidget);
      expect(find.text('4.5'), findsOneWidget);
      expect(find.text('10'), findsOneWidget);
      expect(find.text('Test bio'), findsOneWidget);
      expect(find.byIcon(Icons.star), findsWidgets);
    });

    testWidgets('should have edit button when profile exists', (WidgetTester tester) async {
      // Sign in and create profile
      await authProvider.signInWithGoogle();
      final profile = UserProfile(
        id: 'mock-user-123',
        name: 'Test User',
        email: 'test@example.com',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await userProvider.createProfile(profile);

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.edit), findsOneWidget);
    });

    testWidgets('should display profile stats correctly', (WidgetTester tester) async {
      await authProvider.signInWithGoogle();
      final profile = UserProfile(
        id: 'mock-user-123',
        name: 'Test User',
        email: 'test@example.com',
        averageRating: 4.2,
        totalRides: 15,
        createdAt: DateTime.now().subtract(const Duration(days: 60)),
        updatedAt: DateTime.now(),
      );
      await userProvider.createProfile(profile);

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('15'), findsOneWidget); // Total rides
      expect(find.text('4.2'), findsOneWidget); // Average rating
      expect(find.text('Rides'), findsOneWidget);
      expect(find.text('Rating'), findsOneWidget);
      expect(find.text('Member Since'), findsOneWidget);
    });

    testWidgets('should display contact information', (WidgetTester tester) async {
      await authProvider.signInWithGoogle();
      final profile = UserProfile(
        id: 'mock-user-123',
        name: 'Test User',
        email: 'test@example.com',
        phoneNumber: '+1234567890',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await userProvider.createProfile(profile);

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Contact Information'), findsOneWidget);
      expect(find.text('test@example.com'), findsOneWidget);
      expect(find.text('+1234567890'), findsOneWidget);
      expect(find.byIcon(Icons.email), findsOneWidget);
      expect(find.byIcon(Icons.phone), findsOneWidget);
    });

    testWidgets('should support pull to refresh', (WidgetTester tester) async {
      await authProvider.signInWithGoogle();
      final profile = UserProfile(
        id: 'mock-user-123',
        name: 'Test User',
        email: 'test@example.com',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await userProvider.createProfile(profile);

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Find the RefreshIndicator
      expect(find.byType(RefreshIndicator), findsOneWidget);
    });
  });
}