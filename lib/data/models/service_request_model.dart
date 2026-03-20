import 'package:cloud_firestore/cloud_firestore.dart';

class ServiceRequestModel {
  final String id;
  final String type;
  final String requesterId;
  final String requesterName;
  final String phone;
  final String wilaya;
  final String address;
  final String description;
  final String urgency; // normal, urgent, emergency
  final String status; // pending, in_progress, completed, rejected
  final String? assignedTo;
  final String? assignedToName;
  final String? assignedCarId;
  final Map<String, dynamic> details;
  final DateTime createdAt;
  final DateTime updatedAt;

  ServiceRequestModel({
    required this.id,
    required this.type,
    required this.requesterId,
    required this.requesterName,
    required this.phone,
    required this.wilaya,
    required this.address,
    required this.description,
    required this.urgency,
    this.status = 'pending',
    this.assignedTo,
    this.assignedToName,
    this.assignedCarId,
    this.details = const {},
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type,
      'requesterId': requesterId,
      'requesterName': requesterName,
      'phone': phone,
      'wilaya': wilaya,
      'address': address,
      'description': description,
      'urgency': urgency,
      'status': status,
      'assignedTo': assignedTo,
      'assignedToName': assignedToName,
      'assignedCarId': assignedCarId,
      'details': details,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  factory ServiceRequestModel.fromMap(Map<String, dynamic> map) {
    return ServiceRequestModel(
      id: map['id'] ?? '',
      type: map['type'] ?? '',
      requesterId: map['requesterId'] ?? '',
      requesterName: map['requesterName'] ?? '',
      phone: map['phone'] ?? '',
      wilaya: map['wilaya'] ?? '',
      address: map['address'] ?? '',
      description: map['description'] ?? '',
      urgency: map['urgency'] ?? 'normal',
      status: map['status'] ?? 'pending',
      assignedTo: map['assignedTo'],
      assignedToName: map['assignedToName'],
      assignedCarId: map['assignedCarId'],
      details: Map<String, dynamic>.from(map['details'] ?? {}),
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  ServiceRequestModel copyWith({
    String? id,
    String? type,
    String? requesterId,
    String? requesterName,
    String? phone,
    String? wilaya,
    String? address,
    String? description,
    String? urgency,
    String? status,
    String? assignedTo,
    String? assignedToName,
    String? assignedCarId,
    Map<String, dynamic>? details,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ServiceRequestModel(
      id: id ?? this.id,
      type: type ?? this.type,
      requesterId: requesterId ?? this.requesterId,
      requesterName: requesterName ?? this.requesterName,
      phone: phone ?? this.phone,
      wilaya: wilaya ?? this.wilaya,
      address: address ?? this.address,
      description: description ?? this.description,
      urgency: urgency ?? this.urgency,
      status: status ?? this.status,
      assignedTo: assignedTo ?? this.assignedTo,
      assignedToName: assignedToName ?? this.assignedToName,
      assignedCarId: assignedCarId ?? this.assignedCarId,
      details: details ?? this.details,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
