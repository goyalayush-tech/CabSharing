import 'package:flutter_test/flutter_test.dart';
import 'package:ridelink/models/message.dart';

void main() {
  group('Message', () {
    late DateTime now;

    setUp(() {
      now = DateTime.now();
    });

    Message createValidMessage() {
      return Message(
        id: 'msg123',
        groupId: 'group123',
        senderId: 'user123',
        content: 'Hello everyone!',
        type: MessageType.text,
        timestamp: now,
        readBy: ['user123'],
      );
    }

    group('Creation and Validation', () {
      test('should create valid Message', () {
        final message = createValidMessage();
        
        expect(message.id, 'msg123');
        expect(message.groupId, 'group123');
        expect(message.senderId, 'user123');
        expect(message.content, 'Hello everyone!');
        expect(message.type, MessageType.text);
        expect(message.timestamp, now);
        expect(message.readBy, ['user123']);
      });

      test('should create message with default type', () {
        final message = Message(
          id: 'msg123',
          groupId: 'group123',
          senderId: 'user123',
          content: 'Hello everyone!',
          timestamp: now,
        );
        
        expect(message.type, MessageType.text);
        expect(message.readBy, isEmpty);
      });

      test('should throw error for empty ID', () {
        expect(
          () => Message(
            id: '',
            groupId: 'group123',
            senderId: 'user123',
            content: 'Hello everyone!',
            timestamp: now,
          ),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('should throw error for empty group ID', () {
        expect(
          () => Message(
            id: 'msg123',
            groupId: '',
            senderId: 'user123',
            content: 'Hello everyone!',
            timestamp: now,
          ),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('should throw error for empty sender ID', () {
        expect(
          () => Message(
            id: 'msg123',
            groupId: 'group123',
            senderId: '',
            content: 'Hello everyone!',
            timestamp: now,
          ),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('should throw error for empty content', () {
        expect(
          () => Message(
            id: 'msg123',
            groupId: 'group123',
            senderId: 'user123',
            content: '',
            timestamp: now,
          ),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('should throw error for content too long', () {
        expect(
          () => Message(
            id: 'msg123',
            groupId: 'group123',
            senderId: 'user123',
            content: 'a' * 1001,
            timestamp: now,
          ),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('should throw error for future timestamp', () {
        final futureTime = now.add(Duration(minutes: 2));
        expect(
          () => Message(
            id: 'msg123',
            groupId: 'group123',
            senderId: 'user123',
            content: 'Hello everyone!',
            timestamp: futureTime,
          ),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('should accept timestamp within 1 minute of now', () {
        final almostFutureTime = now.add(Duration(seconds: 30));
        expect(
          () => Message(
            id: 'msg123',
            groupId: 'group123',
            senderId: 'user123',
            content: 'Hello everyone!',
            timestamp: almostFutureTime,
          ),
          returnsNormally,
        );
      });
    });

    group('Business Logic', () {
      test('should identify system message', () {
        final systemMessage = Message(
          id: 'msg123',
          groupId: 'group123',
          senderId: 'system',
          content: 'User joined the group',
          type: MessageType.system,
          timestamp: now,
        );
        
        expect(systemMessage.isSystemMessage, true);
      });

      test('should identify image message', () {
        final imageMessage = Message(
          id: 'msg123',
          groupId: 'group123',
          senderId: 'user123',
          content: 'image_url',
          type: MessageType.image,
          timestamp: now,
        );
        
        expect(imageMessage.hasImage, true);
      });

      test('should identify location message', () {
        final locationMessage = Message(
          id: 'msg123',
          groupId: 'group123',
          senderId: 'user123',
          content: '40.7128,-74.0060',
          type: MessageType.location,
          timestamp: now,
        );
        
        expect(locationMessage.hasLocation, true);
      });

      test('should check if read by user', () {
        final message = createValidMessage();
        
        expect(message.isReadBy('user123'), true);
        expect(message.isReadBy('user456'), false);
      });

      test('should mark message as read', () {
        final message = createValidMessage();
        final updatedMessage = message.markAsRead('user456');
        
        expect(updatedMessage.readBy.contains('user456'), true);
        expect(updatedMessage.readBy.contains('user123'), true);
      });

      test('should not duplicate read status', () {
        final message = createValidMessage();
        final updatedMessage = message.markAsRead('user123');
        
        expect(updatedMessage.readBy.length, 1);
        expect(updatedMessage.readBy.first, 'user123');
      });
    });

    group('JSON Serialization', () {
      test('should serialize to JSON correctly', () {
        final message = createValidMessage();
        final json = message.toJson();
        
        expect(json['id'], 'msg123');
        expect(json['groupId'], 'group123');
        expect(json['senderId'], 'user123');
        expect(json['content'], 'Hello everyone!');
        expect(json['type'], 'text');
        expect(json['timestamp'], now.toIso8601String());
        expect(json['readBy'], ['user123']);
      });

      test('should deserialize from JSON correctly', () {
        final json = {
          'id': 'msg123',
          'groupId': 'group123',
          'senderId': 'user123',
          'content': 'Hello everyone!',
          'type': 'text',
          'timestamp': now.toIso8601String(),
          'readBy': ['user123'],
        };
        
        final message = Message.fromJson(json);
        
        expect(message.id, 'msg123');
        expect(message.groupId, 'group123');
        expect(message.senderId, 'user123');
        expect(message.content, 'Hello everyone!');
        expect(message.type, MessageType.text);
        expect(message.readBy, ['user123']);
      });

      test('should handle missing optional fields in JSON', () {
        final json = {
          'id': 'msg123',
          'groupId': 'group123',
          'senderId': 'user123',
          'content': 'Hello everyone!',
          'timestamp': now.toIso8601String(),
        };
        
        final message = Message.fromJson(json);
        
        expect(message.type, MessageType.text);
        expect(message.readBy, isEmpty);
      });
    });

    group('Copy With', () {
      test('should copy message with new values', () {
        final original = createValidMessage();
        final copied = original.copyWith(
          content: 'Updated content',
          type: MessageType.image,
          readBy: ['user123', 'user456'],
        );
        
        expect(copied.id, original.id);
        expect(copied.groupId, original.groupId);
        expect(copied.senderId, original.senderId);
        expect(copied.content, 'Updated content');
        expect(copied.type, MessageType.image);
        expect(copied.readBy, ['user123', 'user456']);
        expect(copied.timestamp, original.timestamp);
      });
    });
  });

  group('MessageType', () {
    test('should have all expected message types', () {
      expect(MessageType.values.length, 4);
      expect(MessageType.values.contains(MessageType.text), true);
      expect(MessageType.values.contains(MessageType.image), true);
      expect(MessageType.values.contains(MessageType.location), true);
      expect(MessageType.values.contains(MessageType.system), true);
    });
  });
}