# RideLink Technology Stack

## Framework & Platform
- **Flutter**: Cross-platform mobile development framework
- **Dart**: Programming language (SDK >=3.0.0)
- **Target Platforms**: Android, iOS, Web

## Backend & Services
- **Firebase Core**: Backend-as-a-Service platform
  - **Firebase Auth**: User authentication with Google Sign-In
  - **Cloud Firestore**: NoSQL database for real-time data
  - **Firebase Storage**: File storage for profile images
  - **Firebase Messaging**: Push notifications
  - **Firebase Crashlytics**: Crash reporting and analytics

## State Management & Architecture
- **Provider**: State management solution
- **GoRouter**: Declarative routing and navigation
- **Service Layer Pattern**: Business logic separation with interfaces
- **Repository Pattern**: Data access abstraction
- **Mock Services**: Development and testing with mock implementations

## External Integrations
- **Google Maps Platform**: Maps, Places API, Directions API
- **Google Sign-In**: OAuth authentication
- **Flutter Stripe**: Payment processing
- **Geolocator**: Location services and GPS tracking

## Development Tools
- **flutter_lints**: Code analysis and linting
- **mockito**: Mocking framework for testing
- **build_runner**: Code generation
- **hive**: Local storage and caching

## Common Commands

### Development
```bash
# Install dependencies
flutter pub get

# Run the app
flutter run

# Run with specific device
flutter run -d chrome  # for web
flutter run -d android # for Android

# Hot reload during development
# Press 'r' in terminal or save files in IDE
```

### Testing
```bash
# Run all tests
flutter test

# Run specific test file
flutter test test/models/user_profile_test.dart

# Run tests with coverage
flutter test --coverage
```

### Build & Deploy
```bash
# Build for Android
flutter build apk --release
flutter build appbundle --release

# Build for iOS
flutter build ios --release

# Build for web
flutter build web --release
```

### Code Quality
```bash
# Analyze code
flutter analyze

# Format code
dart format .

# Generate code (for Hive, etc.)
flutter packages pub run build_runner build
```

## Configuration Requirements
- Firebase project setup with configuration files
- Google Maps API key configuration
- Payment gateway (Stripe) API keys
- Platform-specific configurations for Android/iOS