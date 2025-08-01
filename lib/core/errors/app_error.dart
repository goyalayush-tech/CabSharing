enum ErrorType {
  network,
  auth,
  validation,
  payment,
  location,
  permission,
  firebase,
  unknown,
}

class AppError implements Exception {
  final ErrorType type;
  final String message;
  final String? code;
  final dynamic originalError;
  final StackTrace? stackTrace;

  const AppError({
    required this.type,
    required this.message,
    this.code,
    this.originalError,
    this.stackTrace,
  });

  // Factory constructors for different error types
  factory AppError.network(String message, [dynamic originalError]) {
    return AppError(
      type: ErrorType.network,
      message: message,
      originalError: originalError,
    );
  }

  factory AppError.auth(String message, [String? code, dynamic originalError]) {
    return AppError(
      type: ErrorType.auth,
      message: message,
      code: code,
      originalError: originalError,
    );
  }

  factory AppError.validation(String message) {
    return AppError(
      type: ErrorType.validation,
      message: message,
    );
  }

  factory AppError.payment(String message, [dynamic originalError]) {
    return AppError(
      type: ErrorType.payment,
      message: message,
      originalError: originalError,
    );
  }

  factory AppError.location(String message, [dynamic originalError]) {
    return AppError(
      type: ErrorType.location,
      message: message,
      originalError: originalError,
    );
  }

  factory AppError.permission(String message) {
    return AppError(
      type: ErrorType.permission,
      message: message,
    );
  }

  factory AppError.firebase(String message, [String? code, dynamic originalError]) {
    return AppError(
      type: ErrorType.firebase,
      message: message,
      code: code,
      originalError: originalError,
    );
  }

  factory AppError.unknown(String message, [dynamic originalError]) {
    return AppError(
      type: ErrorType.unknown,
      message: message,
      originalError: originalError,
    );
  }

  @override
  String toString() {
    return 'AppError(type: $type, message: $message, code: $code)';
  }

  String get userFriendlyMessage {
    switch (type) {
      case ErrorType.network:
        return 'Network connection error. Please check your internet connection.';
      case ErrorType.auth:
        return 'Authentication failed. Please try signing in again.';
      case ErrorType.validation:
        return message;
      case ErrorType.payment:
        return 'Payment failed. Please try again or use a different payment method.';
      case ErrorType.location:
        return 'Unable to get your location. Please enable location services.';
      case ErrorType.permission:
        return 'Permission required. Please grant the necessary permissions.';
      case ErrorType.firebase:
        return 'Service temporarily unavailable. Please try again later.';
      case ErrorType.unknown:
        return 'Something went wrong. Please try again.';
    }
  }

  bool get isRetryable {
    switch (type) {
      case ErrorType.network:
      case ErrorType.firebase:
      case ErrorType.unknown:
        return true;
      case ErrorType.auth:
      case ErrorType.validation:
      case ErrorType.payment:
      case ErrorType.location:
      case ErrorType.permission:
        return false;
    }
  }
}