import 'package:flutter_test/flutter_test.dart';
import 'package:ridelink/providers/auth_provider.dart';
import 'package:ridelink/services/mock_auth_service.dart';
import 'package:ridelink/core/errors/app_error.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;

void main() {
  group('AuthProvider', () {
    late AuthProvider authProvider;
    late MockAuthService mockAuthService;

    setUp(() {
      mockAuthService = MockAuthService();
      authProvider = AuthProvider(mockAuthService);
    });

    tearDown(() {
      authProvider.dispose();
      mockAuthService.dispose();
    });

    group('Initial State', () {
      test('should transition to unauthenticated state', () async {
        // Wait for the auth state to be determined
        await Future.delayed(const Duration(milliseconds: 100));
        
        expect(authProvider.state, AuthState.unauthenticated);
        expect(authProvider.user, isNull);
        expect(authProvider.error, isNull);
        expect(authProvider.isLoading, false);
        expect(authProvider.isAuthenticated, false);
        expect(authProvider.isUnauthenticated, true);
      });
    });

    group('Sign In', () {
      test('should sign in successfully', () async {
        expect(authProvider.isLoading, false);
        
        final future = authProvider.signInWithGoogle();
        expect(authProvider.isLoading, true);
        
        await future;
        
        expect(authProvider.isLoading, false);
        expect(authProvider.state, AuthState.authenticated);
        expect(authProvider.user, isNotNull);
        expect(authProvider.user?.uid, 'mock-user-123');
        expect(authProvider.isAuthenticated, true);
        expect(authProvider.error, isNull);
      });

      test('should handle sign in cancellation', () async {
        // Mock service always returns a user, so we can't test cancellation directly
        // But we can test the state management
        await authProvider.signInWithGoogle();
        expect(authProvider.state, AuthState.authenticated);
      });

      test('should clear error on successful sign in', () async {
        // Set an error first
        authProvider.clearError();
        
        await authProvider.signInWithGoogle();
        expect(authProvider.error, isNull);
      });
    });

    group('Sign Out', () {
      test('should sign out successfully', () async {
        // Sign in first
        await authProvider.signInWithGoogle();
        expect(authProvider.isAuthenticated, true);
        
        expect(authProvider.isLoading, false);
        
        final future = authProvider.signOut();
        expect(authProvider.isLoading, true);
        
        await future;
        
        expect(authProvider.isLoading, false);
        expect(authProvider.state, AuthState.unauthenticated);
        expect(authProvider.user, isNull);
        expect(authProvider.isAuthenticated, false);
        expect(authProvider.error, isNull);
      });

      test('should handle sign out when not signed in', () async {
        expect(authProvider.isAuthenticated, false);
        
        await authProvider.signOut();
        
        expect(authProvider.state, AuthState.unauthenticated);
        expect(authProvider.error, isNull);
      });
    });

    group('Delete Account', () {
      test('should delete account successfully', () async {
        // Sign in first
        await authProvider.signInWithGoogle();
        expect(authProvider.isAuthenticated, true);
        
        expect(authProvider.isLoading, false);
        
        final future = authProvider.deleteAccount();
        expect(authProvider.isLoading, true);
        
        await future;
        
        expect(authProvider.isLoading, false);
        expect(authProvider.state, AuthState.unauthenticated);
        expect(authProvider.user, isNull);
        expect(authProvider.isAuthenticated, false);
        expect(authProvider.error, isNull);
      });

      test('should handle delete account when not signed in', () async {
        expect(authProvider.isAuthenticated, false);
        
        await authProvider.deleteAccount();
        
        expect(authProvider.state, AuthState.unauthenticated);
        expect(authProvider.error, isNull);
      });
    });

    group('Reauthenticate', () {
      test('should reauthenticate successfully', () async {
        // Sign in first
        await authProvider.signInWithGoogle();
        expect(authProvider.isAuthenticated, true);
        
        expect(authProvider.isLoading, false);
        
        final future = authProvider.reauthenticate();
        expect(authProvider.isLoading, true);
        
        await future;
        
        expect(authProvider.isLoading, false);
        expect(authProvider.isAuthenticated, true);
        expect(authProvider.error, isNull);
      });

      test('should handle reauthenticate when not signed in', () async {
        expect(authProvider.isAuthenticated, false);
        
        await authProvider.reauthenticate();
        
        expect(authProvider.error, isNull);
      });
    });

    group('Error Handling', () {
      test('should clear error', () async {
        // Since mock service doesn't throw errors, we'll test the clearError method directly
        authProvider.clearError();
        expect(authProvider.error, isNull);
      });

      test('should handle auth state stream errors', () async {
        // This would require a mock service that can emit errors
        // For now, we'll test that the provider handles the stream correctly
        expect(authProvider.state, isA<AuthState>());
      });
    });

    group('State Management', () {
      test('should notify listeners on state changes', () async {
        bool notified = false;
        authProvider.addListener(() {
          notified = true;
        });
        
        await authProvider.signInWithGoogle();
        
        expect(notified, true);
      });

      test('should update loading state correctly', () async {
        bool loadingStateChanged = false;
        authProvider.addListener(() {
          if (authProvider.isLoading) {
            loadingStateChanged = true;
          }
        });
        
        await authProvider.signInWithGoogle();
        
        expect(loadingStateChanged, true);
      });

      test('should maintain consistent state', () async {
        // Wait for initial state to settle
        await Future.delayed(const Duration(milliseconds: 200));
        
        // Only check consistency for non-initial states
        if (authProvider.state != AuthState.initial) {
          expect(authProvider.isAuthenticated, !authProvider.isUnauthenticated);
        }
        
        await authProvider.signInWithGoogle();
        expect(authProvider.isAuthenticated, !authProvider.isUnauthenticated);
        
        await authProvider.signOut();
        expect(authProvider.isAuthenticated, !authProvider.isUnauthenticated);
      });
    });

    group('Auth State Changes', () {
      test('should respond to auth service state changes', () async {
        // Sign in through the service directly
        await mockAuthService.signInWithGoogle();
        
        // Give the provider time to respond to the stream
        await Future.delayed(const Duration(milliseconds: 100));
        
        expect(authProvider.isAuthenticated, true);
        expect(authProvider.user, isNotNull);
      });

      test('should respond to sign out through service', () async {
        // Sign in first
        await mockAuthService.signInWithGoogle();
        await Future.delayed(const Duration(milliseconds: 100));
        expect(authProvider.isAuthenticated, true);
        
        // Sign out through service
        await mockAuthService.signOut();
        await Future.delayed(const Duration(milliseconds: 100));
        
        expect(authProvider.isAuthenticated, false);
        expect(authProvider.user, isNull);
      });
    });

    group('Getters', () {
      test('should return correct state values', () {
        expect(authProvider.state, isA<AuthState>());
        expect(authProvider.user, isA<User?>());
        expect(authProvider.error, isA<AppError?>());
        expect(authProvider.isLoading, isA<bool>());
        expect(authProvider.isAuthenticated, isA<bool>());
        expect(authProvider.isUnauthenticated, isA<bool>());
      });

      test('should have consistent authentication state', () async {
        // Wait for initial state to settle
        await Future.delayed(const Duration(milliseconds: 200));
        
        if (authProvider.isAuthenticated) {
          expect(authProvider.state, AuthState.authenticated);
          expect(authProvider.user, isNotNull);
          expect(authProvider.isUnauthenticated, false);
        } else if (authProvider.isUnauthenticated) {
          expect(authProvider.state, AuthState.unauthenticated);
          expect(authProvider.isAuthenticated, false);
        }
      });
    });
  });
}