class ProjectModel {
  final int id;
  String name;
  String tags;
  DateTime createdAt;

  ProjectModel({
    this.id = 0,
    required this.name,
    required this.createdAt,
    required this.tags,
  });

  bool equals(ProjectModel other) {
    return id == other.id &&
        name == other.name &&
        tags == other.tags &&
        createdAt == other.createdAt;
  }

  factory ProjectModel.fromJson(Map<String, dynamic> json) {
    return ProjectModel(
      id: json['id'],
      name: json['name'],
      tags: json['tags'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'tags': tags,
      'created_at': createdAt.toIso8601String().split('.').first,
    };
  }

  ProjectModel deepCopy() {
    return ProjectModel(
      id: id,
      name: name,
      tags: tags,
      createdAt: createdAt,
    );
  }
}
