import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:ridelink/models/ride_group.dart';
import 'package:ridelink/models/user_profile.dart';
import 'package:ridelink/services/ride_service.dart';
import 'package:ridelink/services/notification_service.dart';
import 'package:ridelink/services/user_service.dart';
import 'package:ridelink/core/errors/app_error.dart';

@GenerateMocks([IRideService, INotificationService, IUserService])
import 'dynamic_ride_joining_test.mocks.dart';

void main() {
  group('Dynamic Ride Joining System', () {
    late MockIRideService mockRideService;
    late MockINotificationService mockNotificationService;
    late MockIUserService mockUserService;

    setUp(() {
      mockRideService = MockIRideService();
      mockNotificationService = MockINotificationService();
      mockUserService = MockIUserService();
    });

    group('Join Request Flow', () {
      test('should successfully send join request with notification', () async {
        // Arrange
        const rideId = 'ride123';
        const userId = 'user456';
        const leaderId = 'leader789';
        const destination = 'Downtown Mall';
        const userName = 'John Doe';

        final ride = RideGroup(
          id: rideId,
          leaderId: leaderId,
          pickupLocation: 'Airport',
          pickupCoordinates: LatLng(40.7128, -74.0060),
          destination: destination,
          destinationCoordinates: LatLng(40.7589, -73.9851),
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

        final userProfile = UserProfile(
          id: userId,
          name: userName,
          email: 'john@example.com',
          averageRating: 4.5,
          totalRides: 10,
          isVerified: true,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        when(mockRideService.getRide(rideId)).thenAnswer((_) async => ride);
        when(mockRideService.requestToJoin(rideId, userId)).thenAnswer((_) async {});
        when(mockUserService.getUserProfile(userId)).thenAnswer((_) async => userProfile);
        when(mockNotificationService.sendJoinRequestNotification(leaderId, destination, userName))
            .thenAnswer((_) async {});

        // Act
        await mockRideService.requestToJoin(rideId, userId);
        final user = await mockUserService.getUserProfile(userId);
        await mockNotificationService.sendJoinRequestNotification(leaderId, destination, user!.name);

        // Assert
        verify(mockRideService.requestToJoin(rideId, userId)).called(1);
        verify(mockNotificationService.sendJoinRequestNotification(leaderId, destination, userName)).called(1);
      });

      test('should handle join request when ride is full', () async {
        // Arrange
        const rideId = 'ride123';
        const userId = 'user456';

        when(mockRideService.requestToJoin(rideId, userId))
            .thenThrow(AppError.validation('No available seats'));

        // Act & Assert
        expect(
          () => mockRideService.requestToJoin(rideId, userId),
          throwsA(isA<AppError>()),
        );
      });

      test('should prevent duplicate join requests', () async {
        // Arrange
        const rideId = 'ride123';
        const userId = 'user456';

        when(mockRideService.requestToJoin(rideId, userId))
            .thenThrow(AppError.validation('Join request already exists'));

        // Act & Assert
        expect(
          () => mockRideService.requestToJoin(rideId, userId),
          throwsA(isA<AppError>()),
        );
      });
    });

    group('Join Request Approval Flow', () {
      test('should successfully approve join request and update ride data', () async {
        // Arrange
        const rideId = 'ride123';
        const requesterId = 'user456';
        const destination = 'Downtown Mall';

        when(mockRideService.approveJoinRequest(rideId, requesterId)).thenAnswer((_) async {});
        when(mockNotificationService.sendJoinRequestResponseNotification(requesterId, destination, true))
            .thenAnswer((_) async {});

        // Act
        await mockRideService.approveJoinRequest(rideId, requesterId);
        await mockNotificationService.sendJoinRequestResponseNotification(requesterId, destination, true);

        // Assert
        verify(mockRideService.approveJoinRequest(rideId, requesterId)).called(1);
        verify(mockNotificationService.sendJoinRequestResponseNotification(requesterId, destination, true)).called(1);
      });

      test('should successfully reject join request with reason', () async {
        // Arrange
        const rideId = 'ride123';
        const requesterId = 'user456';
        const destination = 'Downtown Mall';
        const reason = 'Profile does not meet requirements';

        when(mockRideService.rejectJoinRequest(rideId, requesterId, reason)).thenAnswer((_) async {});
        when(mockNotificationService.sendJoinRequestResponseNotification(requesterId, destination, false))
            .thenAnswer((_) async {});

        // Act
        await mockRideService.rejectJoinRequest(rideId, requesterId, reason);
        await mockNotificationService.sendJoinRequestResponseNotification(requesterId, destination, false);

        // Assert
        verify(mockRideService.rejectJoinRequest(rideId, requesterId, reason)).called(1);
        verify(mockNotificationService.sendJoinRequestResponseNotification(requesterId, destination, false)).called(1);
      });
    });

    group('Real-time Updates', () {
      test('should provide real-time ride updates through stream', () async {
        // Arrange
        const rideId = 'ride123';
        final initialRide = RideGroup(
          id: rideId,
          leaderId: 'leader789',
          pickupLocation: 'Airport',
          pickupCoordinates: LatLng(40.7128, -74.0060),
          destination: 'Downtown Mall',
          destinationCoordinates: LatLng(40.7589, -73.9851),
          scheduledTime: DateTime.now().add(const Duration(hours: 2)),
          totalSeats: 4,
          availableSeats: 3,
          totalFare: 40.0,
          pricePerPerson: 13.33,
          femaleOnly: false,
          status: RideStatus.created,
          memberIds: [],
          joinRequests: [],
          createdAt: DateTime.now(),
        );

        final updatedRide = initialRide.copyWith(
          availableSeats: 2,
          pricePerPerson: 20.0,
          memberIds: ['user456'],
        );

        when(mockRideService.getRideStream(rideId))
            .thenAnswer((_) => Stream.fromIterable([initialRide, updatedRide]));

        // Act
        final stream = mockRideService.getRideStream(rideId);
        final rides = await stream.take(2).toList();

        // Assert
        expect(rides.length, 2);
        expect(rides[0]?.availableSeats, 3);
        expect(rides[1]?.availableSeats, 2);
        expect(rides[1]?.memberIds.length, 1);
        expect(rides[1]?.pricePerPerson, 20.0);
      });

      test('should handle stream errors gracefully', () async {
        // Arrange
        const rideId = 'ride123';
        when(mockRideService.getRideStream(rideId))
            .thenAnswer((_) => Stream.error(AppError.network('Connection failed')));

        // Act & Assert
        expect(
          mockRideService.getRideStream(rideId),
          emitsError(isA<AppError>()),
        );
      });
    });

    group('Dynamic Price Calculation', () {
      test('should recalculate price per person when members join', () async {
        // Arrange
        const rideId = 'ride123';
        const totalFare = 60.0;
        
        // Initial state: 1 member (leader), price = 60.0
        final initialRide = RideGroup(
          id: rideId,
          leaderId: 'leader789',
          pickupLocation: 'Airport',
          pickupCoordinates: LatLng(40.7128, -74.0060),
          destination: 'Downtown Mall',
          destinationCoordinates: LatLng(40.7589, -73.9851),
          scheduledTime: DateTime.now().add(const Duration(hours: 2)),
          totalSeats: 4,
          availableSeats: 3,
          totalFare: totalFare,
          pricePerPerson: totalFare, // 60.0 for 1 person
          femaleOnly: false,
          status: RideStatus.created,
          memberIds: [],
          joinRequests: [],
          createdAt: DateTime.now(),
        );

        // After 1 member joins: 2 people total, price = 30.0 each
        final afterFirstJoin = initialRide.copyWith(
          availableSeats: 2,
          pricePerPerson: totalFare / 2, // 30.0 each
          memberIds: ['user456'],
        );

        // After 2nd member joins: 3 people total, price = 20.0 each
        final afterSecondJoin = afterFirstJoin.copyWith(
          availableSeats: 1,
          pricePerPerson: totalFare / 3, // 20.0 each
          memberIds: ['user456', 'user789'],
        );

        when(mockRideService.getRideStream(rideId))
            .thenAnswer((_) => Stream.fromIterable([initialRide, afterFirstJoin, afterSecondJoin]));

        // Act
        final stream = mockRideService.getRideStream(rideId);
        final rides = await stream.take(3).toList();

        // Assert
        expect(rides[0]?.pricePerPerson, 60.0); // 1 person
        expect(rides[1]?.pricePerPerson, 30.0); // 2 people
        expect(rides[2]?.pricePerPerson, closeTo(20.0, 0.01)); // 3 people
        expect(rides[2]?.memberIds.length, 2);
        expect(rides[2]?.availableSeats, 1);
      });
    });

    group('Female-Only Ride Filtering', () {
      test('should filter female-only rides for male users', () async {
        // Arrange
        final searchCriteria = {
          'destination': 'Downtown Mall',
          'femaleOnly': false, // Male user searching
        };

        when(mockRideService.searchRides(searchCriteria))
            .thenAnswer((_) async => []); // Should return empty for male user

        // Act
        final rides = await mockRideService.searchRides(searchCriteria);

        // Assert
        expect(rides, isEmpty);
      });

      test('should include female-only rides for female users', () async {
        // Arrange
        final femaleOnlyRide = RideGroup(
          id: 'ride123',
          leaderId: 'leader789',
          pickupLocation: 'Airport',
          pickupCoordinates: LatLng(40.7128, -74.0060),
          destination: 'Downtown Mall',
          destinationCoordinates: LatLng(40.7589, -73.9851),
          scheduledTime: DateTime.now().add(const Duration(hours: 2)),
          totalSeats: 4,
          availableSeats: 3,
          totalFare: 40.0,
          pricePerPerson: 13.33,
          femaleOnly: true,
          status: RideStatus.created,
          memberIds: [],
          joinRequests: [],
          createdAt: DateTime.now(),
        );

        final searchCriteria = {
          'destination': 'Downtown Mall',
          'femaleOnly': true, // Female user searching
        };

        when(mockRideService.searchRides(searchCriteria))
            .thenAnswer((_) async => [femaleOnlyRide]);

        // Act
        final rides = await mockRideService.searchRides(searchCriteria);

        // Assert
        expect(rides.length, 1);
        expect(rides.first.femaleOnly, true);
      });
    });

    group('Error Handling', () {
      test('should handle network errors gracefully', () async {
        // Arrange
        const rideId = 'ride123';
        const userId = 'user456';

        when(mockRideService.requestToJoin(rideId, userId))
            .thenThrow(AppError.network('No internet connection'));

        // Act & Assert
        expect(
          () => mockRideService.requestToJoin(rideId, userId),
          throwsA(isA<AppError>()),
        );
      });

      test('should handle authentication errors', () async {
        // Arrange
        const rideId = 'ride123';
        const userId = 'user456';

        when(mockRideService.requestToJoin(rideId, userId))
            .thenThrow(AppError.auth('Authentication required', 'unauthenticated'));

        // Act & Assert
        expect(
          () => mockRideService.requestToJoin(rideId, userId),
          throwsA(isA<AppError>()),
        );
      });

      test('should handle validation errors', () async {
        // Arrange
        const rideId = 'ride123';
        const userId = 'user456';

        when(mockRideService.requestToJoin(rideId, userId))
            .thenThrow(AppError.validation('Ride ID cannot be empty'));

        // Act & Assert
        expect(
          () => mockRideService.requestToJoin(rideId, userId),
          throwsA(isA<AppError>()),
        );
      });
    });
  });
}
