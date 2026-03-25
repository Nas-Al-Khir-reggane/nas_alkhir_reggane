import 'package:cloud_firestore/cloud_firestore.dart';

class ChatMessageModel {
  final String? id;
  final String senderId;
  final String senderName;
  final String? senderImage; // إضافة صورة المرسل
  final String message;
  final String? imageUrl;
  final DateTime createdAt;
  final bool isRead;
  final String chatId;
  final Map<String, dynamic>? replyTo;

  ChatMessageModel({
    this.id,
    required this.senderId,
    required this.senderName,
    this.senderImage,
    required this.message,
    this.imageUrl,
    required this.createdAt,
    this.isRead = false,
    required this.chatId,
    this.replyTo,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'senderId': senderId,
      'senderName': senderName,
      'senderImage': senderImage,
      'message': message,
      'imageUrl': imageUrl,
      'createdAt': FieldValue.serverTimestamp(), // توحيد المسمى
      'isRead': isRead,
      'chatId': chatId,
      if (replyTo != null) 'reply_to': replyTo,
    };
  }

  factory ChatMessageModel.fromMap(Map<String, dynamic> map) {
    DateTime parsedDate;
    var createdAtData = map['createdAt'] ?? map['created_at']; // دعم الصيغتين مؤقتاً
    
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
      senderName: (map['senderName'] ?? map['sender_name'])?.toString() ?? 'مستخدم',
      senderImage: map['senderImage'] ?? map['sender_image'],
      message: map['message']?.toString() ?? '',
      imageUrl: (map['imageUrl'] ?? map['image_url'])?.toString(),
      createdAt: parsedDate,
      isRead: map['isRead'] ?? map['is_read'] ?? false,
      chatId: (map['chatId'] ?? map['chat_id'])?.toString() ?? '',
      replyTo: map['reply_to'] != null ? Map<String, dynamic>.from(map['reply_to']) : null,
    );
  }
}
