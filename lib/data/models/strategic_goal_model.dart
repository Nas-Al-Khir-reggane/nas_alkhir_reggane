import 'package:cloud_firestore/cloud_firestore.dart';

enum GoalType { donations, beneficiaries, services, other }

class StrategicGoalModel {
  final String id;
  final String title;
  final String description;
  final GoalType type;
  final double targetValue;
  final double currentValue; // This will likely be calculated dynamically, but stored for reference
  final String unit; // e.g., "دج", "طرد", "عائلة"
  final DateTime startDate;
  final DateTime endDate;
  final bool isActive;
  final String? serviceTypeId; // If type is 'services', which service?
  final String? projectId; // NEW: Pre-selected project for donation
  final String? projectName; // NEW: Pre-selected project name

  StrategicGoalModel({
    required this.id,
    required this.title,
    required this.description,
    required this.type,
    required this.targetValue,
    this.currentValue = 0,
    required this.unit,
    required this.startDate,
    required this.endDate,
    this.isActive = true,
    this.serviceTypeId,
    this.projectId,
    this.projectName,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'type': type.name,
      'targetValue': targetValue,
      'currentValue': currentValue,
      'unit': unit,
      'startDate': Timestamp.fromDate(startDate),
      'endDate': Timestamp.fromDate(endDate),
      'isActive': isActive,
      'serviceTypeId': serviceTypeId,
      'projectId': projectId,
      'projectName': projectName,
    };
  }

  factory StrategicGoalModel.fromMap(Map<String, dynamic> map, String docId) {
    return StrategicGoalModel(
      id: docId,
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      type: GoalType.values.firstWhere((e) => e.name == map['type'], orElse: () => GoalType.other),
      targetValue: (map['targetValue'] ?? 0.0).toDouble(),
      currentValue: (map['currentValue'] ?? 0.0).toDouble(),
      unit: map['unit'] ?? '',
      startDate: (map['startDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      endDate: (map['endDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isActive: map['isActive'] ?? true,
      serviceTypeId: map['serviceTypeId'],
      projectId: map['projectId'],
      projectName: map['projectName'],
    );
  }

  double get progressPercentage => targetValue > 0 ? (currentValue / targetValue) : 0.0;
  bool get isCompleted => currentValue >= targetValue;

  StrategicGoalModel copyWith({
    String? id,
    String? title,
    String? description,
    GoalType? type,
    double? targetValue,
    double? currentValue,
    String? unit,
    DateTime? startDate,
    DateTime? endDate,
    bool? isActive,
    String? serviceTypeId,
    String? projectId,
    String? projectName,
  }) {
    return StrategicGoalModel(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      type: type ?? this.type,
      targetValue: targetValue ?? this.targetValue,
      currentValue: currentValue ?? this.currentValue,
      unit: unit ?? this.unit,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      isActive: isActive ?? this.isActive,
      serviceTypeId: serviceTypeId ?? this.serviceTypeId,
      projectId: projectId ?? this.projectId,
      projectName: projectName ?? this.projectName,
    );
  }
}
