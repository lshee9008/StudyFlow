import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import '../../core/db_helper/users_db_helper.dart';
import '../core/provider_config.dart';
import '../models/user_model.dart';

final userProvider = StateNotifierProvider<UserNotifier, UserModel?>((ref) {
  return UserNotifier()..loadUser();
});

class UserNotifier extends StateNotifier<UserModel?> {
  UserNotifier()
    : super(
        UserModel(
          id: '',
          name: '',
          join_path: '',
          password: '',
          social_id: '',
          is_login: 0,
        ),
      );

  Future<UserModel?> loadUser({UserModel? loadUser}) async {
    print("UserNotifier - loadUser called");
    final user = loadUser ?? await UsersDBHelper.selectUser();
    state = user;
    print("UserNotifier - Loaded users from local DB: $state");
    print("UserNotifier - dataIsLoaded set to true");
    if (isOnlineMode && state != null) {
      try {
        final response = await http.get(
          Uri.parse('$baseUrl/api/users/${state!.id}'),
        );
        // 3. 디버깅을 위해 상태 코드와 바디를 확인하세요.
        print('loadUser Status Code: ${response.statusCode}');
        print('Body: ${response.body}');

        switch (response.statusCode) {
          case 200:
            final data = json.decode(utf8.decode(response.bodyBytes));
            final serverUser = UserModel(
              id: data['id'],
              name: data['name'],
              join_path: data['join_path'],
              password: data['password'],
              social_id: data['social_id'],
              is_login: 1,
            );
            return serverUser;
          case 500:
            return null;
        }
      } catch (e) {
        print("front error: $e");
      }
    }

    // 서버 통신 실패 혹은 오프라인일 때, 로컬 데이터의 첫 번째 유저 반환
    return state;
  }

  // 2. 새 유저 추가
  Future<String?> addUser(UserModel user) async {
    if (isOnlineMode) {
      try {
        final headers = {"Content-Type": "application/json"};
        final body = json.encode({
          'id': user.id,
          'name': user.name,
          'join_path': user.join_path,
          'password': user.password,
          'social_id': user.social_id,
        });

        final response = await http.post(
          Uri.parse('$baseUrl/api/users/'),
          headers: headers,
          body: body,
        );

        // 디버깅을 위해 상태 코드와 바디를 확인하세요.
        print('addUser Status Code: ${response.statusCode}');
        print('Body: ${response.body}');

        switch (response.statusCode) {
          case 200:
            await UsersDBHelper.insertUser(user);
            state = user;
            return null;
          case 400:
            return response.body;
          case 500:
            return response.body;
        }
      } catch (e) {
        print("front error: $e");
      }
    }
    return '현재 인터넷과 연결되어 있는지 확인해주세요.';
  }

  Future<String?> loginUser(String userName, String userPassword) async {
    if (isOnlineMode) {
      try {
        final response = await http.post(
          Uri.parse('$baseUrl/api/users/login'),
          headers: {"Content-Type": "application/json"},
          body: json.encode({'name': userName, 'password': userPassword}),
        );

        print('loginUser Status Code: ${response.statusCode}');
        print('Body: ${response.body}');

        switch (response.statusCode) {
          case 200:
            final data = json.decode(utf8.decode(response.bodyBytes));
            final loggedInUser = UserModel(
              id: data['id'],
              name: data['name'],
              join_path: data['join_path'],
              password: data['password'],
              social_id: data['social_id'],
              is_login: 1,
            );
            List<UserModel>? localUsers = await UsersDBHelper.selectUsers();
            if (localUsers != null) {
              for (var localuser in localUsers) {
                if (localuser.id == loggedInUser.id) {
                  await UsersDBHelper.updateUser(localuser.id!, is_login: '1');
                  state = loggedInUser;
                  return null;
                }
              }
            }
            await UsersDBHelper.insertUser(loggedInUser);
            state = loggedInUser;
            return null;
          case 400:
            return response.body;
          case 500:
            return response.body;
        }
      } catch (e) {
        print("front error: $e");
      }
    }
    return '현재 인터넷과 연결되어 있는지 확인해주세요.';
  }

  Future<void> loginExistingUser(String userId) async {
    await UsersDBHelper.updateUser(userId, is_login: '1');
    state = await UsersDBHelper.selectUser();
    state!.is_login = 1;
  }

  Future<void> logoutExistingUser(String userId) async {
    state = UserModel(
      id: '',
      name: '',
      join_path: '',
      password: '',
      social_id: '',
      is_login: 0,
    );
    await UsersDBHelper.updateUser(userId, is_login: '0');
  }

  Future<String?> deleteUser(String userId) async {
    if (isOnlineMode) {
      try {
        final response = await http.delete(
          Uri.parse('$baseUrl/api/users/$userId'),
        );

        print('deleteUser Status Code: ${response.statusCode}');
        print('Body: ${response.body}');

        switch (response.statusCode) {
          case 200:
            await UsersDBHelper.deleteUser(userId);
            state = null;
            return null;
          case 400:
            return response.body;
          case 500:
            return response.body;
        }
      } catch (e) {
        print("front error: $e");
      }
    }
    return '현재 인터넷과 연결되어 있는지 확인해주세요.';
  }

  // 3. 이름(닉네임) 업데이트 (화면 즉시 반영)
  Future<String?> updateUser(UserModel newUser) async {
    if (isOnlineMode) {
      try {
        final response = await http.put(
          Uri.parse('$baseUrl/api/users/${newUser.id!}'),
          headers: {"Content-Type": "application/json"},
          body: json.encode({
            'name': newUser.name,
            'password': newUser.password,
          }),
        );

        print('updateUser Status Code: ${response.statusCode}');
        print('Body: ${response.body}');

        switch (response.statusCode) {
          case 200:
            await UsersDBHelper.updateUser(newUser.id!, name: newUser.name);
            state = state!.updateWith(
              name: newUser.name,
              password: newUser.password,
            );
            return null;
          case 400:
            return response.body;
          case 500:
            return response.body;
        }
      } catch (e) {
        print("front error: $e");
      }
    }
    return '현재 인터넷과 연결되어 있는지 확인해주세요.';
  }
}
