class AppConfig {
  // Firebase Configuration
  static const String firebaseProjectId = 'your-project-id';
  static const String firebaseApiKey = 'your-api-key';
  static const String firebaseAuthDomain = 'your-project-id.firebaseapp.com';
  static const String firebaseStorageBucket = 'your-project-id.appspot.com';
  
  // Google Sign-In Configuration
  static const String googleClientId = 'YOUR_GOOGLE_CLIENT_ID.apps.googleusercontent.com';
  
  // Development mode flag
  static const bool isDevelopment = true;
  
  // Mock authentication for development
  static const bool useMockAuth = isDevelopment;
}