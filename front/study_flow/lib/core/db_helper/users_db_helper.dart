import 'package:flutter/foundation.dart';
import 'package:study_flow/models/user_model.dart';
import 'all_db_helper.dart';

class UsersDBHelper {
  static Future<int> insertUser(UserModel user) async {
    if (kIsWeb) return 0;
    final db = await LocalDatabase.instance.database;
    return await db.insert('users', user.toMap());
  }

  static Future<UserModel?> selectUser() async {
    if (kIsWeb) return null;
    final db = await LocalDatabase.instance.database;
    final result = await db.query(
      'users',
      where: 'is_login = ?',
      whereArgs: [1],
    );
    return result.isNotEmpty ? UserModel.fromJson(result.first) : null;
  }

  static Future<List<UserModel>?> selectUsers() async {
    if (kIsWeb) return null;
    final db = await LocalDatabase.instance.database;
    final result = await db.query('users');
    return result.isNotEmpty
        ? result.map((json) => UserModel.fromJson(json)).toList()
        : null;
  }

  static Future<int> updateUser(
    String id, {
    String? name,
    String? password,
    String? is_login,
  }) async {
    if (kIsWeb) return 0;
    final db = await LocalDatabase.instance.database;
    final Map<String, dynamic> updates = {};
    if (name != null) updates['name'] = name;
    if (password != null) updates['password'] = password;
    if (is_login != null) updates['is_login'] = is_login;
    if (updates.isEmpty) return 0;
    return await db.update('users', updates, where: 'id = ?', whereArgs: [id]);
  }

  static Future<int> deleteUser(String id) async {
    if (kIsWeb) return 0;
    final db = await LocalDatabase.instance.database;
    return await db.delete('users', where: 'id = ?', whereArgs: [id]);
  }
}
