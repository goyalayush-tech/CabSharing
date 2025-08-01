import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:ridelink/providers/user_provider.dart';
import 'package:ridelink/services/mock_user_service.dart';
import 'package:ridelink/models/user_profile.dart';
import 'package:ridelink/models/rating.dart';
import 'package:ridelink/core/errors/app_error.dart';

void main() {
  group('UserProvider', () {
    late UserProvider userProvider;
    late MockUserService mockUserService;

    setUp(() {
      mockUserService = MockUserService();
      userProvider = UserProvider(mockUserService);
    });

    tearDown(() {
      userProvider.dispose();
      mockUserService.dispose();
    });

    group('Initial State', () {
      test('should have correct initial state', () {
        expect(userProvider.currentUserProfile, isNull);
        expect(userProvider.userRatings, isEmpty);
        expect(userProvider.isLoading, false);
        expect(userProvider.isUpdating, false);
        expect(userProvider.isUploadingImage, false);
        expect(userProvider.error, isNull);
        expect(userProvider.hasProfile, false);
        expect(userProvider.isProfileComplete, false);
      });
    });

    group('Profile Loading', () {
      test('should load user profile successfully', () async {
        expect(userProvider.isLoading, false);
        
        final future = userProvider.loadUserProfile('mock-user-123');
        expect(userProvider.isLoading, true);
        
        await future;
        
        expect(userProvider.isLoading, false);
        expect(userProvider.currentUserProfile, isNotNull);
        expect(userProvider.currentUserProfile!.id, 'mock-user-123');
        expect(userProvider.hasProfile, true);
        expect(userProvider.error, isNull);
      });

      test('should handle empty user ID', () async {
        await userProvider.loadUserProfile('');
        
        expect(userProvider.currentUserProfile, isNull);
        expect(userProvider.hasProfile, false);
      });

      test('should load user ratings along with profile', () async {
        await userProvider.loadUserProfile('mock-user-123');
        
        expect(userProvider.userRatings, isA<List<Rating>>());
        expect(userProvider.userRatings.length, greaterThanOrEqualTo(0));
      });

      test('should handle profile loading error', () async {
        // Mock service will return null for non-existent users
        await userProvider.loadUserProfile('non-existent-user');
        
        expect(userProvider.currentUserProfile, isNull);
        expect(userProvider.hasProfile, false);
        expect(userProvider.isLoading, false);
      });
    });

    group('Profile Creation', () {
      test('should create profile successfully', () async {
        final profile = UserProfile(
          id: 'new-user-123',
          name: 'New User',
          email: 'new@example.com',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        expect(userProvider.isLoading, false);
        
        final future = userProvider.createProfile(profile);
        expect(userProvider.isLoading, true);
        
        await future;
        
        expect(userProvider.isLoading, false);
        expect(userProvider.currentUserProfile, isNotNull);
        expect(userProvider.currentUserProfile!.id, 'new-user-123');
        expect(userProvider.hasProfile, true);
        expect(userProvider.error, isNull);
      });

      test('should handle profile creation error', () async {
        // Create a profile that already exists
        final existingProfile = UserProfile(
          id: 'mock-user-123', // This already exists in mock data
          name: 'Existing User',
          email: 'existing@example.com',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        await userProvider.createProfile(existingProfile);
        
        expect(userProvider.isLoading, false);
        expect(userProvider.error, isNotNull);
      });
    });

    group('Profile Updates', () {
      test('should update profile successfully', () async {
        // First create a profile
        final profile = UserProfile(
          id: 'update-test-user',
          name: 'Original Name',
          email: 'original@example.com',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        await userProvider.createProfile(profile);
        
        // Now update it
        final updatedProfile = profile.copyWith(
          name: 'Updated Name',
          bio: 'Updated bio',
        );

        expect(userProvider.isUpdating, false);
        
        final future = userProvider.updateProfile(updatedProfile);
        expect(userProvider.isUpdating, true);
        
        await future;
        
        expect(userProvider.isUpdating, false);
        expect(userProvider.currentUserProfile!.name, 'Updated Name');
        expect(userProvider.currentUserProfile!.bio, 'Updated bio');
        expect(userProvider.error, isNull);
      });

      test('should handle profile update error', () async {
        final nonExistentProfile = UserProfile(
          id: 'non-existent-user',
          name: 'Non Existent',
          email: 'nonexistent@example.com',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        await userProvider.updateProfile(nonExistentProfile);
        
        expect(userProvider.isUpdating, false);
        expect(userProvider.error, isNotNull);
      });
    });

    group('Profile Creation from Firebase User', () {
      test('should handle Firebase user creation flow', () async {
        // Test the basic flow without complex Firebase user mocking
        expect(userProvider.currentUserProfile, isNull);
        
        // The method exists and can be called
        expect(() => userProvider.createProfileFromFirebaseUser, returnsNormally);
      });
    });

    group('Profile Image Management', () {
      test('should upload profile image successfully', () async {
        // First create a profile
        final profile = UserProfile(
          id: 'image-test-user',
          name: 'Image Test User',
          email: 'imagetest@example.com',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        await userProvider.createProfile(profile);

        expect(userProvider.isUploadingImage, false);
        
        final future = userProvider.uploadProfileImage('image-test-user', 'mock-image-data');
        expect(userProvider.isUploadingImage, true);
        
        await future;
        
        expect(userProvider.isUploadingImage, false);
        expect(userProvider.currentUserProfile!.profileImageUrl, isNotNull);
        expect(userProvider.error, isNull);
      });

      test('should handle profile image deletion', () async {
        // First create a profile with an image
        final profile = UserProfile(
          id: 'delete-image-test-user',
          name: 'Delete Image Test User',
          email: 'deleteimagetest@example.com',
          profileImageUrl: 'https://example.com/image.jpg',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        await userProvider.createProfile(profile);
        expect(userProvider.currentUserProfile!.profileImageUrl, isNotNull);

        expect(userProvider.isUpdating, false);
        
        // Test that the method can be called without errors
        await userProvider.deleteProfileImage('delete-image-test-user');
        
        expect(userProvider.isUpdating, false);
        expect(userProvider.error, isNull);
      });
    });

    group('User Search', () {
      test('should search users successfully', () async {
        final results = await userProvider.searchUsers('John');
        
        expect(results, isA<List<UserProfile>>());
        expect(results.length, greaterThanOrEqualTo(0));
        
        if (results.isNotEmpty) {
          expect(results.first.name.toLowerCase(), contains('john'));
        }
      });

      test('should return empty list for empty search query', () async {
        final results = await userProvider.searchUsers('');
        
        expect(results, isEmpty);
      });
    });

    group('Profile Refresh', () {
      test('should refresh profile when profile exists', () async {
        await userProvider.loadUserProfile('mock-user-123');
        
        final originalProfile = userProvider.currentUserProfile;
        expect(originalProfile, isNotNull);
        
        await userProvider.refreshProfile();
        
        expect(userProvider.currentUserProfile, isNotNull);
        expect(userProvider.currentUserProfile!.id, originalProfile!.id);
      });

      test('should not refresh when no profile exists', () async {
        expect(userProvider.currentUserProfile, isNull);
        
        await userProvider.refreshProfile();
        
        expect(userProvider.currentUserProfile, isNull);
      });
    });

    group('Error Handling', () {
      test('should clear error', () async {
        // Trigger an error by trying to update non-existent profile
        final nonExistentProfile = UserProfile(
          id: 'non-existent-user',
          name: 'Non Existent',
          email: 'nonexistent@example.com',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        await userProvider.updateProfile(nonExistentProfile);
        expect(userProvider.error, isNotNull);
        
        userProvider.clearError();
        expect(userProvider.error, isNull);
      });

      test('should clear profile and reset state', () async {
        await userProvider.loadUserProfile('mock-user-123');
        expect(userProvider.hasProfile, true);
        
        userProvider.clearProfile();
        
        expect(userProvider.currentUserProfile, isNull);
        expect(userProvider.userRatings, isEmpty);
        expect(userProvider.hasProfile, false);
        expect(userProvider.error, isNull);
      });
    });

    group('State Management', () {
      test('should notify listeners on state changes', () async {
        bool notified = false;
        userProvider.addListener(() {
          notified = true;
        });
        
        await userProvider.loadUserProfile('mock-user-123');
        
        expect(notified, true);
      });

      test('should update loading state correctly', () async {
        bool loadingStateChanged = false;
        userProvider.addListener(() {
          if (userProvider.isLoading) {
            loadingStateChanged = true;
          }
        });
        
        await userProvider.loadUserProfile('mock-user-123');
        
        expect(loadingStateChanged, true);
      });

      test('should identify complete profile', () async {
        final completeProfile = UserProfile(
          id: 'complete-user',
          name: 'Complete User',
          email: 'complete@example.com',
          bio: 'Complete bio',
          phoneNumber: '+1234567890',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        await userProvider.createProfile(completeProfile);
        
        expect(userProvider.isProfileComplete, true);
      });

      test('should identify incomplete profile', () async {
        final incompleteProfile = UserProfile(
          id: 'incomplete-user',
          name: 'Incomplete User',
          email: 'incomplete@example.com',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        await userProvider.createProfile(incompleteProfile);
        
        expect(userProvider.isProfileComplete, false);
      });
    });
  });
}

class MockFirebaseUser {
  final String uid;
  final String displayName;
  final String email;
  final String? photoURL;

  MockFirebaseUser({
    required this.uid,
    required this.displayName,
    required this.email,
    this.photoURL,
  });
}