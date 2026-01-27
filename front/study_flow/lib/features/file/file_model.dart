class FileModel {
  final String id;
  final String projectId;
  final String title;
  final String content;
  final String? summary;
  final String tags;
  final String? icon;
  final String? prompt; // [NEW] 프롬프트 저장용 필드 추가
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
    this.prompt, // [NEW]
    required this.createdAt,
    this.updatedAt,
  });

  factory FileModel.fromJson(Map<String, dynamic> json) {
    return FileModel(
      id: json['id']?.toString() ?? '',
      projectId: json['project_id']?.toString() ?? '',
      title: json['title']?.toString() ?? '제목 없음',
      content: json['content']?.toString() ?? '',
      summary: json['summary']?.toString(),
      tags: json['tags']?.toString() ?? '',
      icon: json['icon']?.toString(),
      prompt: json['prompt']?.toString(), // [NEW] DB에서 프롬프트 읽기
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
      'project_id': projectId,
      'title': title,
      'content': content,
      'summary': summary,
      'tags': tags,
      'icon': icon,
      'prompt': prompt, // [NEW] DB에 프롬프트 저장
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }
}
