# Offline Functionality

This document describes the offline functionality implemented for the RideLink app's free map integration.

## Overview

The offline functionality ensures that users can still view maps and access cached data when they have poor or no internet connectivity. This is particularly important for a ride-sharing app where users may be in areas with spotty network coverage.

## Features

### 1. Offline Detection and State Management

- **Automatic Detection**: The app automatically detects when the device goes offline or comes back online
- **Real-time Updates**: Connectivity status is monitored in real-time using the `connectivity_plus` package
- **State Persistence**: Offline state is maintained across the app and communicated to all relevant components

### 2. Map Tile Caching

- **Automatic Caching**: Map tiles are automatically cached when loaded online
- **Offline Display**: Cached tiles are displayed when offline, even if expired
- **Storage Management**: Cached tiles are stored using Hive for efficient local storage
- **Cache Expiration**: Tiles have configurable expiration times (default: 24 hours)

### 3. Offline UI Indicators

- **Offline Banner**: Shows at the top of screens when offline with retry functionality
- **Visual Indicators**: Maps show an "Offline Mode" overlay when offline
- **Disabled Controls**: Interactive elements are disabled when offline (search, current location)
- **Status Messages**: Clear messaging about what features are available offline

### 4. Graceful Degradation

- **Search Disabled**: Location search is disabled offline with appropriate messaging
- **Current Location Disabled**: GPS-based current location is disabled offline
- **Cached Data**: Previously loaded markers and routes remain visible
- **Map Interaction**: Basic map viewing and zooming still work offline

## Implementation

### Core Services

#### OfflineService
```dart
// Initialize offline service
final offlineService = OfflineService();
await offlineService.initialize();

// Check connectivity status
bool isOnline = offlineService.isOnline;

// Listen for connectivity changes
offlineService.connectivityStream.listen((isOnline) {
  // Handle connectivity changes
});
```

#### MapCacheService
```dart
// Initialize cache service
final cacheService = HiveMapCacheService();
await cacheService.initialize();

// Cache a map tile
await cacheService.cacheTile(mapTile);

// Retrieve cached tile
final cachedTile = await cacheService.getCachedTile(tileKey);

// Get cache statistics
final stats = await cacheService.getCacheStats();
```

### Widget Integration

#### FreeMapWidget with Offline Support
```dart
FreeMapWidget(
  initialLocation: location,
  markers: markers,
  offlineService: offlineService,
  cacheService: cacheService,
  showOfflineBanner: true,
)
```

#### OfflineBanner
```dart
OfflineBanner(
  offlineService: offlineService,
  onRetry: () => offlineService.refreshConnectivity(),
  customMessage: 'Offline: Search unavailable',
)
```

#### OfflineWrapper
```dart
OfflineWrapper(
  offlineService: offlineService,
  child: OnlineWidget(),
  offlineChild: OfflineWidget(),
)
```

## Usage Examples

### Basic Offline-Aware Map
```dart
class MapScreen extends StatefulWidget {
  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> with OfflineAwareMixin {
  late IOfflineService _offlineService;
  late IMapCacheService _cacheService;

  @override
  void initState() {
    super.initState();
    _offlineService = OfflineService();
    _cacheService = HiveMapCacheService();
    
    initializeOfflineService(_offlineService);
    
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    await _offlineService.initialize();
    await _cacheService.initialize();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          OfflineBanner(
            offlineService: _offlineService,
            onRetry: () => _offlineService.refreshConnectivity(),
          ),
          Expanded(
            child: FreeMapWidget(
              offlineService: _offlineService,
              cacheService: _cacheService,
              // ... other properties
            ),
          ),
        ],
      ),
    );
  }
}
```

### Location Picker with Offline Support
```dart
FreeLocationPicker(
  title: 'Select Location',
  offlineService: offlineService,
  cacheService: cacheService,
  allowSearch: true, // Will be disabled when offline
  allowCurrentLocation: true, // Will be disabled when offline
)
```

## Configuration

### Cache Settings
```dart
// Configure cache duration for different data types
const tileCacheDuration = Duration(hours: 24);
const geocodingCacheDuration = Duration(hours: 24);
const routeCacheDuration = Duration(hours: 6);
```

### Connectivity Settings
```dart
// Configure connectivity check timeout
const connectivityTimeout = Duration(seconds: 5);

// Configure retry intervals
const retryInterval = Duration(seconds: 30);
```

## Testing

### Unit Tests
- `test/services/offline_service_test.dart` - Tests offline service functionality
- `test/services/offline_tile_provider_test.dart` - Tests tile caching and offline loading
- `test/widgets/offline_banner_test.dart` - Tests offline UI components

### Integration Tests
- `test/integration/offline_functionality_test.dart` - Tests complete offline workflows

### Manual Testing
1. Start the app with internet connection
2. Navigate to map screens and load some tiles
3. Disable internet connection (airplane mode or disconnect WiFi)
4. Verify offline banner appears
5. Verify cached tiles are still visible
6. Verify search and location features are disabled
7. Re-enable internet connection
8. Verify online functionality returns

## Performance Considerations

### Cache Management
- **Size Limits**: Cache has configurable size limits to prevent excessive storage usage
- **Cleanup**: Expired cache entries are automatically cleaned up
- **Memory Usage**: In-memory caching for frequently accessed data

### Network Efficiency
- **Debounced Checks**: Connectivity checks are debounced to avoid excessive network calls
- **Fallback Hosts**: Multiple hosts are checked for connectivity verification
- **Timeout Handling**: Network requests have appropriate timeouts

## Troubleshooting

### Common Issues

#### Cache Not Working
- Ensure Hive is properly initialized
- Check storage permissions
- Verify cache service initialization

#### Connectivity Detection Issues
- Check `connectivity_plus` package setup
- Verify network permissions in manifest
- Test on different network types (WiFi, cellular)

#### UI Not Updating
- Ensure widgets are listening to connectivity stream
- Check StreamBuilder implementation
- Verify state management

### Debug Information
```dart
// Get cache statistics
final stats = await cacheService.getCacheStats();
print('Cache stats: $stats');

// Check connectivity status
print('Is online: ${offlineService.isOnline}');

// Force connectivity refresh
await offlineService.refreshConnectivity();
```

## Future Enhancements

### Planned Features
1. **Selective Caching**: Allow users to pre-cache specific areas
2. **Cache Prioritization**: Intelligent cache management based on usage patterns
3. **Offline Sync**: Queue actions performed offline for sync when online
4. **Progressive Loading**: Load lower quality tiles when bandwidth is limited

### Performance Improvements
1. **Compression**: Compress cached tiles to save storage
2. **Predictive Caching**: Cache tiles for likely user destinations
3. **Background Sync**: Update cache in background when online

## Dependencies

- `connectivity_plus: ^6.0.5` - Network connectivity detection
- `hive: ^2.2.3` - Local storage for caching
- `flutter_map: ^6.1.0` - Map widget with tile provider support
- `cached_network_image: ^3.3.0` - Image caching support

## Related Files

### Core Implementation
- `lib/services/offline_service.dart` - Main offline service
- `lib/services/offline_tile_provider.dart` - Offline-aware tile provider
- `lib/services/map_cache_service.dart` - Caching service
- `lib/widgets/offline_banner.dart` - Offline UI components

### Widget Integration
- `lib/widgets/free_map_widget.dart` - Map widget with offline support
- `lib/widgets/free_location_picker.dart` - Location picker with offline support

### Examples and Documentation
- `lib/widgets/examples/offline_map_example.dart` - Complete offline demo
- `OFFLINE_FUNCTIONALITY.md` - This documentation file