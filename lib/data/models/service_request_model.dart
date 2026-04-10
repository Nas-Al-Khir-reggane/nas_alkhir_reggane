import 'package:cloud_firestore/cloud_firestore.dart';

class ServiceRequestModel {
  final String id;
  final String type;
  final String typeName;
  final String requesterId;
  final String requesterName;
  final String phone;
  final String wilaya;
  final String commune;
  final String address;
  final String description;
  final String urgency; // normal, urgent, emergency
  final String status; // pending, in_progress, completed, rejected
  final String? assignedTo;
  final String? assignedToName;
  final String? assignedCarId;
  final Map<String, dynamic> details;
  final bool isSeenByAdmin;
  final String bloodType;
  final String hospital;
  final String patientName;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<String> attachments; // Storage paths (preferred) or legacy file URLs
  final List<Map<String, dynamic>> donorResponses; // [{name, phone, respondedAt, userId}]
  final double? latitude;
  final double? longitude;
  final List<Map<String, dynamic>> notifiedDonors; // [{id, name, phone, bloodType}]
  final String? roomNumber; // رقم الغرفة في دار السبيل ✨

  ServiceRequestModel({
    required this.id,
    required this.type,
    this.typeName = '',
    required this.requesterId,
    required this.requesterName,
    required this.phone,
    required this.wilaya,
    this.commune = '',
    required this.address,
    required this.description,
    required this.urgency,
    this.status = 'pending',
    this.assignedTo,
    this.assignedToName,
    this.assignedCarId,
    this.details = const {},
    this.isSeenByAdmin = false,
    this.bloodType = '',
    this.hospital = '',
    this.patientName = '',
    required this.createdAt,
    required this.updatedAt,
    this.attachments = const [],
    this.donorResponses = const [],
    this.notifiedDonors = const [],
    this.latitude,
    this.longitude,
    this.roomNumber,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type,
      'typeName': typeName,
      'requesterId': requesterId,
      'requesterName': requesterName,
      'phone': phone,
      'wilaya': wilaya,
      'commune': commune,
      'address': address,
      'description': description,
      'urgency': urgency,
      'status': status,
      'assignedTo': assignedTo,
      'assignedToName': assignedToName,
      'assignedCarId': assignedCarId,
      'details': details,
      'isSeenByAdmin': isSeenByAdmin,
      'bloodType': bloodType,
      'hospital': hospital,
      'patientName': patientName,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'attachments': attachments,
      'donorResponses': donorResponses,
      'notifiedDonors': notifiedDonors,
      'latitude': latitude,
      'longitude': longitude,
      'roomNumber': roomNumber,
    };
  }

  factory ServiceRequestModel.fromMap(Map<String, dynamic> map, {String? id}) {
    // Robust mapping to handle different key formats from Firestore
    return ServiceRequestModel(
      id: id ?? map['id'] ?? '',
      type: map['type'] ?? '',
      typeName: map['typeName'] ?? map['type_name'] ?? '',
      requesterId: map['requesterId'] ?? map['requester_id'] ?? map['userId'] ?? '',
      requesterName: (map['requesterName'] != null && map['requesterName'].toString().isNotEmpty)
          ? map['requesterName']
          : (map['name'] ?? map['userName'] ?? map['requester_name'] ?? ''),
      phone: map['phone'] ?? map['phoneNumber'] ?? map['phone_number'] ?? '',
      wilaya: map['wilaya'] ?? '',
      commune: map['commune'] ?? '',
      address: map['address'] ?? map['location'] ?? map['address_detail'] ?? '',
      description: map['description'] ?? map['details_text'] ?? map['notes'] ?? '',
      urgency: map['urgency'] ?? 'normal',
      status: map['status'] ?? 'pending',
      assignedTo: map['assignedTo'] ?? map['assigned_to'],
      assignedToName: map['assignedToName'] ?? map['assigned_to_name'],
      assignedCarId: map['assignedCarId'] ?? map['assigned_car_id'],
      details: Map<String, dynamic>.from(map['details'] ?? {}),
      isSeenByAdmin: map['isSeenByAdmin'] ?? map['is_seen_by_admin'] ?? false,
        bloodType: map['bloodType'] ?? map['details']?['الفصيلة'] ?? map['details']?['فصيلة الدم'] ?? map['details']?['bloodType'] ?? '',
        hospital: map['hospital'] ?? map['details']?['المستشفى'] ?? map['details']?['hospital'] ?? map['deliveryLocation'] ?? '',
        patientName: map['patientName'] ?? map['details']?['اسم المريض'] ?? map['details']?['المريض'] ?? map['requesterName'] ?? map['name'] ?? '',
      createdAt: (map['createdAt'] is Timestamp) 
          ? (map['createdAt'] as Timestamp).toDate() 
          : (map['created_at'] is Timestamp) 
              ? (map['created_at'] as Timestamp).toDate() 
              : DateTime.now(),
      updatedAt: (map['updatedAt'] is Timestamp) 
          ? (map['updatedAt'] as Timestamp).toDate() 
          : (map['updated_at'] is Timestamp) 
              ? (map['updated_at'] as Timestamp).toDate() 
              : DateTime.now(),
      attachments: (map['attachments'] != null && map['attachments'] is List) 
          ? List<String>.from(map['attachments']) 
          : const [],
      donorResponses: (map['donorResponses'] ?? map['donor_responses']) != null 
          ? List<Map<String, dynamic>>.from(map['donorResponses'] ?? map['donor_responses']) 
          : const [],
      notifiedDonors: (map['notifiedDonors'] ?? map['notified_donors']) != null 
          ? List<Map<String, dynamic>>.from(map['notifiedDonors'] ?? map['notified_donors']) 
          : const [],
      latitude: (map['latitude'] as num?)?.toDouble(),
      longitude: (map['longitude'] as num?)?.toDouble(),
      roomNumber: map['roomNumber'] ?? map['room_number'],
    );
  }

  ServiceRequestModel copyWith({
    String? id,
    String? type,
    String? typeName,
    String? requesterId,
    String? requesterName,
    String? phone,
    String? wilaya,
    String? commune,
    String? address,
    String? description,
    String? urgency,
    String? status,
    String? assignedTo,
    String? assignedToName,
    String? assignedCarId,
    Map<String, dynamic>? details,
    bool? isSeenByAdmin,
    String? bloodType,
    String? hospital,
    String? patientName,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<String>? attachments,
    List<Map<String, dynamic>>? donorResponses,
    List<Map<String, dynamic>>? notifiedDonors,
    String? roomNumber,
  }) {
    return ServiceRequestModel(
      id: id ?? this.id,
      type: type ?? this.type,
      typeName: typeName ?? this.typeName,
      requesterId: requesterId ?? this.requesterId,
      requesterName: requesterName ?? this.requesterName,
      phone: phone ?? this.phone,
      wilaya: wilaya ?? this.wilaya,
      commune: commune ?? this.commune,
      address: address ?? this.address,
      description: description ?? this.description,
      urgency: urgency ?? this.urgency,
      status: status ?? this.status,
      assignedTo: assignedTo ?? this.assignedTo,
      assignedToName: assignedToName ?? this.assignedToName,
      assignedCarId: assignedCarId ?? this.assignedCarId,
      details: details ?? this.details,
      isSeenByAdmin: isSeenByAdmin ?? this.isSeenByAdmin,
      bloodType: bloodType ?? this.bloodType,
      hospital: hospital ?? this.hospital,
      patientName: patientName ?? this.patientName,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      attachments: attachments ?? this.attachments,
      donorResponses: donorResponses ?? this.donorResponses,
      notifiedDonors: notifiedDonors ?? this.notifiedDonors,
      roomNumber: roomNumber ?? this.roomNumber,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ServiceRequestModel && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
