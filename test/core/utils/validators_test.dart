import 'package:flutter_test/flutter_test.dart';
import 'package:ridelink/core/utils/validators.dart';

void main() {
  group('Validators', () {
    group('validateEmail', () {
      test('should return null for valid email', () {
        expect(Validators.validateEmail('test@example.com'), null);
        expect(Validators.validateEmail('user.name@domain.co.uk'), null);
        expect(Validators.validateEmail('test123@test-domain.org'), null);
      });

      test('should return error for invalid email', () {
        expect(Validators.validateEmail('invalid-email'), isNotNull);
        expect(Validators.validateEmail('test@'), isNotNull);
        expect(Validators.validateEmail('@domain.com'), isNotNull);
        expect(Validators.validateEmail('test.domain.com'), isNotNull);
      });

      test('should return error for empty email', () {
        expect(Validators.validateEmail(''), isNotNull);
        expect(Validators.validateEmail(null), isNotNull);
      });
    });

    group('validatePhoneNumber', () {
      test('should return null for valid phone numbers', () {
        expect(Validators.validatePhoneNumber('+1234567890'), null);
        expect(Validators.validatePhoneNumber('(555) 123-4567'), null);
        expect(Validators.validatePhoneNumber('+44 20 7946 0958'), null);
        expect(Validators.validatePhoneNumber('1234567890'), null);
      });

      test('should return null for empty phone (optional)', () {
        expect(Validators.validatePhoneNumber(''), null);
        expect(Validators.validatePhoneNumber(null), null);
      });

      test('should return error for invalid phone numbers', () {
        expect(Validators.validatePhoneNumber('123'), isNotNull);
        expect(Validators.validatePhoneNumber('abc123'), isNotNull);
        expect(Validators.validatePhoneNumber('++123456'), isNotNull);
      });
    });

    group('validateRequired', () {
      test('should return null for valid values', () {
        expect(Validators.validateRequired('test', 'Field'), null);
        expect(Validators.validateRequired('  test  ', 'Field'), null);
      });

      test('should return error for empty values', () {
        expect(Validators.validateRequired('', 'Field'), contains('Field is required'));
        expect(Validators.validateRequired('   ', 'Field'), contains('Field is required'));
        expect(Validators.validateRequired(null, 'Field'), contains('Field is required'));
      });
    });

    group('validateFare', () {
      test('should return null for valid fares', () {
        expect(Validators.validateFare('50.0'), null);
        expect(Validators.validateFare('100'), null);
        expect(Validators.validateFare('999.99'), null);
      });

      test('should return error for invalid fares', () {
        expect(Validators.validateFare(''), isNotNull);
        expect(Validators.validateFare(null), isNotNull);
        expect(Validators.validateFare('abc'), isNotNull);
        expect(Validators.validateFare('0'), isNotNull);
        expect(Validators.validateFare('-50'), isNotNull);
        expect(Validators.validateFare('10001'), isNotNull);
      });
    });

    group('validateSeats', () {
      test('should return null for valid seat counts', () {
        expect(Validators.validateSeats(1), null);
        expect(Validators.validateSeats(4), null);
        expect(Validators.validateSeats(8), null);
      });

      test('should return error for invalid seat counts', () {
        expect(Validators.validateSeats(null), isNotNull);
        expect(Validators.validateSeats(0), isNotNull);
        expect(Validators.validateSeats(-1), isNotNull);
        expect(Validators.validateSeats(9), isNotNull);
      });
    });

    group('validateRating', () {
      test('should return null for valid ratings', () {
        expect(Validators.validateRating(1), null);
        expect(Validators.validateRating(3), null);
        expect(Validators.validateRating(5), null);
      });

      test('should return error for invalid ratings', () {
        expect(Validators.validateRating(null), isNotNull);
        expect(Validators.validateRating(0), isNotNull);
        expect(Validators.validateRating(6), isNotNull);
        expect(Validators.validateRating(-1), isNotNull);
      });
    });

    group('validateName', () {
      test('should return null for valid names', () {
        expect(Validators.validateName('John'), null);
        expect(Validators.validateName('John Doe'), null);
        expect(Validators.validateName('  John  '), null);
      });

      test('should return error for invalid names', () {
        expect(Validators.validateName(''), isNotNull);
        expect(Validators.validateName('   '), isNotNull);
        expect(Validators.validateName(null), isNotNull);
        expect(Validators.validateName('J'), isNotNull);
        expect(Validators.validateName('a' * 51), isNotNull);
      });
    });

    group('validateBio', () {
      test('should return null for valid bios', () {
        expect(Validators.validateBio('This is a bio'), null);
        expect(Validators.validateBio(''), null);
        expect(Validators.validateBio(null), null);
        expect(Validators.validateBio('a' * 500), null);
      });

      test('should return error for bio too long', () {
        expect(Validators.validateBio('a' * 501), isNotNull);
      });
    });

    group('validateNotes', () {
      test('should return null for valid notes', () {
        expect(Validators.validateNotes('Some notes'), null);
        expect(Validators.validateNotes(''), null);
        expect(Validators.validateNotes(null), null);
        expect(Validators.validateNotes('a' * 500), null);
      });

      test('should return error for notes too long', () {
        expect(Validators.validateNotes('a' * 501), isNotNull);
      });
    });

    group('validateDateTime', () {
      test('should return null for future dates', () {
        final futureDate = DateTime.now().add(const Duration(hours: 1));
        expect(Validators.validateDateTime(futureDate), null);
      });

      test('should return error for past dates', () {
        final pastDate = DateTime.now().subtract(const Duration(hours: 1));
        expect(Validators.validateDateTime(pastDate), isNotNull);
        expect(Validators.validateDateTime(null), isNotNull);
      });
    });

    group('isValidDateTime', () {
      test('should return true for future dates', () {
        final futureDate = DateTime.now().add(const Duration(hours: 1));
        expect(Validators.isValidDateTime(futureDate), true);
      });

      test('should return false for past dates', () {
        final pastDate = DateTime.now().subtract(const Duration(hours: 1));
        expect(Validators.isValidDateTime(pastDate), false);
        expect(Validators.isValidDateTime(null), false);
      });
    });

    group('validateLocation', () {
      test('should return null for valid locations', () {
        expect(Validators.validateLocation('New York'), null);
        expect(Validators.validateLocation('Downtown Station'), null);
        expect(Validators.validateLocation('123 Main St'), null);
      });

      test('should return error for invalid locations', () {
        expect(Validators.validateLocation(''), isNotNull);
        expect(Validators.validateLocation('   '), isNotNull);
        expect(Validators.validateLocation(null), isNotNull);
        expect(Validators.validateLocation('NY'), isNotNull);
      });
    });
  });
}