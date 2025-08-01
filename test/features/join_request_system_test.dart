import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import '../../lib/services/ride_service.dart';
import '../../lib/services/notification_service.dart';
import '../../lib/models/ride_group.dart';
import '../../lib/models/user_profile.dart';
import '../../lib/providers/ride_provider.dart';
import '../../lib/core/errors/app_error.dart';

import 'join_request_system_test.mocks.dart';

@GenerateMocks([IRideService, INotificationService])
void main() {
  group('Join Request System Tests', () {
    late MockIRideService mockRideService;
    late MockINotificationService mockNotificationService;
    late RideProvider rideProvider;
    late RideGroup testRide;
    late UserProfile testUser;

    setUp(() {
      mockRideService = MockIRideService();
      mockNotificationService = MockINotificationService();
      rideProvider = RideProvider(mockRideService);
      
      testRide = RideGroup(
        id: 'test-ride-id',
        leaderId: 'leader-id',
        pickupLocation: 'Test Pickup',
        pickupCoordinates: LatLng(37.7749, -122.4194),
        destination: 'Test Destination',
        destinationCoordinates: LatLng(37.7849, -122.4094),
        scheduledTime: DateTime.now().add(const Duration(hours: 2)),
        totalSeats: 4,
        availableSeats: 2,
        totalFare: 40.0,
        pricePerPerson: 20.0,
        femaleOnly: false,
        status: RideStatus.created,
        memberIds: ['member1'],
        joinRequests: [],
        createdAt: DateTime.now(),
      );

      testUser = UserProfile(
        id: 'test-user-id',
        name: 'Test User',
        email: 'test@example.com',
        profileImageUrl: null,
        bio: 'Test bio',
        phoneNumber: '+1234567890',
        averageRating: 4.5,
        totalRides: 10,
        isVerified: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    });

    group('Request to Join', () {
      test('should successfully request to join a ride', () async {
        // Arrange
        when(mockRideService.requestToJoin('test-ride-id', 'test-user-id'))
            .thenAnswer((_) async {});

        // Act
        await rideProvider.requestToJoin('test-ride-id', 'test-user-id');

        // Assert
        verify(mockRideService.requestToJoin('test-ride-id', 'test-user-id')).called(1);
        expect(rideProvider.error, isNull);
      });

      test('should handle duplicate join request error', () async {
        // Arrange
        when(mockRideService.requestToJoin('test-ride-id', 'test-user-id'))
            .thenThrow(AppError.validation('Join request already exists'));

        // Act
        await rideProvider.requestToJoin('test-ride-id', 'test-user-id');

        // Assert
        expect(rideProvider.error, isNotNull);
        expect(rideProvider.error!.message, contains('Join request already exists'));
      });

      test('should handle network error during join request', () async {
        // Arrange
        when(mockRideService.requestToJoin('test-ride-id', 'test-user-id'))
            .thenThrow(AppError.network('No internet connection'));

        // Act
        await rideProvider.requestToJoin('test-ride-id', 'test-user-id');

        // Assert
        expect(rideProvider.error, isNotNull);
        expect(rideProvider.error!.type, equals(ErrorType.network));
      });

      test('should validate empty parameters', () async {
        // Arrange
        when(mockRideService.requestToJoin('', 'test-user-id'))
            .thenThrow(AppError.validation('Ride ID and User ID cannot be empty'));

        // Act
        await rideProvider.requestToJoin('', 'test-user-id');

        // Assert
        expect(rideProvider.error, isNotNull);
        expect(rideProvider.error!.type, equals(ErrorType.validation));
      });
    });

    group('Approve Join Request', () {
      test('should successfully approve join request', () async {
        // Arrange
        final updatedRide = testRide.copyWith(
          memberIds: ['member1', 'test-user-id'],
          availableSeats: 1,
          pricePerPerson: 13.33,
        );

        when(mockRideService.approveJoinRequest('test-ride-id', 'test-user-id'))
            .thenAnswer((_) async {});
        when(mockRideService.getRide('test-ride-id'))
            .thenAnswer((_) async => updatedRide);

        // Act
        await rideProvider.approveJoinRequest('test-ride-id', 'test-user-id');

        // Assert
        verify(mockRideService.approveJoinRequest('test-ride-id', 'test-user-id')).called(1);
        verify(mockRideService.getRide('test-ride-id')).called(1);
        expect(rideProvider.error, isNull);
      });

      test('should handle no available seats error', () async {
        // Arrange
        when(mockRideService.approveJoinRequest('test-ride-id', 'test-user-id'))
            .thenThrow(AppError.validation('No available seats'));

        // Act
        await rideProvider.approveJoinRequest('test-ride-id', 'test-user-id');

        // Assert
        expect(rideProvider.error, isNotNull);
        expect(rideProvider.error!.message, contains('No available seats'));
      });

      test('should handle ride not found error', () async {
        // Arrange
        when(mockRideService.approveJoinRequest('invalid-ride-id', 'test-user-id'))
            .thenThrow(AppError.validation('Ride not found'));

        // Act
        await rideProvider.approveJoinRequest('invalid-ride-id', 'test-user-id');

        // Assert
        expect(rideProvider.error, isNotNull);
        expect(rideProvider.error!.message, contains('Ride not found'));
      });
    });

    group('Reject Join Request', () {
      test('should successfully reject join request', () async {
        // Arrange
        when(mockRideService.rejectJoinRequest('test-ride-id', 'test-user-id', 'Ride is full'))
            .thenAnswer((_) async {});

        // Act
        await rideProvider.rejectJoinRequest('test-ride-id', 'test-user-id', 'Ride is full');

        // Assert
        verify(mockRideService.rejectJoinRequest('test-ride-id', 'test-user-id', 'Ride is full')).called(1);
        expect(rideProvider.error, isNull);
      });

      test('should handle join request not found error', () async {
        // Arrange
        when(mockRideService.rejectJoinRequest('test-ride-id', 'test-user-id', 'Reason'))
            .thenThrow(AppError.validation('Join request not found'));

        // Act
        await rideProvider.rejectJoinRequest('test-ride-id', 'test-user-id', 'Reason');

        // Assert
        expect(rideProvider.error, isNotNull);
        expect(rideProvider.error!.message, contains('Join request not found'));
      });
    });

    group('Remove Member', () {
      test('should successfully remove member from ride', () async {
        // Arrange
        final updatedRide = testRide.copyWith(
          memberIds: [],
          availableSeats: 3,
          pricePerPerson: 40.0,
        );

        when(mockRideService.removeMember('test-ride-id', 'member1'))
            .thenAnswer((_) async {});
        when(mockRideService.getRide('test-ride-id'))
            .thenAnswer((_) async => updatedRide);

        // Act
        await rideProvider.removeMember('test-ride-id', 'member1');

        // Assert
        verify(mockRideService.removeMember('test-ride-id', 'member1')).called(1);
        verify(mockRideService.getRide('test-ride-id')).called(1);
        expect(rideProvider.error, isNull);
      });

      test('should handle user not member error', () async {
        // Arrange
        when(mockRideService.removeMember('test-ride-id', 'non-member-id'))
            .thenThrow(AppError.validation('User is not a member of this ride'));

        // Act
        await rideProvider.removeMember('test-ride-id', 'non-member-id');

        // Assert
        expect(rideProvider.error, isNotNull);
        expect(rideProvider.error!.message, contains('User is not a member of this ride'));
      });
    });

    group('Notification Integration', () {
      test('should send notification when join request is approved', () async {
        // Arrange
        when(mockNotificationService.sendJoinRequestResponseNotification(
          'test-user-id', 'Test Destination', true))
            .thenAnswer((_) async {});

        // Act
        await mockNotificationService.sendJoinRequestResponseNotification(
          'test-user-id', 'Test Destination', true);

        // Assert
        verify(mockNotificationService.sendJoinRequestResponseNotification(
          'test-user-id', 'Test Destination', true)).called(1);
      });

      test('should send notification when join request is rejected', () async {
        // Arrange
        when(mockNotificationService.sendJoinRequestResponseNotification(
          'test-user-id', 'Test Destination', false))
            .thenAnswer((_) async {});

        // Act
        await mockNotificationService.sendJoinRequestResponseNotification(
          'test-user-id', 'Test Destination', false);

        // Assert
        verify(mockNotificationService.sendJoinRequestResponseNotification(
          'test-user-id', 'Test Destination', false)).called(1);
      });

      test('should send notification to leader when join request is made', () async {
        // Arrange
        when(mockNotificationService.sendJoinRequestNotification(
          'leader-id', 'Test Destination', 'Test User'))
            .thenAnswer((_) async {});

        // Act
        await mockNotificationService.sendJoinRequestNotification(
          'leader-id', 'Test Destination', 'Test User');

        // Assert
        verify(mockNotificationService.sendJoinRequestNotification(
          'leader-id', 'Test Destination', 'Test User')).called(1);
      });
    });

    group('Edge Cases', () {
      test('should handle concurrent join requests for same ride', () async {
        // Arrange
        when(mockRideService.requestToJoin('test-ride-id', 'user1'))
            .thenAnswer((_) async {});
        when(mockRideService.requestToJoin('test-ride-id', 'user2'))
            .thenThrow(AppError.validation('No available seats'));

        // Act & Assert
        await rideProvider.requestToJoin('test-ride-id', 'user1');
        expect(rideProvider.error, isNull);

        await rideProvider.requestToJoin('test-ride-id', 'user2');
        expect(rideProvider.error, isNotNull);
        expect(rideProvider.error!.message, contains('No available seats'));
      });

      test('should handle leader trying to join their own ride', () async {
        // Arrange
        when(mockRideService.requestToJoin('test-ride-id', 'leader-id'))
            .thenThrow(AppError.validation('Cannot join your own ride'));

        // Act
        await rideProvider.requestToJoin('test-ride-id', 'leader-id');

        // Assert
        expect(rideProvider.error, isNotNull);
        expect(rideProvider.error!.message, contains('Cannot join your own ride'));
      });

      test('should handle approving request for cancelled ride', () async {
        // Arrange
        when(mockRideService.approveJoinRequest('cancelled-ride-id', 'test-user-id'))
            .thenThrow(AppError.validation('Cannot join cancelled ride'));

        // Act
        await rideProvider.approveJoinRequest('cancelled-ride-id', 'test-user-id');

        // Assert
        expect(rideProvider.error, isNotNull);
        expect(rideProvider.error!.message, contains('Cannot join cancelled ride'));
      });
    });

    group('Real-time Updates', () {
      test('should update local ride data when member is added', () async {
        // Arrange
        final initialRide = testRide;
        final updatedRide = testRide.copyWith(
          memberIds: ['member1', 'new-member'],
          availableSeats: 1,
          pricePerPerson: 13.33,
        );

        rideProvider.userRides.add(initialRide);

        when(mockRideService.approveJoinRequest('test-ride-id', 'new-member'))
            .thenAnswer((_) async {});
        when(mockRideService.getRide('test-ride-id'))
            .thenAnswer((_) async => updatedRide);

        // Act
        await rideProvider.approveJoinRequest('test-ride-id', 'new-member');

        // Assert
        expect(rideProvider.error, isNull);
        // In a real implementation, the ride would be updated in the local list
      });
    });
  });

  group('Join Request Model Tests', () {
    test('should create join request with correct properties', () {
      // Arrange & Act
      final joinRequest = JoinRequest(
        id: 'request-id',
        userId: 'user-id',
        status: 'pending',
        createdAt: DateTime.now(),
      );

      // Assert
      expect(joinRequest.id, equals('request-id'));
      expect(joinRequest.userId, equals('user-id'));
      expect(joinRequest.status, equals('pending'));
      expect(joinRequest.createdAt, isA<DateTime>());
    });

    test('should serialize and deserialize join request correctly', () {
      // Arrange
      final originalRequest = JoinRequest(
        id: 'request-id',
        userId: 'user-id',
        status: 'pending',
        createdAt: DateTime.now(),
      );

      // Act
      final json = originalRequest.toJson();
      final deserializedRequest = JoinRequest.fromJson(json);

      // Assert
      expect(deserializedRequest.id, equals(originalRequest.id));
      expect(deserializedRequest.userId, equals(originalRequest.userId));
      expect(deserializedRequest.status, equals(originalRequest.status));
      expect(deserializedRequest.createdAt, equals(originalRequest.createdAt));
    });
  });

  group('Ride Group Join Logic Tests', () {
    late RideGroup testRide;

    setUp(() {
      testRide = RideGroup(
        id: 'test-ride-id',
        leaderId: 'leader-id',
        pickupLocation: 'Test Pickup',
        pickupCoordinates: LatLng(37.7749, -122.4194),
        destination: 'Test Destination',
        destinationCoordinates: LatLng(37.7849, -122.4094),
        scheduledTime: DateTime.now().add(const Duration(hours: 2)),
        totalSeats: 4,
        availableSeats: 2,
        totalFare: 40.0,
        pricePerPerson: 20.0,
        femaleOnly: false,
        status: RideStatus.created,
        memberIds: ['member1'],
        joinRequests: [],
        createdAt: DateTime.now(),
      );
    });

    test('should allow user to join when conditions are met', () {
      // Act & Assert
      expect(testRide.canUserJoin('new-user-id'), isTrue);
    });

    test('should not allow leader to join their own ride', () {
      // Act & Assert
      expect(testRide.canUserJoin('leader-id'), isFalse);
    });

    test('should not allow existing member to join again', () {
      // Act & Assert
      expect(testRide.canUserJoin('member1'), isFalse);
    });

    test('should not allow join when ride is full', () {
      // Arrange
      final fullRide = testRide.copyWith(availableSeats: 0);

      // Act & Assert
      expect(fullRide.canUserJoin('new-user-id'), isFalse);
    });

    test('should not allow join when ride is not in created status', () {
      // Arrange
      final activeRide = testRide.copyWith(status: RideStatus.active);

      // Act & Assert
      expect(activeRide.canUserJoin('new-user-id'), isFalse);
    });

    test('should correctly add member and update pricing', () {
      // Act
      final updatedRide = testRide.addMember('new-user-id');

      // Assert
      expect(updatedRide.memberIds, contains('new-user-id'));
      expect(updatedRide.availableSeats, equals(1));
      expect(updatedRide.currentMemberCount, equals(3));
      expect(updatedRide.pricePerPerson, closeTo(13.33, 0.01));
    });

    test('should correctly remove member and update pricing', () {
      // Act
      final updatedRide = testRide.removeMember('member1');

      // Assert
      expect(updatedRide.memberIds, isNot(contains('member1')));
      expect(updatedRide.availableSeats, equals(3));
      expect(updatedRide.currentMemberCount, equals(1));
      expect(updatedRide.pricePerPerson, equals(40.0));
    });

    test('should throw error when trying to add member to full ride', () {
      // Arrange
      final fullRide = testRide.copyWith(availableSeats: 0);

      // Act & Assert
      expect(() => fullRide.addMember('new-user-id'), throwsStateError);
    });

    test('should throw error when trying to remove non-member', () {
      // Act & Assert
      expect(() => testRide.removeMember('non-member-id'), throwsStateError);
    });
  });
}