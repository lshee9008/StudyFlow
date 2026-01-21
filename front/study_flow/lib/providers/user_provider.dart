import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import '../core/provider_config.dart';
import '../core/local_db_helper.dart';
import '../models/user_model.dart';

final userProvider = StateNotifierProvider<UserNotifier, UserModel>((ref) {
  return UserNotifier()..loadUser();
});

class UserNotifier extends StateNotifier<UserModel> {
  UserNotifier() : super(UserModel(name: ''));

  Future<void> loadUser() async {
    final db = await LocalDatabase.instance.database;
    UserModel user = await db.query('user').then((maps) {
      if (maps.isNotEmpty) {
        return maps.first as UserModel;
      } else {
        return UserModel(name: '');
      }
    });
    state = user;

    if (isOnlineMode) {
      try {
        final response = await http.get(Uri.parse('$baseUrl/user/'));
        if (response.statusCode == 200) {
          final data = json.decode(utf8.decode(response.bodyBytes));
          final serverUser = data != null
              ? UserModel(id: data['id'], name: data['name'])
              : UserModel(name: '');
          state = serverUser;
        }
      } catch (e) {
        print("front error: $e");
      }
    }
  }
}
