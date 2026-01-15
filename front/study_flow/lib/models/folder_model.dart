class FolderModel {
  final String id;
  final String name;
  final DateTime createdAt;

  FolderModel({required this.id, required this.name, required this.createdAt});

  factory FolderModel.fromJson(Map<String, dynamic> json) {
    return FolderModel(
      id: json['id'],
      name: json['name'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toMap() {
    return {'id': id, 'name': name, 'created_at': createdAt.toIso8601String()};
  }
}
