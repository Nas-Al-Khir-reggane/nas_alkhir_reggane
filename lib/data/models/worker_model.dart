class WorkerModel {
  final String id;
  final String name;
  final String phone;
  final String role;
  final List<String> assignedTasks;
  final int completedTasks;
  final bool isAvailable;

  WorkerModel({
    required this.id,
    required this.name,
    required this.phone,
    required this.role,
    this.assignedTasks = const [],
    this.completedTasks = 0,
    this.isAvailable = true,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'role': role,
      'assignedTasks': assignedTasks,
      'completedTasks': completedTasks,
      'isAvailable': isAvailable,
    };
  }

  factory WorkerModel.fromMap(Map<String, dynamic> map) {
    return WorkerModel(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      phone: map['phone'] ?? '',
      role: map['role'] ?? '',
      assignedTasks: List<String>.from(map['assignedTasks'] ?? []),
      completedTasks: map['completedTasks'] ?? 0,
      isAvailable: map['isAvailable'] ?? true,
    );
  }

  WorkerModel copyWith({
    String? id,
    String? name,
    String? phone,
    String? role,
    List<String>? assignedTasks,
    int? completedTasks,
    bool? isAvailable,
  }) {
    return WorkerModel(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      role: role ?? this.role,
      assignedTasks: assignedTasks ?? this.assignedTasks,
      completedTasks: completedTasks ?? this.completedTasks,
      isAvailable: isAvailable ?? this.isAvailable,
    );
  }
}
