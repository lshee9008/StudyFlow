import 'dart:io';

class FileModel {
  final String id;
  final String project_id;
  final DateTime create_at;
  final DateTime? update_at;
  final String title;
  final String tags;
  final String? icon;
  final String? prompt;
  final String content;
  final String? summary;

  FileModel({
    required this.id,
    required this.project_id,
    required this.create_at,
    required this.update_at,
    required this.title,
    required this.tags,
    required this.icon,
    required this.prompt,
    required this.content,
    required this.summary,
  });

  factory FileModel.fromJson(Map<String, dynamic> json) {
    return FileModel(
      id: json['id']?.toString() ?? '',
      project_id: json['project_id']?.toString() ?? '',
      create_at: json['create_at'] != null
          ? DateTime.tryParse(json['create_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      update_at: json['update_at'] != null
          ? DateTime.tryParse(json['update_at'].toString())
          : null,
      title: json['title']?.toString() ?? '제목 없음',
      tags: json['tags']?.toString() ?? '',
      icon: json['icon']?.toString() ?? '',
      prompt: json['prompt']?.toString() ?? '',
      content: json['content']?.toString() ?? '',
      summary: json['summary']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'project_id': project_id,
      'create_at': create_at.toIso8601String(),
      'update_at': update_at?.toIso8601String(),
      'title': title,
      'tags': tags,
      'icon': icon,
      'prompt': prompt,
      'content': content,
      'summary': summary,
    };
  }

  FileModel updateWith({
    DateTime? update_at,
    String? title,
    String? tags,
    String? icon,
    String? prompt,
    String? content,
    String? summary,
  }) {
    return FileModel(
      id: this.id,
      project_id: this.project_id,
      create_at: this.create_at,
      update_at: update_at ?? this.update_at,
      title: title ?? this.title,
      tags: tags ?? this.tags,
      icon: tags ?? this.icon,
      prompt: prompt ?? this.prompt,
      content: content ?? this.content,
      summary: summary ?? this.summary,
    );
  }
}
