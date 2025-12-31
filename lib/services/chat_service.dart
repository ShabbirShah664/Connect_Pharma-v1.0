import 'package:cloud_firestore/cloud_firestore.dart';

class ChatService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Sends a message in a specific chat room.
  /// [chatId] is typically the requestId.
  static Future<void> sendMessage({
    required String chatId,
    required String senderId,
    required String text,
    String? senderName,
  }) async {
    if (text.trim().isEmpty) return;

    final messageData = {
      'text': text.trim(),
      'senderId': senderId,
      'createdAt': FieldValue.serverTimestamp(),
      if (senderName != null) 'senderName': senderName,
    };

    try {
      await _db
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .add(messageData);
      
      // Update last message in metadata if needed (optional)
      await _db.collection('chats').doc(chatId).set({
        'lastMessage': text.trim(),
        'lastMessageAt': FieldValue.serverTimestamp(),
        'participants': FieldValue.arrayUnion([senderId]),
      }, SetOptions(merge: true));
      
    } catch (e) {
      throw Exception('Failed to send message: $e');
    }
  }

  /// Streams messages for a given chat room.
  static Stream<QuerySnapshot<Map<String, dynamic>>> streamMessages(String chatId) {
    return _db
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .snapshots(includeMetadataChanges: true);
  }
}
