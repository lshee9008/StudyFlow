import 'package:study_flow/models/user_model.dart';
import 'all_db_helper.dart'; // 위에서 만든 파일 import

class UsersDBHelper {
  // 유저 추가
  static Future<int> insertUser(UserModel user) async {
    final db = await LocalDatabase.instance.database;
    return await db.insert('users', user.toMap());
  }

  // 유저 조회
  static Future<List<UserModel>> selectUser() async {
    final db = await LocalDatabase.instance.database;
    final result = await db.query('users');
    return result.map((json) => UserModel.fromJson(json)).toList();
  }

  // 유저 수정
  static Future<int> updateUser(
    String id, {
    String? name,
    String? password,
  }) async {
    final db = await LocalDatabase.instance.database;
    final Map<String, dynamic> updates = {};
    if (name != null) updates['name'] = name;
    if (password != null) updates['password'] = password;

    if (updates.isEmpty) return 0;
    return await db.update('users', updates, where: 'id = ?', whereArgs: [id]);
  }

  // 유저 삭제
  static Future<int> deleteUser(String id) async {
    final db = await LocalDatabase.instance.database;
    return await db.delete('users', where: 'id = ?', whereArgs: [id]);
  }
}
