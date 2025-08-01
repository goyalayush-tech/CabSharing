import 'package:flutter_test/flutter_test.dart';
import 'package:ridelink/models/rating.dart';

void main() {
  group('Rating', () {
    late DateTime now;

    setUp(() {
      now = DateTime.now();
    });

    Rating createValidRating() {
      return Rating(
        id: 'rating123',
        rideId: 'ride123',
        raterId: 'user123',
        ratedUserId: 'user456',
        stars: 4,
        comment: 'Great ride!',
        createdAt: now,
      );
    }

    group('Creation and Validation', () {
      test('should create valid Rating', () {
        final rating = createValidRating();
        
        expect(rating.id, 'rating123');
        expect(rating.rideId, 'ride123');
        expect(rating.raterId, 'user123');
        expect(rating.ratedUserId, 'user456');
        expect(rating.stars, 4);
        expect(rating.comment, 'Great ride!');
        expect(rating.createdAt, now);
      });

      test('should create rating without comment', () {
        final rating = Rating(
          id: 'rating123',
          rideId: 'ride123',
          raterId: 'user123',
          ratedUserId: 'user456',
          stars: 4,
          createdAt: now,
        );
        
        expect(rating.comment, null);
        expect(rating.hasComment, false);
      });

      test('should throw error for empty ID', () {
        expect(
          () => Rating(
            id: '',
            rideId: 'ride123',
            raterId: 'user123',
            ratedUserId: 'user456',
            stars: 4,
            createdAt: now,
          ),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('should throw error for empty ride ID', () {
        expect(
          () => Rating(
            id: 'rating123',
            rideId: '',
            raterId: 'user123',
            ratedUserId: 'user456',
            stars: 4,
            createdAt: now,
          ),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('should throw error for empty rater ID', () {
        expect(
          () => Rating(
            id: 'rating123',
            rideId: 'ride123',
            raterId: '',
            ratedUserId: 'user456',
            stars: 4,
            createdAt: now,
          ),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('should throw error for empty rated user ID', () {
        expect(
          () => Rating(
            id: 'rating123',
            rideId: 'ride123',
            raterId: 'user123',
            ratedUserId: '',
            stars: 4,
            createdAt: now,
          ),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('should throw error for self-rating', () {
        expect(
          () => Rating(
            id: 'rating123',
            rideId: 'ride123',
            raterId: 'user123',
            ratedUserId: 'user123',
            stars: 4,
            createdAt: now,
          ),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('should throw error for invalid star rating', () {
        expect(
          () => Rating(
            id: 'rating123',
            rideId: 'ride123',
            raterId: 'user123',
            ratedUserId: 'user456',
            stars: 0,
            createdAt: now,
          ),
          throwsA(isA<ArgumentError>()),
        );

        expect(
          () => Rating(
            id: 'rating123',
            rideId: 'ride123',
            raterId: 'user123',
            ratedUserId: 'user456',
            stars: 6,
            createdAt: now,
          ),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('should throw error for comment too long', () {
        expect(
          () => Rating(
            id: 'rating123',
            rideId: 'ride123',
            raterId: 'user123',
            ratedUserId: 'user456',
            stars: 4,
            comment: 'a' * 501,
            createdAt: now,
          ),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('should throw error for future creation date', () {
        final futureTime = now.add(Duration(hours: 1));
        expect(
          () => Rating(
            id: 'rating123',
            rideId: 'ride123',
            raterId: 'user123',
            ratedUserId: 'user456',
            stars: 4,
            createdAt: futureTime,
          ),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('should accept valid star ratings', () {
        for (int stars = 1; stars <= 5; stars++) {
          expect(
            () => Rating(
              id: 'rating123',
              rideId: 'ride123',
              raterId: 'user123',
              ratedUserId: 'user456',
              stars: stars,
              createdAt: now,
            ),
            returnsNormally,
          );
        }
      });
    });

    group('Business Logic', () {
      test('should validate star rating', () {
        final validRating = createValidRating();
        expect(validRating.isValid(), true);
        
        final invalidRating = Rating(
          id: 'rating123',
          rideId: 'ride123',
          raterId: 'user123',
          ratedUserId: 'user456',
          stars: 3,
          createdAt: now,
        );
        expect(invalidRating.isValid(), true); // 3 is valid
      });

      test('should identify positive rating', () {
        final positiveRating = Rating(
          id: 'rating123',
          rideId: 'ride123',
          raterId: 'user123',
          ratedUserId: 'user456',
          stars: 5,
          createdAt: now,
        );
        
        expect(positiveRating.isPositive, true);
        expect(positiveRating.isNegative, false);
      });

      test('should identify negative rating', () {
        final negativeRating = Rating(
          id: 'rating123',
          rideId: 'ride123',
          raterId: 'user123',
          ratedUserId: 'user456',
          stars: 2,
          createdAt: now,
        );
        
        expect(negativeRating.isNegative, true);
        expect(negativeRating.isPositive, false);
      });

      test('should identify neutral rating', () {
        final neutralRating = Rating(
          id: 'rating123',
          rideId: 'ride123',
          raterId: 'user123',
          ratedUserId: 'user456',
          stars: 3,
          createdAt: now,
        );
        
        expect(neutralRating.isPositive, false);
        expect(neutralRating.isNegative, false);
      });

      test('should check if has comment', () {
        final ratingWithComment = createValidRating();
        expect(ratingWithComment.hasComment, true);
        
        final ratingWithoutComment = Rating(
          id: 'rating123',
          rideId: 'ride123',
          raterId: 'user123',
          ratedUserId: 'user456',
          stars: 4,
          createdAt: now,
        );
        expect(ratingWithoutComment.hasComment, false);
        
        final ratingWithEmptyComment = Rating(
          id: 'rating123',
          rideId: 'ride123',
          raterId: 'user123',
          ratedUserId: 'user456',
          stars: 4,
          comment: '',
          createdAt: now,
        );
        expect(ratingWithEmptyComment.hasComment, false);
      });
    });

    group('JSON Serialization', () {
      test('should serialize to JSON correctly', () {
        final rating = createValidRating();
        final json = rating.toJson();
        
        expect(json['id'], 'rating123');
        expect(json['rideId'], 'ride123');
        expect(json['raterId'], 'user123');
        expect(json['ratedUserId'], 'user456');
        expect(json['stars'], 4);
        expect(json['comment'], 'Great ride!');
        expect(json['createdAt'], now.toIso8601String());
      });

      test('should deserialize from JSON correctly', () {
        final json = {
          'id': 'rating123',
          'rideId': 'ride123',
          'raterId': 'user123',
          'ratedUserId': 'user456',
          'stars': 4,
          'comment': 'Great ride!',
          'createdAt': now.toIso8601String(),
        };
        
        final rating = Rating.fromJson(json);
        
        expect(rating.id, 'rating123');
        expect(rating.rideId, 'ride123');
        expect(rating.raterId, 'user123');
        expect(rating.ratedUserId, 'user456');
        expect(rating.stars, 4);
        expect(rating.comment, 'Great ride!');
      });

      test('should handle null comment in JSON', () {
        final json = {
          'id': 'rating123',
          'rideId': 'ride123',
          'raterId': 'user123',
          'ratedUserId': 'user456',
          'stars': 4,
          'comment': null,
          'createdAt': now.toIso8601String(),
        };
        
        final rating = Rating.fromJson(json);
        expect(rating.comment, null);
      });
    });

    group('Copy With', () {
      test('should copy rating with new values', () {
        final original = createValidRating();
        final copied = original.copyWith(
          stars: 5,
          comment: 'Excellent ride!',
        );
        
        expect(copied.id, original.id);
        expect(copied.rideId, original.rideId);
        expect(copied.raterId, original.raterId);
        expect(copied.ratedUserId, original.ratedUserId);
        expect(copied.stars, 5);
        expect(copied.comment, 'Excellent ride!');
        expect(copied.createdAt, original.createdAt);
      });

      test('should copy rating with null comment', () {
        final original = createValidRating();
        final copied = original.copyWith();
        
        expect(copied.comment, original.comment);
      });
    });
  });
}