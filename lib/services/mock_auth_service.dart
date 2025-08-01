import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'auth_service.dart';

class MockAuthService implements IAuthService {
  User? _currentUser;
  final StreamController<User?> _authStateController = StreamController<User?>.broadcast();

  MockAuthService() {
    // Emit initial null state to simulate Firebase behavior
    Future.microtask(() => _authStateController.add(null));
  }

  @override
  User? get currentUser => _currentUser;

  @override
  bool get isSignedIn => _currentUser != null;

  @override
  Stream<User?> get authStateChanges => _authStateController.stream;

  @override
  Future<User?> signInWithGoogle() async {
    // Simulate network delay
    await Future.delayed(const Duration(seconds: 1));
    
    // Create a mock user
    _currentUser = MockUser();
    _authStateController.add(_currentUser);
    
    return _currentUser;
  }

  @override
  Future<void> signOut() async {
    await Future.delayed(const Duration(milliseconds: 500));
    _currentUser = null;
    _authStateController.add(null);
  }

  @override
  Future<void> deleteAccount() async {
    await Future.delayed(const Duration(milliseconds: 500));
    _currentUser = null;
    _authStateController.add(null);
  }

  @override
  Future<void> reauthenticate() async {
    await Future.delayed(const Duration(milliseconds: 500));
    // Mock reauthentication success
  }

  void dispose() {
    _authStateController.close();
  }
}

class MockUser implements User {
  @override
  String get uid => 'mock-user-123';

  @override
  String? get displayName => 'Mock User';

  @override
  String? get email => 'mockuser@example.com';

  @override
  String? get photoURL => 'https://via.placeholder.com/150';

  @override
  bool get emailVerified => true;

  @override
  DateTime get createdTime => DateTime.now().subtract(const Duration(days: 30));

  @override
  DateTime get lastSignInTime => DateTime.now();

  // Implement other User interface methods with mock data
  @override
  bool get isAnonymous => false;

  @override
  UserMetadata get metadata => MockUserMetadata();

  @override
  List<UserInfo> get providerData => [];

  @override
  String? get refreshToken => 'mock-refresh-token';

  @override
  String? get tenantId => null;

  @override
  String? get phoneNumber => null;

  @override
  Future<void> delete() async {}

  @override
  Future<String> getIdToken([bool forceRefresh = false]) async {
    return 'mock-id-token';
  }

  @override
  Future<IdTokenResult> getIdTokenResult([bool forceRefresh = false]) async {
    return MockIdTokenResult();
  }

  @override
  Future<UserCredential> linkWithCredential(AuthCredential credential) async {
    throw UnimplementedError();
  }

  @override
  Future<ConfirmationResult> linkWithPhoneNumber(String phoneNumber, [RecaptchaVerifier? verifier]) async {
    throw UnimplementedError();
  }

  @override
  Future<UserCredential> linkWithProvider(AuthProvider provider) async {
    throw UnimplementedError();
  }

  @override
  Future<UserCredential> reauthenticateWithCredential(AuthCredential credential) async {
    throw UnimplementedError();
  }

  @override
  Future<ConfirmationResult> reauthenticateWithPhoneNumber(String phoneNumber, [RecaptchaVerifier? verifier]) async {
    throw UnimplementedError();
  }

  @override
  Future<UserCredential> reauthenticateWithProvider(AuthProvider provider) async {
    throw UnimplementedError();
  }

  @override
  Future<void> reload() async {}

  @override
  Future<void> sendEmailVerification([ActionCodeSettings? actionCodeSettings]) async {}

  @override
  Future<User> unlink(String providerId) async {
    return this;
  }

  @override
  Future<void> updateDisplayName(String? displayName) async {}

  @override
  Future<void> updateEmail(String newEmail) async {}

  @override
  Future<void> updatePassword(String newPassword) async {}

  @override
  Future<void> updatePhoneNumber(PhoneAuthCredential phoneCredential) async {}

  @override
  Future<void> updatePhotoURL(String? photoURL) async {}

  @override
  Future<void> updateProfile({String? displayName, String? photoURL}) async {}

  @override
  Future<void> verifyBeforeUpdateEmail(String newEmail, [ActionCodeSettings? actionCodeSettings]) async {}

  @override
  MultiFactor get multiFactor => throw UnimplementedError();

  @override
  Future<UserCredential> linkWithPopup(AuthProvider provider) async {
    throw UnimplementedError();
  }

  @override
  Future<void> linkWithRedirect(AuthProvider provider) async {
    throw UnimplementedError();
  }

  @override
  Future<UserCredential> reauthenticateWithPopup(AuthProvider provider) async {
    throw UnimplementedError();
  }

  @override
  Future<void> reauthenticateWithRedirect(AuthProvider provider) async {
    throw UnimplementedError();
  }
}

class MockUserMetadata implements UserMetadata {
  @override
  DateTime? get creationTime => DateTime.now().subtract(const Duration(days: 30));

  @override
  DateTime? get lastSignInTime => DateTime.now();
}

class MockIdTokenResult implements IdTokenResult {
  @override
  Map<String, dynamic>? get claims => {'email': 'mockuser@example.com'};

  @override
  DateTime? get expirationTime => DateTime.now().add(const Duration(hours: 1));

  @override
  DateTime? get issuedAtTime => DateTime.now();

  @override
  String? get signInProvider => 'google.com';

  @override
  String? get token => 'mock-id-token';

  @override
  DateTime? get authTime => DateTime.now();

  @override
  String? get signInSecondFactor => null;
}