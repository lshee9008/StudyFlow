class ProjectModel {
  final String id;
  final String name;
  final String tags;
  final DateTime createdAt;

  ProjectModel({required this.id, required this.name, required this.createdAt, required this.tags});

  factory ProjectModel.fromJson(Map<String, dynamic> json) {
    return ProjectModel(
      id: json['id'],
      name: json['name'],
      tags: json['tags'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toMap() {
    return {'id': id, 'name': name, 'tags' : tags, 'created_at': createdAt.toIso8601String()};
  }
}
