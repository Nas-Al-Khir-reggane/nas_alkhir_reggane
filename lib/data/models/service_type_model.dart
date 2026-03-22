class ServiceTypeModel {
  final String id;
  final String name;
  final String icon;
  final bool isActive;
  final List<String> fields;

  ServiceTypeModel({
    required this.id,
    required this.name,
    required this.icon,
    this.isActive = true,
    this.fields = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'icon': icon,
      'isActive': isActive,
      'fields': fields,
    };
  }

  factory ServiceTypeModel.fromMap(Map<String, dynamic> map, [String? id]) {
    return ServiceTypeModel(
      id: id ?? map['id'] ?? '',
      name: map['name'] ?? '',
      icon: map['icon'] ?? '',
      isActive: map['isActive'] ?? true,
      fields: List<String>.from(map['fields'] ?? []),
    );
  }
}
