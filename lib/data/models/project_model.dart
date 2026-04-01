import 'package:cloud_firestore/cloud_firestore.dart';

class ProjectUpdate {
  final String id;
  final String title;
  final String description;
  final List<String> images;
  final DateTime date;

  ProjectUpdate({
    required this.id,
    required this.title,
    required this.description,
    this.images = const [],
    required this.date,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'images': images,
      'date': Timestamp.fromDate(date),
    };
  }

  factory ProjectUpdate.fromMap(Map<String, dynamic> map) {
    return ProjectUpdate(
      id: map['id'] ?? '',
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      images: List<String>.from(map['images'] ?? []),
      date: map['date'] is Timestamp 
          ? (map['date'] as Timestamp).toDate() 
          : DateTime.now(),
    );
  }
}

class ProjectModel {
  final String id;
  final String name;
  final String description;
  final String category;
  final double budget;
  final double collected;
  final DateTime? deadline;
  final String status; // active, completed, paused
  final List<ProjectUpdate> updates;
  final DateTime createdAt;
  final String createdBy;
  final int donorsCount;
  final List<String> assignedWorkers;
  final bool isSubscription; // حقل التبرع الدائم
  final bool isMonthlyGoal; // ✨ NEW: حقل تمييز الهدف الشهري عن الإجمالي

  ProjectModel({
    required this.id,
    required this.name,
    required this.description,
    required this.category,
    required this.budget,
    this.collected = 0.0,
    this.deadline,
    this.status = 'active',
    this.updates = const [],
    required this.createdAt,
    required this.createdBy,
    this.donorsCount = 0,
    this.assignedWorkers = const [],
    this.isSubscription = false,
    this.isMonthlyGoal = false, // ✨ NEW
  });

  double get progressPercentage => budget > 0 ? (collected / budget * 100).clamp(0, 100) : 0;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'category': category,
      'budget': budget,
      'collected': collected,
      'deadline': deadline != null ? Timestamp.fromDate(deadline!) : null,
      'status': status,
      'updates': updates.map((x) => x.toMap()).toList(),
      'createdAt': Timestamp.fromDate(createdAt),
      'createdBy': createdBy,
      'donorsCount': donorsCount,
      'assignedWorkers': assignedWorkers,
      'isSubscription': isSubscription,
      'isMonthlyGoal': isMonthlyGoal, // ✨ NEW
    };
  }

  factory ProjectModel.fromMap(Map<String, dynamic> map, [String? docId]) {
    return ProjectModel(
      id: docId ?? map['id'] ?? '',
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      category: map['category'] ?? '',
      budget: (map['budget'] ?? 0.0).toDouble(),
      collected: (map['collected'] ?? 0.0).toDouble(),
      deadline: map['deadline'] is Timestamp ? (map['deadline'] as Timestamp).toDate() : null,
      status: map['status'] ?? 'active',
      updates: List<ProjectUpdate>.from(map['updates']?.map((x) => ProjectUpdate.fromMap(x)) ?? []),
      createdAt: (map['createdAt'] is Timestamp) 
          ? (map['createdAt'] as Timestamp).toDate() 
          : DateTime.now(),
      createdBy: map['createdBy'] ?? '',
      donorsCount: map['donorsCount'] ?? 0,
      assignedWorkers: List<String>.from(map['assignedWorkers'] ?? []),
      isSubscription: map['isSubscription'] ?? false,
      isMonthlyGoal: map['isMonthlyGoal'] ?? false, // ✨ NEW
    );
  }

  ProjectModel copyWith({
    String? id,
    String? name,
    String? description,
    String? category,
    double? budget,
    double? collected,
    DateTime? deadline,
    String? status,
    List<ProjectUpdate>? updates,
    DateTime? createdAt,
    String? createdBy,
    int? donorsCount,
    List<String>? assignedWorkers,
    bool? isSubscription,
    bool? isMonthlyGoal, // ✨ NEW
  }) {
    return ProjectModel(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      category: category ?? this.category,
      budget: budget ?? this.budget,
      collected: collected ?? this.collected,
      deadline: deadline ?? this.deadline,
      status: status ?? this.status,
      updates: updates ?? this.updates,
      createdAt: createdAt ?? this.createdAt,
      createdBy: createdBy ?? this.createdBy,
      donorsCount: donorsCount ?? this.donorsCount,
      assignedWorkers: assignedWorkers ?? this.assignedWorkers,
      isSubscription: isSubscription ?? this.isSubscription,
      isMonthlyGoal: isMonthlyGoal ?? this.isMonthlyGoal, // ✨ NEW
    );
  }
}

