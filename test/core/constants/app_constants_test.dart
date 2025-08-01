import 'package:flutter_test/flutter_test.dart';
import 'package:ridelink/core/constants/app_constants.dart';

void main() {
  group('AppConstants', () {
    test('should have correct app information', () {
      expect(AppConstants.appName, 'RideLink');
      expect(AppConstants.appVersion, '1.0.0');
      expect(AppConstants.appDescription, 'Share the journey, split the cost');
    });

    test('should have Firebase collection names', () {
      expect(AppConstants.usersCollection, 'users');
      expect(AppConstants.ridesCollection, 'rides');
      expect(AppConstants.groupsCollection, 'groups');
      expect(AppConstants.messagesCollection, 'messages');
      expect(AppConstants.ratingsCollection, 'ratings');
      expect(AppConstants.joinRequestsCollection, 'joinRequests');
    });

    test('should have valid ride constraints', () {
      expect(AppConstants.minSeats, 2);
      expect(AppConstants.maxSeats, 8);
      expect(AppConstants.minFare, 1.0);
      expect(AppConstants.maxFare, 1000.0);
      expect(AppConstants.minSeats < AppConstants.maxSeats, true);
      expect(AppConstants.minFare < AppConstants.maxFare, true);
    });

    test('should have valid rating constraints', () {
      expect(AppConstants.minRating, 1);
      expect(AppConstants.maxRating, 5);
      expect(AppConstants.defaultRating, 0.0);
      expect(AppConstants.minRating < AppConstants.maxRating, true);
    });

    test('should have UI constants', () {
      expect(AppConstants.defaultPadding, 16.0);
      expect(AppConstants.defaultRadius, 8.0);
      expect(AppConstants.cardElevation, 2.0);
    });

    test('should have animation durations', () {
      expect(AppConstants.shortAnimation, const Duration(milliseconds: 200));
      expect(AppConstants.mediumAnimation, const Duration(milliseconds: 300));
      expect(AppConstants.longAnimation, const Duration(milliseconds: 500));
    });

    test('should have error messages', () {
      expect(AppConstants.networkError, isNotEmpty);
      expect(AppConstants.authError, isNotEmpty);
      expect(AppConstants.permissionError, isNotEmpty);
      expect(AppConstants.locationError, isNotEmpty);
      expect(AppConstants.paymentError, isNotEmpty);
      expect(AppConstants.genericError, isNotEmpty);
    });

    test('should have success messages', () {
      expect(AppConstants.rideCreatedSuccess, isNotEmpty);
      expect(AppConstants.joinRequestSentSuccess, isNotEmpty);
      expect(AppConstants.paymentSuccess, isNotEmpty);
      expect(AppConstants.profileUpdatedSuccess, isNotEmpty);
    });

    test('should have validation messages', () {
      expect(AppConstants.requiredFieldError, isNotEmpty);
      expect(AppConstants.invalidEmailError, isNotEmpty);
      expect(AppConstants.invalidPhoneError, isNotEmpty);
      expect(AppConstants.invalidFareError, isNotEmpty);
    });

    test('should have date formats', () {
      expect(AppConstants.dateFormat, 'dd/MM/yyyy');
      expect(AppConstants.timeFormat, 'HH:mm');
      expect(AppConstants.dateTimeFormat, 'dd/MM/yyyy HH:mm');
    });

    test('should have shared preferences keys', () {
      expect(AppConstants.userIdKey, 'user_id');
      expect(AppConstants.userTokenKey, 'user_token');
      expect(AppConstants.themeKey, 'theme_mode');
      expect(AppConstants.languageKey, 'language');
      expect(AppConstants.notificationsKey, 'notifications_enabled');
    });

    test('should have Google Maps constants', () {
      expect(AppConstants.defaultZoom, 15.0);
      expect(AppConstants.defaultLatitude, 37.7749);
      expect(AppConstants.defaultLongitude, -122.4194);
    });

    test('should have payment constants', () {
      expect(AppConstants.currency, 'USD');
      expect(AppConstants.paymentDescription, 'RideLink ride payment');
    });

    test('should have notification topic prefixes', () {
      expect(AppConstants.allUsersTopicPrefix, 'all_users');
      expect(AppConstants.rideUpdatesTopicPrefix, 'ride_updates_');
      expect(AppConstants.chatUpdatesTopicPrefix, 'chat_updates_');
    });
  });
}