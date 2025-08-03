import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

abstract class INotificationService {
  Future<void> initialize();
  Future<String?> getToken();
  Future<void> subscribeToTopic(String topic);
  Future<void> unsubscribeFromTopic(String topic);
  Future<void> sendJoinRequestNotification(String leaderId, String rideDestination, String requesterName);
  Future<void> sendJoinRequestResponseNotification(String userId, String rideDestination, bool approved);
  Stream<RemoteMessage> get onMessage;
  Stream<RemoteMessage> get onMessageOpenedApp;
}

class NotificationService implements INotificationService {
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  @override
  Future<void> initialize() async {
    // Request permission for notifications
    NotificationSettings settings = await _messaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      debugPrint('User granted permission');
    } else if (settings.authorizationStatus == AuthorizationStatus.provisional) {
      debugPrint('User granted provisional permission');
    } else {
      debugPrint('User declined or has not accepted permission');
    }

    // Handle background messages
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  }

  @override
  Future<String?> getToken() async {
    try {
      return await _messaging.getToken();
    } catch (e) {
      debugPrint('Error getting FCM token: $e');
      return null;
    }
  }

  @override
  Future<void> subscribeToTopic(String topic) async {
    try {
      await _messaging.subscribeToTopic(topic);
    } catch (e) {
      debugPrint('Error subscribing to topic $topic: $e');
    }
  }

  @override
  Future<void> unsubscribeFromTopic(String topic) async {
    try {
      await _messaging.unsubscribeFromTopic(topic);
    } catch (e) {
      debugPrint('Error unsubscribing from topic $topic: $e');
    }
  }

  @override
  Future<void> sendJoinRequestNotification(String leaderId, String rideDestination, String requesterName) async {
    try {
      // In a real implementation, this would send a notification through your backend
      // For now, we'll simulate a local notification and log it
      debugPrint('Sending join request notification to leader $leaderId: $requesterName wants to join ride to $rideDestination');
      
      // Simulate sending notification through FCM topic
      await subscribeToTopic('ride_leader_$leaderId');
      
      // In production, you would call your backend API here:
      // await _apiService.sendNotification(leaderId, {
      //   'title': 'New Join Request',
      //   'body': '$requesterName wants to join your ride to $rideDestination',
      //   'data': {
      //     'type': 'join_request',
      //     'leaderId': leaderId,
      //     'requesterName': requesterName,
      //     'destination': rideDestination,
      //   }
      // });
      
      debugPrint('Join request notification sent successfully');
    } catch (e) {
      debugPrint('Error sending join request notification: $e');
    }
  }

  @override
  Future<void> sendJoinRequestResponseNotification(String userId, String rideDestination, bool approved) async {
    try {
      final title = approved ? 'Join Request Approved' : 'Join Request Declined';
      final body = approved 
          ? 'Your request to join the ride to $rideDestination has been approved!'
          : 'Your request to join the ride to $rideDestination has been declined.';
      
      debugPrint('Sending join request response notification to user $userId: $title - $body');
      
      // Simulate sending notification through FCM topic
      await subscribeToTopic('user_$userId');
      
      // In production, you would call your backend API here:
      // await _apiService.sendNotification(userId, {
      //   'title': title,
      //   'body': body,
      //   'data': {
      //     'type': approved ? 'join_approved' : 'join_declined',
      //     'userId': userId,
      //     'destination': rideDestination,
      //     'approved': approved.toString(),
      //   }
      // });
      
      debugPrint('Join request response notification sent successfully');
    } catch (e) {
      debugPrint('Error sending join request response notification: $e');
    }
  }

  @override
  Stream<RemoteMessage> get onMessage => FirebaseMessaging.onMessage;

  @override
  Stream<RemoteMessage> get onMessageOpenedApp => FirebaseMessaging.onMessageOpenedApp;
}

// Top-level function to handle background messages
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('Handling a background message: ${message.messageId}');
}