import 'package:flutter_test/flutter_test.dart';
import 'package:ridelink/models/ride_group.dart';

void main() {
  group('RideGroup', () {
    late DateTime now;
    late DateTime futureTime;

    setUp(() {
      now = DateTime.now();
      futureTime = now.add(Duration(hours: 2));
    });

    RideGroup createValidRideGroup() {
      return RideGroup(
        id: 'ride123',
        leaderId: 'leader123',
        pickupLocation: 'Downtown Station',
        pickupCoordinates: LatLng(40.7128, -74.0060),
        destination: 'Airport Terminal',
        destinationCoordinates: LatLng(40.6892, -74.1745),
        scheduledTime: futureTime,
        totalSeats: 4,
        availableSeats: 3,
        totalFare: 100.0,
        pricePerPerson: 100.0, // 100 / 1 person (just leader initially)
        createdAt: now,
      );
    }

    group('Creation and Validation', () {
      test('should create valid RideGroup', () {
        final ride = createValidRideGroup();
        
        expect(ride.id, 'ride123');
        expect(ride.leaderId, 'leader123');
        expect(ride.pickupLocation, 'Downtown Station');
        expect(ride.destination, 'Airport Terminal');
        expect(ride.totalSeats, 4);
        expect(ride.availableSeats, 3);
        expect(ride.totalFare, 100.0);
        expect(ride.pricePerPerson, 100.0);
      });

      test('should throw error for empty ID', () {
        expect(
          () => RideGroup(
            id: '',
            leaderId: 'leader123',
            pickupLocation: 'Downtown Station',
            pickupCoordinates: LatLng(40.7128, -74.0060),
            destination: 'Airport Terminal',
            destinationCoordinates: LatLng(40.6892, -74.1745),
            scheduledTime: futureTime,
            totalSeats: 4,
            availableSeats: 3,
            totalFare: 100.0,
            pricePerPerson: 50.0,
            createdAt: now,
          ),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('should throw error for invalid seat count', () {
        expect(
          () => RideGroup(
            id: 'ride123',
            leaderId: 'leader123',
            pickupLocation: 'Downtown Station',
            pickupCoordinates: LatLng(40.7128, -74.0060),
            destination: 'Airport Terminal',
            destinationCoordinates: LatLng(40.6892, -74.1745),
            scheduledTime: futureTime,
            totalSeats: 0,
            availableSeats: 0,
            totalFare: 100.0,
            pricePerPerson: 50.0,
            createdAt: now,
          ),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('should throw error for past scheduled time', () {
        expect(
          () => RideGroup(
            id: 'ride123',
            leaderId: 'leader123',
            pickupLocation: 'Downtown Station',
            pickupCoordinates: LatLng(40.7128, -74.0060),
            destination: 'Airport Terminal',
            destinationCoordinates: LatLng(40.6892, -74.1745),
            scheduledTime: now.subtract(Duration(hours: 1)),
            totalSeats: 4,
            availableSeats: 3,
            totalFare: 100.0,
            pricePerPerson: 50.0,
            createdAt: now,
          ),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('should throw error for incorrect price calculation', () {
        expect(
          () => RideGroup(
            id: 'ride123',
            leaderId: 'leader123',
            pickupLocation: 'Downtown Station',
            pickupCoordinates: LatLng(40.7128, -74.0060),
            destination: 'Airport Terminal',
            destinationCoordinates: LatLng(40.6892, -74.1745),
            scheduledTime: futureTime,
            totalSeats: 4,
            availableSeats: 3,
            totalFare: 100.0,
            pricePerPerson: 25.0, // Should be 100.0 for 1 person (leader only)
            createdAt: now,
          ),
          throwsA(isA<ArgumentError>()),
        );
      });
    });

    group('Business Logic', () {
      test('should identify full ride', () {
        final fullRide = createValidRideGroup().copyWith(
          availableSeats: 0,
          pricePerPerson: 25.0, // 100 / 4 people
        );
        expect(fullRide.isFull, true);
        expect(fullRide.canAcceptMoreMembers, false);
      });

      test('should identify available ride', () {
        final availableRide = createValidRideGroup();
        expect(availableRide.isFull, false);
        expect(availableRide.canAcceptMoreMembers, true);
      });

      test('should calculate current member count', () {
        final ride = createValidRideGroup();
        expect(ride.currentMemberCount, 1); // totalSeats - availableSeats
      });

      test('should check if user can join', () {
        final ride = createValidRideGroup();
        
        expect(ride.canUserJoin('user123'), true);
        expect(ride.canUserJoin('leader123'), false); // Leader cannot join
      });

      test('should add member correctly', () {
        final ride = createValidRideGroup();
        final updatedRide = ride.addMember('user123');
        
        expect(updatedRide.memberIds.contains('user123'), true);
        expect(updatedRide.availableSeats, 2);
        expect(updatedRide.pricePerPerson, 50.0); // 100 / 2 people (leader + 1 member)
      });

      test('should remove member correctly', () {
        final ride = createValidRideGroup()
            .addMember('user123')
            .addMember('user456');
        
        final updatedRide = ride.removeMember('user123');
        
        expect(updatedRide.memberIds.contains('user123'), false);
        expect(updatedRide.memberIds.contains('user456'), true);
        expect(updatedRide.availableSeats, 2);
      });

      test('should throw error when adding member to full ride', () {
        final fullRide = createValidRideGroup().copyWith(
          availableSeats: 0,
          pricePerPerson: 25.0, // 100 / 4 people
        );
        
        expect(
          () => fullRide.addMember('user123'),
          throwsA(isA<StateError>()),
        );
      });

      test('should throw error when removing non-member', () {
        final ride = createValidRideGroup();
        
        expect(
          () => ride.removeMember('nonmember'),
          throwsA(isA<StateError>()),
        );
      });
    });

    group('JSON Serialization', () {
      test('should serialize to JSON correctly', () {
        final ride = createValidRideGroup();
        final json = ride.toJson();
        
        expect(json['id'], 'ride123');
        expect(json['leaderId'], 'leader123');
        expect(json['totalSeats'], 4);
        expect(json['availableSeats'], 3);
        expect(json['totalFare'], 100.0);
        expect(json['pricePerPerson'], 100.0);
        expect(json['femaleOnly'], false);
        expect(json['status'], 'created');
      });

      test('should deserialize from JSON correctly', () {
        final json = {
          'id': 'ride123',
          'leaderId': 'leader123',
          'pickupLocation': 'Downtown Station',
          'pickupCoordinates': {'latitude': 40.7128, 'longitude': -74.0060},
          'destination': 'Airport Terminal',
          'destinationCoordinates': {'latitude': 40.6892, 'longitude': -74.1745},
          'scheduledTime': futureTime.toIso8601String(),
          'totalSeats': 4,
          'availableSeats': 3,
          'totalFare': 100.0,
          'pricePerPerson': 100.0,
          'femaleOnly': false,
          'status': 'created',
          'memberIds': [],
          'joinRequests': [],
          'createdAt': now.toIso8601String(),
        };
        
        final ride = RideGroup.fromJson(json);
        
        expect(ride.id, 'ride123');
        expect(ride.leaderId, 'leader123');
        expect(ride.totalSeats, 4);
        expect(ride.availableSeats, 3);
        expect(ride.status, RideStatus.created);
      });
    });
  });

  group('LatLng', () {
    test('should create LatLng correctly', () {
      final latLng = LatLng(40.7128, -74.0060);
      
      expect(latLng.latitude, 40.7128);
      expect(latLng.longitude, -74.0060);
    });

    test('should serialize to JSON correctly', () {
      final latLng = LatLng(40.7128, -74.0060);
      final json = latLng.toJson();
      
      expect(json['latitude'], 40.7128);
      expect(json['longitude'], -74.0060);
    });

    test('should deserialize from JSON correctly', () {
      final json = {'latitude': 40.7128, 'longitude': -74.0060};
      final latLng = LatLng.fromJson(json);
      
      expect(latLng.latitude, 40.7128);
      expect(latLng.longitude, -74.0060);
    });
  });

  group('JoinRequest', () {
    test('should create JoinRequest correctly', () {
      final now = DateTime.now();
      final request = JoinRequest(
        id: 'request123',
        userId: 'user123',
        status: 'pending',
        createdAt: now,
      );
      
      expect(request.id, 'request123');
      expect(request.userId, 'user123');
      expect(request.status, 'pending');
      expect(request.createdAt, now);
    });

    test('should serialize to JSON correctly', () {
      final now = DateTime.now();
      final request = JoinRequest(
        id: 'request123',
        userId: 'user123',
        status: 'pending',
        createdAt: now,
      );
      
      final json = request.toJson();
      
      expect(json['id'], 'request123');
      expect(json['userId'], 'user123');
      expect(json['status'], 'pending');
      expect(json['createdAt'], now.toIso8601String());
    });
  });
}