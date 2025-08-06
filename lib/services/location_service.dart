import 'dart:convert';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:http/http.dart' as http;
import '../models/ride_group.dart';
import '../models/place_models.dart';
import '../core/constants/app_constants.dart';

abstract class ILocationService {
  Future<Position> getCurrentLocation();
  Stream<Position> getLocationStream();
  Future<List<Placemark>> getAddressFromCoordinates(double lat, double lng);
  Future<bool> requestLocationPermission();
  Future<List<PlaceSearchResult>> searchPlaces(String query, {LatLng? location, double? radius});
  Future<PlaceDetails> getPlaceDetails(String placeId);
  Future<List<PlaceSearchResult>> getNearbyPlaces(LatLng location, {double radius = 5000, String? type});
}

class LocationService implements ILocationService {
  static const String _placesBaseUrl = 'https://maps.googleapis.com/maps/api/place';

  @override
  Future<Position> getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('Location services are disabled.');
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('Location permissions are denied');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception('Location permissions are permanently denied');
    }

    return await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
      ),
    );
  }

  @override
  Stream<Position> getLocationStream() {
    return Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      ),
    );
  }

  @override
  Future<List<Placemark>> getAddressFromCoordinates(double lat, double lng) async {
    try {
      return await placemarkFromCoordinates(lat, lng);
    } catch (e) {
      throw Exception('Failed to get address from coordinates: $e');
    }
  }

  @override
  Future<bool> requestLocationPermission() async {
    LocationPermission permission = await Geolocator.checkPermission();
    
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    
    return permission == LocationPermission.whileInUse ||
           permission == LocationPermission.always;
  }

  @override
  Future<List<PlaceSearchResult>> searchPlaces(
    String query, {
    LatLng? location,
    double? radius,
  }) async {
    try {
      String locationParam = '';
      if (location != null) {
        locationParam = '&location=${location.latitude},${location.longitude}';
        if (radius != null) {
          locationParam += '&radius=${radius.round()}';
        }
      }

      final url = Uri.parse(
        '$_placesBaseUrl/textsearch/json?'
        'query=${Uri.encodeComponent(query)}'
        '$locationParam&'
        'key=${AppConstants.googleMapsApiKey}'
      );

      final response = await http.get(url);
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data['status'] == 'OK') {
          final results = data['results'] as List;
          return results
              .map((result) => PlaceSearchResult.fromJson(result))
              .toList();
        } else {
          throw Exception('Places search failed: ${data['status']}');
        }
      } else {
        throw Exception('HTTP error: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to search places: $e');
    }
  }

  @override
  Future<PlaceDetails> getPlaceDetails(String placeId) async {
    try {
      final url = Uri.parse(
        '$_placesBaseUrl/details/json?'
        'place_id=$placeId&'
        'fields=place_id,name,formatted_address,geometry,formatted_phone_number,website,rating,photos,opening_hours&'
        'key=${AppConstants.googleMapsApiKey}'
      );

      final response = await http.get(url);
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data['status'] == 'OK') {
          return PlaceDetails.fromJson(data['result']);
        } else {
          throw Exception('Place details failed: ${data['status']}');
        }
      } else {
        throw Exception('HTTP error: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to get place details: $e');
    }
  }

  @override
  Future<List<PlaceSearchResult>> getNearbyPlaces(
    LatLng location, {
    double radius = 5000,
    String? type,
  }) async {
    try {
      String typeParam = type != null ? '&type=$type' : '';
      
      final url = Uri.parse(
        '$_placesBaseUrl/nearbysearch/json?'
        'location=${location.latitude},${location.longitude}&'
        'radius=${radius.round()}'
        '$typeParam&'
        'key=${AppConstants.googleMapsApiKey}'
      );

      final response = await http.get(url);
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data['status'] == 'OK') {
          final results = data['results'] as List;
          return results
              .map((result) => PlaceSearchResult.fromJson(result))
              .toList();
        } else {
          throw Exception('Nearby search failed: ${data['status']}');
        }
      } else {
        throw Exception('HTTP error: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to get nearby places: $e');
    }
  }
}

// Mock implementation for development/testing
class MockLocationService implements ILocationService {
  @override
  Future<Position> getCurrentLocation() async {
    await Future.delayed(const Duration(milliseconds: 500));
    return Position(
      latitude: 37.7749,
      longitude: -122.4194,
      timestamp: DateTime.now(),
      accuracy: 5.0,
      altitude: 0.0,
      altitudeAccuracy: 0.0,
      heading: 0.0,
      headingAccuracy: 0.0,
      speed: 0.0,
      speedAccuracy: 0.0,
    );
  }

  @override
  Stream<Position> getLocationStream() {
    return Stream.periodic(const Duration(seconds: 5), (count) {
      return Position(
        latitude: 37.7749 + (count * 0.001),
        longitude: -122.4194 + (count * 0.001),
        timestamp: DateTime.now(),
        accuracy: 5.0,
        altitude: 0.0,
        altitudeAccuracy: 0.0,
        heading: 0.0,
        headingAccuracy: 0.0,
        speed: 0.0,
        speedAccuracy: 0.0,
      );
    });
  }

  @override
  Future<List<Placemark>> getAddressFromCoordinates(double lat, double lng) async {
    await Future.delayed(const Duration(milliseconds: 300));
    return [
      Placemark(
        street: '123 Mock Street',
        locality: 'Mock City',
        administrativeArea: 'Mock State',
        country: 'Mock Country',
        postalCode: '12345',
      ),
    ];
  }

  @override
  Future<bool> requestLocationPermission() async {
    await Future.delayed(const Duration(milliseconds: 100));
    return true;
  }

  @override
  Future<List<PlaceSearchResult>> searchPlaces(
    String query, {
    LatLng? location,
    double? radius,
  }) async {
    await Future.delayed(const Duration(milliseconds: 500));
    
    return List.generate(5, (index) {
      final baseCoords = location ?? LatLng(37.7749, -122.4194);
      return PlaceSearchResult(
        placeId: 'mock_place_${index}_${query.hashCode}',
        name: '$query - Location ${index + 1}',
        address: '$query Street ${index + 1}, Mock City, Mock Country',
        coordinates: LatLng(
          baseCoords.latitude + (index * 0.001),
          baseCoords.longitude + (index * 0.001),
        ),
        description: 'Mock description for $query location ${index + 1}',
        types: ['establishment', 'point_of_interest'],
      );
    });
  }

  @override
  Future<PlaceDetails> getPlaceDetails(String placeId) async {
    await Future.delayed(const Duration(milliseconds: 300));
    
    return PlaceDetails(
      placeId: placeId,
      name: 'Mock Place Details',
      address: '123 Mock Street, Mock City, Mock Country',
      coordinates: LatLng(37.7749, -122.4194),
      phoneNumber: '+1-555-0123',
      website: 'https://example.com',
      rating: 4.5,
      photos: ['mock_photo_1', 'mock_photo_2'],
      openingHours: {
        'open_now': true,
        'weekday_text': ['Monday: 9:00 AM – 5:00 PM', 'Tuesday: 9:00 AM – 5:00 PM'],
      },
    );
  }

  @override
  Future<List<PlaceSearchResult>> getNearbyPlaces(
    LatLng location, {
    double radius = 5000,
    String? type,
  }) async {
    await Future.delayed(const Duration(milliseconds: 400));
    
    return List.generate(3, (index) {
      return PlaceSearchResult(
        placeId: 'nearby_place_${index}_${location.hashCode}',
        name: '${type ?? 'Place'} ${index + 1}',
        address: 'Nearby Street ${index + 1}, Mock City, Mock Country',
        coordinates: LatLng(
          location.latitude + (index * 0.002),
          location.longitude + (index * 0.002),
        ),
        description: 'Nearby ${type ?? 'place'} ${index + 1}',
        types: [type ?? 'establishment', 'point_of_interest'],
      );
    });
  }
}