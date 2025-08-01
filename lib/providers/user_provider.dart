import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/user_profile.dart';
import '../models/rating.dart';
import '../services/user_service.dart';
import '../core/errors/app_error.dart';

class UserProvider extends ChangeNotifier {
  final IUserService _userService;
  StreamSubscription<UserProfile?>? _profileSubscription;

  UserProfile? _currentUserProfile;
  List<Rating> _userRatings = [];
  bool _isLoading = false;
  bool _isUpdating = false;
  bool _isUploadingImage = false;
  AppError? _error;

  UserProvider(this._userService);

  // Getters
  UserProfile? get currentUserProfile => _currentUserProfile;
  List<Rating> get userRatings => _userRatings;
  bool get isLoading => _isLoading;
  bool get isUpdating => _isUpdating;
  bool get isUploadingImage => _isUploadingImage;
  AppError? get error => _error;
  bool get hasProfile => _currentUserProfile != null;
  bool get isProfileComplete => _currentUserProfile?.isProfileComplete ?? false;

  Future<void> loadUserProfile(String userId) async {
    if (userId.isEmpty) return;

    _setLoading(true);
    _clearError();

    try {
      _currentUserProfile = await _userService.getUserProfile(userId);
      
      // Start listening to profile changes
      _profileSubscription?.cancel();
      _profileSubscription = _userService.getUserProfileStream(userId).listen(
        (profile) {
          _currentUserProfile = profile;
          notifyListeners();
        },
        onError: (error) {
          _setError(error is AppError ? error : AppError.unknown('Profile stream error: $error'));
        },
      );

      // Load user ratings
      if (_currentUserProfile != null) {
        await _loadUserRatings(userId);
      }
    } catch (e) {
      _setError(e is AppError ? e : AppError.unknown('Failed to load profile: $e'));
    } finally {
      _setLoading(false);
    }
  }

  Future<void> createProfile(UserProfile profile) async {
    _setLoading(true);
    _clearError();

    try {
      _currentUserProfile = await _userService.createProfile(profile);
    } catch (e) {
      _setError(e is AppError ? e : AppError.unknown('Failed to create profile: $e'));
    } finally {
      _setLoading(false);
    }
  }

  Future<void> updateProfile(UserProfile profile) async {
    _setUpdating(true);
    _clearError();

    try {
      _currentUserProfile = await _userService.updateProfile(profile);
    } catch (e) {
      _setError(e is AppError ? e : AppError.unknown('Failed to update profile: $e'));
    } finally {
      _setUpdating(false);
    }
  }

  Future<void> createProfileFromFirebaseUser(dynamic firebaseUser) async {
    _setLoading(true);
    _clearError();

    try {
      // Check if profile already exists
      final exists = await _userService.profileExists(firebaseUser.uid);
      
      if (exists) {
        // Load existing profile
        await loadUserProfile(firebaseUser.uid);
      } else {
        // Create new profile
        _currentUserProfile = await _userService.createProfileFromFirebaseUser(firebaseUser);
      }
    } catch (e) {
      _setError(e is AppError ? e : AppError.unknown('Failed to setup profile: $e'));
    } finally {
      _setLoading(false);
    }
  }

  Future<void> uploadProfileImage(String userId, dynamic imageFile) async {
    _setUploadingImage(true);
    _clearError();

    try {
      final imageUrl = await _userService.uploadProfileImage(userId, imageFile);
      
      if (imageUrl != null && _currentUserProfile != null) {
        final updatedProfile = _currentUserProfile!.copyWith(
          profileImageUrl: imageUrl,
          updatedAt: DateTime.now(),
        );
        
        await updateProfile(updatedProfile);
      }
    } catch (e) {
      _setError(e is AppError ? e : AppError.unknown('Failed to upload image: $e'));
    } finally {
      _setUploadingImage(false);
    }
  }

  Future<void> deleteProfileImage(String userId) async {
    _setUpdating(true);
    _clearError();

    try {
      await _userService.deleteProfileImage(userId);
      
      if (_currentUserProfile != null) {
        final updatedProfile = _currentUserProfile!.copyWith(
          profileImageUrl: null,
          updatedAt: DateTime.now(),
        );
        
        await updateProfile(updatedProfile);
      }
    } catch (e) {
      _setError(e is AppError ? e : AppError.unknown('Failed to delete image: $e'));
    } finally {
      _setUpdating(false);
    }
  }

  Future<void> refreshProfile() async {
    if (_currentUserProfile != null) {
      await loadUserProfile(_currentUserProfile!.id);
    }
  }

  Future<void> _loadUserRatings(String userId) async {
    try {
      _userRatings = await _userService.getUserRatings(userId);
      notifyListeners();
    } catch (e) {
      // Don't set error for ratings as it's not critical
      debugPrint('Failed to load user ratings: $e');
    }
  }

  Future<List<UserProfile>> searchUsers(String query) async {
    try {
      return await _userService.searchUsers(query);
    } catch (e) {
      _setError(e is AppError ? e : AppError.unknown('Failed to search users: $e'));
      return [];
    }
  }

  void clearError() {
    _clearError();
  }

  void clearProfile() {
    _profileSubscription?.cancel();
    _currentUserProfile = null;
    _userRatings = [];
    _clearError();
    notifyListeners();
  }

  void _setLoading(bool loading) {
    if (_isLoading != loading) {
      _isLoading = loading;
      notifyListeners();
    }
  }

  void _setUpdating(bool updating) {
    if (_isUpdating != updating) {
      _isUpdating = updating;
      notifyListeners();
    }
  }

  void _setUploadingImage(bool uploading) {
    if (_isUploadingImage != uploading) {
      _isUploadingImage = uploading;
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
    _profileSubscription?.cancel();
    super.dispose();
  }
}