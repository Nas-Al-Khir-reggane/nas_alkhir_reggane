import 'package:cloud_firestore/cloud_firestore.dart';

class WorkerUpdate {
  final String id;
  final String workerId;
  final String workerName;
  final String description;
  final String? imageUrl;
  final DateTime createdAt;

  WorkerUpdate({
    required this.id,
    required this.workerId,
    required this.workerName,
    required this.description,
    this.imageUrl,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'workerId': workerId,
      'workerName': workerName,
      'description': description,
      'imageUrl': imageUrl,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory WorkerUpdate.fromMap(Map<String, dynamic> map, String id) {
    return WorkerUpdate(
      id: id,
      workerId: map['workerId'] ?? '',
      workerName: map['workerName'] ?? '',
      description: map['description'] ?? '',
      imageUrl: map['imageUrl'],
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
