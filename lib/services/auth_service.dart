import 'dart:async';
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../core/errors/app_error.dart';

abstract class IAuthService {
  Future<User?> signInWithGoogle();
  Future<void> signOut();
  Stream<User?> get authStateChanges;
  User? get currentUser;
  bool get isSignedIn;
  Future<void> deleteAccount();
  Future<void> reauthenticate();
}

class AuthService implements IAuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    // For web, you can also specify the clientId here as an alternative
    // clientId: 'YOUR_GOOGLE_CLIENT_ID.apps.googleusercontent.com',
  );

  @override
  User? get currentUser => _auth.currentUser;

  @override
  bool get isSignedIn => _auth.currentUser != null;

  @override
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  @override
  Future<User?> signInWithGoogle() async {
    try {
      // Check network connectivity
      await _checkNetworkConnectivity();

      // Start Google Sign-In flow
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      
      // User cancelled the sign-in
      if (googleUser == null) {
        return null;
      }

      // Get authentication details
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      
      // Validate tokens
      if (googleAuth.accessToken == null || googleAuth.idToken == null) {
        throw AppError.auth(
          'Failed to get authentication tokens from Google',
          'missing-tokens',
        );
      }

      // Create Firebase credential
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Sign in to Firebase
      final UserCredential userCredential = await _auth.signInWithCredential(credential);
      
      if (userCredential.user == null) {
        throw AppError.auth(
          'Failed to create Firebase user',
          'user-creation-failed',
        );
      }

      return userCredential.user;
    } on FirebaseAuthException catch (e) {
      throw _handleFirebaseAuthException(e);
    } on SocketException catch (_) {
      throw AppError.network('No internet connection. Please check your network and try again.');
    } on TimeoutException catch (_) {
      throw AppError.network('Sign-in timed out. Please try again.');
    } catch (e) {
      if (e is AppError) rethrow;
      throw AppError.auth('An unexpected error occurred during sign-in: ${e.toString()}', 'unknown');
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await _checkNetworkConnectivity();
      
      await Future.wait([
        _auth.signOut(),
        _googleSignIn.signOut(),
      ]);
    } on SocketException catch (_) {
      throw AppError.network('No internet connection. Please check your network and try again.');
    } catch (e) {
      throw AppError.auth('Failed to sign out: ${e.toString()}', 'signout-failed');
    }
  }

  @override
  Future<void> deleteAccount() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw AppError.auth('No user is currently signed in', 'no-user');
      }

      await _checkNetworkConnectivity();
      
      // Reauthenticate before deletion for security
      await reauthenticate();
      
      // Delete the user account
      await user.delete();
      
      // Sign out from Google
      await _googleSignIn.signOut();
    } on FirebaseAuthException catch (e) {
      throw _handleFirebaseAuthException(e);
    } on SocketException catch (_) {
      throw AppError.network('No internet connection. Please check your network and try again.');
    } catch (e) {
      if (e is AppError) rethrow;
      throw AppError.auth('Failed to delete account: ${e.toString()}', 'delete-failed');
    }
  }

  @override
  Future<void> reauthenticate() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw AppError.auth('No user is currently signed in', 'no-user');
      }

      await _checkNetworkConnectivity();

      // Get fresh Google credentials
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        throw AppError.auth('Reauthentication cancelled by user', 'cancelled');
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Reauthenticate with Firebase
      await user.reauthenticateWithCredential(credential);
    } on FirebaseAuthException catch (e) {
      throw _handleFirebaseAuthException(e);
    } on SocketException catch (_) {
      throw AppError.network('No internet connection. Please check your network and try again.');
    } catch (e) {
      if (e is AppError) rethrow;
      throw AppError.auth('Reauthentication failed: ${e.toString()}', 'reauth-failed');
    }
  }

  Future<void> _checkNetworkConnectivity() async {
    try {
      final result = await InternetAddress.lookup('google.com');
      if (result.isEmpty || result[0].rawAddress.isEmpty) {
        throw const SocketException('No internet connection');
      }
    } on SocketException {
      throw AppError.network('No internet connection. Please check your network and try again.');
    }
  }

  AppError _handleFirebaseAuthException(FirebaseAuthException e) {
    switch (e.code) {
      case 'account-exists-with-different-credential':
        return AppError.auth(
          'An account already exists with a different sign-in method',
          e.code,
        );
      case 'invalid-credential':
        return AppError.auth(
          'The credential is invalid or has expired',
          e.code,
        );
      case 'operation-not-allowed':
        return AppError.auth(
          'Google sign-in is not enabled for this app',
          e.code,
        );
      case 'user-disabled':
        return AppError.auth(
          'This user account has been disabled',
          e.code,
        );
      case 'user-not-found':
        return AppError.auth(
          'No user found with this credential',
          e.code,
        );
      case 'wrong-password':
        return AppError.auth(
          'Invalid password',
          e.code,
        );
      case 'too-many-requests':
        return AppError.auth(
          'Too many failed attempts. Please try again later',
          e.code,
        );
      case 'network-request-failed':
        return AppError.network(
          'Network error occurred. Please check your connection and try again',
        );
      case 'requires-recent-login':
        return AppError.auth(
          'This operation requires recent authentication. Please sign in again',
          e.code,
        );
      default:
        return AppError.auth(
          e.message ?? 'An authentication error occurred',
          e.code,
        );
    }
  }
}