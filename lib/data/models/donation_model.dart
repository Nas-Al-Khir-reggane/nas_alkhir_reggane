import 'package:cloud_firestore/cloud_firestore.dart';

class DonationModel {
  final String id;
  final String donorId;
  final String donorName;
  final double amount;
  final String projectId;
  final String projectName;
  final String method; // cash, bank, online
  final String status; // pending, confirmed
  final DateTime date;
  final String? notes;
  final bool isRecurring;
  final bool isAnonymous;
  final bool requestPrayerPost;
  final String? prayerType; // deceased, healing, barakah, parents, general
  final String? prayerTarget; // name of the person
  final String? prayerColor; // emerald, sapphire, gold, rose, slate
  final String? prayerAction; // dua, request
  final String? prayerCustomMessage; // donor-defined text shown on card
  final String? proofImageUrl;
  final String? proofImageId;
  final String? serviceRequestId; // ✨ مرتب بطلب خدمة معين (خاص بحزب المائة ألف)

  DonationModel({
    required this.id,
    required this.donorId,
    required this.donorName,
    required this.amount,
    required this.projectId,
    required this.projectName,
    required this.method,
    this.status = 'pending',
    required this.date,
    this.notes,
    this.isRecurring = false,
    this.isAnonymous = false,
    this.requestPrayerPost = false,
    this.prayerType,
    this.prayerTarget,
    this.prayerColor,
    this.prayerAction,
    this.prayerCustomMessage,
    this.proofImageUrl,
    this.proofImageId,
    this.serviceRequestId,
  });

  static String normalizeMethod(String? rawMethod) {
    final value = (rawMethod ?? '').trim().toLowerCase();
    switch (value) {
      case 'cash':
      case 'نقد':
      case 'نقدي':
        return 'cash';
      case 'bank':
      case 'bank_transfer':
      case 'transfer':
      case 'wire':
      case 'حوالة':
      case 'تحويل':
      case 'تحويل بنكي':
        return 'bank';
      case 'online':
      case 'electronic':
      case 'card':
      case 'visa':
      case 'الكتروني':
      case 'إلكتروني':
        return 'online';
      default:
        return 'cash';
    }
  }

  static String methodLabel(String? rawMethod) {
    switch (normalizeMethod(rawMethod)) {
      case 'cash':
        return 'نقدي';
      case 'bank':
        return 'تحويل بنكي';
      case 'online':
        return 'إلكتروني';
      default:
        return 'نقدي';
    }
  }

  Map<String, dynamic> toMap() {
    final normalizedMethod = normalizeMethod(method);
    return {
      'id': id,
      'donorId': donorId,
      'donorName': donorName,
      'amount': amount,
      'projectId': projectId,
      'projectName': projectName,
      'method': normalizedMethod,
      'paymentMethod': normalizedMethod,
      'status': status,
      'date': Timestamp.fromDate(date),
      'notes': notes,
      'isRecurring': isRecurring,
      'isAnonymous': isAnonymous,
      'requestPrayerPost': requestPrayerPost,
      'prayerType': prayerType,
      'prayerTarget': prayerTarget,
      'prayerColor': prayerColor,
      'prayerAction': prayerAction,
      'prayerCustomMessage': prayerCustomMessage,
      'proofImageUrl': proofImageUrl,
      'proofImageId': proofImageId,
      'serviceRequestId': serviceRequestId,
    };
  }

  factory DonationModel.fromMap(Map<String, dynamic> map) {
    return DonationModel(
      id: map['id'] ?? '',
      donorId: map['donorId'] ?? '',
      donorName: map['donorName'] ?? '',
      amount: (map['amount'] ?? 0.0).toDouble(),
      projectId: map['projectId'] ?? '',
      projectName: map['projectName'] ?? '',
        method: normalizeMethod(map['method'] ?? map['paymentMethod']),
      status: map['status'] ?? 'pending',
      date: map['date'] is Timestamp 
          ? (map['date'] as Timestamp).toDate() 
          : DateTime.now(),
      notes: map['notes'],
      isRecurring: map['isRecurring'] ?? false,
      isAnonymous: map['isAnonymous'] ?? false,
      requestPrayerPost: map['requestPrayerPost'] ?? false,
      prayerType: map['prayerType'],
      prayerTarget: map['prayerTarget'],
      prayerColor: map['prayerColor'],
      prayerAction: map['prayerAction'],
      prayerCustomMessage: map['prayerCustomMessage'] ?? map['prayerMessage'],
      proofImageUrl: map['proofImageUrl'],
      proofImageId: map['proofImageId'],
      serviceRequestId: map['serviceRequestId'],
    );
  }

  DonationModel copyWith({
    String? id,
    String? donorId,
    String? donorName,
    double? amount,
    String? projectId,
    String? projectName,
    String? method,
    String? status,
    DateTime? date,
    String? notes,
    bool? isRecurring,
    bool? isAnonymous,
    String? prayerColor,
    String? prayerAction,
    String? prayerCustomMessage,
    String? proofImageUrl,
    String? proofImageId,
    String? serviceRequestId,
  }) {
    return DonationModel(
      id: id ?? this.id,
      donorId: donorId ?? this.donorId,
      donorName: donorName ?? this.donorName,
      amount: amount ?? this.amount,
      projectId: projectId ?? this.projectId,
      projectName: projectName ?? this.projectName,
      method: method ?? this.method,
      status: status ?? this.status,
      date: date ?? this.date,
      notes: notes ?? this.notes,
      isRecurring: isRecurring ?? this.isRecurring,
      isAnonymous: isAnonymous ?? this.isAnonymous,
      prayerColor: prayerColor ?? this.prayerColor,
      prayerAction: prayerAction ?? this.prayerAction,
      prayerCustomMessage: prayerCustomMessage ?? this.prayerCustomMessage,
      proofImageUrl: proofImageUrl ?? this.proofImageUrl,
      proofImageId: proofImageId ?? this.proofImageId,
      serviceRequestId: serviceRequestId ?? this.serviceRequestId,
    );
  }
}

