import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import '../models/ride_group.dart';
import '../models/place_models.dart';
import '../services/free_geocoding_service.dart';
import '../services/offline_service.dart';
import '../services/map_cache_service.dart';
import '../core/config/free_map_config.dart';
import '../core/constants/app_constants.dart';
import 'free_map_widget.dart';
import 'offline_banner.dart';

/// Enhanced location picker using free services with offline support
class FreeLocationPicker extends StatefulWidget {
  final String title;
  final LatLng? initialLocation;
  final String? initialAddress;
  final Function(LatLng, String?)? onLocationSelected;
  final bool showMap;
  final bool allowCurrentLocation;
  final bool allowSearch;
  final FreeMapConfig? config;
  final IOfflineService? offlineService;
  final IMapCacheService? cacheService;
  final String? hintText;
  final double initialZoom;
  final bool showCoordinates;
  final bool allowManualCoordinateEntry;
  final int maxSearchResults;

  const FreeLocationPicker({
    super.key,
    required this.title,
    this.initialLocation,
    this.initialAddress,
    this.onLocationSelected,
    this.showMap = true,
    this.allowCurrentLocation = true,
    this.allowSearch = true,
    this.config,
    this.offlineService,
    this.cacheService,
    this.hintText,
    this.initialZoom = 15.0,
    this.showCoordinates = false,
    this.allowManualCoordinateEntry = false,
    this.maxSearchResults = 5,
  });

  @override
  State<FreeLocationPicker> createState() => _FreeLocationPickerState();
}

class _FreeLocationPickerState extends State<FreeLocationPicker> with OfflineAwareMixin {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  
  List<PlaceSearchResult> _searchResults = [];
  bool _isSearching = false;
  bool _isLoadingCurrentLocation = false;
  bool _isLoadingAddress = false;
  
  LatLng? _selectedLocation;
  String? _selectedAddress;
  List<MapMarkerData> _markers = [];
  String? _lastError;
  
  late FreeMapConfig _config;
  late IOfflineService _offlineService;
  late IMapCacheService _cacheService;
  IFreeGeocodingService? _geocodingService;

  @override
  void initState() {
    super.initState();
    _config = widget.config ?? const FreeMapConfig();
    _offlineService = widget.offlineService ?? MockOfflineService();
    _cacheService = widget.cacheService ?? MockMapCacheService();
    
    initializeOfflineService(_offlineService);
    
    if (widget.initialLocation != null) {
      _selectedLocation = widget.initialLocation;
      _selectedAddress = widget.initialAddress;
      _updateMarkers();
      
      // Load address if not provided and online
      if (_selectedAddress == null && isOnline) {
        _loadAddressFromCoordinates(widget.initialLocation!);
      }
    }
    
    // Listen for connectivity changes
    _offlineService.connectivityStream.listen((isOnline) {
      if (mounted) {
        setState(() {});
        if (!isOnline) {
          // Clear search results when going offline
          _searchResults.clear();
          _isSearching = false;
        }
      }
    });
    
    if (widget.initialAddress != null) {
      _searchController.text = widget.initialAddress!;
    }
    
    // Check location permissions on init
    _checkLocationPermissions();
  }
  
  Future<void> _checkLocationPermissions() async {
    if (!widget.allowCurrentLocation) return;
    
    try {
      final permission = await Geolocator.checkPermission();
      // Permission check completed
    } catch (e) {
      // Permission check failed
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    try {
      _geocodingService = context.read<IFreeGeocodingService>();
    } catch (e) {
      // Service not available, will handle gracefully
      debugPrint('FreeGeocodingService not available: $e');
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
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
                onTap: () => _showLocationDetails(),
              ),
            ]
          : [];
    });
  }

  void _showLocationDetails() {
    if (_selectedLocation == null) return;
    
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Selected Location',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _selectedAddress ?? 'Unknown address',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              'Coordinates: ${_selectedLocation!.latitude.toStringAsFixed(6)}, '
              '${_selectedLocation!.longitude.toStringAsFixed(6)}',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _confirmSelection();
                  },
                  child: const Text('Confirm'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _searchPlaces(String query) async {
    if (query.trim().isEmpty || _geocodingService == null) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
        _lastError = null;
      });
      return;
    }

    // Check if offline
    if (!isOnline) {
      setState(() {
        _lastError = 'Search unavailable offline';
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.wifi_off, color: Colors.white, size: 20),
                SizedBox(width: 12),
                Text('Search unavailable offline'),
              ],
            ),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    setState(() {
      _isSearching = true;
      _lastError = null;
    });

    try {
      final results = await _geocodingService!.searchPlaces(
        query,
        location: _selectedLocation,
      );
      
      // Limit results to maxSearchResults
      final limitedResults = results.take(widget.maxSearchResults).toList();
      
      setState(() {
        _searchResults = limitedResults;
        _isSearching = false;
        _lastError = null;
      });
    } catch (e) {
      final errorMessage = _getErrorMessage(e);
      setState(() {
        _searchResults = [];
        _isSearching = false;
        _lastError = errorMessage;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Search failed: $errorMessage'),
            backgroundColor: Colors.red,
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: () => _searchPlaces(query),
            ),
          ),
        );
      }
    }
  }
  
  String _getErrorMessage(dynamic error) {
    if (error.toString().contains('rate limit')) {
      return 'Too many requests. Please wait a moment.';
    } else if (error.toString().contains('network')) {
      return 'Network error. Check your connection.';
    } else if (error.toString().contains('timeout')) {
      return 'Request timed out. Please try again.';
    } else {
      return 'Search service temporarily unavailable';
    }
  }

  Future<void> _loadAddressFromCoordinates(LatLng coordinates) async {
    if (_geocodingService == null) return;

    setState(() {
      _isLoadingAddress = true;
    });

    try {
      final placeDetails = await _geocodingService!.reverseGeocode(coordinates);
      
      setState(() {
        _selectedAddress = placeDetails?.address ?? 
            '${coordinates.latitude.toStringAsFixed(4)}, ${coordinates.longitude.toStringAsFixed(4)}';
        _isLoadingAddress = false;
      });
      
      _updateMarkers();
    } catch (e) {
      setState(() {
        _selectedAddress = '${coordinates.latitude.toStringAsFixed(4)}, ${coordinates.longitude.toStringAsFixed(4)}';
        _isLoadingAddress = false;
      });
      
      _updateMarkers();
      
      debugPrint('Reverse geocoding failed: $e');
    }
  }

  Future<void> _getCurrentLocation() async {
    setState(() {
      _isLoadingCurrentLocation = true;
      _lastError = null;
    });

    try {
      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('Location services are disabled. Please enable them in settings.');
      }

      // Check permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Location permissions are denied. Please grant location access.');
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw Exception('Location permissions are permanently denied. Please enable them in app settings.');
      }

      // Get current position with timeout
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      ).timeout(
        const Duration(seconds: 20),
        onTimeout: () => throw Exception('Location request timed out. Please try again.'),
      );

      final currentLocation = LatLng(position.latitude, position.longitude);
      
      setState(() {
        _selectedLocation = currentLocation;
        _isLoadingCurrentLocation = false;
      });

      _updateMarkers();
      await _loadAddressFromCoordinates(currentLocation);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Current location detected'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      final errorMessage = _getLocationErrorMessage(e);
      setState(() {
        _isLoadingCurrentLocation = false;
        _lastError = errorMessage;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'Settings',
              textColor: Colors.white,
              onPressed: () => Geolocator.openAppSettings(),
            ),
          ),
        );
      }
    }
  }
  
  String _getLocationErrorMessage(dynamic error) {
    final errorStr = error.toString().toLowerCase();
    if (errorStr.contains('permission')) {
      return 'Location permission required. Tap Settings to enable.';
    } else if (errorStr.contains('disabled') || errorStr.contains('service')) {
      return 'Location services disabled. Please enable in device settings.';
    } else if (errorStr.contains('timeout')) {
      return 'Location request timed out. Please try again.';
    } else {
      return 'Unable to get current location. Please try again.';
    }
  }

  void _onMapLocationSelected(LatLng location) {
    setState(() {
      _selectedLocation = location;
      _searchController.clear();
      _searchResults = [];
    });

    _updateMarkers();
    _loadAddressFromCoordinates(location);
  }

  void _onSearchResultSelected(PlaceSearchResult result) {
    setState(() {
      _selectedLocation = result.coordinates;
      _selectedAddress = result.address;
      _searchController.text = result.name;
      _searchResults = [];
    });

    _updateMarkers();
    _searchFocusNode.unfocus();
  }

  void _confirmSelection() {
    if (_selectedLocation != null) {
      widget.onLocationSelected?.call(_selectedLocation!, _selectedAddress);
      Navigator.of(context).pop({
        'location': _selectedLocation,
        'address': _selectedAddress,
      });
    }
  }
  
  void _showManualCoordinateEntry() {
    final latController = TextEditingController();
    final lngController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Enter Coordinates'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: latController,
              decoration: const InputDecoration(
                labelText: 'Latitude',
                hintText: 'e.g., 37.7749',
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: lngController,
              decoration: const InputDecoration(
                labelText: 'Longitude',
                hintText: 'e.g., -122.4194',
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final lat = double.tryParse(latController.text);
              final lng = double.tryParse(lngController.text);
              
              if (lat != null && lng != null && 
                  lat >= -90 && lat <= 90 && 
                  lng >= -180 && lng <= 180) {
                final location = LatLng(lat, lng);
                setState(() {
                  _selectedLocation = location;
                  _selectedAddress = '${lat.toStringAsFixed(6)}, ${lng.toStringAsFixed(6)}';
                });
                _updateMarkers();
                _loadAddressFromCoordinates(location);
                Navigator.of(context).pop();
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please enter valid coordinates'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: const Text('Set Location'),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    if (!widget.allowSearch) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          TextField(
            controller: _searchController,
            focusNode: _searchFocusNode,
            enabled: isOnline,
            decoration: InputDecoration(
              hintText: isOnline 
                  ? (widget.hintText ?? 'Search for a location...')
                  : 'Search unavailable offline',
              prefixIcon: Icon(
                isOnline ? Icons.search : Icons.search_off,
                color: isOnline ? null : Colors.grey,
              ),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        setState(() {
                          _searchResults = [];
                        });
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              filled: !isOnline,
              fillColor: isOnline ? null : Colors.grey.shade100,
            ),
            onChanged: isOnline ? (value) {
              // Debounce search
              Future.delayed(const Duration(milliseconds: 500), () {
                if (_searchController.text == value) {
                  _searchPlaces(value);
                }
              });
            } : null,
            onSubmitted: isOnline ? _searchPlaces : null,
          ),
          
          // Search results
          if (_isSearching)
            const Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(),
            )
          else if (_searchResults.isNotEmpty)
            Container(
              constraints: const BoxConstraints(maxHeight: 200),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _searchResults.length,
                itemBuilder: (context, index) {
                  final result = _searchResults[index];
                  return ListTile(
                    leading: const Icon(Icons.place),
                    title: Text(result.name),
                    subtitle: Text(result.address),
                    onTap: () => _onSearchResultSelected(result),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSelectedLocationInfo() {
    if (_selectedLocation == null) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        border: Border(
          left: BorderSide(color: Colors.green.shade400, width: 4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.location_on, color: Colors.green),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Selected Location',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              if (widget.allowManualCoordinateEntry)
                IconButton(
                  icon: const Icon(Icons.edit_location_alt, size: 20),
                  onPressed: _showManualCoordinateEntry,
                  tooltip: 'Enter coordinates manually',
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (_isLoadingAddress)
            const Row(
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 8),
                Text('Loading address...'),
              ],
            )
          else
            Text(
              _selectedAddress ?? 'Unknown address',
              style: const TextStyle(fontSize: 14),
            ),
          if (widget.showCoordinates) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Lat: ${_selectedLocation!.latitude.toStringAsFixed(6)}, '
                    'Lng: ${_selectedLocation!.longitude.toStringAsFixed(6)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.copy, size: 16),
                  onPressed: () => _copyCoordinates(),
                  tooltip: 'Copy coordinates',
                ),
              ],
            ),
          ],
          if (_lastError != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.error_outline, color: Colors.red.shade600, size: 16),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    _lastError!,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.red.shade600,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
  
  void _copyCoordinates() {
    if (_selectedLocation != null) {
      final coordinates = '${_selectedLocation!.latitude.toStringAsFixed(6)}, ${_selectedLocation!.longitude.toStringAsFixed(6)}';
      // Note: In a real app, you'd use Clipboard.setData here
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Coordinates copied: $coordinates'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Widget _buildInstructions() {
    String instruction;
    IconData icon;
    Color color;
    
    if (!isOnline) {
      instruction = 'Offline mode: Search and current location unavailable';
      icon = Icons.wifi_off;
      color = Colors.orange;
    } else if (_selectedLocation == null) {
      instruction = 'Search for a location, tap on the map, or use current location';
      icon = Icons.info_outline;
      color = Colors.blue;
    } else {
      instruction = 'Tap "CONFIRM" to use this location';
      icon = Icons.check_circle_outline;
      color = Colors.green;
    }
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              instruction,
              style: TextStyle(
                fontSize: 14,
                fontStyle: FontStyle.italic,
                color: color.withValues(alpha: 0.8),
              ),
            ),
          ),
        ],
      ),
    );
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
          // Offline banner
          OfflineBanner(
            offlineService: _offlineService,
            onRetry: () => _offlineService.refreshConnectivity(),
            customMessage: 'Offline: Search and current location unavailable',
          ),
          
          // Search bar
          _buildSearchBar(),
          
          // Selected location info
          _buildSelectedLocationInfo(),
          
          // Instructions
          _buildInstructions(),
          
          // Map
          if (widget.showMap)
            Expanded(
              child: FreeMapWidget(
                initialLocation: _selectedLocation ?? 
                    LatLng(AppConstants.defaultLatitude, AppConstants.defaultLongitude),
                markers: _markers,
                onLocationSelected: _onMapLocationSelected,
                showCurrentLocation: widget.allowCurrentLocation,
                showZoomControls: true,
                allowLocationSelection: true,
                initialZoom: widget.initialZoom,
                config: _config,
                offlineService: _offlineService,
                cacheService: _cacheService,
                showOfflineBanner: false, // Already shown at top level
              ),
            ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          // Current location button
          if (widget.allowCurrentLocation)
            FloatingActionButton(
              heroTag: "free_location_picker_current_location",
              onPressed: (_isLoadingCurrentLocation || !isOnline) ? null : _getCurrentLocation,
              backgroundColor: isOnline ? null : Colors.grey.shade300,
              child: _isLoadingCurrentLocation
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Icon(
                      Icons.my_location,
                      color: isOnline ? null : Colors.grey.shade500,
                    ),
            ),
          
          const SizedBox(height: 16),
          
          // Confirm button
          if (_selectedLocation != null)
            FloatingActionButton.extended(
              heroTag: "free_location_picker_confirm_location",
              onPressed: _confirmSelection,
              icon: const Icon(Icons.check),
              label: const Text('Confirm Location'),
            ),
        ],
      ),
    );
  }
}

/// Helper function to show the free location picker
Future<Map<String, dynamic>?> showFreeLocationPicker({
  required BuildContext context,
  required String title,
  LatLng? initialLocation,
  String? initialAddress,
  bool allowCurrentLocation = true,
  bool allowSearch = true,
  String? hintText,
  FreeMapConfig? config,
}) async {
  return await Navigator.of(context).push<Map<String, dynamic>>(
    MaterialPageRoute(
      builder: (context) => FreeLocationPicker(
        title: title,
        initialLocation: initialLocation,
        initialAddress: initialAddress,
        allowCurrentLocation: allowCurrentLocation,
        allowSearch: allowSearch,
        hintText: hintText,
        config: config,
      ),
    ),
  );
}