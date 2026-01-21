class FileModel {
  final String id;
  final String projectId;
  final String title;
  final String content;
  final String? summary;
  final String tags;
  final String? icon; // [핵심] 아이콘 필드
  final DateTime createdAt;
  final DateTime? updatedAt;

  FileModel({
    required this.id,
    required this.projectId,
    required this.title,
    this.content = '',
    this.summary,
    this.tags = '',
    this.icon,
    required this.createdAt,
    this.updatedAt,
  });

  factory FileModel.fromJson(Map<String, dynamic> json) {
    return FileModel(
      id: json['id'].toString(),
      projectId: json['project_id'].toString(),
      title: json['title'],
      content: json['content'] ?? '',
      summary: json['summary'],
      tags: json['tags'] ?? '',
      icon: json['icon'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'project_id': projectId,
      'title': title,
      'content': content,
      'summary': summary,
      'tags': tags,
      'icon': icon,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }
}
