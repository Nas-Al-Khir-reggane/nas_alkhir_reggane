import 'package:cloud_firestore/cloud_firestore.dart';

enum UserRole { superAdmin, admin, worker, donor, beneficiary, guest }

extension UserRoleExtension on UserRole {
  String get displayName {
    switch (this) {
      case UserRole.superAdmin:
        return 'مدير عام';
      case UserRole.admin:
        return 'مدير';
      case UserRole.worker:
        return 'عامل/متطوع';
      case UserRole.donor:
        return 'متبرع';
      case UserRole.beneficiary:
        return 'مستفيد';
      case UserRole.guest:
        return 'زائر';
    }
  }
}

class UserModel {
  final String id;
  final String name;
  final String email;
  final String phone;
  final String wilaya;
  final String address;
  final UserRole role;
  final List<String> permissions;
  final bool isApproved;
  final DateTime createdAt;
  final String? profileImage;
  
  // Worker specific fields
  final String? workerRole;
  final bool isAvailable;
  final bool isActive;
  final int completedTasks;
  final int totalTrips;
  final double rating;
  final int ratingCount;
  final DateTime? lastActivity;
  final int currentTasksCount;
  final String? notes;

  UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.wilaya,
    required this.address,
    required this.role,
    this.permissions = const [],
    this.isApproved = false,
    required this.createdAt,
    this.profileImage,
    this.workerRole,
    this.isAvailable = true,
    this.isActive = true,
    this.completedTasks = 0,
    this.totalTrips = 0,
    this.rating = 0.0,
    this.ratingCount = 0,
    this.lastActivity,
    this.currentTasksCount = 0,
    this.notes,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'phone': phone,
      'wilaya': wilaya,
      'address': address,
      'role': role.name,
      'permissions': permissions,
      'isApproved': isApproved,
      'createdAt': Timestamp.fromDate(createdAt),
      'profileImage': profileImage,
      'workerRole': workerRole,
      'isAvailable': isAvailable,
      'isActive': isActive,
      'completedTasks': completedTasks,
      'totalTrips': totalTrips,
      'rating': rating,
      'ratingCount': ratingCount,
      'lastActivity': lastActivity != null ? Timestamp.fromDate(lastActivity!) : null,
      'currentTasksCount': currentTasksCount,
      'notes': notes,
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map, [String? docId]) {
    return UserModel(
      id: docId ?? map['id'] ?? '',
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      phone: map['phone'] ?? '',
      wilaya: map['wilaya'] ?? '',
      address: map['address'] ?? '',
      role: UserRole.values.firstWhere((e) => e.name == map['role'], orElse: () => UserRole.guest),
      permissions: List<String>.from(map['permissions'] ?? []),
      isApproved: map['isApproved'] ?? false,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      profileImage: map['profileImage'],
      workerRole: map['workerRole'],
      isAvailable: map['isAvailable'] ?? true,
      isActive: map['isActive'] ?? true,
      completedTasks: map['completedTasks'] ?? 0,
      totalTrips: map['totalTrips'] ?? 0,
      rating: (map['rating'] ?? 0.0).toDouble(),
      ratingCount: map['ratingCount'] ?? 0,
      lastActivity: (map['lastActivity'] as Timestamp?)?.toDate(),
      currentTasksCount: map['currentTasksCount'] ?? 0,
      notes: map['notes'],
    );
  }

  UserModel copyWith({
    String? id,
    String? name,
    String? email,
    String? phone,
    String? wilaya,
    String? address,
    UserRole? role,
    List<String>? permissions,
    bool? isApproved,
    DateTime? createdAt,
    String? profileImage,
    String? workerRole,
    bool? isAvailable,
    bool? isActive,
    int? completedTasks,
    int? totalTrips,
    double? rating,
    int? ratingCount,
    DateTime? lastActivity,
    int? currentTasksCount,
    String? notes,
  }) {
    return UserModel(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      wilaya: wilaya ?? this.wilaya,
      address: address ?? this.address,
      role: role ?? this.role,
      permissions: permissions ?? this.permissions,
      isApproved: isApproved ?? this.isApproved,
      createdAt: createdAt ?? this.createdAt,
      profileImage: profileImage ?? this.profileImage,
      workerRole: workerRole ?? this.workerRole,
      isAvailable: isAvailable ?? this.isAvailable,
      isActive: isActive ?? this.isActive,
      completedTasks: completedTasks ?? this.completedTasks,
      totalTrips: totalTrips ?? this.totalTrips,
      rating: rating ?? this.rating,
      ratingCount: ratingCount ?? this.ratingCount,
      lastActivity: lastActivity ?? this.lastActivity,
      currentTasksCount: currentTasksCount ?? this.currentTasksCount,
      notes: notes ?? this.notes,
    );
  }
}
