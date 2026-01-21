class ProjectModel {
  // 1. int를 String으로 변경
  final String id;
  String name;
  String tags;
  DateTime createdAt;

  ProjectModel({
    required this.id, // 기본값 0 삭제 (String이므로)
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
      // 2. 들어오는 값이 숫자라도 문자로 변환해서 안전하게 받음
      id: json['id'].toString(),
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
    return ProjectModel(id: id, name: name, tags: tags, createdAt: createdAt);
  }
}
