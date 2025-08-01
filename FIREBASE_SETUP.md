# Firebase Setup Guide for RideLink

## Prerequisites
1. A Google account
2. Access to Firebase Console
3. Flutter development environment

## Step 1: Create Firebase Project

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Click "Create a project" or "Add project"
3. Enter project name: `ridelink-cab-sharing` (or your preferred name)
4. Enable Google Analytics (optional)
5. Click "Create project"

## Step 2: Enable Authentication

1. In your Firebase project, go to "Authentication" in the left sidebar
2. Click "Get started"
3. Go to "Sign-in method" tab
4. Enable "Google" sign-in provider
5. Add your project's authorized domains (for web):
   - `localhost` (for development)
   - Your production domain (when deploying)

## Step 3: Add Web App to Firebase

1. In Project Overview, click the web icon (`</>`)
2. Register your app with nickname: `ridelink-web`
3. Copy the Firebase configuration object
4. Replace the placeholder values in `lib/firebase_options.dart`

## Step 4: Configure Google Sign-In for Web

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Select your Firebase project
3. Go to "APIs & Services" > "Credentials"
4. Find your OAuth 2.0 Client ID for Web application
5. Copy the Client ID
6. Replace `YOUR_GOOGLE_CLIENT_ID` in `web/index.html` with your actual Client ID

## Step 5: Update Configuration Files

### Update `lib/firebase_options.dart`:
Replace placeholder values with your actual Firebase config:

```dart
static const FirebaseOptions web = FirebaseOptions(
  apiKey: 'your-actual-api-key',
  appId: 'your-actual-app-id',
  messagingSenderId: 'your-actual-sender-id',
  projectId: 'your-actual-project-id',
  authDomain: 'your-actual-project-id.firebaseapp.com',
  storageBucket: 'your-actual-project-id.appspot.com',
);
```

### Update `web/index.html`:
Replace the Google Client ID:

```html
<meta name="google-signin-client_id" content="your-actual-client-id.apps.googleusercontent.com">
```

### Update `lib/core/config/app_config.dart`:
Replace placeholder values with your actual configuration.

## Step 6: Disable Mock Authentication

In `lib/core/config/app_config.dart`, set:

```dart
static const bool useMockAuth = false;
```

## Step 7: Test the Setup

1. Run `flutter pub get`
2. Run `flutter run -d chrome`
3. Try signing in with Google

## Troubleshooting

### Common Issues:

1. **"ClientID not set" error**: 
   - Make sure the Google Client ID is correctly set in `web/index.html`
   - Verify the Client ID format includes `.apps.googleusercontent.com`

2. **"Firebase not initialized" error**:
   - Ensure Firebase configuration is correct in `firebase_options.dart`
   - Check that `Firebase.initializeApp()` is called in `main.dart`

3. **"Unauthorized domain" error**:
   - Add your domain to authorized domains in Firebase Authentication settings
   - For development, make sure `localhost` is added

4. **CORS errors**:
   - This usually resolves itself once proper domains are configured
   - Try running on different ports if needed

## Development Mode

For development without Firebase setup, you can use the mock authentication:

1. Keep `useMockAuth = true` in `app_config.dart`
2. The app will use a mock user for testing UI flows
3. Switch to real Firebase when ready for production

## Security Notes

- Never commit real API keys to version control
- Use environment variables for production deployments
- Regularly rotate API keys and credentials
- Set up proper Firebase security rules before production