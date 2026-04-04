import 'package:cloud_firestore/cloud_firestore.dart';

class ChatMessageModel {
  final String? id;
  final String senderId;
  final String senderName;
  final String? senderImage;
  final String message;
  final String? imageUrl;
  final String? audioUrl;
  final int? audioDuration;
  final DateTime createdAt;
  final bool isRead;
  final String chatId;
  final Map<String, dynamic>? replyTo;
  final bool isDeleted;
  final bool isForwarded;
  final bool isSystem;
  final Map<String, dynamic>? reactions;

  ChatMessageModel({
    this.id,
    required this.senderId,
    required this.senderName,
    this.senderImage,
    required this.message,
    this.imageUrl,
    this.audioUrl,
    this.audioDuration,
    required this.createdAt,
    this.isRead = false,
    required this.chatId,
    this.replyTo,
    this.isDeleted = false,
    this.isForwarded = false,
    this.isSystem = false,
    this.reactions,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'senderId': senderId,
      'senderName': senderName,
      'senderImage': senderImage,
      'message': message,
      'imageUrl': imageUrl,
      'audioUrl': audioUrl,
      'audioDuration': audioDuration,
      'createdAt': FieldValue.serverTimestamp(),
      'isRead': isRead,
      'chatId': chatId,
      if (replyTo != null) 'reply_to': replyTo,
      'isDeleted': isDeleted,
      'isForwarded': isForwarded,
      'isSystem': isSystem,
      if (reactions != null) 'reactions': reactions,
    };
  }

  factory ChatMessageModel.fromMap(Map<String, dynamic> map) {
    DateTime parsedDate;
    var createdAtData = map['createdAt'] ?? map['created_at'];
    
    if (createdAtData is Timestamp) {
      parsedDate = createdAtData.toDate();
    } else if (createdAtData is String) {
      parsedDate = DateTime.tryParse(createdAtData) ?? DateTime.now();
    } else {
      parsedDate = DateTime.now();
    }

    return ChatMessageModel(
      id: map['id']?.toString(),
      senderId: (map['senderId'] ?? map['sender_id'])?.toString() ?? '',
      senderName: (map['senderName'] ?? map['sender_name'])?.toString() ?? 'مجهول',
      senderImage: map['senderImage'] ?? map['sender_image'],
      message: map['message']?.toString() ?? '',
      imageUrl: (map['imageUrl'] ?? map['image_url'])?.toString(),
      audioUrl: (map['audioUrl'] ?? map['audio_url'])?.toString(),
      audioDuration: map['audioDuration'] ?? map['audio_duration'],
      createdAt: parsedDate,
      isRead: map['isRead'] ?? map['is_read'] ?? false,
      chatId: (map['chatId'] ?? map['chat_id'])?.toString() ?? '',
      replyTo: map['reply_to'] != null ? Map<String, dynamic>.from(map['reply_to']) : null,
      isDeleted: map['isDeleted'] ?? false,
      isForwarded: map['isForwarded'] ?? false,
      isSystem: map['isSystem'] ?? false,
      reactions: map['reactions'] != null ? Map<String, dynamic>.from(map['reactions']) : null,
    );
  }
}

