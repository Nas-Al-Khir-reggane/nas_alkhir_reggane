class ServiceTypeModel {
  final String id;
  final String name;
  final String icon;
  final bool isActive;
  final int popularity; 
  final List<String> fields;

  ServiceTypeModel({
    required this.id,
    required this.name,
    required this.icon,
    this.isActive = true,
    this.popularity = 0,
    this.fields = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'icon': icon,
      'isActive': isActive,
      'popularity': popularity,
      'fields': fields,
    };
  }

  factory ServiceTypeModel.fromMap(Map<String, dynamic> map, [String? id]) {
    return ServiceTypeModel(
      id: id ?? map['id'] ?? '',
      name: map['name'] ?? '',
      icon: map['icon'] ?? '',
      isActive: map['isActive'] ?? true,
      popularity: map['popularity'] ?? 0,
      fields: List<String>.from(map['fields'] ?? []),
    );
  }
}

