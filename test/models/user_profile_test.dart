import 'package:flutter_test/flutter_test.dart';
import 'package:ridelink/models/user_profile.dart';

void main() {
  group('UserProfile', () {
    test('should create UserProfile from JSON', () {
      final json = {
        'id': 'user123',
        'name': 'John Doe',
        'email': 'john@example.com',
        'profileImageUrl': 'https://example.com/image.jpg',
        'bio': 'Test bio',
        'phoneNumber': '+1234567890',
        'averageRating': 4.5,
        'totalRides': 10,
        'isVerified': true,
        'createdAt': '2023-01-01T00:00:00.000Z',
        'updatedAt': '2023-01-01T00:00:00.000Z',
      };

      final userProfile = UserProfile.fromJson(json);

      expect(userProfile.id, 'user123');
      expect(userProfile.name, 'John Doe');
      expect(userProfile.email, 'john@example.com');
      expect(userProfile.profileImageUrl, 'https://example.com/image.jpg');
      expect(userProfile.bio, 'Test bio');
      expect(userProfile.phoneNumber, '+1234567890');
      expect(userProfile.averageRating, 4.5);
      expect(userProfile.totalRides, 10);
      expect(userProfile.isVerified, true);
    });

    test('should convert UserProfile to JSON', () {
      final userProfile = UserProfile(
        id: 'user123',
        name: 'John Doe',
        email: 'john@example.com',
        profileImageUrl: 'https://example.com/image.jpg',
        bio: 'Test bio',
        phoneNumber: '+1234567890',
        averageRating: 4.5,
        totalRides: 10,
        isVerified: true,
        createdAt: DateTime.parse('2023-01-01T00:00:00.000Z'),
        updatedAt: DateTime.parse('2023-01-01T00:00:00.000Z'),
      );

      final json = userProfile.toJson();

      expect(json['id'], 'user123');
      expect(json['name'], 'John Doe');
      expect(json['email'], 'john@example.com');
      expect(json['profileImageUrl'], 'https://example.com/image.jpg');
      expect(json['bio'], 'Test bio');
      expect(json['phoneNumber'], '+1234567890');
      expect(json['averageRating'], 4.5);
      expect(json['totalRides'], 10);
      expect(json['isVerified'], true);
      expect(json['createdAt'], '2023-01-01T00:00:00.000Z');
      expect(json['updatedAt'], '2023-01-01T00:00:00.000Z');
    });

    test('should create UserProfile with default values', () {
      final userProfile = UserProfile(
        id: 'user123',
        name: 'John Doe',
        email: 'john@example.com',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      expect(userProfile.averageRating, 0.0);
      expect(userProfile.totalRides, 0);
      expect(userProfile.isVerified, false);
      expect(userProfile.profileImageUrl, null);
      expect(userProfile.bio, null);
      expect(userProfile.phoneNumber, null);
    });

    test('should copy UserProfile with new values', () {
      final original = UserProfile(
        id: 'user123',
        name: 'John Doe',
        email: 'john@example.com',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final copied = original.copyWith(
        name: 'Jane Doe',
        bio: 'New bio',
        averageRating: 4.8,
      );

      expect(copied.id, original.id);
      expect(copied.name, 'Jane Doe');
      expect(copied.email, original.email);
      expect(copied.bio, 'New bio');
      expect(copied.averageRating, 4.8);
      expect(copied.totalRides, original.totalRides);
    });

    group('Validation', () {
      test('should throw error for empty ID', () {
        expect(
          () => UserProfile(
            id: '',
            name: 'John Doe',
            email: 'john@example.com',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('should throw error for empty name', () {
        expect(
          () => UserProfile(
            id: 'user123',
            name: '',
            email: 'john@example.com',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('should throw error for invalid email', () {
        expect(
          () => UserProfile(
            id: 'user123',
            name: 'John Doe',
            email: 'invalid-email',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('should throw error for invalid rating range', () {
        expect(
          () => UserProfile(
            id: 'user123',
            name: 'John Doe',
            email: 'john@example.com',
            averageRating: 6.0,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('should throw error for negative total rides', () {
        expect(
          () => UserProfile(
            id: 'user123',
            name: 'John Doe',
            email: 'john@example.com',
            totalRides: -1,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('should throw error for invalid phone number', () {
        expect(
          () => UserProfile(
            id: 'user123',
            name: 'John Doe',
            email: 'john@example.com',
            phoneNumber: '123',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('should throw error for bio too long', () {
        expect(
          () => UserProfile(
            id: 'user123',
            name: 'John Doe',
            email: 'john@example.com',
            bio: 'a' * 501,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('should accept valid phone numbers', () {
        final validPhones = ['+1234567890', '(555) 123-4567', '+44 20 7946 0958'];
        
        for (final phone in validPhones) {
          expect(
            () => UserProfile(
              id: 'user123',
              name: 'John Doe',
              email: 'john@example.com',
              phoneNumber: phone,
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ),
            returnsNormally,
          );
        }
      });
    });

    group('Business Logic', () {
      test('should identify complete profile', () {
        final completeProfile = UserProfile(
          id: 'user123',
          name: 'John Doe',
          email: 'john@example.com',
          bio: 'Test bio',
          phoneNumber: '+1234567890',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        expect(completeProfile.isProfileComplete, true);
      });

      test('should identify incomplete profile', () {
        final incompleteProfile = UserProfile(
          id: 'user123',
          name: 'John Doe',
          email: 'john@example.com',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        expect(incompleteProfile.isProfileComplete, false);
      });

      test('should identify good rating', () {
        final goodRatingProfile = UserProfile(
          id: 'user123',
          name: 'John Doe',
          email: 'john@example.com',
          averageRating: 4.5,
          totalRides: 10,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        expect(goodRatingProfile.hasGoodRating, true);
      });

      test('should identify poor rating', () {
        final poorRatingProfile = UserProfile(
          id: 'user123',
          name: 'John Doe',
          email: 'john@example.com',
          averageRating: 3.0,
          totalRides: 10,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        expect(poorRatingProfile.hasGoodRating, false);
      });
    });
  });
}