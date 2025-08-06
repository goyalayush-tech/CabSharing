import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmaps;
import 'package:provider/provider.dart';
import '../models/ride_group.dart';
import '../models/place_models.dart';
import '../services/location_service.dart';

class DynamicMapWidget extends StatefulWidget {
  final LatLng? initialLocation;
  final List<MapMarkerData> markers;
  final List<LatLng>? polylinePoints;
  final Function(LatLng)? onLocationSelected;
  final bool showCurrentLocation;
  final bool allowLocationSelection;
  final double? height;
  final EdgeInsets? padding;

  const DynamicMapWidget({
    super.key,
    this.initialLocation,
    this.markers = const [],
    this.polylinePoints,
    this.onLocationSelected,
    this.showCurrentLocation = true,
    this.allowLocationSelection = false,
    this.height,
    this.padding,
  });

  @override
  State<DynamicMapWidget> createState() => _DynamicMapWidgetState();
}

class _DynamicMapWidgetState extends State<DynamicMapWidget> {
  gmaps.GoogleMapController? _controller;
  LatLng? _currentLocation;
  Set<gmaps.Marker> _markers = {};
  Set<gmaps.Polyline> _polylines = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initializeMap();
  }

  @override
  void didUpdateWidget(DynamicMapWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.markers != widget.markers ||
        oldWidget.polylinePoints != widget.polylinePoints) {
      _updateMapElements();
    }
  }

  Future<void> _initializeMap() async {
    try {
      if (widget.showCurrentLocation) {
        final locationService = context.read<ILocationService>();
        final position = await locationService.getCurrentLocation();
        _currentLocation = LatLng(position.latitude, position.longitude);
      }
      
      _updateMapElements();
    } catch (e) {
      // Handle location error - use default location or show error
      _currentLocation = widget.initialLocation ?? LatLng(37.7749, -122.4194);
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _updateMapElements() {
    _updateMarkers();
    _updatePolylines();
  }

  void _updateMarkers() {
    final markers = <gmaps.Marker>{};
    
    // Add current location marker
    if (_currentLocation != null && widget.showCurrentLocation) {
      markers.add(
        gmaps.Marker(
          markerId: const gmaps.MarkerId('current_location'),
          position: gmaps.LatLng(_currentLocation!.latitude, _currentLocation!.longitude),
          icon: gmaps.BitmapDescriptor.defaultMarkerWithHue(gmaps.BitmapDescriptor.hueBlue),
          infoWindow: const gmaps.InfoWindow(title: 'Your Location'),
        ),
      );
    }
    
    // Add custom markers
    for (int i = 0; i < widget.markers.length; i++) {
      final marker = widget.markers[i];
      markers.add(
        gmaps.Marker(
          markerId: gmaps.MarkerId('marker_$i'),
          position: gmaps.LatLng(marker.coordinates.latitude, marker.coordinates.longitude),
          icon: _getMarkerIcon(marker.type),
          infoWindow: gmaps.InfoWindow(
            title: marker.title,
            snippet: marker.description,
          ),
          onTap: marker.onTap,
        ),
      );
    }
    
    setState(() {
      _markers = markers;
    });
  }

  void _updatePolylines() {
    final polylines = <gmaps.Polyline>{};
    
    if (widget.polylinePoints != null && widget.polylinePoints!.isNotEmpty) {
      polylines.add(
        gmaps.Polyline(
          polylineId: const gmaps.PolylineId('route'),
          points: widget.polylinePoints!
              .map((point) => gmaps.LatLng(point.latitude, point.longitude))
              .toList(),
          color: Theme.of(context).primaryColor,
          width: 4,
          patterns: [],
        ),
      );
    }
    
    setState(() {
      _polylines = polylines;
    });
  }

  gmaps.BitmapDescriptor _getMarkerIcon(MapMarkerType type) {
    switch (type) {
      case MapMarkerType.pickup:
        return gmaps.BitmapDescriptor.defaultMarkerWithHue(gmaps.BitmapDescriptor.hueGreen);
      case MapMarkerType.destination:
        return gmaps.BitmapDescriptor.defaultMarkerWithHue(gmaps.BitmapDescriptor.hueRed);
      case MapMarkerType.waypoint:
        return gmaps.BitmapDescriptor.defaultMarkerWithHue(gmaps.BitmapDescriptor.hueOrange);
      case MapMarkerType.user:
        return gmaps.BitmapDescriptor.defaultMarkerWithHue(gmaps.BitmapDescriptor.hueBlue);
      default:
        return gmaps.BitmapDescriptor.defaultMarker;
    }
  }

  void _onMapTap(gmaps.LatLng position) {
    if (widget.allowLocationSelection && widget.onLocationSelected != null) {
      final latLng = LatLng(position.latitude, position.longitude);
      widget.onLocationSelected!(latLng);
    }
  }

  void _onMapCreated(gmaps.GoogleMapController controller) {
    _controller = controller;
    _fitMarkersInView();
  }

  void _fitMarkersInView() {
    if (_controller == null || _markers.isEmpty) return;
    
    final bounds = _calculateBounds();
    if (bounds != null) {
      _controller!.animateCamera(
        gmaps.CameraUpdate.newLatLngBounds(bounds, 100.0),
      );
    }
  }

  gmaps.LatLngBounds? _calculateBounds() {
    if (_markers.isEmpty) return null;
    
    double minLat = double.infinity;
    double maxLat = -double.infinity;
    double minLng = double.infinity;
    double maxLng = -double.infinity;
    
    for (final marker in _markers) {
      minLat = minLat < marker.position.latitude ? minLat : marker.position.latitude;
      maxLat = maxLat > marker.position.latitude ? maxLat : marker.position.latitude;
      minLng = minLng < marker.position.longitude ? minLng : marker.position.longitude;
      maxLng = maxLng > marker.position.longitude ? maxLng : marker.position.longitude;
    }
    
    return gmaps.LatLngBounds(
      southwest: gmaps.LatLng(minLat, minLng),
      northeast: gmaps.LatLng(maxLat, maxLng),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        height: widget.height ?? 300,
        child: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    final initialPosition = widget.initialLocation ?? _currentLocation ?? LatLng(37.7749, -122.4194);

    return Container(
      height: widget.height ?? 300,
      padding: widget.padding,
      child: gmaps.GoogleMap(
        onMapCreated: _onMapCreated,
        initialCameraPosition: gmaps.CameraPosition(
          target: gmaps.LatLng(initialPosition.latitude, initialPosition.longitude),
          zoom: 14.0,
        ),
        markers: _markers,
        polylines: _polylines,
        onTap: _onMapTap,
        myLocationEnabled: widget.showCurrentLocation,
        myLocationButtonEnabled: widget.showCurrentLocation,
        mapType: gmaps.MapType.normal,
        zoomControlsEnabled: true,
        compassEnabled: true,
        trafficEnabled: false,
      ),
    );
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }
}

enum MapMarkerType {
  pickup,
  destination,
  waypoint,
  user,
  generic,
}

class MapMarkerData {
  final LatLng coordinates;
  final String title;
  final String? description;
  final MapMarkerType type;
  final VoidCallback? onTap;

  MapMarkerData({
    required this.coordinates,
    required this.title,
    this.description,
    this.type = MapMarkerType.generic,
    this.onTap,
  });
}