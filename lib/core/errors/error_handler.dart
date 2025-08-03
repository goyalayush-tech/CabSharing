import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'app_error.dart';

class ErrorHandler {
  static AppError handleError(dynamic error) {
    if (error is AppError) {
      return error;
    }

    if (error is FirebaseAuthException) {
      return _handleFirebaseAuthError(error);
    }

    if (error is FirebaseException) {
      return _handleFirebaseError(error);
    }

    if (error is Exception) {
      return AppError.unknown(error.toString(), error);
    }

    return AppError.unknown('An unexpected error occurred', error);
  }

  static AppError _handleFirebaseAuthError(FirebaseAuthException error) {
    switch (error.code) {
      case 'user-not-found':
        return AppError.auth('No user found with this email address.', error.code, error);
      case 'wrong-password':
        return AppError.auth('Incorrect password.', error.code, error);
      case 'email-already-in-use':
        return AppError.auth('An account already exists with this email address.', error.code, error);
      case 'weak-password':
        return AppError.auth('The password is too weak.', error.code, error);
      case 'invalid-email':
        return AppError.auth('The email address is invalid.', error.code, error);
      case 'user-disabled':
        return AppError.auth('This user account has been disabled.', error.code, error);
      case 'too-many-requests':
        return AppError.auth('Too many requests. Please try again later.', error.code, error);
      case 'operation-not-allowed':
        return AppError.auth('This sign-in method is not allowed.', error.code, error);
      case 'network-request-failed':
        return AppError.network('Network error. Please check your connection.', error);
      default:
        return AppError.auth(error.message ?? 'Authentication failed.', error.code, error);
    }
  }

  static AppError _handleFirebaseError(FirebaseException error) {
    switch (error.code) {
      case 'permission-denied':
        return AppError.permission('You don\'t have permission to perform this action.');
      case 'unavailable':
        return AppError.firebase('Service is currently unavailable. Please try again later.', error.code, error);
      case 'deadline-exceeded':
        return AppError.network('Request timed out. Please try again.', error);
      case 'not-found':
        return AppError.firebase('The requested resource was not found.', error.code, error);
      case 'already-exists':
        return AppError.firebase('The resource already exists.', error.code, error);
      case 'resource-exhausted':
        return AppError.firebase('Resource limit exceeded. Please try again later.', error.code, error);
      case 'failed-precondition':
        return AppError.firebase('Operation failed due to invalid state.', error.code, error);
      case 'aborted':
        return AppError.firebase('Operation was aborted.', error.code, error);
      case 'out-of-range':
        return AppError.validation('Invalid input range.');
      case 'unimplemented':
        return AppError.firebase('This feature is not yet implemented.', error.code, error);
      case 'internal':
        return AppError.firebase('Internal server error. Please try again later.', error.code, error);
      case 'data-loss':
        return AppError.firebase('Data corruption detected.', error.code, error);
      case 'unauthenticated':
        return AppError.auth('Authentication required. Please sign in.', error.code, error);
      default:
        return AppError.firebase(error.message ?? 'Firebase error occurred.', error.code, error);
    }
  }

  static void showErrorSnackBar(BuildContext context, AppError error) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(error.userFriendlyMessage),
        backgroundColor: Colors.red,
        action: error.isRetryable
            ? SnackBarAction(
                label: 'Retry',
                textColor: Colors.white,
                onPressed: () {
                  // Implement retry logic based on context
                },
              )
            : null,
      ),
    );
  }

  static void showErrorDialog(BuildContext context, AppError error) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_getErrorTitle(error.type)),
        content: Text(error.userFriendlyMessage),
        actions: [
          if (error.isRetryable)
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                // Implement retry logic
              },
              child: const Text('Retry'),
            ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  static String _getErrorTitle(ErrorType type) {
    switch (type) {
      case ErrorType.network:
        return 'Connection Error';
      case ErrorType.auth:
        return 'Authentication Error';
      case ErrorType.validation:
        return 'Validation Error';
      case ErrorType.payment:
        return 'Payment Error';
      case ErrorType.location:
        return 'Location Error';
      case ErrorType.permission:
        return 'Permission Required';
      case ErrorType.firebase:
        return 'Service Error';
      case ErrorType.unknown:
        return 'Error';
    }
  }
}