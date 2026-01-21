class ProjectFileModel {
  final int id;
  final int projectId;
  String name;
  String tags;
  DateTime createdAt;

  factory ProjectFileModel.fromJson(Map<String, dynamic> json) {
    return ProjectFileModel(
      id: json['id'],
      projectId: json['project_id'],
      name: json['name'],
      tags: json['tags'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  ProjectFileModel({this.id = 0, required this.projectId, required this.name, required this.tags, required this.createdAt});
}