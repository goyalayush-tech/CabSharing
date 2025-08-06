# Free Map Services Setup Guide

This guide will help you set up the free map services for RideLink without using Google Maps API.

## Quick Start (No API Keys Required)

The basic setup works immediately with no configuration:

1. **Maps**: Uses OpenStreetMap tiles (completely free)
2. **Geocoding**: Uses Nominatim (free, no API key)
3. **Basic Routing**: Falls back to straight-line distance

```bash
flutter pub get
flutter run
```

## Enhanced Setup (Recommended)

For full routing functionality, get a free OpenRouteService API key:

### Step 1: Get OpenRouteService API Key (Free)

1. Go to [OpenRouteService](https://openrouteservice.org/dev/#/signup)
2. Sign up for a free account
3. Get your API key (2,000 requests/day free)
4. No credit card required!

### Step 2: Configure API Key

1. Open `lib/core/constants/app_constants.dart`
2. Replace the placeholder:

```dart
static const String openRouteServiceApiKey = 'YOUR_ACTUAL_API_KEY_HERE';
```

### Step 3: Test the Setup

```bash
flutter pub get
flutter run
```

## Service Limits (All Free)

| Service | Free Limit | Features |
|---------|------------|----------|
| OpenStreetMap | Unlimited* | Map tiles, basic display |
| Nominatim | 1 req/sec | Geocoding, address search |
| OpenRouteService | 2,000/day | Routing, directions |

*With fair use policy (max 2 req/sec)

## Features Available

### ✅ Completely Free Features
- Interactive maps with zoom/pan
- Location search and geocoding
- Reverse geocoding (coordinates to address)
- Current location detection
- Map markers and overlays
- Offline map tile caching

### ✅ Free with API Key
- Turn-by-turn directions
- Route polylines on map
- Distance and duration calculation
- Fare estimation based on route
- Optimized waypoint routing

### ❌ Not Available (Premium Only)
- Real-time traffic data
- Satellite imagery
- Street view
- Advanced place details

## Offline Support

The app automatically caches:
- Map tiles for offline viewing
- Geocoding results for 24 hours
- Route calculations for reuse

## Fallback System

If free services are unavailable:
1. **Primary**: Free services (OSM, Nominatim, OpenRouteService)
2. **Fallback**: Google Maps (if configured)
3. **Final**: Manual coordinate entry

## Development vs Production

### Development Mode
- Uses mock services for faster development
- No API calls during testing
- Simulated data for consistent testing

### Production Mode
- Uses real free services
- Automatic fallback handling
- Full caching and offline support

## Troubleshooting

### Common Issues

1. **Maps not loading**
   - Check internet connection
   - Verify OSM tile server is accessible
   - Clear app cache and restart

2. **Search not working**
   - Nominatim may be rate-limited (1 req/sec)
   - Try searching less frequently
   - Check network connectivity

3. **No routing/directions**
   - Verify OpenRouteService API key is set
   - Check daily limit (2,000 requests)
   - Ensure API key is valid

### Debug Steps

1. Check Flutter logs for error messages
2. Verify network connectivity
3. Test with different search terms
4. Clear app cache: `flutter clean`

## Cost Comparison

| Solution | Monthly Cost | Requests |
|----------|--------------|----------|
| **Free Maps (This)** | **$0** | **60,000+** |
| Google Maps | $200 credit | ~28,000 |
| MapBox | $0-50 | 50,000 |
| HERE Maps | $0-200 | 250,000 |

## Migration from Google Maps

If you were using Google Maps before:

1. **No code changes needed** - the app automatically uses free services
2. **Data compatibility** - existing location data works unchanged  
3. **Gradual migration** - can use both services during transition
4. **Fallback support** - Google Maps as backup if needed

## Production Deployment

Before deploying:

1. ✅ Get OpenRouteService API key
2. ✅ Test all location features
3. ✅ Verify offline functionality
4. ✅ Monitor service usage
5. ✅ Set up error monitoring

## Support

- **OpenStreetMap**: [wiki.openstreetmap.org](https://wiki.openstreetmap.org)
- **Nominatim**: [nominatim.org/release-docs](https://nominatim.org/release-docs)
- **OpenRouteService**: [openrouteservice.org/dev](https://openrouteservice.org/dev)
- **Flutter Map**: [docs.fleaflet.dev](https://docs.fleaflet.dev)

## Next Steps

1. Run `flutter pub get` to install dependencies
2. Test basic map functionality
3. Get OpenRouteService API key for routing
4. Customize map styles and markers as needed
5. Deploy and monitor usage

The free map integration is now ready to use! 🎉