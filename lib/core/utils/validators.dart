class Validators {
  static String? validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'Email is required';
    }
    
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(value)) {
      return 'Please enter a valid email address';
    }
    
    return null;
  }

  static String? validatePhoneNumber(String? value) {
    if (value == null || value.isEmpty) {
      return null; // Phone number is optional
    }
    
    final phoneRegex = RegExp(r'^\+?[\d\s\-\(\)]{10,}$');
    if (!phoneRegex.hasMatch(value)) {
      return 'Please enter a valid phone number';
    }
    
    return null;
  }

  static String? validateRequired(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName is required';
    }
    return null;
  }

  static String? validateFare(String? value) {
    if (value == null || value.isEmpty) {
      return 'Fare is required';
    }
    
    final fare = double.tryParse(value);
    if (fare == null) {
      return 'Please enter a valid number';
    }
    
    if (fare <= 0) {
      return 'Fare must be greater than 0';
    }
    
    if (fare > 10000) {
      return 'Fare seems too high';
    }
    
    return null;
  }

  static String? validateSeats(int? value) {
    if (value == null) {
      return 'Number of seats is required';
    }
    
    if (value < 1) {
      return 'At least 1 seat is required';
    }
    
    if (value > 8) {
      return 'Maximum 8 seats allowed';
    }
    
    return null;
  }

  static String? validateRating(int? value) {
    if (value == null) {
      return 'Rating is required';
    }
    
    if (value < 1 || value > 5) {
      return 'Rating must be between 1 and 5';
    }
    
    return null;
  }

  static String? validateName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Name is required';
    }
    
    if (value.trim().length < 2) {
      return 'Name must be at least 2 characters';
    }
    
    if (value.trim().length > 50) {
      return 'Name must be less than 50 characters';
    }
    
    return null;
  }

  static String? validateBio(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null; // Bio is optional
    }
    
    if (value.trim().length > 500) {
      return 'Bio must be less than 500 characters';
    }
    
    return null;
  }

  static String? validateNotes(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null; // Notes are optional
    }
    
    if (value.trim().length > 500) {
      return 'Notes must be less than 500 characters';
    }
    
    return null;
  }

  static bool isValidDateTime(DateTime? dateTime) {
    if (dateTime == null) return false;
    
    final now = DateTime.now();
    return dateTime.isAfter(now);
  }

  static String? validateDateTime(DateTime? dateTime) {
    if (dateTime == null) {
      return 'Date and time are required';
    }
    
    if (!isValidDateTime(dateTime)) {
      return 'Please select a future date and time';
    }
    
    return null;
  }

  static String? validateLocation(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Location is required';
    }
    
    if (value.trim().length < 3) {
      return 'Location must be at least 3 characters';
    }
    
    return null;
  }
}