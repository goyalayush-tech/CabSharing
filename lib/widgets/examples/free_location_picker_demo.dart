import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../free_location_picker.dart';
import '../../models/ride_group.dart';
import '../../services/free_geocoding_service.dart';
import '../../core/config/free_map_config.dart';

/// Demo screen showing FreeLocationPicker functionality
class FreeLocationPickerDemo extends StatefulWidget {
  const FreeLocationPickerDemo({super.key});

  @override
  State<FreeLocationPickerDemo> createState() => _FreeLocationPickerDemoState();
}

class _FreeLocationPickerDemoState extends State<FreeLocationPickerDemo> {
  LatLng? _selectedLocation;
  String? _selectedAddress;

  void _openLocationPicker() async {
    final result = await showFreeLocationPicker(
      context: context,
      title: 'Select Pickup Location',
      initialLocation: _selectedLocation,
      initialAddress: _selectedAddress,
      allowCurrentLocation: true,
      allowSearch: true,
      hintText: 'Search for pickup location...',
    );

    if (result != null) {
      setState(() {
        _selectedLocation = result['location'] as LatLng?;
        _selectedAddress = result['address'] as String?;
      });
    }
  }

  void _clearSelection() {
    setState(() {
      _selectedLocation = null;
      _selectedAddress = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Free Location Picker Demo'),
        actions: [
          if (_selectedLocation != null)
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: _clearSelection,
              tooltip: 'Clear selection',
            ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Free Location Picker Demo',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            
            const Text(
              'This demo shows the FreeLocationPicker widget functionality:',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 8),
            
            const Text('• Search for locations using free geocoding'),
            const Text('• Select locations by tapping on the map'),
            const Text('• Get current location with GPS'),
            const Text('• Reverse geocoding for addresses'),
            const Text('• Offline-friendly with caching'),
            
            const SizedBox(height: 24),
            
            // Selected location display
            if (_selectedLocation != null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  border: Border.all(color: Colors.green.shade200),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.location_on, color: Colors.green),
                        SizedBox(width: 8),
                        Text(
                          'Selected Location',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _selectedAddress ?? 'Unknown address',
                      style: const TextStyle(fontSize: 14),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Coordinates: ${_selectedLocation!.latitude.toStringAsFixed(6)}, '
                      '${_selectedLocation!.longitude.toStringAsFixed(6)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ] else ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Column(
                  children: [
                    Icon(
                      Icons.location_off,
                      size: 48,
                      color: Colors.grey,
                    ),
                    SizedBox(height: 8),
                    Text(
                      'No location selected',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Tap the button below to select a location',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
            
            // Action buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _openLocationPicker,
                    icon: const Icon(Icons.add_location),
                    label: Text(_selectedLocation == null 
                        ? 'Select Location' 
                        : 'Change Location'),
                  ),
                ),
                if (_selectedLocation != null) ...[
                  const SizedBox(width: 16),
                  ElevatedButton.icon(
                    onPressed: _clearSelection,
                    icon: const Icon(Icons.clear),
                    label: const Text('Clear'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ],
            ),
            
            const SizedBox(height: 24),
            
            // Features info
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Features:',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    
                    _buildFeatureCard(
                      icon: Icons.search,
                      title: 'Free Geocoding',
                      description: 'Search for locations using Nominatim (OpenStreetMap)',
                    ),
                    
                    _buildFeatureCard(
                      icon: Icons.map,
                      title: 'Interactive Map',
                      description: 'Tap on the map to select any location',
                    ),
                    
                    _buildFeatureCard(
                      icon: Icons.my_location,
                      title: 'Current Location',
                      description: 'Get your current location using GPS',
                    ),
                    
                    _buildFeatureCard(
                      icon: Icons.cached,
                      title: 'Caching',
                      description: 'Cached results for better performance and offline support',
                    ),
                    
                    _buildFeatureCard(
                      icon: Icons.money_off,
                      title: 'Cost-Free',
                      description: 'No API costs - uses free OpenStreetMap services',
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureCard({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(icon, color: Colors.blue),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Example of how to provide the geocoding service
class FreeLocationPickerDemoWithProvider extends StatelessWidget {
  const FreeLocationPickerDemoWithProvider({super.key});

  @override
  Widget build(BuildContext context) {
    return Provider<IFreeGeocodingService>(
      create: (_) => MockFreeGeocodingService(), // Use mock for demo
      child: const FreeLocationPickerDemo(),
    );
  }
}