import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/message.dart';

abstract class IChatService {
  Stream<List<Message>> getGroupMessages(String groupId);
  Future<void> sendMessage(String groupId, Message message);
  Future<void> markMessagesAsRead(String groupId, String userId);
}

class ChatService implements IChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  Stream<List<Message>> getGroupMessages(String groupId) {
    return _firestore
        .collection('groups')
        .doc(groupId)
        .collection('messages')
        .orderBy('timestamp', descending: false)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Message.fromJson({...doc.data(), 'id': doc.id}))
            .toList());
  }

  @override
  Future<void> sendMessage(String groupId, Message message) async {
    try {
      await _firestore
          .collection('groups')
          .doc(groupId)
          .collection('messages')
          .add(message.toJson());
    } catch (e) {
      throw Exception('Failed to send message: $e');
    }
  }

  @override
  Future<void> markMessagesAsRead(String groupId, String userId) async {
    try {
      final messagesQuery = await _firestore
          .collection('groups')
          .doc(groupId)
          .collection('messages')
          .where('senderId', isNotEqualTo: userId)
          .get();

      final batch = _firestore.batch();
      for (final doc in messagesQuery.docs) {
        final message = Message.fromJson({...doc.data(), 'id': doc.id});
        if (!message.isReadBy(userId)) {
          batch.update(doc.reference, {
            'readBy': FieldValue.arrayUnion([userId])
          });
        }
      }
      await batch.commit();
    } catch (e) {
      throw Exception('Failed to mark messages as read: $e');
    }
  }
}