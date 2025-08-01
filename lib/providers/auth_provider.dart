import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import '../core/errors/app_error.dart';

enum AuthState {
  initial,
  authenticated,
  unauthenticated,
  loading,
}

class AuthProvider extends ChangeNotifier {
  final IAuthService _authService;
  StreamSubscription<User?>? _authStateSubscription;
  
  AuthState _state = AuthState.initial;
  User? _user;
  AppError? _error;
  bool _isLoading = false;

  AuthProvider(this._authService) {
    _initializeAuthState();
  }

  // Getters
  AuthState get state => _state;
  User? get user => _user;
  AppError? get error => _error;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _state == AuthState.authenticated && _user != null;
  bool get isUnauthenticated => _state == AuthState.unauthenticated;

  void _initializeAuthState() {
    _authStateSubscription = _authService.authStateChanges.listen(
      (User? user) {
        _user = user;
        if (user != null) {
          _setState(AuthState.authenticated);
        } else {
          _setState(AuthState.unauthenticated);
        }
        _clearError();
      },
      onError: (error) {
        _setError(AppError.auth('Authentication state error: $error', 'state-error'));
      },
    );
  }

  Future<void> signInWithGoogle() async {
    _setLoading(true);
    _clearError();

    try {
      final user = await _authService.signInWithGoogle();
      if (user != null) {
        _user = user;
        _setState(AuthState.authenticated);
      } else {
        // User cancelled sign-in
        _setState(AuthState.unauthenticated);
      }
    } catch (e) {
      _setError(e is AppError ? e : AppError.auth('Sign-in failed: $e', 'signin-failed'));
      _setState(AuthState.unauthenticated);
    } finally {
      _setLoading(false);
    }
  }

  Future<void> signOut() async {
    _setLoading(true);
    _clearError();

    try {
      await _authService.signOut();
      _user = null;
      _setState(AuthState.unauthenticated);
    } catch (e) {
      _setError(e is AppError ? e : AppError.auth('Sign-out failed: $e', 'signout-failed'));
    } finally {
      _setLoading(false);
    }
  }

  Future<void> deleteAccount() async {
    _setLoading(true);
    _clearError();

    try {
      await _authService.deleteAccount();
      _user = null;
      _setState(AuthState.unauthenticated);
    } catch (e) {
      _setError(e is AppError ? e : AppError.auth('Account deletion failed: $e', 'delete-failed'));
    } finally {
      _setLoading(false);
    }
  }

  Future<void> reauthenticate() async {
    _setLoading(true);
    _clearError();

    try {
      await _authService.reauthenticate();
      // Refresh user data after reauthentication
      _user = _authService.currentUser;
      notifyListeners();
    } catch (e) {
      _setError(e is AppError ? e : AppError.auth('Reauthentication failed: $e', 'reauth-failed'));
    } finally {
      _setLoading(false);
    }
  }

  void clearError() {
    _clearError();
  }

  void _setState(AuthState newState) {
    if (_state != newState) {
      _state = newState;
      notifyListeners();
    }
  }

  void _setLoading(bool loading) {
    if (_isLoading != loading) {
      _isLoading = loading;
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
    _authStateSubscription?.cancel();
    super.dispose();
  }
}