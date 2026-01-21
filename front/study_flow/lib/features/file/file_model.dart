class FileModel {
  final String id;
  final String projectId; // [중요] DB의 project_id와 연결
  final String title;
  final String content;
  final String? summary;
  final String tags;
  final String? icon;
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
      id: json['id']?.toString() ?? '',
      projectId: json['project_id']?.toString() ?? '', // [중요] 매핑 확인
      title: json['title']?.toString() ?? '제목 없음',
      content: json['content']?.toString() ?? '',
      summary: json['summary']?.toString(),
      tags: json['tags']?.toString() ?? '',
      icon: json['icon']?.toString(),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'project_id': projectId, // [중요] DB 컬럼명 project_id와 일치해야 함
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
