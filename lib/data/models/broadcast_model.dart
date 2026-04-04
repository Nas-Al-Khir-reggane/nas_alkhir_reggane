import 'package:cloud_firestore/cloud_firestore.dart';

class BroadcastModel {
  final String id;
  final String title;
  final String body;
  final List<String> viewedByUserIds;
  final int viewCount;
  final bool isActive;
  final DateTime createdAt;

  BroadcastModel({
    required this.id,
    required this.title,
    required this.body,
    this.viewedByUserIds = const [],
    this.viewCount = 0,
    this.isActive = true,
    required this.createdAt,
  });

  factory BroadcastModel.fromMap(Map<String, dynamic> map, String id) {
    return BroadcastModel(
      id: id,
      title: map['title'] ?? '',
      body: map['body'] ?? '',
      viewedByUserIds: List<String>.from(map['viewedByUserIds'] ?? []),
      viewCount: (map['viewCount'] ?? 0) as int,
      isActive: map['isActive'] ?? true,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'body': body,
      'viewedByUserIds': viewedByUserIds,
      'viewCount': viewCount,
      'isActive': isActive,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  BroadcastModel copyWith({
    String? id,
    String? title,
    String? body,
    List<String>? viewedByUserIds,
    int? viewCount,
    bool? isActive,
    DateTime? createdAt,
  }) {
    return BroadcastModel(
      id: id ?? this.id,
      title: title ?? this.title,
      body: body ?? this.body,
      viewedByUserIds: viewedByUserIds ?? this.viewedByUserIds,
      viewCount: viewCount ?? this.viewCount,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
