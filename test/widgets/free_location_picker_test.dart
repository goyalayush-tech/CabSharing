import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:provider/provider.dart';
import 'package:ridelink/widgets/free_location_picker.dart';
import 'package:ridelink/models/ride_group.dart';
import 'package:ridelink/models/place_models.dart';
import 'package:ridelink/services/free_geocoding_service.dart';

import 'free_location_picker_test.mocks.dart';

@GenerateMocks([IFreeGeocodingService])
void main() {
  group('FreeLocationPicker', () {
    late MockIFreeGeocodingService mockGeocodingService;

    setUp(() {
      mockGeocodingService = MockIFreeGeocodingService();
    });

    Widget createTestWidget({
      String title = 'Select Location',
      LatLng? initialLocation,
      String? initialAddress,
      bool allowSearch = true,
    }) {
      return MaterialApp(
        home: Provider<IFreeGeocodingService>.value(
          value: mockGeocodingService,
          child: FreeLocationPicker(
            title: title,
            initialLocation: initialLocation,
            initialAddress: initialAddress,
            allowSearch: allowSearch,
          ),
        ),
      );
    }

    testWidgets('should render with default configuration', (tester) async {
      await tester.pumpWidget(createTestWidget());

      expect(find.text('Select Location'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Search for a location or tap on the map to select'), findsOneWidget);
    });

    testWidgets('should display initial location when provided', (tester) async {
      final initialLocation = LatLng(37.7749, -122.4194);
      const initialAddress = 'San Francisco, CA';

      await tester.pumpWidget(createTestWidget(
        initialLocation: initialLocation,
        initialAddress: initialAddress,
      ));

      expect(find.text('Selected Location'), findsOneWidget);
      expect(find.text('CONFIRM'), findsOneWidget);
    });

    testWidgets('should show search results when searching', (tester) async {
      final searchResults = [
        PlaceSearchResult(
          placeId: '1',
          name: 'Test Location 1',
          address: '123 Test St, Test City',
          coordinates: LatLng(37.7749, -122.4194),
        ),
      ];

      when(mockGeocodingService.searchPlaces(any, location: anyNamed('location')))
          .thenAnswer((_) async => searchResults);

      await tester.pumpWidget(createTestWidget());

      // Enter search text
      await tester.enterText(find.byType(TextField), 'test location');
      await tester.pump(const Duration(milliseconds: 600)); // Wait for debounce
      await tester.pump(); // Pump again for async operation

      expect(find.text('Test Location 1'), findsOneWidget);
      expect(find.text('123 Test St, Test City'), findsOneWidget);
    });

    testWidgets('should handle search errors gracefully', (tester) async {
      when(mockGeocodingService.searchPlaces(any, location: anyNamed('location')))
          .thenThrow(Exception('Search failed'));

      await tester.pumpWidget(createTestWidget());

      await tester.enterText(find.byType(TextField), 'test');
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump();

      expect(find.text('Search failed: Exception: Search failed'), findsOneWidget);
    });

    testWidgets('should hide search bar when allowSearch is false', (tester) async {
      await tester.pumpWidget(createTestWidget(allowSearch: false));

      expect(find.byType(TextField), findsNothing);
    });

    testWidgets('should handle reverse geocoding for coordinates', (tester) async {
      final placeResult = PlaceSearchResult(
        placeId: '1',
        name: 'Test Place',
        address: 'Loaded Address',
        coordinates: LatLng(37.7749, -122.4194),
      );

      when(mockGeocodingService.reverseGeocode(any))
          .thenAnswer((_) async => placeResult);

      await tester.pumpWidget(createTestWidget(
        initialLocation: LatLng(37.7749, -122.4194),
      ));

      await tester.pump(); // Allow async operation to complete
      await tester.pump(); // Complete the async operation
      
      expect(find.text('Loaded Address'), findsOneWidget);
    });

    testWidgets('should handle reverse geocoding errors', (tester) async {
      when(mockGeocodingService.reverseGeocode(any))
          .thenThrow(Exception('Reverse geocoding failed'));

      await tester.pumpWidget(createTestWidget(
        initialLocation: LatLng(37.7749, -122.4194),
      ));

      await tester.pump(); // Allow async operation to complete
      await tester.pump(); // Complete the error handling

      // Should show coordinates as fallback
      expect(find.textContaining('37.7749'), findsOneWidget);
    });
  });
}