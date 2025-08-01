import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

abstract class ILocationService {
  Future<Position> getCurrentLocation();
  Stream<Position> getLocationStream();
  Future<List<Placemark>> getAddressFromCoordinates(double lat, double lng);
  Future<bool> requestLocationPermission();
}

class LocationService implements ILocationService {
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
      desiredAccuracy: LocationAccuracy.high,
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
}