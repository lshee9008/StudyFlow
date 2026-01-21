class ProjectModel {
  final String id;
  String name;
  String tags;
  final DateTime createdAt;

  ProjectModel({
    required this.id,
    required this.name,
    required this.tags,
    required this.createdAt,
  });

  factory ProjectModel.fromJson(Map<String, dynamic> json) {
    return ProjectModel(
      // [안전장치] 데이터가 없어도 에러가 나지 않도록 처리
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '제목 없음',
      tags: json['tags']?.toString() ?? '',
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'tags': tags,
      'created_at': createdAt.toIso8601String(),
    };
  }

  // [NEW] 상태 업데이트용 복사본 생성 기능
  ProjectModel copyWith({String? name, String? tags}) {
    return ProjectModel(
      id: this.id,
      name: name ?? this.name,
      tags: tags ?? this.tags,
      createdAt: this.createdAt,
    );
  }
}
