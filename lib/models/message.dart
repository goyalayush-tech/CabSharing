enum MessageType { text, image, location, system }

class Message {
  final String id;
  final String groupId;
  final String senderId;
  final String content;
  final MessageType type;
  final DateTime timestamp;
  final List<String> readBy;

  Message({
    required this.id,
    required this.groupId,
    required this.senderId,
    required this.content,
    this.type = MessageType.text,
    required this.timestamp,
    this.readBy = const [],
  }) {
    _validate();
  }

  void _validate() {
    if (id.isEmpty) throw ArgumentError('Message ID cannot be empty');
    if (groupId.isEmpty) throw ArgumentError('Group ID cannot be empty');
    if (senderId.isEmpty) throw ArgumentError('Sender ID cannot be empty');
    if (content.isEmpty) throw ArgumentError('Message content cannot be empty');
    if (content.length > 1000) {
      throw ArgumentError('Message content cannot exceed 1000 characters');
    }
    if (timestamp.isAfter(DateTime.now().add(const Duration(minutes: 1)))) {
      throw ArgumentError('Message timestamp cannot be in the future');
    }
  }

  bool get isSystemMessage {
    return type == MessageType.system;
  }

  bool get hasImage {
    return type == MessageType.image;
  }

  bool get hasLocation {
    return type == MessageType.location;
  }

  int get unreadCount {
    // This would typically be calculated based on group member count
    // For now, we'll return a placeholder
    return 0;
  }

  Message markAsRead(String userId) {
    if (readBy.contains(userId)) {
      return this; // Already read
    }
    
    final newReadBy = List<String>.from(readBy)..add(userId);
    return copyWith(readBy: newReadBy);
  }

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['id'] as String,
      groupId: json['groupId'] as String,
      senderId: json['senderId'] as String,
      content: json['content'] as String,
      type: MessageType.values.firstWhere(
        (e) => e.toString().split('.').last == json['type'],
        orElse: () => MessageType.text,
      ),
      timestamp: DateTime.parse(json['timestamp'] as String),
      readBy: List<String>.from(json['readBy'] as List? ?? []),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'groupId': groupId,
      'senderId': senderId,
      'content': content,
      'type': type.toString().split('.').last,
      'timestamp': timestamp.toIso8601String(),
      'readBy': readBy,
    };
  }

  Message copyWith({
    String? id,
    String? groupId,
    String? senderId,
    String? content,
    MessageType? type,
    DateTime? timestamp,
    List<String>? readBy,
  }) {
    return Message(
      id: id ?? this.id,
      groupId: groupId ?? this.groupId,
      senderId: senderId ?? this.senderId,
      content: content ?? this.content,
      type: type ?? this.type,
      timestamp: timestamp ?? this.timestamp,
      readBy: readBy ?? this.readBy,
    );
  }

  bool isReadBy(String userId) {
    return readBy.contains(userId);
  }
}