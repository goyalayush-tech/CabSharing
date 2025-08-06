import 'package:flutter/material.dart';
import '../free_map_widget.dart';
import '../../models/ride_group.dart';
import '../../core/config/free_map_config.dart';

/// Example usage of FreeMapWidget
class FreeMapExample extends StatefulWidget {
  const FreeMapExample({super.key});

  @override
  State<FreeMapExample> createState() => _FreeMapExampleState();
}

class _FreeMapExampleState extends State<FreeMapExample> {
  LatLng? selectedLocation;
  List<MapMarkerData> markers = [];
  List<LatLng> routePoints = [];

  @override
  void initState() {
    super.initState();
    _initializeExampleData();
  }

  void _initializeExampleData() {
    // Add some example markers
    markers = [
      MapMarkerData(
        coordinates: LatLng(37.7749, -122.4194),
        type: MapMarkerType.pickup,
        title: 'Pickup Location',
        subtitle: 'San Francisco, CA',
        onTap: () => _showMarkerInfo('Pickup Location'),
      ),
      MapMarkerData(
        coordinates: LatLng(37.7849, -122.4094),
        type: MapMarkerType.destination,
        title: 'Destination',
        subtitle: 'Downtown SF',
        onTap: () => _showMarkerInfo('Destination'),
      ),
      MapMarkerData(
        coordinates: LatLng(37.7799, -122.4144),
        type: MapMarkerType.rideLocation,
        title: 'Available Ride',
        subtitle: '2 seats available',
        onTap: () => _showMarkerInfo('Available Ride'),
      ),
    ];

    // Add example route
    routePoints = [
      LatLng(37.7749, -122.4194),
      LatLng(37.7779, -122.4164),
      LatLng(37.7809, -122.4134),
      LatLng(37.7839, -122.4104),
      LatLng(37.7849, -122.4094),
    ];
  }

  void _showMarkerInfo(String title) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Tapped on: $title'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _onLocationSelected(LatLng location) {
    setState(() {
      selectedLocation = location;
      // Add a search result marker at the selected location
      markers.add(
        MapMarkerData(
          coordinates: location,
          type: MapMarkerType.searchResult,
          title: 'Selected Location',
          subtitle: '${location.latitude.toStringAsFixed(4)}, ${location.longitude.toStringAsFixed(4)}',
          onTap: () => _showMarkerInfo('Selected Location'),
        ),
      );
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Location selected: ${location.latitude.toStringAsFixed(4)}, ${location.longitude.toStringAsFixed(4)}',
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _clearMarkers() {
    setState(() {
      markers.clear();
      routePoints.clear();
      selectedLocation = null;
    });
  }

  void _resetExample() {
    setState(() {
      selectedLocation = null;
    });
    _initializeExampleData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Free Map Widget Example'),
        actions: [
          IconButton(
            icon: const Icon(Icons.clear),
            onPressed: _clearMarkers,
            tooltip: 'Clear markers',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _resetExample,
            tooltip: 'Reset example',
          ),
        ],
      ),
      body: Column(
        children: [
          // Info panel
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: Colors.blue.shade50,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Free Map Widget Demo',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text('• Tap on the map to select a location'),
                const Text('• Tap on markers to see their info'),
                const Text('• Use zoom controls to navigate'),
                if (selectedLocation != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'Selected: ${selectedLocation!.latitude.toStringAsFixed(4)}, ${selectedLocation!.longitude.toStringAsFixed(4)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          
          // Map widget
          Expanded(
            child: FreeMapWidget(
              initialLocation: LatLng(37.7749, -122.4194),
              markers: markers,
              polylinePoints: routePoints.isNotEmpty ? routePoints : null,
              onLocationSelected: _onLocationSelected,
              showCurrentLocation: true,
              showZoomControls: true,
              allowLocationSelection: true,
              initialZoom: 13.0,
              config: const FreeMapConfig.development(),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          // Example of programmatically adding a marker
          setState(() {
            markers.add(
              MapMarkerData(
                coordinates: LatLng(
                  37.7749 + (0.01 * (markers.length % 5)),
                  -122.4194 + (0.01 * (markers.length % 5)),
                ),
                type: MapMarkerType.searchResult,
                title: 'Dynamic Marker ${markers.length + 1}',
                subtitle: 'Added programmatically',
                onTap: () => _showMarkerInfo('Dynamic Marker ${markers.length}'),
              ),
            );
          });
        },
        icon: const Icon(Icons.add_location),
        label: const Text('Add Marker'),
      ),
    );
  }
}