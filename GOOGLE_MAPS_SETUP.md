# Google Maps Setup Guide

This guide will help you set up Google Maps integration for the RideLink app.

## Prerequisites

1. Google Cloud Platform account
2. Billing enabled on your GCP project
3. Flutter development environment set up

## Step 1: Create Google Cloud Project

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Create a new project or select an existing one
3. Enable billing for the project

## Step 2: Enable Required APIs

Enable the following APIs in your Google Cloud Console:

1. **Maps SDK for Android**
2. **Maps SDK for iOS** 
3. **Places API**
4. **Directions API**
5. **Geocoding API**
6. **Distance Matrix API**

To enable APIs:
1. Go to "APIs & Services" > "Library"
2. Search for each API and click "Enable"

## Step 3: Create API Key

1. Go to "APIs & Services" > "Credentials"
2. Click "Create Credentials" > "API Key"
3. Copy the generated API key
4. (Recommended) Click "Restrict Key" to add restrictions:
   - **Application restrictions**: Set to "Android apps" and add your package name
   - **API restrictions**: Select only the APIs you enabled above

## Step 4: Configure Flutter App

### Android Configuration

1. Open `android/app/src/main/AndroidManifest.xml`
2. Replace `YOUR_GOOGLE_MAPS_API_KEY` with your actual API key:

```xml
<meta-data android:name="com.google.android.geo.API_KEY"
           android:value="YOUR_ACTUAL_API_KEY_HERE"/>
```

### iOS Configuration

1. Open `ios/Runner/AppDelegate.swift`
2. Add the following import at the top:

```swift
import GoogleMaps
```

3. Add this line in the `application` method:

```swift
GMSServices.provideAPIKey("YOUR_ACTUAL_API_KEY_HERE")
```

### App Constants

1. Open `lib/core/constants/app_constants.dart`
2. Replace the placeholder with your actual API key:

```dart
static const String googleMapsApiKey = 'YOUR_ACTUAL_API_KEY_HERE';
```

## Step 5: Install Dependencies

Run the following command to install the required packages:

```bash
flutter pub get
```

## Step 6: Test the Integration

1. Run the app: `flutter run`
2. Try creating a new ride and selecting pickup/destination locations
3. Verify that:
   - Location search works
   - Map displays correctly
   - Current location can be detected
   - Places suggestions appear

## API Usage and Pricing

### Free Tier Limits (per month)
- **Maps SDK**: $200 free credit (28,000 map loads)
- **Places API**: $200 free credit (varies by request type)
- **Directions API**: $200 free credit (~40,000 requests)
- **Geocoding API**: $200 free credit (~40,000 requests)

### Cost Optimization Tips

1. **Cache Results**: Store frequently accessed place details locally
2. **Limit Search Radius**: Use smaller radius for place searches
3. **Batch Requests**: Combine multiple geocoding requests when possible
4. **Use Autocomplete**: Implement place autocomplete to reduce full search requests
5. **Monitor Usage**: Set up billing alerts in Google Cloud Console

## Security Best Practices

1. **Restrict API Keys**: Always restrict your API keys to specific apps and APIs
2. **Use Different Keys**: Use separate API keys for development and production
3. **Monitor Usage**: Regularly check API usage in Google Cloud Console
4. **Rotate Keys**: Periodically rotate your API keys for security

## Troubleshooting

### Common Issues

1. **Map not loading**: Check if API key is correctly set and Maps SDK is enabled
2. **Places search not working**: Verify Places API is enabled and API key has correct restrictions
3. **"API key not valid" error**: Check if the API key is correctly copied and restrictions are properly set
4. **Location permission denied**: Ensure location permissions are granted in device settings

### Debug Steps

1. Check Android/iOS logs for specific error messages
2. Verify API key restrictions in Google Cloud Console
3. Test API key using Google's API Explorer
4. Check billing account status and quotas

## Production Deployment

Before deploying to production:

1. Create separate API keys for production
2. Set up proper API key restrictions
3. Configure billing alerts
4. Test thoroughly on physical devices
5. Monitor API usage and costs

## Support

For additional help:
- [Google Maps Platform Documentation](https://developers.google.com/maps/documentation)
- [Flutter Google Maps Plugin](https://pub.dev/packages/google_maps_flutter)
- [Google Cloud Support](https://cloud.google.com/support)