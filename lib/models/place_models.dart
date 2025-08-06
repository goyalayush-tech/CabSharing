import 'package:hive/hive.dart';
import '../models/ride_group.dart';

part 'place_models.g.dart';

@HiveType(typeId: 2)
class PlaceSearchResult extends HiveObject {
  @HiveField(0)
  final String placeId;

  @HiveField(1)
  final String name;

  @HiveField(2)
  final String address;

  @HiveField(3)
  final LatLng coordinates;

  @HiveField(4)
  final String? description;

  @HiveField(5)
  final List<String> types;

  @HiveField(6)
  final DateTime? cachedAt;

  @HiveField(7)
  final double? relevanceScore;

  PlaceSearchResult({
    required this.placeId,
    required this.name,
    required this.address,
    required this.coordinates,
    this.description,
    this.types = const [],
    this.cachedAt,
    this.relevanceScore,
  });

  factory PlaceSearchResult.fromJson(Map<String, dynamic> json) {
    return PlaceSearchResult(
      placeId: json['place_id'] as String,
      name: json['name'] as String,
      address: json['formatted_address'] as String,
      coordinates: LatLng(
        json['geometry']['location']['lat'] as double,
        json['geometry']['location']['lng'] as double,
      ),
      description: json['description'] as String?,
      types: List<String>.from(json['types'] as List? ?? []),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'place_id': placeId,
      'name': name,
      'formatted_address': address,
      'geometry': {
        'location': {
          'lat': coordinates.latitude,
          'lng': coordinates.longitude,
        },
      },
      'description': description,
      'types': types,
    };
  }
}

@HiveType(typeId: 3)
class PlaceDetails extends HiveObject {
  @HiveField(0)
  final String placeId;

  @HiveField(1)
  final String name;

  @HiveField(2)
  final String address;

  @HiveField(3)
  final LatLng coordinates;

  @HiveField(4)
  final String? phoneNumber;

  @HiveField(5)
  final String? website;

  @HiveField(6)
  final double? rating;

  @HiveField(7)
  final List<String> photos;

  @HiveField(8)
  final Map<String, dynamic> openingHours;

  PlaceDetails({
    required this.placeId,
    required this.name,
    required this.address,
    required this.coordinates,
    this.phoneNumber,
    this.website,
    this.rating,
    this.photos = const [],
    this.openingHours = const {},
  });

  factory PlaceDetails.fromJson(Map<String, dynamic> json) {
    return PlaceDetails(
      placeId: json['place_id'] as String,
      name: json['name'] as String,
      address: json['formatted_address'] as String,
      coordinates: LatLng(
        json['geometry']['location']['lat'] as double,
        json['geometry']['location']['lng'] as double,
      ),
      phoneNumber: json['formatted_phone_number'] as String?,
      website: json['website'] as String?,
      rating: (json['rating'] as num?)?.toDouble(),
      photos: List<String>.from(json['photos']?.map((p) => p['photo_reference']) ?? []),
      openingHours: json['opening_hours'] as Map<String, dynamic>? ?? {},
    );
  }
}

class RouteInfo {
  final List<LatLng> polylinePoints;
  final double distanceKm;
  final Duration estimatedDuration;
  final String textInstructions;
  final double estimatedFare;
  final List<RouteStep> steps;

  RouteInfo({
    required this.polylinePoints,
    required this.distanceKm,
    required this.estimatedDuration,
    required this.textInstructions,
    required this.estimatedFare,
    this.steps = const [],
  });

  RouteInfo copyWith({
    List<LatLng>? polylinePoints,
    double? distanceKm,
    Duration? estimatedDuration,
    String? textInstructions,
    double? estimatedFare,
    List<RouteStep>? steps,
  }) {
    return RouteInfo(
      polylinePoints: polylinePoints ?? this.polylinePoints,
      distanceKm: distanceKm ?? this.distanceKm,
      estimatedDuration: estimatedDuration ?? this.estimatedDuration,
      textInstructions: textInstructions ?? this.textInstructions,
      estimatedFare: estimatedFare ?? this.estimatedFare,
      steps: steps ?? this.steps,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'polylinePoints': polylinePoints.map((p) => {'lat': p.latitude, 'lng': p.longitude}).toList(),
      'distanceKm': distanceKm,
      'estimatedDuration': estimatedDuration.inSeconds,
      'textInstructions': textInstructions,
      'estimatedFare': estimatedFare,
      'steps': steps.map((s) => s.toJson()).toList(),
    };
  }

  factory RouteInfo.fromJson(Map<String, dynamic> json) {
    // Handle both Google Directions API format and our cached format
    if (json.containsKey('routes')) {
      // Google Directions API format
      final route = json['routes'][0];
      final leg = route['legs'][0];
      
      return RouteInfo(
        polylinePoints: _decodePolyline(route['overview_polyline']['points']),
        distanceKm: (leg['distance']['value'] as int) / 1000.0,
        estimatedDuration: Duration(seconds: leg['duration']['value'] as int),
        textInstructions: leg['duration']['text'] as String,
        estimatedFare: 0.0, // Will be calculated separately
        steps: (leg['steps'] as List?)
            ?.map((step) => RouteStep.fromJson(step))
            .toList() ?? [],
      );
    } else {
      // Our cached format
      final polylinePoints = (json['polylinePoints'] as List)
          .map((p) => LatLng(p['lat'] as double, p['lng'] as double))
          .toList();
      
      return RouteInfo(
        polylinePoints: polylinePoints,
        distanceKm: (json['distanceKm'] as num).toDouble(),
        estimatedDuration: Duration(seconds: json['estimatedDuration'] as int),
        textInstructions: json['textInstructions'] as String,
        estimatedFare: (json['estimatedFare'] as num).toDouble(),
        steps: (json['steps'] as List?)
            ?.map((s) => RouteStep.fromJson(s as Map<String, dynamic>))
            .toList() ?? [],
      );
    }
  }

  static List<LatLng> _decodePolyline(String encoded) {
    // Simple polyline decoding - in production use google_polyline_algorithm
    List<LatLng> points = [];
    int index = 0, len = encoded.length;
    int lat = 0, lng = 0;

    while (index < len) {
      int b, shift = 0, result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;

      points.add(LatLng(lat / 1E5, lng / 1E5));
    }
    return points;
  }
}

class RouteStep {
  final String instructions;
  final double distanceKm;
  final Duration duration;
  final LatLng startLocation;
  final LatLng endLocation;

  RouteStep({
    required this.instructions,
    required this.distanceKm,
    required this.duration,
    required this.startLocation,
    required this.endLocation,
  });

  Map<String, dynamic> toJson() {
    return {
      'instructions': instructions,
      'distanceKm': distanceKm,
      'duration': duration.inSeconds,
      'startLocation': {'lat': startLocation.latitude, 'lng': startLocation.longitude},
      'endLocation': {'lat': endLocation.latitude, 'lng': endLocation.longitude},
    };
  }

  factory RouteStep.fromJson(Map<String, dynamic> json) {
    // Handle both Google Directions API format and our cached format
    if (json.containsKey('html_instructions')) {
      // Google Directions API format
      return RouteStep(
        instructions: json['html_instructions'] as String,
        distanceKm: (json['distance']['value'] as int) / 1000.0,
        duration: Duration(seconds: json['duration']['value'] as int),
        startLocation: LatLng(
          json['start_location']['lat'] as double,
          json['start_location']['lng'] as double,
        ),
        endLocation: LatLng(
          json['end_location']['lat'] as double,
          json['end_location']['lng'] as double,
        ),
      );
    } else {
      // Our cached format
      return RouteStep(
        instructions: json['instructions'] as String,
        distanceKm: (json['distanceKm'] as num).toDouble(),
        duration: Duration(seconds: json['duration'] as int),
        startLocation: LatLng(
          json['startLocation']['lat'] as double,
          json['startLocation']['lng'] as double,
        ),
        endLocation: LatLng(
          json['endLocation']['lat'] as double,
          json['endLocation']['lng'] as double,
        ),
      );
    }
  }
}