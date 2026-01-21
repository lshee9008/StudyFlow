class FileModel {
  final String id;
  final String projectId;
  final String title; // name -> title 변경
  final String content; // content_raw -> content 변경 (JSON 문자열 저장)
  final String? summary; // AI 요약 저장 (없을 수 있으므로 nullable)
  final String tags;
  final DateTime createdAt;
  final DateTime? updatedAt; // 수정 시간 (없을 수 있으므로 nullable)

  FileModel({
    required this.id,
    required this.projectId,
    required this.title,
    this.content = '', // 기본값 빈 문자열
    this.summary, // 초기엔 null
    this.tags = '',
    required this.createdAt,
    this.updatedAt,
  });

  // 1. DB에서 가져올 때 (Select)
  factory FileModel.fromJson(Map<String, dynamic> json) {
    return FileModel(
      id: json['id'].toString(), // 숫자로 들어와도 문자로 변환
      projectId: json['project_id'].toString(),
      title: json['title'],
      content: json['content'] ?? '',
      summary: json['summary'], // DB에 null이면 null로 들어옴
      tags: json['tags'] ?? '',
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : null,
    );
  }

  // 2. DB에 저장할 때 (Insert/Update)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'project_id': projectId,
      'title': title,
      'content': content,
      'summary': summary,
      'tags': tags,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(), // null이면 저장 안 됨(또는 null 저장)
    };
  }

  // 3. 수정할 때 사용 (Immutable 객체 복사)
  FileModel copyWith({
    String? title,
    String? content,
    String? summary,
    String? tags,
    DateTime? updatedAt,
  }) {
    return FileModel(
      id: this.id,
      projectId: this.projectId,
      title: title ?? this.title,
      content: content ?? this.content,
      summary: summary ?? this.summary,
      tags: tags ?? this.tags,
      createdAt: this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
