# RideLink - Collaborative Cab-Sharing App

A Flutter-based mobile application that facilitates collaborative cab-sharing through a group-based system where users can create or join ride-sharing groups to reduce travel costs and build community connections.

## Features

- **Google Authentication**: Secure sign-in with Google accounts
- **Ride Creation**: Group leaders can create rides with detailed journey information
- **Ride Discovery**: Search and browse available rides with filtering options
- **Group Management**: Join requests, approvals, and member management
- **Real-time Chat**: In-app communication for ride coordination
- **Location Tracking**: Real-time GPS tracking during rides
- **Payment Integration**: Secure payment processing and splitting
- **Rating System**: Community trust through user ratings
- **Safety Features**: Female-only ride options and user verification

## Tech Stack

- **Frontend**: Flutter
- **Backend**: Firebase (Firestore, Auth, Cloud Functions, Storage)
- **Maps**: Google Maps Platform
- **Payments**: Stripe/Razorpay
- **State Management**: Provider
- **Navigation**: GoRouter

## Project Structure

```
lib/
├── core/
│   ├── router/          # App navigation and routing
│   └── theme/           # App theming and styling
├── models/              # Data models and entities
├── screens/             # UI screens and pages
│   ├── auth/           # Authentication screens
│   ├── home/           # Home and main screens
│   ├── profile/        # User profile screens
│   └── rides/          # Ride-related screens
├── services/           # Business logic and API services
└── widgets/            # Reusable UI components
```

## Getting Started

### Prerequisites

- Flutter SDK (>=3.0.0)
- Firebase project setup
- Google Maps API key
- Payment gateway account (Stripe/Razorpay)

### Installation

1. Clone the repository
2. Install dependencies:
   ```bash
   flutter pub get
   ```

3. Configure Firebase:
   - Create a Firebase project
   - Add Android/iOS apps to your Firebase project
   - Download and add configuration files
   - Update `firebase_options.dart` with your project details

4. Configure Google Maps:
   - Get a Google Maps API key
   - Add the API key to `android/app/src/main/AndroidManifest.xml`
   - Add the API key to iOS configuration

5. Run the app:
   ```bash
   flutter run
   ```

## Configuration

### Firebase Setup

1. Create a new Firebase project at [Firebase Console](https://console.firebase.google.com/)
2. Enable Authentication with Google Sign-In provider
3. Set up Firestore database
4. Configure Firebase Storage for profile images
5. Set up Firebase Cloud Messaging for notifications

### Google Maps Setup

1. Enable Google Maps SDK for Android/iOS
2. Enable Places API and Directions API
3. Add API key to platform-specific configuration files

### Payment Gateway Setup

Configure your preferred payment gateway (Stripe or Razorpay) and add the necessary API keys to your environment configuration.

## Development Status

This project is currently in development. The basic project structure and core dependencies have been set up. Implementation is following a spec-driven development approach with incremental feature development.

## Contributing

This project follows a structured development approach with detailed specifications and task-based implementation. Please refer to the project specifications in `.kiro/specs/ridelink-cab-sharing/` for detailed requirements and implementation plans.

## License

This project is licensed under the MIT License - see the LICENSE file for details.