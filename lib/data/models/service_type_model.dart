class ServiceTypeModel {
  final String id;
  final String name;
  final String icon;
  final String? color; // ✨ حقل اللون الجديد للتصنيف البصري
  final bool isActive;
  final int popularity; 
  final List<String> fields;
  final Map<String, String> fieldConfigs; // ✨ نوع كل حقل (text, selection, date, etc.)

  ServiceTypeModel({
    required this.id,
    required this.name,
    required this.icon,
    this.color,
    this.isActive = true,
    this.popularity = 0,
    this.fields = const [],
    this.fieldConfigs = const {},
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'icon': icon,
      'color': color,
      'isActive': isActive,
      'popularity': popularity,
      'fields': fields,
      'fieldConfigs': fieldConfigs,
    };
  }

  factory ServiceTypeModel.fromMap(Map<String, dynamic> map, [String? id]) {
    return ServiceTypeModel(
      id: id ?? map['id'] ?? '',
      name: map['name'] ?? '',
      icon: map['icon'] ?? '',
      color: map['color'],
      isActive: map['isActive'] ?? true,
      popularity: map['popularity'] ?? 0,
      fields: List<String>.from(map['fields'] ?? []),
      fieldConfigs: Map<String, String>.from(map['fieldConfigs'] ?? {}),
    );
  }
}

