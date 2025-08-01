import 'package:flutter_test/flutter_test.dart';
import 'package:ridelink/services/mock_user_service.dart';
import 'package:ridelink/models/user_profile.dart';
import 'package:ridelink/models/rating.dart';

void main() {
  group('MockUserService', () {
    late MockUserService userService;

    setUp(() {
      userService = MockUserService();
    });

    tearDown(() {
      userService.dispose();
    });

    group('Profile Management', () {
      test('should create user profile successfully', () async {
        final profile = UserProfile(
          id: 'test-user-123',
          name: 'Test User',
          email: 'test@example.com',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        final createdProfile = await userService.createProfile(profile);

        expect(createdProfile.id, profile.id);
        expect(createdProfile.name, profile.name);
        expect(createdProfile.email, profile.email);
      });

      test('should throw error when creating duplicate profile', () async {
        final profile = UserProfile(
          id: 'test-user-123',
          name: 'Test User',
          email: 'test@example.com',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        await userService.createProfile(profile);

        expect(
          () => userService.createProfile(profile),
          throwsA(isA<Exception>()),
        );
      });

      test('should update user profile successfully', () async {
        final profile = UserProfile(
          id: 'test-user-123',
          name: 'Test User',
          email: 'test@example.com',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        await userService.createProfile(profile);

        final updatedProfile = profile.copyWith(
          name: 'Updated User',
          bio: 'Updated bio',
        );

        final result = await userService.updateProfile(updatedProfile);

        expect(result.name, 'Updated User');
        expect(result.bio, 'Updated bio');
      });

      test('should throw error when updating non-existent profile', () async {
        final profile = UserProfile(
          id: 'non-existent-user',
          name: 'Test User',
          email: 'test@example.com',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        expect(
          () => userService.updateProfile(profile),
          throwsA(isA<Exception>()),
        );
      });

      test('should get user profile successfully', () async {
        final profile = UserProfile(
          id: 'test-user-123',
          name: 'Test User',
          email: 'test@example.com',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        await userService.createProfile(profile);

        final retrievedProfile = await userService.getUserProfile('test-user-123');

        expect(retrievedProfile, isNotNull);
        expect(retrievedProfile!.id, profile.id);
        expect(retrievedProfile.name, profile.name);
      });

      test('should return null for non-existent user profile', () async {
        final retrievedProfile = await userService.getUserProfile('non-existent-user');

        expect(retrievedProfile, isNull);
      });

      test('should check if profile exists', () async {
        final profile = UserProfile(
          id: 'test-user-123',
          name: 'Test User',
          email: 'test@example.com',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        expect(await userService.profileExists('test-user-123'), false);

        await userService.createProfile(profile);

        expect(await userService.profileExists('test-user-123'), true);
      });
    });

    group('User Ratings', () {
      test('should get user rating successfully', () async {
        final rating = await userService.getUserRating('mock-user-123');

        expect(rating, isA<double>());
        expect(rating, greaterThanOrEqualTo(0.0));
        expect(rating, lessThanOrEqualTo(5.0));
      });

      test('should get user ratings list', () async {
        final ratings = await userService.getUserRatings('mock-user-123');

        expect(ratings, isA<List<Rating>>());
        expect(ratings.length, greaterThanOrEqualTo(0));
      });

      test('should update user rating', () async {
        await userService.updateUserRating('mock-user-123', 4.5);

        // Verify the rating was updated by checking the profile
        final profile = await userService.getUserProfile('mock-user-123');
        expect(profile?.averageRating, 4.5);
      });
    });

    group('Profile Image Management', () {
      test('should upload profile image successfully', () async {
        final imageUrl = await userService.uploadProfileImage('test-user-123', 'mock-image-data');

        expect(imageUrl, isNotNull);
        expect(imageUrl, contains('placeholder'));
      });

      test('should delete profile image successfully', () async {
        await userService.deleteProfileImage('test-user-123');
        // Mock service doesn't throw errors for deletion
      });
    });

    group('User Search', () {
      test('should search users by name', () async {
        final results = await userService.searchUsers('John');

        expect(results, isA<List<UserProfile>>());
        expect(results.length, greaterThanOrEqualTo(0));
        
        if (results.isNotEmpty) {
          expect(results.first.name.toLowerCase(), contains('john'));
        }
      });

      test('should return empty list for empty search query', () async {
        final results = await userService.searchUsers('');

        expect(results, isEmpty);
      });

      test('should return sorted results', () async {
        final results = await userService.searchUsers('e'); // Search for users with 'e' in name

        if (results.length > 1) {
          for (int i = 0; i < results.length - 1; i++) {
            expect(
              results[i].name.compareTo(results[i + 1].name),
              lessThanOrEqualTo(0),
            );
          }
        }
      });
    });

    group('Ride Count Management', () {
      test('should increment ride count', () async {
        final originalProfile = await userService.getUserProfile('mock-user-123');
        final originalCount = originalProfile?.totalRides ?? 0;

        await userService.incrementRideCount('mock-user-123');

        final updatedProfile = await userService.getUserProfile('mock-user-123');
        expect(updatedProfile?.totalRides, originalCount + 1);
      });
    });

    group('Profile Creation from Firebase User', () {
      test('should create profile from Firebase user', () async {
        final mockFirebaseUser = MockFirebaseUser();
        
        final profile = await userService.createProfileFromFirebaseUser(mockFirebaseUser);

        expect(profile.id, mockFirebaseUser.uid);
        expect(profile.name, mockFirebaseUser.displayName);
        expect(profile.email, mockFirebaseUser.email);
      });
    });

    group('Profile Stream', () {
      test('should provide profile stream', () async {
        final profile = UserProfile(
          id: 'stream-test-user',
          name: 'Stream Test User',
          email: 'stream@example.com',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        await userService.createProfile(profile);

        final stream = userService.getUserProfileStream('stream-test-user');
        
        expect(stream, isA<Stream<UserProfile?>>());
        
        final firstValue = await stream.first;
        expect(firstValue, isNotNull);
        expect(firstValue!.id, 'stream-test-user');
      });
    });
  });
}

class MockFirebaseUser {
  String get uid => 'firebase-user-123';
  String get displayName => 'Firebase User';
  String get email => 'firebase@example.com';
  String? get photoURL => null;
}