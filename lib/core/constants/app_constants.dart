class AppConstants {
  // App Information
  static const String appName = 'RideLink';
  static const String appVersion = '1.0.0';
  static const String appDescription = 'Share the journey, split the cost';

  // Firebase Collections
  static const String usersCollection = 'users';
  static const String ridesCollection = 'rides';
  static const String groupsCollection = 'groups';
  static const String messagesCollection = 'messages';
  static const String ratingsCollection = 'ratings';
  static const String joinRequestsCollection = 'joinRequests';

  // Ride Constants
  static const int minSeats = 2;
  static const int maxSeats = 8;
  static const double minFare = 1.0;
  static const double maxFare = 1000.0;

  // Rating Constants
  static const int minRating = 1;
  static const int maxRating = 5;
  static const double defaultRating = 0.0;

  // UI Constants
  static const double defaultPadding = 16.0;
  static const double defaultRadius = 8.0;
  static const double cardElevation = 2.0;

  // Animation Durations
  static const Duration shortAnimation = Duration(milliseconds: 200);
  static const Duration mediumAnimation = Duration(milliseconds: 300);
  static const Duration longAnimation = Duration(milliseconds: 500);

  // Error Messages
  static const String networkError = 'Network connection error. Please check your internet connection.';
  static const String authError = 'Authentication failed. Please try again.';
  static const String permissionError = 'Permission denied. Please grant the required permissions.';
  static const String locationError = 'Unable to get location. Please enable location services.';
  static const String paymentError = 'Payment failed. Please try again.';
  static const String genericError = 'Something went wrong. Please try again.';

  // Success Messages
  static const String rideCreatedSuccess = 'Ride created successfully!';
  static const String joinRequestSentSuccess = 'Join request sent successfully!';
  static const String paymentSuccess = 'Payment completed successfully!';
  static const String profileUpdatedSuccess = 'Profile updated successfully!';

  // Validation Messages
  static const String requiredFieldError = 'This field is required';
  static const String invalidEmailError = 'Please enter a valid email address';
  static const String invalidPhoneError = 'Please enter a valid phone number';
  static const String invalidFareError = 'Please enter a valid fare amount';

  // Date Formats
  static const String dateFormat = 'dd/MM/yyyy';
  static const String timeFormat = 'HH:mm';
  static const String dateTimeFormat = 'dd/MM/yyyy HH:mm';

  // Shared Preferences Keys
  static const String userIdKey = 'user_id';
  static const String userTokenKey = 'user_token';
  static const String themeKey = 'theme_mode';
  static const String languageKey = 'language';
  static const String notificationsKey = 'notifications_enabled';

  // API Endpoints (if using custom backend)
  static const String baseUrl = 'https://api.ridelink.com';
  static const String authEndpoint = '/auth';
  static const String ridesEndpoint = '/rides';
  static const String usersEndpoint = '/users';
  static const String paymentsEndpoint = '/payments';

  // Google Maps
  static const double defaultZoom = 15.0;
  static const double defaultLatitude = 37.7749;
  static const double defaultLongitude = -122.4194;

  // Payment
  static const String currency = 'USD';
  static const String paymentDescription = 'RideLink ride payment';

  // Notification Topics
  static const String allUsersTopicPrefix = 'all_users';
  static const String rideUpdatesTopicPrefix = 'ride_updates_';
  static const String chatUpdatesTopicPrefix = 'chat_updates_';
}