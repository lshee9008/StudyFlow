// ignore_for_file: non_constant_identifier_names

class ProjectModel {
  final String id;
  String user_id;
  final DateTime create_at;
  DateTime update_at;
  String name;
  String tags;
  String icon;
  int is_sync;

  ProjectModel({
    required this.id,
    required this.user_id,
    required this.create_at,
    required this.update_at,
    required this.name,
    required this.tags,
    required this.icon,
    required this.is_sync,
  });

  factory ProjectModel.fromJson(Map<String, dynamic> json) {
    return ProjectModel(
      // [안전장치] 데이터가 없어도 에러가 나지 않도록 처리
      id: json['id']?.toString() ?? '',
      user_id: json['user_id'] ?? '',
      create_at: json['create_at'] != null
          ? DateTime.tryParse(json['create_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      update_at: json['update_at'] != null
          ? DateTime.tryParse(json['update_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      name: json['name']?.toString() ?? '제목 없음',
      tags: json['tags']?.toString() ?? '',
      icon: json['icon']?.toString() ?? '',
      is_sync: json['is_sync'] == 1 ? 1 : 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': user_id,
      'create_at': create_at.toIso8601String(),
      'update_at': update_at.toIso8601String(),
      'name': name,
      'tags': tags,
      'icon': icon,
      'is_sync': is_sync,
    };
  }

  // [NEW] 상태 업데이트용 복사본 생성 기능
  ProjectModel updateWith({
    DateTime? update_at,
    String? name,
    String? tags,
    String? icon,
    int? is_sync,
  }) {
    return ProjectModel(
      id: id,
      user_id: user_id,
      create_at: create_at,
      update_at: update_at ?? this.update_at,
      name: name ?? this.name,
      tags: tags ?? this.tags,
      icon: icon ?? this.icon,
      is_sync: is_sync ?? this.is_sync,
    );
  }
}
