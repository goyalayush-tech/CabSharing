import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_map/flutter_map.dart';
import '../../lib/widgets/free_map_widget.dart';
import '../../lib/models/ride_group.dart';
import '../../lib/core/config/free_map_config.dart';

void main() {
  group('FreeMapWidget', () {
    testWidgets('should render with default configuration', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: FreeMapWidget(),
          ),
        ),
      );

      expect(find.byType(FlutterMap), findsOneWidget);
      expect(find.byType(TileLayer), findsOneWidget);
    });

    testWidgets('should display markers when provided', (tester) async {
      final markers = [
        MapMarkerData(
          coordinates: LatLng(37.7749, -122.4194),
          type: MapMarkerType.pickup,
          title: 'Pickup Location',
        ),
        MapMarkerData(
          coordinates: LatLng(37.7849, -122.4094),
          type: MapMarkerType.destination,
          title: 'Destination',
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FreeMapWidget(
              markers: markers,
            ),
          ),
        ),
      );

      expect(find.byType(FlutterMap), findsOneWidget);
      expect(find.byType(MarkerLayer), findsOneWidget);
    });

    testWidgets('should show zoom controls when enabled', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: FreeMapWidget(
              showZoomControls: true,
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.add), findsOneWidget);
      expect(find.byIcon(Icons.remove), findsOneWidget);
    });

    testWidgets('should hide zoom controls when disabled', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: FreeMapWidget(
              showZoomControls: false,
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.add), findsNothing);
      expect(find.byIcon(Icons.remove), findsNothing);
    });

    testWidgets('should show current location button when enabled', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: FreeMapWidget(
              showCurrentLocation: true,
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.my_location), findsOneWidget);
    });

    testWidgets('should display polyline when route points provided', (tester) async {
      final routePoints = [
        LatLng(37.7749, -122.4194),
        LatLng(37.7849, -122.4094),
        LatLng(37.7949, -122.3994),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FreeMapWidget(
              polylinePoints: routePoints,
            ),
          ),
        ),
      );

      expect(find.byType(FlutterMap), findsOneWidget);
      expect(find.byType(PolylineLayer), findsOneWidget);
    });

    testWidgets('should use custom configuration when provided', (tester) async {
      const customConfig = FreeMapConfig(
        osmTileServerUrl: 'https://custom-tile-server.com/{z}/{x}/{y}.png',
        requestTimeout: Duration(seconds: 5),
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: FreeMapWidget(
              config: customConfig,
            ),
          ),
        ),
      );

      expect(find.byType(FlutterMap), findsOneWidget);
    });

    group('MapMarkerData', () {
      test('should create marker data with required fields', () {
        final marker = MapMarkerData(
          coordinates: LatLng(37.7749, -122.4194),
          type: MapMarkerType.pickup,
        );

        expect(marker.coordinates.latitude, 37.7749);
        expect(marker.coordinates.longitude, -122.4194);
        expect(marker.type, MapMarkerType.pickup);
      });

      test('should create marker data with optional fields', () {
        final marker = MapMarkerData(
          coordinates: LatLng(37.7749, -122.4194),
          type: MapMarkerType.destination,
          title: 'Test Location',
          subtitle: 'Test Subtitle',
        );

        expect(marker.title, 'Test Location');
        expect(marker.subtitle, 'Test Subtitle');
      });
    });

    group('MapMarkerType', () {
      test('should have all required marker types', () {
        expect(MapMarkerType.values, contains(MapMarkerType.pickup));
        expect(MapMarkerType.values, contains(MapMarkerType.destination));
        expect(MapMarkerType.values, contains(MapMarkerType.currentLocation));
        expect(MapMarkerType.values, contains(MapMarkerType.rideLocation));
        expect(MapMarkerType.values, contains(MapMarkerType.searchResult));
      });
    });

    group('CachedNetworkTileProvider', () {
      test('should create tile provider instance', () {
        final provider = CachedNetworkTileProvider();
        expect(provider, isA<TileProvider>());
      });
    });
  });
}