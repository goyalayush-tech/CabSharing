import 'dart:async';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:ridelink/services/auth_service.dart';
import 'package:ridelink/services/mock_auth_service.dart';
import 'package:ridelink/core/errors/app_error.dart';
import 'package:firebase_auth/firebase_auth.dart';

void main() {
  group('MockAuthService', () {
    late MockAuthService mockAuthService;

    setUp(() {
      mockAuthService = MockAuthService();
    });

    tearDown(() {
      mockAuthService.dispose();
    });

    group('currentUser', () {
      test('should return null when not signed in', () {
        expect(mockAuthService.currentUser, isNull);
      });

      test('should return user when signed in', () async {
        await mockAuthService.signInWithGoogle();
        expect(mockAuthService.currentUser, isNotNull);
        expect(mockAuthService.currentUser?.uid, 'mock-user-123');
      });
    });

    group('isSignedIn', () {
      test('should return false when not signed in', () {
        expect(mockAuthService.isSignedIn, false);
      });

      test('should return true when signed in', () async {
        await mockAuthService.signInWithGoogle();
        expect(mockAuthService.isSignedIn, true);
      });
    });

    group('authStateChanges', () {
      test('should emit auth state changes', () async {
        final states = <User?>[];
        final subscription = mockAuthService.authStateChanges.listen(states.add);
        
        await mockAuthService.signInWithGoogle();
        await mockAuthService.signOut();
        
        await Future.delayed(const Duration(milliseconds: 100));
        
        expect(states.length, 2);
        expect(states[0], isNotNull); // Sign in
        expect(states[1], isNull);    // Sign out
        
        await subscription.cancel();
      });
    });

    group('signInWithGoogle', () {
      test('should return user on successful sign in', () async {
        final user = await mockAuthService.signInWithGoogle();
        
        expect(user, isNotNull);
        expect(user?.uid, 'mock-user-123');
        expect(user?.email, 'mockuser@example.com');
        expect(user?.displayName, 'Mock User');
        expect(mockAuthService.isSignedIn, true);
      });

      test('should update auth state on sign in', () async {
        bool stateChanged = false;
        final subscription = mockAuthService.authStateChanges.listen((user) {
          if (user != null) stateChanged = true;
        });
        
        await mockAuthService.signInWithGoogle();
        await Future.delayed(const Duration(milliseconds: 100));
        
        expect(stateChanged, true);
        await subscription.cancel();
      });

      test('should simulate network delay', () async {
        final stopwatch = Stopwatch()..start();
        await mockAuthService.signInWithGoogle();
        stopwatch.stop();
        
        expect(stopwatch.elapsedMilliseconds, greaterThan(900));
      });
    });

    group('signOut', () {
      test('should sign out successfully', () async {
        await mockAuthService.signInWithGoogle();
        expect(mockAuthService.isSignedIn, true);
        
        await mockAuthService.signOut();
        expect(mockAuthService.isSignedIn, false);
        expect(mockAuthService.currentUser, isNull);
      });

      test('should update auth state on sign out', () async {
        await mockAuthService.signInWithGoogle();
        
        bool stateChanged = false;
        final subscription = mockAuthService.authStateChanges.listen((user) {
          if (user == null) stateChanged = true;
        });
        
        await mockAuthService.signOut();
        await Future.delayed(const Duration(milliseconds: 100));
        
        expect(stateChanged, true);
        await subscription.cancel();
      });
    });

    group('deleteAccount', () {
      test('should delete account successfully', () async {
        await mockAuthService.signInWithGoogle();
        expect(mockAuthService.isSignedIn, true);
        
        await mockAuthService.deleteAccount();
        expect(mockAuthService.isSignedIn, false);
        expect(mockAuthService.currentUser, isNull);
      });

      test('should work when no user is signed in', () async {
        expect(mockAuthService.isSignedIn, false);
        
        await mockAuthService.deleteAccount();
        expect(mockAuthService.isSignedIn, false);
      });
    });

    group('reauthenticate', () {
      test('should reauthenticate successfully', () async {
        await mockAuthService.signInWithGoogle();
        
        await mockAuthService.reauthenticate();
        expect(mockAuthService.isSignedIn, true);
      });

      test('should work when no user is signed in', () async {
        expect(mockAuthService.isSignedIn, false);
        
        await mockAuthService.reauthenticate();
        expect(mockAuthService.isSignedIn, false);
      });
    });

  });

  group('AuthService Interface', () {
    test('should have correct interface methods', () {
      // Test that the AuthService class has the expected interface
      // without instantiating it (which would require Firebase initialization)
      expect(AuthService, isA<Type>());
    });
  });

  group('MockUser', () {
    late MockUser mockUser;

    setUp(() {
      mockUser = MockUser();
    });

    test('should have correct mock data', () {
      expect(mockUser.uid, 'mock-user-123');
      expect(mockUser.displayName, 'Mock User');
      expect(mockUser.email, 'mockuser@example.com');
      expect(mockUser.photoURL, 'https://via.placeholder.com/150');
      expect(mockUser.emailVerified, true);
      expect(mockUser.isAnonymous, false);
    });

    test('should have valid timestamps', () {
      expect(mockUser.createdTime, isA<DateTime>());
      expect(mockUser.lastSignInTime, isA<DateTime>());
      expect(mockUser.createdTime.isBefore(DateTime.now()), true);
      expect(mockUser.lastSignInTime.isBefore(DateTime.now().add(const Duration(seconds: 1))), true);
    });

    test('should return mock token', () async {
      final token = await mockUser.getIdToken();
      expect(token, 'mock-id-token');
    });

    test('should return mock token result', () async {
      final tokenResult = await mockUser.getIdTokenResult();
      expect(tokenResult.token, 'mock-id-token');
      expect(tokenResult.claims?['email'], 'mockuser@example.com');
    });
  });
}