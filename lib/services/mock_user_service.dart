import 'dart:async';
import 'dart:math';
import '../models/user_profile.dart';
import '../models/rating.dart';
import '../services/user_service.dart';

class MockUserService implements IUserService {
  final Map<String, UserProfile> _profiles = {};
  final Map<String, List<Rating>> _userRatings = {};
  final StreamController<UserProfile?> _profileStreamController = StreamController<UserProfile?>.broadcast();

  MockUserService() {
    _initializeMockData();
  }

  void _initializeMockData() {
    // Create some mock users
    final mockUsers = [
      UserProfile(
        id: 'mock-user-123',
        name: 'John Doe',
        email: 'john.doe@example.com',
        bio: 'Love traveling and meeting new people!',
        phoneNumber: '+1234567890',
        averageRating: 4.5,
        totalRides: 15,
        isVerified: true,
        createdAt: DateTime.now().subtract(const Duration(days: 30)),
        updatedAt: DateTime.now(),
      ),
      UserProfile(
        id: 'user-456',
        name: 'Jane Smith',
        email: 'jane.smith@example.com',
        bio: 'Eco-friendly commuter',
        phoneNumber: '+1987654321',
        averageRating: 4.8,
        totalRides: 22,
        isVerified: true,
        createdAt: DateTime.now().subtract(const Duration(days: 45)),
        updatedAt: DateTime.now(),
      ),
      UserProfile(
        id: 'user-789',
        name: 'Mike Johnson',
        email: 'mike.johnson@example.com',
        averageRating: 4.2,
        totalRides: 8,
        createdAt: DateTime.now().subtract(const Duration(days: 15)),
        updatedAt: DateTime.now(),
      ),
    ];

    for (final user in mockUsers) {
      _profiles[user.id] = user;
      _generateMockRatings(user.id);
    }
  }

  void _generateMockRatings(String userId) {
    final random = Random();
    final ratings = <Rating>[];
    
    for (int i = 0; i < random.nextInt(10) + 5; i++) {
      ratings.add(Rating(
        id: 'rating-${userId}-$i',
        rideId: 'ride-$i',
        raterId: 'rater-$i',
        ratedUserId: userId,
        stars: random.nextInt(3) + 3, // 3-5 stars
        comment: _getRandomComment(),
        createdAt: DateTime.now().subtract(Duration(days: random.nextInt(30))),
      ));
    }
    
    _userRatings[userId] = ratings;
  }

  String _getRandomComment() {
    final comments = [
      'Great ride companion!',
      'Very punctual and friendly',
      'Smooth ride, would recommend',
      'Nice conversation during the trip',
      'Professional and courteous',
      'Made the journey enjoyable',
    ];
    return comments[Random().nextInt(comments.length)];
  }

  @override
  Future<UserProfile> createProfile(UserProfile profile) async {
    await Future.delayed(const Duration(milliseconds: 500));
    
    if (_profiles.containsKey(profile.id)) {
      throw Exception('User profile already exists');
    }
    
    _profiles[profile.id] = profile;
    _profileStreamController.add(profile);
    return profile;
  }

  @override
  Future<UserProfile> updateProfile(UserProfile profile) async {
    await Future.delayed(const Duration(milliseconds: 300));
    
    if (!_profiles.containsKey(profile.id)) {
      throw Exception('User profile does not exist');
    }
    
    final updatedProfile = profile.copyWith(updatedAt: DateTime.now());
    _profiles[profile.id] = updatedProfile;
    _profileStreamController.add(updatedProfile);
    return updatedProfile;
  }

  @override
  Future<UserProfile?> getUserProfile(String userId) async {
    await Future.delayed(const Duration(milliseconds: 200));
    return _profiles[userId];
  }

  @override
  Stream<UserProfile?> getUserProfileStream(String userId) {
    return Stream.periodic(const Duration(seconds: 1), (_) => _profiles[userId])
        .distinct();
  }

  @override
  Future<double> getUserRating(String userId) async {
    await Future.delayed(const Duration(milliseconds: 150));
    
    final ratings = _userRatings[userId];
    if (ratings == null || ratings.isEmpty) return 0.0;
    
    final totalStars = ratings.map((r) => r.stars).reduce((a, b) => a + b);
    return totalStars / ratings.length;
  }

  @override
  Future<List<Rating>> getUserRatings(String userId) async {
    await Future.delayed(const Duration(milliseconds: 200));
    return _userRatings[userId] ?? [];
  }

  @override
  Future<String?> uploadProfileImage(String userId, dynamic imageFile) async {
    await Future.delayed(const Duration(seconds: 2));
    // Return a mock image URL
    return 'https://via.placeholder.com/150/0000FF/FFFFFF?text=${userId.substring(0, 2).toUpperCase()}';
  }

  @override
  Future<void> deleteProfileImage(String userId) async {
    await Future.delayed(const Duration(milliseconds: 500));
    
    // Update the profile to remove the image URL
    final profile = _profiles[userId];
    if (profile != null) {
      final updatedProfile = profile.copyWith(
        profileImageUrl: null,
        updatedAt: DateTime.now(),
      );
      _profiles[userId] = updatedProfile;
      _profileStreamController.add(updatedProfile);
    }
  }

  @override
  Future<UserProfile> createProfileFromFirebaseUser(dynamic firebaseUser) async {
    await Future.delayed(const Duration(milliseconds: 300));
    
    final now = DateTime.now();
    
    // Handle both real Firebase User and mock objects
    String uid;
    String name;
    String email;
    String? photoURL;
    
    if (firebaseUser.uid != null) {
      uid = firebaseUser.uid;
      name = firebaseUser.displayName ?? 'Mock User';
      email = firebaseUser.email ?? 'mock@example.com';
      photoURL = firebaseUser.photoURL;
    } else {
      uid = 'mock-user-${Random().nextInt(1000)}';
      name = 'Mock User';
      email = 'mock@example.com';
      photoURL = null;
    }
    
    final profile = UserProfile(
      id: uid,
      name: name,
      email: email,
      profileImageUrl: photoURL,
      createdAt: now,
      updatedAt: now,
    );
    
    return await createProfile(profile);
  }

  @override
  Future<bool> profileExists(String userId) async {
    await Future.delayed(const Duration(milliseconds: 100));
    return _profiles.containsKey(userId);
  }

  @override
  Future<List<UserProfile>> searchUsers(String query) async {
    await Future.delayed(const Duration(milliseconds: 300));
    
    if (query.isEmpty) return [];
    
    final results = _profiles.values
        .where((profile) => 
            profile.name.toLowerCase().contains(query.toLowerCase()) ||
            profile.email.toLowerCase().contains(query.toLowerCase()))
        .toList();
    
    results.sort((a, b) => a.name.compareTo(b.name));
    return results;
  }

  @override
  Future<void> incrementRideCount(String userId) async {
    await Future.delayed(const Duration(milliseconds: 200));
    
    final profile = _profiles[userId];
    if (profile != null) {
      final updatedProfile = profile.copyWith(
        totalRides: profile.totalRides + 1,
        updatedAt: DateTime.now(),
      );
      _profiles[userId] = updatedProfile;
      _profileStreamController.add(updatedProfile);
    }
  }

  @override
  Future<void> updateUserRating(String userId, double newRating) async {
    await Future.delayed(const Duration(milliseconds: 200));
    
    final profile = _profiles[userId];
    if (profile != null) {
      final updatedProfile = profile.copyWith(
        averageRating: newRating,
        updatedAt: DateTime.now(),
      );
      _profiles[userId] = updatedProfile;
      _profileStreamController.add(updatedProfile);
    }
  }

  void dispose() {
    _profileStreamController.close();
  }
}