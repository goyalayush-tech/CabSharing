import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/ride_group.dart';
import '../services/ride_service.dart';
import '../core/errors/app_error.dart';

class RideProvider extends ChangeNotifier {
  final IRideService _rideService;
  StreamSubscription<List<RideGroup>>? _userRidesSubscription;

  List<RideGroup> _userRides = [];
  List<RideGroup> _searchResults = [];
  List<RideGroup> _nearbyRides = [];
  RideGroup? _currentRide;
  
  bool _isLoading = false;
  bool _isCreating = false;
  bool _isSearching = false;
  bool _isLoadingNearby = false;
  AppError? _error;

  RideProvider(this._rideService);

  // Getters
  List<RideGroup> get userRides => _userRides;
  List<RideGroup> get searchResults => _searchResults;
  List<RideGroup> get nearbyRides => _nearbyRides;
  RideGroup? get currentRide => _currentRide;
  bool get isLoading => _isLoading;
  bool get isCreating => _isCreating;
  bool get isSearching => _isSearching;
  bool get isLoadingNearby => _isLoadingNearby;
  AppError? get error => _error;

  // Filtered user rides
  List<RideGroup> get upcomingRides => _userRides
      .where((ride) => ride.scheduledTime.isAfter(DateTime.now()) && 
                      (ride.status == RideStatus.created || ride.status == RideStatus.active))
      .toList();

  List<RideGroup> get completedRides => _userRides
      .where((ride) => ride.status == RideStatus.completed)
      .toList();

  List<RideGroup> get cancelledRides => _userRides
      .where((ride) => ride.status == RideStatus.cancelled)
      .toList();

  Future<void> createRide(RideGroup ride) async {
    _setCreating(true);
    _clearError();

    try {
      final rideId = await _rideService.createRide(ride);
      
      // Add the created ride to user rides
      final createdRide = ride.copyWith(id: rideId);
      _userRides.insert(0, createdRide);
      notifyListeners();
      
    } catch (e) {
      _setError(e is AppError ? e : AppError.unknown('Failed to create ride: $e'));
    } finally {
      _setCreating(false);
    }
  }

  Future<void> loadUserRides(String userId) async {
    _setLoading(true);
    _clearError();

    try {
      _userRides = await _rideService.getUserRides(userId);
      
      // Start listening to real-time updates
      _userRidesSubscription?.cancel();
      _userRidesSubscription = _rideService.getUserRidesStream(userId).listen(
        (rides) {
          _userRides = rides;
          notifyListeners();
        },
        onError: (error) {
          _setError(error is AppError ? error : AppError.unknown('User rides stream error: $error'));
        },
      );
      
    } catch (e) {
      _setError(e is AppError ? e : AppError.unknown('Failed to load user rides: $e'));
    } finally {
      _setLoading(false);
    }
  }

  Future<void> searchRides(Map<String, dynamic> criteria) async {
    _setSearching(true);
    _clearError();

    try {
      _searchResults = await _rideService.searchRides(criteria);
    } catch (e) {
      _setError(e is AppError ? e : AppError.unknown('Failed to search rides: $e'));
    } finally {
      _setSearching(false);
    }
  }

  Future<void> loadNearbyRides(double lat, double lng, {double radiusKm = 50}) async {
    _setLoadingNearby(true);
    _clearError();

    try {
      _nearbyRides = await _rideService.getNearbyRides(lat, lng, radiusKm: radiusKm);
    } catch (e) {
      _setError(e is AppError ? e : AppError.unknown('Failed to load nearby rides: $e'));
    } finally {
      _setLoadingNearby(false);
    }
  }

  Future<void> loadRide(String rideId) async {
    _setLoading(true);
    _clearError();

    try {
      _currentRide = await _rideService.getRide(rideId);
    } catch (e) {
      _setError(e is AppError ? e : AppError.unknown('Failed to load ride: $e'));
    } finally {
      _setLoading(false);
    }
  }

  Future<void> updateRide(RideGroup ride) async {
    _setLoading(true);
    _clearError();

    try {
      await _rideService.updateRide(ride);
      
      // Update local data
      _updateLocalRide(ride);
      
    } catch (e) {
      _setError(e is AppError ? e : AppError.unknown('Failed to update ride: $e'));
    } finally {
      _setLoading(false);
    }
  }

  // Real-time ride stream
  Stream<RideGroup?> getRideStream(String rideId) {
    return _rideService.getRideStream(rideId);
  }

  // Get single ride
  Future<RideGroup?> getRide(String rideId) async {
    try {
      return await _rideService.getRide(rideId);
    } catch (e) {
      _setError(e is AppError ? e : AppError.unknown('Failed to get ride: $e'));
      return null;
    }
  }

  // Join request methods
  Future<void> requestToJoin(String rideId, String userId) async {
    _clearError();

    try {
      await _rideService.requestToJoin(rideId, userId);
      
      // The real-time stream will automatically update the UI
      // No need to manually update local state
      
    } catch (e) {
      _setError(e is AppError ? e : AppError.unknown('Failed to request to join ride: $e'));
      rethrow;
    }
  }

  Future<void> approveJoinRequest(String rideId, String requesterId) async {
    _clearError();

    try {
      await _rideService.approveJoinRequest(rideId, requesterId);
      
      // The real-time stream will automatically update the UI
      // No need to manually update local state
      
    } catch (e) {
      _setError(e is AppError ? e : AppError.unknown('Failed to approve join request: $e'));
      rethrow;
    }
  }

  Future<void> rejectJoinRequest(String rideId, String requesterId, String reason) async {
    _clearError();

    try {
      await _rideService.rejectJoinRequest(rideId, requesterId, reason);
      
      // The real-time stream will automatically update the UI
      // No need to manually update local state
      
    } catch (e) {
      _setError(e is AppError ? e : AppError.unknown('Failed to reject join request: $e'));
      rethrow;
    }
  }

  Future<void> removeMember(String rideId, String memberId) async {
    _clearError();

    try {
      await _rideService.removeMember(rideId, memberId);
      
      // The real-time stream will automatically update the UI
      // No need to manually update local state
      
    } catch (e) {
      _setError(e is AppError ? e : AppError.unknown('Failed to remove member: $e'));
      rethrow;
    }
  }

  Future<void> startRide(String rideId) async {
    _clearError();

    try {
      await _rideService.startRide(rideId);
      
      // Update local state
      _updateRideStatus(rideId, RideStatus.active);
      
    } catch (e) {
      _setError(e is AppError ? e : AppError.unknown('Failed to start ride: $e'));
      rethrow;
    }
  }

  Future<void> completeRide(String rideId) async {
    _clearError();

    try {
      await _rideService.completeRide(rideId);
      
      // Update local state
      _updateRideStatus(rideId, RideStatus.completed);
      
    } catch (e) {
      _setError(e is AppError ? e : AppError.unknown('Failed to complete ride: $e'));
      rethrow;
    }
  }

  Future<void> cancelRide(String rideId, String reason) async {
    _clearError();

    try {
      await _rideService.cancelRide(rideId, reason);
      
      // Update local state
      _updateRideStatus(rideId, RideStatus.cancelled);
      
    } catch (e) {
      _setError(e is AppError ? e : AppError.unknown('Failed to cancel ride: $e'));
      rethrow;
    }
  }

  Future<double> calculateDistance(LatLng from, LatLng to) async {
    try {
      return await _rideService.calculateDistance(from, to);
    } catch (e) {
      _setError(e is AppError ? e : AppError.unknown('Failed to calculate distance: $e'));
      return 0.0;
    }
  }

  Future<double> calculateFare(LatLng from, LatLng to, int passengers) async {
    try {
      return await _rideService.calculateFare(from, to, passengers);
    } catch (e) {
      _setError(e is AppError ? e : AppError.unknown('Failed to calculate fare: $e'));
      return 0.0;
    }
  }

  void clearSearchResults() {
    _searchResults = [];
    notifyListeners();
  }

  void clearNearbyRides() {
    _nearbyRides = [];
    notifyListeners();
  }

  void clearCurrentRide() {
    _currentRide = null;
    notifyListeners();
  }

  void clearError() {
    _clearError();
  }

  void _updateLocalRide(RideGroup updatedRide) {
    // Update in user rides
    final userRideIndex = _userRides.indexWhere((ride) => ride.id == updatedRide.id);
    if (userRideIndex != -1) {
      _userRides[userRideIndex] = updatedRide;
    }
    
    // Update in search results
    final searchIndex = _searchResults.indexWhere((ride) => ride.id == updatedRide.id);
    if (searchIndex != -1) {
      _searchResults[searchIndex] = updatedRide;
    }
    
    // Update in nearby rides
    final nearbyIndex = _nearbyRides.indexWhere((ride) => ride.id == updatedRide.id);
    if (nearbyIndex != -1) {
      _nearbyRides[nearbyIndex] = updatedRide;
    }
    
    // Update current ride
    if (_currentRide?.id == updatedRide.id) {
      _currentRide = updatedRide;
    }
    
    notifyListeners();
  }

  void _updateRideStatus(String rideId, RideStatus status) {
    // Update in user rides
    final userRideIndex = _userRides.indexWhere((ride) => ride.id == rideId);
    if (userRideIndex != -1) {
      _userRides[userRideIndex] = _userRides[userRideIndex].copyWith(status: status);
    }
    
    // Update in search results
    final searchIndex = _searchResults.indexWhere((ride) => ride.id == rideId);
    if (searchIndex != -1) {
      _searchResults[searchIndex] = _searchResults[searchIndex].copyWith(status: status);
    }
    
    // Update in nearby rides
    final nearbyIndex = _nearbyRides.indexWhere((ride) => ride.id == rideId);
    if (nearbyIndex != -1) {
      _nearbyRides[nearbyIndex] = _nearbyRides[nearbyIndex].copyWith(status: status);
    }
    
    // Update current ride
    if (_currentRide?.id == rideId) {
      _currentRide = _currentRide!.copyWith(status: status);
    }
    
    notifyListeners();
  }

  void _setLoading(bool loading) {
    if (_isLoading != loading) {
      _isLoading = loading;
      notifyListeners();
    }
  }

  void _setCreating(bool creating) {
    if (_isCreating != creating) {
      _isCreating = creating;
      notifyListeners();
    }
  }

  void _setSearching(bool searching) {
    if (_isSearching != searching) {
      _isSearching = searching;
      notifyListeners();
    }
  }

  void _setLoadingNearby(bool loading) {
    if (_isLoadingNearby != loading) {
      _isLoadingNearby = loading;
      notifyListeners();
    }
  }

  void _setError(AppError error) {
    _error = error;
    notifyListeners();
  }

  void _clearError() {
    if (_error != null) {
      _error = null;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _userRidesSubscription?.cancel();
    super.dispose();
  }
}