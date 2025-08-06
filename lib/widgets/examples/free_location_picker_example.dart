import 'package:flutter/material.dart';
import '../free_map_widget.dart';
import '../../models/ride_group.dart';

/// Example of using FreeMapWidget as a location picker
class FreeLocationPickerExample extends StatefulWidget {
  final String title;
  final LatLng? initialLocation;
  final Function(LatLng, String?)? onLocationSelected;

  const FreeLocationPickerExample({
    super.key,
    required this.title,
    this.initialLocation,
    this.onLocationSelected,
  });

  @override
  State<FreeLocationPickerExample> createState() => _FreeLocationPickerExampleState();
}

class _FreeLocationPickerExampleState extends State<FreeLocationPickerExample> {
  LatLng? _selectedLocation;
  String? _selectedAddress;
  List<MapMarkerData> _markers = [];

  @override
  void initState() {
    super.initState();
    if (widget.initialLocation != null) {
      _selectedLocation = widget.initialLocation;
      _updateMarkers();
    }
  }

  void _updateMarkers() {
    setState(() {
      _markers = _selectedLocation != null
          ? [
              MapMarkerData(
                coordinates: _selectedLocation!,
                type: MapMarkerType.searchResult,
                title: 'Selected Location',
                subtitle: _selectedAddress ?? 'Tap to select',
              ),
            ]
          : [];
    });
  }

  void _onLocationSelected(LatLng location) {
    setState(() {
      _selectedLocation = location;
      _selectedAddress = '${location.latitude.toStringAsFixed(4)}, ${location.longitude.toStringAsFixed(4)}';
    });
    _updateMarkers();
    
    // Call the callback if provided
    widget.onLocationSelected?.call(location, _selectedAddress);
  }

  void _confirmSelection() {
    if (_selectedLocation != null) {
      Navigator.of(context).pop({
        'location': _selectedLocation,
        'address': _selectedAddress,
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          if (_selectedLocation != null)
            TextButton(
              onPressed: _confirmSelection,
              child: const Text(
                'CONFIRM',
                style: TextStyle(color: Colors.white),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // Selected location info
          if (_selectedLocation != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              color: Colors.green.shade50,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Selected Location:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _selectedAddress ?? 'Unknown address',
                    style: const TextStyle(fontSize: 14),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Lat: ${_selectedLocation!.latitude.toStringAsFixed(6)}, '
                    'Lng: ${_selectedLocation!.longitude.toStringAsFixed(6)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
          
          // Instructions
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            color: Colors.blue.shade50,
            child: const Text(
              'Tap on the map to select a location',
              style: TextStyle(
                fontSize: 14,
                fontStyle: FontStyle.italic,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          
          // Map
          Expanded(
            child: FreeMapWidget(
              initialLocation: widget.initialLocation ?? 
                  LatLng(37.7749, -122.4194), // Default to San Francisco
              markers: _markers,
              onLocationSelected: _onLocationSelected,
              showCurrentLocation: true,
              showZoomControls: true,
              allowLocationSelection: true,
              initialZoom: 15.0,
            ),
          ),
        ],
      ),
      floatingActionButton: _selectedLocation != null
          ? FloatingActionButton.extended(
              onPressed: _confirmSelection,
              icon: const Icon(Icons.check),
              label: const Text('Confirm Location'),
            )
          : null,
    );
  }
}

/// Helper function to show the location picker
Future<Map<String, dynamic>?> showFreeLocationPicker({
  required BuildContext context,
  required String title,
  LatLng? initialLocation,
}) async {
  return await Navigator.of(context).push<Map<String, dynamic>>(
    MaterialPageRoute(
      builder: (context) => FreeLocationPickerExample(
        title: title,
        initialLocation: initialLocation,
      ),
    ),
  );
}