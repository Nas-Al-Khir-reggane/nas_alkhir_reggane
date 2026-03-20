import 'package:cloud_firestore/cloud_firestore.dart';

class ChatMessageModel {
  final String id;
  final String senderId;
  final String senderName;
  final String message;
  final String? imageUrl;
  final DateTime createdAt;
  final bool isRead;

  ChatMessageModel({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.message,
    this.imageUrl,
    required this.createdAt,
    this.isRead = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'senderId': senderId,
      'senderName': senderName,
      'message': message,
      'imageUrl': imageUrl,
      'createdAt': Timestamp.fromDate(createdAt),
      'isRead': isRead,
    };
  }

  factory ChatMessageModel.fromMap(Map<String, dynamic> map) {
    return ChatMessageModel(
      id: map['id'] ?? '',
      senderId: map['senderId'] ?? '',
      senderName: map['senderName'] ?? '',
      message: map['message'] ?? '',
      imageUrl: map['imageUrl'],
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      isRead: map['isRead'] ?? false,
    );
  }
}
