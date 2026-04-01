class TaskTypeModel {
  final String id;
  final String name;
  final String description;
  final bool isActive;

  TaskTypeModel({
    required this.id,
    required this.name,
    required this.description,
    this.isActive = true,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'isActive': isActive,
    };
  }

  factory TaskTypeModel.fromMap(Map<String, dynamic> map, [String? id]) {
    return TaskTypeModel(
      id: id ?? map['id'] ?? '',
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      isActive: map['isActive'] ?? true,
    );
  }
}

