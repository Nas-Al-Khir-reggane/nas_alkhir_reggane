import 'package:cloud_firestore/cloud_firestore.dart';

enum UserRole { superAdmin, admin, worker, donor, beneficiary, chatModerator }

extension UserRoleExtension on UserRole {
  String get displayName {
    switch (this) {
      case UserRole.superAdmin:
        return 'مدير عام';
      case UserRole.admin:
        return 'مدير';
      case UserRole.worker:
        return 'متطوع';
      case UserRole.donor:
        return 'متبرع';
      case UserRole.beneficiary:
        return 'مستفيد';
      case UserRole.chatModerator:
        return 'مشرف الدردشة';
    }
  }
}

class UserModel {
  final String id;
  final String name;
  final String email;
  final String phone;
  final String wilaya;
  final String commune; // حقل البلدية الجديد
  final String address;
  final UserRole role;
  final List<String> permissions;
  final bool isApproved;
  final DateTime createdAt;
  final String? profileImage;
  final String? bloodType; // حقل زمرة الدم الجديد
  final bool receiveBloodAlerts; // خيار استقبال تنبيهات التبرع بالدم
  final DateTime? lastDonatedAt; // تاريخ آخر تبرع بالدم
  final bool isDonorAvailable; // هل المستخدم جاهز للتبرع حالياً؟
  final int bloodDonationsCount; // عدد تبرعات الدم الناجحة ✨
  final String? activeBloodRequestId; // ✨ معرف طلب الدم النشط للمتبرع
  final String gender; // ✨ حقل الجنس
  final String? avatarSeed; // ✨ مفتاح توليد الأفاتار الرقمي
  final String? avatarType; // ✨ نوع الأفاتار الرقمي (مثلاً: human, robot)
  
  // Worker specific fields
  final String? workerRole;
  final List<String> volunteerServices; // قائمة الخدمات التطوعية المختارة ✨
  final String? ghuslExpertise; // مستوى الخبرة في التغسيل (خبير/مساعد) ✨
  final String? otherServices; // خدمات أخرى يدوية ✨
  final bool isAvailable;
  final bool isActive;
  final int completedTasks;
  final int totalTrips;
  final double rating;
  final int ratingCount;
  final DateTime? lastActivity;
  final int currentTasksCount;
  final String? notes;
  // الأدوار الإضافية التي يمنحها المدير: 'canDonate', 'canRequestService'
  final List<String> additionalRoles;

  UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.wilaya,
    this.commune = '',
    required this.address,
    required this.role,
    this.permissions = const [],
    this.isApproved = false,
    required this.createdAt,
    this.profileImage,
    this.bloodType,
    this.receiveBloodAlerts = true,
    this.lastDonatedAt,
    this.isDonorAvailable = true,
    this.bloodDonationsCount = 0,
    this.workerRole,
    this.volunteerServices = const [],
    this.ghuslExpertise,
    this.otherServices,
    this.isAvailable = true,
    this.isActive = true,
    this.completedTasks = 0,
    this.totalTrips = 0,
    this.rating = 0.0,
    this.ratingCount = 0,
    this.lastActivity,
    this.currentTasksCount = 0,
    this.notes,
    this.activeBloodRequestId,
    this.gender = 'غير محدد',
    this.avatarSeed,
    this.avatarType = 'avataaars',
    this.additionalRoles = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'phone': phone,
      'wilaya': wilaya,
      'commune': commune,
      'address': address,
      'role': role.name,
      'permissions': permissions,
      'isApproved': isApproved,
      'createdAt': Timestamp.fromDate(createdAt),
      'profileImage': profileImage,
      'bloodType': bloodType,
      'receiveBloodAlerts': receiveBloodAlerts,
      'lastDonatedAt': lastDonatedAt != null ? Timestamp.fromDate(lastDonatedAt!) : null,
      'isDonorAvailable': isDonorAvailable,
      'bloodDonationsCount': bloodDonationsCount,
      'workerRole': workerRole,
      'volunteerServices': volunteerServices,
      'ghuslExpertise': ghuslExpertise,
      'otherServices': otherServices,
      'isAvailable': isAvailable,
      'isActive': isActive,
      'completedTasks': completedTasks,
      'totalTrips': totalTrips,
      'rating': rating,
      'ratingCount': ratingCount,
      'lastActivity': lastActivity != null ? Timestamp.fromDate(lastActivity!) : null,
      'currentTasksCount': currentTasksCount,
      'notes': notes,
      'activeBloodRequestId': activeBloodRequestId,
      'gender': gender,
      'avatarSeed': avatarSeed,
      'avatarType': avatarType,
      'additionalRoles': additionalRoles,
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map, [String? docId]) {
    UserRole getRoleFromString(String? roleStr) {
      if (roleStr == null) return UserRole.beneficiary;
      String normalized = roleStr.replaceAll('_', '').toLowerCase();
      if (normalized == 'superadmin') return UserRole.superAdmin;
      if (normalized == 'admin' || normalized == 'subadmin') return UserRole.admin;
      if (normalized == 'worker') return UserRole.worker;
      if (normalized == 'donor') return UserRole.donor;
      if (normalized == 'beneficiary') return UserRole.beneficiary;
      if (normalized == 'chatmoderator' || normalized == 'chatmod') return UserRole.chatModerator;
      return UserRole.beneficiary;
    }

    return UserModel(
      id: docId ?? map['id'] ?? '',
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      phone: map['phone'] ?? '',
      wilaya: map['wilaya'] ?? '',
      commune: map['commune'] ?? '',
      address: map['address'] ?? '',
      role: getRoleFromString(map['role']),
      permissions: List<String>.from(map['permissions'] ?? []),
      isApproved: map['isApproved'] ?? false,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      profileImage: map['profileImage'],
      bloodType: map['bloodType'],
      receiveBloodAlerts: map['receiveBloodAlerts'] ?? true,
      lastDonatedAt: (map['lastDonatedAt'] as Timestamp?)?.toDate(),
      isDonorAvailable: map['isDonorAvailable'] ?? true,
      bloodDonationsCount: map['bloodDonationsCount'] ?? 0,
      workerRole: map['workerRole'],
      volunteerServices: List<String>.from(map['volunteerServices'] ?? []),
      ghuslExpertise: map['ghuslExpertise'],
      otherServices: map['otherServices'],
      isAvailable: map['isAvailable'] ?? true,
      isActive: map['isActive'] ?? true,
      completedTasks: map['completedTasks'] ?? 0,
      totalTrips: map['totalTrips'] ?? 0,
      rating: (map['rating'] ?? 0.0).toDouble(),
      ratingCount: map['ratingCount'] ?? 0,
      lastActivity: (map['lastActivity'] as Timestamp?)?.toDate(),
      currentTasksCount: map['currentTasksCount'] ?? 0,
      notes: map['notes'],
      activeBloodRequestId: map['activeBloodRequestId'],
      gender: map['gender'] ?? 'غير محدد',
      avatarSeed: map['avatarSeed'],
      avatarType: map['avatarType'] ?? 'avataaars',
      additionalRoles: List<String>.from(map['additionalRoles'] ?? []),
    );
  }

  UserModel copyWith({
    String? id,
    String? name,
    String? email,
    String? phone,
    String? wilaya,
    String? commune,
    String? address,
    UserRole? role,
    List<String>? permissions,
    bool? isApproved,
    DateTime? createdAt,
    String? profileImage,
    String? bloodType,
    bool? receiveBloodAlerts,
    DateTime? lastDonatedAt,
    bool? isDonorAvailable,
    int? bloodDonationsCount,
    String? workerRole,
    List<String>? volunteerServices,
    String? ghuslExpertise,
    String? otherServices,
    bool? isAvailable,
    bool? isActive,
    int? completedTasks,
    int? totalTrips,
    double? rating,
    int? ratingCount,
    DateTime? lastActivity,
    int? currentTasksCount,
    String? notes,
    String? activeBloodRequestId,
    String? gender,
    String? avatarSeed,
    String? avatarType,
    List<String>? additionalRoles,
  }) {
    return UserModel(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      wilaya: wilaya ?? this.wilaya,
      commune: commune ?? this.commune,
      address: address ?? this.address,
      role: role ?? this.role,
      permissions: permissions ?? this.permissions,
      isApproved: isApproved ?? this.isApproved,
      createdAt: createdAt ?? this.createdAt,
      profileImage: profileImage ?? this.profileImage,
      bloodType: bloodType ?? this.bloodType,
      receiveBloodAlerts: receiveBloodAlerts ?? this.receiveBloodAlerts,
      lastDonatedAt: lastDonatedAt ?? this.lastDonatedAt,
      isDonorAvailable: isDonorAvailable ?? this.isDonorAvailable,
      bloodDonationsCount: bloodDonationsCount ?? this.bloodDonationsCount,
      workerRole: workerRole ?? this.workerRole,
      volunteerServices: volunteerServices ?? this.volunteerServices,
      ghuslExpertise: ghuslExpertise ?? this.ghuslExpertise,
      otherServices: otherServices ?? this.otherServices,
      isAvailable: isAvailable ?? this.isAvailable,
      isActive: isActive ?? this.isActive,
      completedTasks: completedTasks ?? this.completedTasks,
      totalTrips: totalTrips ?? this.totalTrips,
      rating: rating ?? this.rating,
      ratingCount: ratingCount ?? this.ratingCount,
      lastActivity: lastActivity ?? this.lastActivity,
      currentTasksCount: currentTasksCount ?? this.currentTasksCount,
      notes: notes ?? this.notes,
      activeBloodRequestId: activeBloodRequestId ?? this.activeBloodRequestId,
      gender: gender ?? this.gender,
      avatarSeed: avatarSeed ?? this.avatarSeed,
      avatarType: avatarType ?? this.avatarType,
      additionalRoles: additionalRoles ?? this.additionalRoles,
    );
  }

  int get smartDonationCoolOffDays {
    if (gender == 'ذكر') return 60;
    if (gender == 'أنثى') return 90;
    return 90; // Default safe period
  }

  bool get canDonateBloodSmart {
    if (lastDonatedAt == null) return true;
    final now = DateTime.now();
    final difference = now.difference(lastDonatedAt!).inDays;
    return difference >= smartDonationCoolOffDays;
  }
}

