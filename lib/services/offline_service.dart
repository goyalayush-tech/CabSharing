import 'dart:async';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

/// Service for managing offline/online state and connectivity
abstract class IOfflineService {
  /// Current connectivity status
  bool get isOnline;
  
  /// Stream of connectivity changes
  Stream<bool> get connectivityStream;
  
  /// Initialize the service
  Future<void> initialize();
  
  /// Dispose resources
  void dispose();
  
  /// Check if device has internet connectivity
  Future<bool> checkConnectivity();
  
  /// Force refresh connectivity status
  Future<void> refreshConnectivity();
}

class OfflineService extends ChangeNotifier implements IOfflineService {
  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  final StreamController<bool> _connectivityController = StreamController<bool>.broadcast();
  
  bool _isOnline = true;
  bool _isInitialized = false;

  @override
  bool get isOnline => _isOnline;

  @override
  Stream<bool> get connectivityStream => _connectivityController.stream;

  @override
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      // Check initial connectivity
      await refreshConnectivity();
      
      // Listen for connectivity changes
      _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
        _onConnectivityChanged,
        onError: (error) {
          debugPrint('Connectivity stream error: $error');
        },
      );
      
      _isInitialized = true;
    } catch (e) {
      debugPrint('Failed to initialize offline service: $e');
      // Assume online if initialization fails
      _updateConnectivityStatus(true);
    }
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    _connectivityController.close();
    super.dispose();
  }

  @override
  Future<bool> checkConnectivity() async {
    try {
      // First check connectivity result
      final connectivityResults = await _connectivity.checkConnectivity();
      
      // If no connectivity, definitely offline
      if (connectivityResults.contains(ConnectivityResult.none)) {
        return false;
      }
      
      // If we have connectivity, verify with actual internet access
      return await _verifyInternetAccess();
    } catch (e) {
      debugPrint('Error checking connectivity: $e');
      return false;
    }
  }

  @override
  Future<void> refreshConnectivity() async {
    final isConnected = await checkConnectivity();
    _updateConnectivityStatus(isConnected);
  }

  /// Handle connectivity changes from the stream
  void _onConnectivityChanged(List<ConnectivityResult> results) async {
    try {
      // If no connectivity, immediately set offline
      if (results.contains(ConnectivityResult.none)) {
        _updateConnectivityStatus(false);
        return;
      }
      
      // If we have connectivity, verify internet access
      final hasInternet = await _verifyInternetAccess();
      _updateConnectivityStatus(hasInternet);
    } catch (e) {
      debugPrint('Error handling connectivity change: $e');
      // On error, assume offline to be safe
      _updateConnectivityStatus(false);
    }
  }

  /// Verify actual internet access by attempting to reach a reliable host
  Future<bool> _verifyInternetAccess() async {
    try {
      final result = await InternetAddress.lookup('google.com')
          .timeout(const Duration(seconds: 5));
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (e) {
      // Try alternative hosts if Google is blocked
      try {
        final result = await InternetAddress.lookup('cloudflare.com')
            .timeout(const Duration(seconds: 5));
        return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
      } catch (e) {
        return false;
      }
    }
  }

  /// Update connectivity status and notify listeners
  void _updateConnectivityStatus(bool isConnected) {
    if (_isOnline != isConnected) {
      _isOnline = isConnected;
      _connectivityController.add(_isOnline);
      notifyListeners();
      
      debugPrint('Connectivity changed: ${_isOnline ? 'ONLINE' : 'OFFLINE'}');
    }
  }
}

/// Mock implementation for testing
class MockOfflineService implements IOfflineService {
  bool _isOnline = true;
  final StreamController<bool> _connectivityController = StreamController<bool>.broadcast();

  @override
  bool get isOnline => _isOnline;

  @override
  Stream<bool> get connectivityStream => _connectivityController.stream;

  @override
  Future<void> initialize() async {
    await Future.delayed(const Duration(milliseconds: 10));
  }

  @override
  void dispose() {
    _connectivityController.close();
  }

  @override
  Future<bool> checkConnectivity() async {
    await Future.delayed(const Duration(milliseconds: 50));
    return _isOnline;
  }

  @override
  Future<void> refreshConnectivity() async {
    await Future.delayed(const Duration(milliseconds: 50));
    _connectivityController.add(_isOnline);
  }

  /// Test helper to simulate connectivity changes
  void setConnectivity(bool isOnline) {
    _isOnline = isOnline;
    _connectivityController.add(_isOnline);
  }
}