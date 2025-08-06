# RideLink Project Structure

## Root Directory Organization
```
ridelink/
├── lib/                    # Main application source code
├── test/                   # Unit and widget tests
├── android/                # Android-specific configuration
├── web/                    # Web platform configuration
├── windows/                # Windows platform configuration
├── assets/                 # Static assets (images, icons)
├── .kiro/                  # Kiro AI assistant configuration
└── build/                  # Generated build artifacts
```

## Core Application Structure (`lib/`)
```
lib/
├── main.dart              # Application entry point
├── app.dart               # Root app widget with providers
├── firebase_options.dart  # Firebase configuration
├── core/                  # Core application infrastructure
│   ├── config/           # App configuration and constants
│   ├── constants/        # Application constants
│   ├── errors/           # Error handling and custom exceptions
│   ├── router/           # Navigation and routing configuration
│   ├── theme/            # UI theming and styling
│   └── utils/            # Utility functions and helpers
├── models/               # Data models and entities
├── providers/            # State management (Provider pattern)
├── screens/              # UI screens organized by feature
│   ├── auth/            # Authentication screens
│   ├── chat/            # Chat and messaging screens
│   ├── home/            # Home and dashboard screens
│   ├── profile/         # User profile screens
│   └── rides/           # Ride-related screens
├── services/            # Business logic and external API services
└── widgets/             # Reusable UI components
```

## Test Structure (`test/`)
```
test/
├── core/                 # Tests for core functionality
│   ├── constants/       # Constants tests
│   └── utils/           # Utility function tests
├── features/            # Integration and feature tests
├── models/              # Model class tests
├── providers/           # Provider state management tests
├── screens/             # Screen widget tests
├── services/            # Service layer tests
└── widget_test.dart     # Default Flutter widget test
```

## Architecture Patterns

### Service Layer Pattern
- **Interfaces**: Abstract service contracts (e.g., `IAuthService`)
- **Implementations**: Concrete service classes (e.g., `AuthService`)
- **Mock Services**: Testing implementations (e.g., `MockAuthService`)

### Provider State Management
- **Providers**: State management classes extending `ChangeNotifier`
- **Dependency Injection**: Services injected via Provider at app root
- **State Separation**: Each feature has dedicated provider

### Screen Organization
- **Feature-based**: Screens grouped by functionality
- **Consistent Naming**: `*_screen.dart` convention
- **Route Integration**: Screens registered in `AppRouter`

### Widget Structure
- **Reusable Components**: Shared UI elements in `widgets/`
- **Stateless Preference**: Favor stateless widgets when possible
- **Composition**: Build complex UIs through widget composition

## File Naming Conventions
- **Screens**: `feature_name_screen.dart`
- **Services**: `feature_service.dart` with interface `IFeatureService`
- **Models**: `model_name.dart` (singular, snake_case)
- **Providers**: `feature_provider.dart`
- **Widgets**: `widget_name.dart` (descriptive, snake_case)
- **Tests**: Mirror source structure with `_test.dart` suffix

## Import Organization
1. **Dart/Flutter imports** (dart:*, flutter/*)
2. **Third-party packages** (package:*)
3. **Local imports** (relative paths)
4. **Blank line separation** between groups

## Configuration Files
- **pubspec.yaml**: Dependencies and asset declarations
- **analysis_options.yaml**: Dart analyzer configuration
- **firebase_options.dart**: Firebase platform configuration
- **.kiro/**: AI assistant steering rules and specifications