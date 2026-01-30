class UserModel {
  String? id;
  String name;
  String join_path;
  String password;
  String social_id;

  UserModel({
    required this.id,
    required this.name,
    required this.join_path,
    required this.password,
    required this.social_id,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      // [안전장치] 데이터가 없어도 에러가 나지 않도록 처리
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '제목 없음',
      join_path: json['join_path']?.toString() ?? '',
      password: json['password']?.toString() ?? '',
      social_id: json['social_id']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'join_path': join_path,
      'password': password,
      'social_id': social_id,
    };
  }

  UserModel updateWith({String? name, String? password}) {
    return UserModel(
      id: this.id,
      name: name ?? this.name,
      join_path: this.join_path,
      password: password ?? this.password,
      social_id: this.social_id,
    );
  }
}
