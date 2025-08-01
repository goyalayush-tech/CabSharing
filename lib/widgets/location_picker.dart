import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/ride_group.dart';
import '../services/location_service.dart';

class LocationPickerScreen extends StatefulWidget {
  final String title;
  final LatLng? initialLocation;

  const LocationPickerScreen({
    super.key,
    required this.title,
    this.initialLocation,
  });

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  final _searchController = TextEditingController();
  final List<LocationSearchResult> _searchResults = [];
  bool _isLoading = false;
  LatLng? _selectedLocation;
  String? _selectedAddress;

  @override
  void initState() {
    super.initState();
    if (widget.initialLocation != null) {
      _selectedLocation = widget.initialLocation;
      _loadAddressFromCoordinates(widget.initialLocation!);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadAddressFromCoordinates(LatLng coordinates) async {
    try {
      final locationService = context.read<LocationService>();
      final placemarks = await locationService.getAddressFromCoordinates(
        coordinates.latitude,
        coordinates.longitude,
      );
      
      if (placemarks.isNotEmpty && mounted) {
        final placemark = placemarks.first;
        setState(() {
          _selectedAddress = '${placemark.street}, ${placemark.locality}, ${placemark.country}';
        });
      }
    } catch (e) {
      // Handle error silently or show a message
    }
  }

  Future<void> _searchLocations(String query) async {
    if (query.isEmpty) {
      setState(() {
        _searchResults.clear();
      });
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // In a real implementation, you would use Google Places API or similar
      // For now, we'll simulate search results
      await Future.delayed(const Duration(milliseconds: 500));
      
      final mockResults = [
        LocationSearchResult(
          name: '$query - Location 1',
          address: '$query Street, City, Country',
          coordinates: LatLng(37.7749 + (query.length * 0.001), -122.4194),
        ),
        LocationSearchResult(
          name: '$query - Location 2',
          address: '$query Avenue, City, Country',
          coordinates: LatLng(37.7749 - (query.length * 0.001), -122.4194),
        ),
        LocationSearchResult(
          name: '$query - Location 3',
          address: '$query Road, City, Country',
          coordinates: LatLng(37.7749, -122.4194 + (query.length * 0.001)),
        ),
      ];

      if (mounted) {
        setState(() {
          _searchResults.clear();
          _searchResults.addAll(mockResults);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Search failed: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _getCurrentLocation() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final locationService = context.read<LocationService>();
      final position = await locationService.getCurrentLocation();
      final coordinates = LatLng(position.latitude, position.longitude);
      
      setState(() {
        _selectedLocation = coordinates;
      });
      
      await _loadAddressFromCoordinates(coordinates);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to get current location: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _selectLocation(LocationSearchResult result) {
    setState(() {
      _selectedLocation = result.coordinates;
      _selectedAddress = result.address;
      _searchController.text = result.name;
      _searchResults.clear();
    });
  }

  void _confirmSelection() {
    if (_selectedLocation != null && _selectedAddress != null) {
      Navigator.of(context).pop({
        'coordinates': _selectedLocation,
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
          TextButton(
            onPressed: _selectedLocation != null ? _confirmSelection : null,
            child: const Text('Select'),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search for a location...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _isLoading
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : IconButton(
                            icon: const Icon(Icons.my_location),
                            onPressed: _getCurrentLocation,
                          ),
                  ),
                  onChanged: _searchLocations,
                ),
                const SizedBox(height: 8),
                if (_selectedAddress != null)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Theme.of(context).primaryColor.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.location_on,
                          color: Theme.of(context).primaryColor,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _selectedAddress!,
                            style: TextStyle(
                              color: Theme.of(context).primaryColor,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),

          // Search Results
          Expanded(
            child: _searchResults.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text(
                          'Search for a location above',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: _searchResults.length,
                    itemBuilder: (context, index) {
                      final result = _searchResults[index];
                      return ListTile(
                        leading: const Icon(Icons.location_on),
                        title: Text(result.name),
                        subtitle: Text(result.address),
                        onTap: () => _selectLocation(result),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class LocationSearchResult {
  final String name;
  final String address;
  final LatLng coordinates;

  LocationSearchResult({
    required this.name,
    required this.address,
    required this.coordinates,
  });
}