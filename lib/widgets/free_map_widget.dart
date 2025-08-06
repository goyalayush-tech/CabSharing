import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as ll;
import 'package:cached_network_image/cached_network_image.dart';
import '../models/ride_group.dart' as rg;
import '../core/config/free_map_config.dart';
import '../core/constants/app_constants.dart';
import '../services/offline_service.dart';
import '../services/map_cache_service.dart';
import '../services/offline_tile_provider.dart';
import 'offline_banner.dart';

/// Marker types for different use cases
enum MapMarkerType {
  pickup,
  destination,
  currentLocation,
  rideLocation,
  searchResult,
}

/// Data class for map markers
class MapMarkerData {
  final rg.LatLng coordinates;
  final MapMarkerType type;
  final String? title;
  final String? subtitle;
  final VoidCallback? onTap;
  final Widget? customIcon;

  MapMarkerData({
    required this.coordinates,
    required this.type,
    this.title,
    this.subtitle,
    this.onTap,
    this.customIcon,
  });
}

/// Free map widget using OpenStreetMap tiles with offline support
class FreeMapWidget extends StatefulWidget {
  final rg.LatLng? initialLocation;
  final List<MapMarkerData> markers;
  final List<rg.LatLng>? polylinePoints;
  final Function(rg.LatLng)? onLocationSelected;
  final bool showCurrentLocation;
  final bool allowLocationSelection;
  final double initialZoom;
  final FreeMapConfig? config;
  final bool showZoomControls;
  final bool enableRotation;
  final EdgeInsets? padding;
  final IOfflineService? offlineService;
  final IMapCacheService? cacheService;
  final bool showOfflineBanner;

  const FreeMapWidget({
    super.key,
    this.initialLocation,
    this.markers = const [],
    this.polylinePoints,
    this.onLocationSelected,
    this.showCurrentLocation = false,
    this.allowLocationSelection = true,
    this.initialZoom = AppConstants.defaultZoom,
    this.config,
    this.showZoomControls = true,
    this.enableRotation = false,
    this.padding,
    this.offlineService,
    this.cacheService,
    this.showOfflineBanner = true,
  });

  @override
  State<FreeMapWidget> createState() => _FreeMapWidgetState();
}

class _FreeMapWidgetState extends State<FreeMapWidget> with OfflineAwareMixin {
  late MapController _mapController;
  late FreeMapConfig _config;
  late IOfflineService _offlineService;
  late IMapCacheService _cacheService;
  
  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _config = widget.config ?? const FreeMapConfig();
    _offlineService = widget.offlineService ?? MockOfflineService();
    _cacheService = widget.cacheService ?? MockMapCacheService();
    
    initializeOfflineService(_offlineService);
    
    // Listen for connectivity changes
    _offlineService.connectivityStream.listen((isOnline) {
      if (mounted) {
        setState(() {});
        if (isOnline) {
          showOnlineSnackBar();
        } else {
          showOfflineSnackBar();
        }
      }
    });
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  /// Convert custom LatLng to flutter_map LatLng
  ll.LatLng _convertToFlutterMapLatLng(rg.LatLng latLng) {
    return ll.LatLng(latLng.latitude, latLng.longitude);
  }

  /// Convert flutter_map LatLng to custom LatLng
  rg.LatLng _convertFromFlutterMapLatLng(ll.LatLng latLng) {
    return rg.LatLng(latLng.latitude, latLng.longitude);
  }

  /// Get marker icon based on type
  Widget _getMarkerIcon(MapMarkerType type) {
    switch (type) {
      case MapMarkerType.pickup:
        return Container(
          width: 40,
          height: 40,
          decoration: const BoxDecoration(
            color: Colors.green,
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.location_on,
            color: Colors.white,
            size: 24,
          ),
        );
      case MapMarkerType.destination:
        return Container(
          width: 40,
          height: 40,
          decoration: const BoxDecoration(
            color: Colors.red,
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.flag,
            color: Colors.white,
            size: 24,
          ),
        );
      case MapMarkerType.currentLocation:
        return Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.blue,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3),
          ),
          child: const Icon(
            Icons.my_location,
            color: Colors.white,
            size: 20,
          ),
        );
      case MapMarkerType.rideLocation:
        return Container(
          width: 40,
          height: 40,
          decoration: const BoxDecoration(
            color: Colors.orange,
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.directions_car,
            color: Colors.white,
            size: 24,
          ),
        );
      case MapMarkerType.searchResult:
        return Container(
          width: 35,
          height: 35,
          decoration: const BoxDecoration(
            color: Colors.purple,
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.place,
            color: Colors.white,
            size: 20,
          ),
        );
    }
  }

  /// Handle map tap events
  void _onMapTap(TapPosition tapPosition, ll.LatLng point) {
    if (widget.allowLocationSelection && widget.onLocationSelected != null) {
      final customLatLng = _convertFromFlutterMapLatLng(point);
      widget.onLocationSelected!(customLatLng);
    }
  }

  /// Get appropriate tile provider based on offline status
  TileProvider _getTileProvider() {
    if (widget.offlineService != null && widget.cacheService != null) {
      return OfflineTileProvider(
        cacheService: _cacheService,
        offlineService: _offlineService,
        baseUrl: _config.osmTileServerUrl,
      );
    }
    
    // Fallback to cached network provider
    return CachedNetworkTileProvider();
  }

  /// Handle retry when offline
  void _handleRetry() {
    _offlineService.refreshConnectivity();
  }

  /// Build markers for the map
  List<Marker> _buildMarkers() {
    return widget.markers.map((markerData) {
      return Marker(
        point: _convertToFlutterMapLatLng(markerData.coordinates),
        width: 40,
        height: 40,
        child: GestureDetector(
          onTap: markerData.onTap,
          child: markerData.customIcon ?? _getMarkerIcon(markerData.type),
        ),
      );
    }).toList();
  }

  /// Build polyline for routes
  List<Polyline> _buildPolylines() {
    if (widget.polylinePoints == null || widget.polylinePoints!.isEmpty) {
      return [];
    }

    return [
      Polyline(
        points: widget.polylinePoints!
            .map((point) => _convertToFlutterMapLatLng(point))
            .toList(),
        strokeWidth: 4.0,
        color: Colors.blue,
        borderStrokeWidth: 2.0,
        borderColor: Colors.white,
      ),
    ];
  }

  /// Get initial center point
  ll.LatLng _getInitialCenter() {
    if (widget.initialLocation != null) {
      return _convertToFlutterMapLatLng(widget.initialLocation!);
    }
    
    // If we have markers, center on the first one
    if (widget.markers.isNotEmpty) {
      return _convertToFlutterMapLatLng(widget.markers.first.coordinates);
    }
    
    // Default to app constants location
    return const ll.LatLng(
      AppConstants.defaultLatitude,
      AppConstants.defaultLongitude,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Offline banner
        if (widget.showOfflineBanner)
          OfflineBanner(
            offlineService: _offlineService,
            onRetry: _handleRetry,
            customMessage: isOnline 
                ? null 
                : 'Offline mode: Showing cached map tiles',
          ),
        
        // Map
        Expanded(
          child: Stack(
            children: [
              FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: _getInitialCenter(),
                  initialZoom: widget.initialZoom,
                  onTap: isOnline && widget.allowLocationSelection ? _onMapTap : null,
                  interactionOptions: InteractionOptions(
                    enableScrollWheel: true,
                    enableMultiFingerGestureRace: true,
                    rotationThreshold: widget.enableRotation ? 0.0 : double.infinity,
                  ),
                ),
                children: [
                  // OSM Tile Layer with offline support
                  TileLayer(
                    urlTemplate: _config.osmTileServerUrl,
                    userAgentPackageName: 'com.ridelink.app',
                    maxZoom: 18,
                    tileProvider: _getTileProvider(),
                  ),
                  
                  // Polylines (routes) - only show if online or cached
                  if (isOnline || widget.polylinePoints != null)
                    PolylineLayer(
                      polylines: _buildPolylines(),
                    ),
                  
                  // Markers
                  MarkerLayer(
                    markers: _buildMarkers(),
                  ),
                  
                  // Offline overlay
                  if (!isOnline)
                    Container(
                      color: Colors.black.withValues(alpha: 0.1),
                      child: const Center(
                        child: Chip(
                          avatar: Icon(Icons.wifi_off, size: 16),
                          label: Text(
                            'Offline Mode',
                            style: TextStyle(fontSize: 12),
                          ),
                          backgroundColor: Colors.white,
                        ),
                      ),
                    ),
                ],
              ),
        
              // Zoom controls
              if (widget.showZoomControls)
                Positioned(
                  right: 16,
                  bottom: 100,
                  child: Column(
                    children: [
                      FloatingActionButton.small(
                        heroTag: "zoom_in",
                        onPressed: () {
                          final zoom = _mapController.camera.zoom;
                          _mapController.move(
                            _mapController.camera.center,
                            zoom + 1,
                          );
                        },
                        child: const Icon(Icons.add),
                      ),
                      const SizedBox(height: 8),
                      FloatingActionButton.small(
                        heroTag: "zoom_out",
                        onPressed: () {
                          final zoom = _mapController.camera.zoom;
                          _mapController.move(
                            _mapController.camera.center,
                            zoom - 1,
                          );
                        },
                        child: const Icon(Icons.remove),
                      ),
                    ],
                  ),
                ),
              
              // Current location button (disabled when offline)
              if (widget.showCurrentLocation)
                Positioned(
                  right: 16,
                  bottom: 40,
                  child: FloatingActionButton.small(
                    heroTag: "current_location",
                    onPressed: isOnline ? () {
                      // This would integrate with location service
                      // For now, just center on default location
                      _mapController.move(
                        const ll.LatLng(
                          AppConstants.defaultLatitude,
                          AppConstants.defaultLongitude,
                        ),
                        widget.initialZoom,
                      );
                    } : null,
                    backgroundColor: isOnline ? null : Colors.grey.shade300,
                    child: Icon(
                      Icons.my_location,
                      color: isOnline ? null : Colors.grey.shade500,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Custom tile provider with caching support
class CachedNetworkTileProvider extends TileProvider {
  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) {
    final url = getTileUrl(coordinates, options);
    return CachedNetworkImageProvider(
      url,
      headers: const {
        'User-Agent': 'RideLink/1.0.0 (Flutter App)',
      },
    );
  }
}