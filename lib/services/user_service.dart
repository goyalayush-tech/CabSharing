import 'dart:io';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_profile.dart';
import '../models/rating.dart';
import '../core/errors/app_error.dart';

abstract class IUserService {
  Future<UserProfile> createProfile(UserProfile profile);
  Future<UserProfile> updateProfile(UserProfile profile);
  Future<UserProfile?> getUserProfile(String userId);
  Future<double> getUserRating(String userId);
  Future<List<Rating>> getUserRatings(String userId);
  Future<String?> uploadProfileImage(String userId, dynamic imageFile);
  Future<void> deleteProfileImage(String userId);
  Future<UserProfile> createProfileFromFirebaseUser(User firebaseUser);
  Future<bool> profileExists(String userId);
  Stream<UserProfile?> getUserProfileStream(String userId);
  Future<List<UserProfile>> searchUsers(String query);
  Future<void> incrementRideCount(String userId);
  Future<void> updateUserRating(String userId, double newRating);
}

class UserService implements IUserService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final String _collection = 'users';
  final String _ratingsCollection = 'ratings';

  @override
  Future<UserProfile> createProfile(UserProfile profile) async {
    try {
      await _checkNetworkConnectivity();
      
      final docRef = _firestore.collection(_collection).doc(profile.id);
      
      // Check if profile already exists
      final existingDoc = await docRef.get();
      if (existingDoc.exists) {
        throw AppError.validation('User profile already exists');
      }
      
      await docRef.set(profile.toJson());
      return profile;
    } on FirebaseException catch (e) {
      throw _handleFirebaseException(e, 'create profile');
    } catch (e) {
      if (e is AppError) rethrow;
      throw AppError.unknown('Failed to create user profile: ${e.toString()}');
    }
  }

  @override
  Future<UserProfile> updateProfile(UserProfile profile) async {
    try {
      await _checkNetworkConnectivity();
      
      final docRef = _firestore.collection(_collection).doc(profile.id);
      
      // Check if profile exists
      final existingDoc = await docRef.get();
      if (!existingDoc.exists) {
        throw AppError.validation('User profile does not exist');
      }
      
      final updatedProfile = profile.copyWith(updatedAt: DateTime.now());
      await docRef.update(updatedProfile.toJson());
      
      return updatedProfile;
    } on FirebaseException catch (e) {
      throw _handleFirebaseException(e, 'update profile');
    } catch (e) {
      if (e is AppError) rethrow;
      throw AppError.unknown('Failed to update user profile: ${e.toString()}');
    }
  }

  @override
  Future<UserProfile?> getUserProfile(String userId) async {
    try {
      await _checkNetworkConnectivity();
      
      if (userId.isEmpty) {
        throw AppError.validation('User ID cannot be empty');
      }
      
      final doc = await _firestore.collection(_collection).doc(userId).get();
      
      if (doc.exists && doc.data() != null) {
        return UserProfile.fromJson(doc.data()!);
      }
      return null;
    } on FirebaseException catch (e) {
      throw _handleFirebaseException(e, 'get user profile');
    } catch (e) {
      if (e is AppError) rethrow;
      throw AppError.unknown('Failed to get user profile: ${e.toString()}');
    }
  }

  @override
  Stream<UserProfile?> getUserProfileStream(String userId) {
    if (userId.isEmpty) {
      return Stream.error(AppError.validation('User ID cannot be empty'));
    }
    
    return _firestore
        .collection(_collection)
        .doc(userId)
        .snapshots()
        .map((doc) {
          if (doc.exists && doc.data() != null) {
            return UserProfile.fromJson(doc.data()!);
          }
          return null;
        })
        .handleError((error) {
          if (error is FirebaseException) {
            throw _handleFirebaseException(error, 'stream user profile');
          }
          throw AppError.unknown('Failed to stream user profile: ${error.toString()}');
        });
  }

  @override
  Future<double> getUserRating(String userId) async {
    try {
      await _checkNetworkConnectivity();
      
      if (userId.isEmpty) {
        throw AppError.validation('User ID cannot be empty');
      }
      
      final ratingsQuery = await _firestore
          .collection(_ratingsCollection)
          .where('ratedUserId', isEqualTo: userId)
          .get();
      
      if (ratingsQuery.docs.isEmpty) return 0.0;
      
      final ratings = ratingsQuery.docs
          .map((doc) => Rating.fromJson(doc.data()))
          .toList();
      
      final totalStars = ratings.map((r) => r.stars).reduce((a, b) => a + b);
      return totalStars / ratings.length;
    } on FirebaseException catch (e) {
      throw _handleFirebaseException(e, 'get user rating');
    } catch (e) {
      if (e is AppError) rethrow;
      throw AppError.unknown('Failed to get user rating: ${e.toString()}');
    }
  }

  @override
  Future<List<Rating>> getUserRatings(String userId) async {
    try {
      await _checkNetworkConnectivity();
      
      if (userId.isEmpty) {
        throw AppError.validation('User ID cannot be empty');
      }
      
      final ratingsQuery = await _firestore
          .collection(_ratingsCollection)
          .where('ratedUserId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .limit(50) // Limit to recent 50 ratings
          .get();
      
      return ratingsQuery.docs
          .map((doc) => Rating.fromJson(doc.data()))
          .toList();
    } on FirebaseException catch (e) {
      throw _handleFirebaseException(e, 'get user ratings');
    } catch (e) {
      if (e is AppError) rethrow;
      throw AppError.unknown('Failed to get user ratings: ${e.toString()}');
    }
  }

  @override
  Future<String?> uploadProfileImage(String userId, dynamic imageFile) async {
    try {
      await _checkNetworkConnectivity();
      
      if (userId.isEmpty) {
        throw AppError.validation('User ID cannot be empty');
      }
      
      final ref = _storage.ref().child('profile_images').child('$userId.jpg');
      
      UploadTask uploadTask;
      
      if (imageFile is File) {
        // For mobile platforms
        uploadTask = ref.putFile(imageFile);
      } else if (imageFile is Uint8List) {
        // For web platform
        uploadTask = ref.putData(imageFile);
      } else {
        throw AppError.validation('Invalid image file type');
      }
      
      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();
      
      return downloadUrl;
    } on FirebaseException catch (e) {
      throw _handleFirebaseException(e, 'upload profile image');
    } catch (e) {
      if (e is AppError) rethrow;
      throw AppError.unknown('Failed to upload profile image: ${e.toString()}');
    }
  }

  @override
  Future<void> deleteProfileImage(String userId) async {
    try {
      await _checkNetworkConnectivity();
      
      if (userId.isEmpty) {
        throw AppError.validation('User ID cannot be empty');
      }
      
      final ref = _storage.ref().child('profile_images').child('$userId.jpg');
      await ref.delete();
    } on FirebaseException catch (e) {
      if (e.code != 'object-not-found') {
        throw _handleFirebaseException(e, 'delete profile image');
      }
      // Ignore if image doesn't exist
    } catch (e) {
      if (e is AppError) rethrow;
      throw AppError.unknown('Failed to delete profile image: ${e.toString()}');
    }
  }

  @override
  Future<UserProfile> createProfileFromFirebaseUser(User firebaseUser) async {
    final now = DateTime.now();
    
    final profile = UserProfile(
      id: firebaseUser.uid,
      name: firebaseUser.displayName ?? 'User',
      email: firebaseUser.email ?? '',
      profileImageUrl: firebaseUser.photoURL,
      createdAt: now,
      updatedAt: now,
    );
    
    return await createProfile(profile);
  }

  @override
  Future<bool> profileExists(String userId) async {
    try {
      await _checkNetworkConnectivity();
      
      if (userId.isEmpty) {
        return false;
      }
      
      final doc = await _firestore.collection(_collection).doc(userId).get();
      return doc.exists;
    } on FirebaseException catch (e) {
      throw _handleFirebaseException(e, 'check profile existence');
    } catch (e) {
      if (e is AppError) rethrow;
      throw AppError.unknown('Failed to check profile existence: ${e.toString()}');
    }
  }

  @override
  Future<List<UserProfile>> searchUsers(String query) async {
    try {
      await _checkNetworkConnectivity();
      
      if (query.isEmpty) {
        return [];
      }
      
      // Search by name (case-insensitive)
      final nameQuery = await _firestore
          .collection(_collection)
          .where('name', isGreaterThanOrEqualTo: query)
          .where('name', isLessThanOrEqualTo: '$query\uf8ff')
          .limit(20)
          .get();
      
      final profiles = nameQuery.docs
          .map((doc) => UserProfile.fromJson(doc.data()))
          .toList();
      
      // Remove duplicates and sort by name
      final uniqueProfiles = <String, UserProfile>{};
      for (final profile in profiles) {
        uniqueProfiles[profile.id] = profile;
      }
      
      final result = uniqueProfiles.values.toList();
      result.sort((a, b) => a.name.compareTo(b.name));
      
      return result;
    } on FirebaseException catch (e) {
      throw _handleFirebaseException(e, 'search users');
    } catch (e) {
      if (e is AppError) rethrow;
      throw AppError.unknown('Failed to search users: ${e.toString()}');
    }
  }

  @override
  Future<void> incrementRideCount(String userId) async {
    try {
      await _checkNetworkConnectivity();
      
      if (userId.isEmpty) {
        throw AppError.validation('User ID cannot be empty');
      }
      
      final docRef = _firestore.collection(_collection).doc(userId);
      
      await _firestore.runTransaction((transaction) async {
        final doc = await transaction.get(docRef);
        
        if (!doc.exists) {
          throw AppError.validation('User profile does not exist');
        }
        
        final currentCount = doc.data()?['totalRides'] as int? ?? 0;
        transaction.update(docRef, {
          'totalRides': currentCount + 1,
          'updatedAt': DateTime.now().toIso8601String(),
        });
      });
    } on FirebaseException catch (e) {
      throw _handleFirebaseException(e, 'increment ride count');
    } catch (e) {
      if (e is AppError) rethrow;
      throw AppError.unknown('Failed to increment ride count: ${e.toString()}');
    }
  }

  @override
  Future<void> updateUserRating(String userId, double newRating) async {
    try {
      await _checkNetworkConnectivity();
      
      if (userId.isEmpty) {
        throw AppError.validation('User ID cannot be empty');
      }
      
      if (newRating < 0.0 || newRating > 5.0) {
        throw AppError.validation('Rating must be between 0.0 and 5.0');
      }
      
      final docRef = _firestore.collection(_collection).doc(userId);
      
      await docRef.update({
        'averageRating': newRating,
        'updatedAt': DateTime.now().toIso8601String(),
      });
    } on FirebaseException catch (e) {
      throw _handleFirebaseException(e, 'update user rating');
    } catch (e) {
      if (e is AppError) rethrow;
      throw AppError.unknown('Failed to update user rating: ${e.toString()}');
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

  AppError _handleFirebaseException(FirebaseException e, String operation) {
    switch (e.code) {
      case 'permission-denied':
        return AppError.auth('Permission denied to $operation', e.code);
      case 'not-found':
        return AppError.validation('Resource not found while trying to $operation');
      case 'already-exists':
        return AppError.validation('Resource already exists');
      case 'resource-exhausted':
        return AppError.network('Service temporarily unavailable. Please try again later.');
      case 'unauthenticated':
        return AppError.auth('Authentication required to $operation', e.code);
      case 'unavailable':
        return AppError.network('Service temporarily unavailable. Please try again later.');
      case 'deadline-exceeded':
        return AppError.network('Request timed out. Please try again.');
      default:
        return AppError.unknown('Failed to $operation: ${e.message ?? e.code}');
    }
  }
}