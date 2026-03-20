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
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      phone: map['phone'] ?? '',
      wilaya: map['wilaya'] ?? '',
      address: map['address'] ?? '',
      role: UserRole.values.firstWhere((e) => e.name == map['role'], orElse: () => UserRole.guest),
      permissions: List<String>.from(map['permissions'] ?? []),
      isApproved: map['isApproved'] ?? false,
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      profileImage: map['profileImage'],
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
    );
  }
}
