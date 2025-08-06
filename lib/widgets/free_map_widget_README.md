# FreeMapWidget Documentation

## Overview

The `FreeMapWidget` is a Flutter widget that provides interactive map functionality using OpenStreetMap tiles through the `flutter_map` package. It's designed as a free alternative to Google Maps for the RideLink application.

## Features

- **OpenStreetMap Integration**: Uses OSM tiles with custom tile provider
- **Multiple Marker Types**: Support for pickup, destination, current location, ride location, and search result markers
- **Polyline Rendering**: Display routes and paths on the map
- **Interactive Controls**: Zoom controls, current location button, and tap-to-select functionality
- **Caching Support**: Built-in tile caching using `CachedNetworkImageProvider`
- **Customizable Configuration**: Configurable through `FreeMapConfig`

## Basic Usage

```dart
import 'package:flutter/material.dart';
import '../widgets/free_map_widget.dart';
import '../models/ride_group.dart';

class MyMapScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FreeMapWidget(
        initialLocation: LatLng(37.7749, -122.4194),
        showCurrentLocation: true,
        showZoomControls: true,
        onLocationSelected: (location) {
          print('Selected: ${location.latitude}, ${location.longitude}');
        },
      ),
    );
  }
}
```

## Advanced Usage with Markers and Routes

```dart
FreeMapWidget(
  initialLocation: LatLng(37.7749, -122.4194),
  markers: [
    MapMarkerData(
      coordinates: LatLng(37.7749, -122.4194),
      type: MapMarkerType.pickup,
      title: 'Pickup Location',
      subtitle: 'San Francisco, CA',
      onTap: () => print('Pickup marker tapped'),
    ),
    MapMarkerData(
      coordinates: LatLng(37.7849, -122.4094),
      type: MapMarkerType.destination,
      title: 'Destination',
      subtitle: 'Downtown SF',
    ),
  ],
  polylinePoints: [
    LatLng(37.7749, -122.4194),
    LatLng(37.7799, -122.4144),
    LatLng(37.7849, -122.4094),
  ],
  onLocationSelected: (location) {
    // Handle location selection
  },
  showCurrentLocation: true,
  showZoomControls: true,
  initialZoom: 15.0,
)
```

## Properties

### Core Properties

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `initialLocation` | `LatLng?` | `null` | Initial center point of the map |
| `markers` | `List<MapMarkerData>` | `[]` | List of markers to display |
| `polylinePoints` | `List<LatLng>?` | `null` | Points for drawing route lines |
| `onLocationSelected` | `Function(LatLng)?` | `null` | Callback when user taps on map |
| `showCurrentLocation` | `bool` | `false` | Show current location button |
| `allowLocationSelection` | `bool` | `true` | Allow tap-to-select functionality |
| `initialZoom` | `double` | `15.0` | Initial zoom level |

### UI Properties

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `showZoomControls` | `bool` | `true` | Show zoom in/out buttons |
| `enableRotation` | `bool` | `false` | Allow map rotation |
| `padding` | `EdgeInsets?` | `null` | Map padding |

### Configuration

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `config` | `FreeMapConfig?` | `null` | Map service configuration |

## MapMarkerData

The `MapMarkerData` class represents a marker on the map:

```dart
MapMarkerData({
  required LatLng coordinates,
  required MapMarkerType type,
  String? title,
  String? subtitle,
  VoidCallback? onTap,
  Widget? customIcon,
})
```

### Marker Types

- `MapMarkerType.pickup` - Green circle with location icon
- `MapMarkerType.destination` - Red circle with flag icon
- `MapMarkerType.currentLocation` - Blue circle with my_location icon
- `MapMarkerType.rideLocation` - Orange circle with car icon
- `MapMarkerType.searchResult` - Purple circle with place icon

## Custom Configuration

Use `FreeMapConfig` to customize the map behavior:

```dart
const customConfig = FreeMapConfig(
  osmTileServerUrl: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
  requestTimeout: Duration(seconds: 10),
  maxRetries: 3,
  enableFallback: true,
);

FreeMapWidget(
  config: customConfig,
  // ... other properties
)
```

## Integration Examples

### Location Picker

```dart
class LocationPickerScreen extends StatefulWidget {
  @override
  _LocationPickerScreenState createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  LatLng? selectedLocation;
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Select Location')),
      body: FreeMapWidget(
        onLocationSelected: (location) {
          setState(() {
            selectedLocation = location;
          });
        },
        markers: selectedLocation != null ? [
          MapMarkerData(
            coordinates: selectedLocation!,
            type: MapMarkerType.searchResult,
            title: 'Selected Location',
          ),
        ] : [],
      ),
      floatingActionButton: selectedLocation != null
          ? FloatingActionButton(
              onPressed: () => Navigator.pop(context, selectedLocation),
              child: Icon(Icons.check),
            )
          : null,
    );
  }
}
```

### Ride Route Display

```dart
class RideRouteScreen extends StatelessWidget {
  final LatLng pickup;
  final LatLng destination;
  final List<LatLng> routePoints;
  
  const RideRouteScreen({
    required this.pickup,
    required this.destination,
    required this.routePoints,
  });
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Ride Route')),
      body: FreeMapWidget(
        markers: [
          MapMarkerData(
            coordinates: pickup,
            type: MapMarkerType.pickup,
            title: 'Pickup',
          ),
          MapMarkerData(
            coordinates: destination,
            type: MapMarkerType.destination,
            title: 'Destination',
          ),
        ],
        polylinePoints: routePoints,
        initialLocation: pickup,
        showZoomControls: true,
      ),
    );
  }
}
```

## Testing

The widget includes comprehensive tests. Run them with:

```bash
flutter test test/widgets/free_map_widget_test.dart
```

## Performance Considerations

1. **Tile Caching**: The widget uses `CachedNetworkImageProvider` for efficient tile caching
2. **Marker Optimization**: Markers are rebuilt only when the markers list changes
3. **Memory Management**: The `MapController` is properly disposed
4. **Network Efficiency**: Respects OSM usage policies with appropriate User-Agent headers

## Limitations

1. **Offline Support**: Limited to cached tiles only
2. **Geocoding**: Requires separate integration with geocoding services
3. **Routing**: Requires separate integration with routing services
4. **Rate Limits**: Subject to OpenStreetMap usage policies

## Dependencies

- `flutter_map: ^6.1.0`
- `latlong2: ^0.9.1`
- `cached_network_image: ^3.3.0`

## Related Components

- `FreeGeocodingService` - For address search and reverse geocoding
- `FreeRoutingService` - For route calculation
- `MapCacheService` - For advanced caching strategies
- `FallbackManager` - For service fallback handling