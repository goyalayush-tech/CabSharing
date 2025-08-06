import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/ride_group.dart';
import '../models/place_models.dart';
import '../services/location_service.dart';
import 'dynamic_map_widget.dart';

class EnhancedLocationPicker extends StatefulWidget {
  final String title;
  final LatLng? initialLocation;
  final bool showMap;

  const EnhancedLocationPicker({
    super.key,
    required this.title,
    this.initialLocation,
    this.showMap = true,
  });

  @override
  State<EnhancedLocationPicker> createState() => _EnhancedLocationPickerState();
}

class _EnhancedLocationPickerState extends State<EnhancedLocationPicker> {
  final _searchController = TextEditingController();
  final List<PlaceSearchResult> _searchResults = [];
  bool _isLoading = false;
  LatLng? _selectedLocation;
  String? _selectedAddress;
  String? _selectedPlaceId;

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
      final locationService = context.read<ILocationService>();
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
      final locationService = context.read<ILocationService>();
      LatLng? currentLocation;
      
      // Try to get current location for better search results
      try {
        final position = await locationService.getCurrentLocation();
        currentLocation = LatLng(position.latitude, position.longitude);
      } catch (e) {
        // Use default or selected location if current location fails
        currentLocation = _selectedLocation;
      }
      
      final results = await locationService.searchPlaces(
        query,
        location: currentLocation,
        radius: 50000, // 50km radius
      );

      if (mounted) {
        setState(() {
          _searchResults.clear();
          _searchResults.addAll(results);
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
      final locationService = context.read<ILocationService>();
      final position = await locationService.getCurrentLocation();
      final coordinates = LatLng(position.latitude, position.longitude);
      
      setState(() {
        _selectedLocation = coordinates;
        _selectedPlaceId = null; // Clear place ID for GPS location
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

  void _selectLocation(PlaceSearchResult result) {
    setState(() {
      _selectedLocation = result.coordinates;
      _selectedAddress = result.address;
      _selectedPlaceId = result.placeId;
      _searchController.text = result.name;
      _searchResults.clear();
    });
  }

  void _onMapLocationSelected(LatLng location) {
    setState(() {
      _selectedLocation = location;
      _selectedPlaceId = null; // Clear place ID for map selection
    });
    _loadAddressFromCoordinates(location);
  }

  void _confirmSelection() {
    if (_selectedLocation != null && _selectedAddress != null) {
      Navigator.of(context).pop({
        'coordinates': _selectedLocation,
        'address': _selectedAddress,
        'placeId': _selectedPlaceId,
      });
    }
  }

  List<MapMarkerData> _getMapMarkers() {
    if (_selectedLocation == null) return [];
    
    return [
      MapMarkerData(
        coordinates: _selectedLocation!,
        title: 'Selected Location',
        description: _selectedAddress,
        type: MapMarkerType.destination,
      ),
    ];
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

          // Map (if enabled)
          if (widget.showMap)
            Container(
              height: 200,
              margin: const EdgeInsets.symmetric(horizontal: 16),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: DynamicMapWidget(
                  initialLocation: _selectedLocation ?? widget.initialLocation,
                  markers: _getMapMarkers(),
                  onLocationSelected: _onMapLocationSelected,
                  allowLocationSelection: true,
                  showCurrentLocation: true,
                ),
              ),
            ),

          if (widget.showMap) const SizedBox(height: 16),

          // Search Results
          Expanded(
            child: _searchResults.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search, size: 64, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text(
                          widget.showMap 
                              ? 'Search above or tap on the map'
                              : 'Search for a location above',
                          style: TextStyle(color: Colors.grey[600]),
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
                        trailing: result.types.isNotEmpty
                            ? Chip(
                                label: Text(
                                  result.types.first.replaceAll('_', ' '),
                                  style: const TextStyle(fontSize: 10),
                                ),
                                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              )
                            : null,
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

// Keep the old LocationPickerScreen for backward compatibility
class LocationPickerScreen extends StatelessWidget {
  final String title;
  final LatLng? initialLocation;

  const LocationPickerScreen({
    super.key,
    required this.title,
    this.initialLocation,
  });

  @override
  Widget build(BuildContext context) {
    return EnhancedLocationPicker(
      title: title,
      initialLocation: initialLocation,
      showMap: false, // Keep old behavior
    );
  }
}