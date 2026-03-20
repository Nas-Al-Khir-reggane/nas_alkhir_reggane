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
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'donorId': donorId,
      'donorName': donorName,
      'amount': amount,
      'projectId': projectId,
      'projectName': projectName,
      'method': method,
      'status': status,
      'date': Timestamp.fromDate(date),
      'notes': notes,
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
      method: map['method'] ?? '',
      status: map['status'] ?? 'pending',
      date: (map['date'] as Timestamp).toDate(),
      notes: map['notes'],
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
    );
  }
}
