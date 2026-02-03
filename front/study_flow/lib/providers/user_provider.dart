import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import 'dart:convert';

import '../core/provider_config.dart';
import '../core/local_db_helper.dart';
import '../models/user_model.dart';

final userProvider = StateNotifierProvider<UserNotifier, List<UserModel>>((
  ref,
) {
  return UserNotifier()..loadUser();
});

class UserNotifier extends StateNotifier<List<UserModel>> {
  UserNotifier()
    : super([
        UserModel(id: '', name: '', join_path: '', password: '', social_id: ''),
      ]);

  Future<UserModel?> loadUser() async {
    final user = await LocalDatabase.instance.selectUser();
    print(user);

    state = user;

    List<UserModel> userModelState = state;

    print(userModelState);

    if (isOnlineMode) {
      try {
        final headers = {"Content-Type": "application/json"};

        // 1. 보낼 데이터를 먼저 Map으로 만듭니다.
        final Map<String, dynamic> requestData = {
          'id': Uuid().v4(),
          'name': 'dqwdqwdqwdw',
          'join_path': '카카오',
          'social_id': 'dwqdqwdqdw',
          'password': '13123123jebw@',
        };

        print(requestData);

        final body = jsonEncode(requestData);

        print('body : $body');

        final response = await http.post(
          Uri.parse('$baseUrl/api/users/'), // URL 끝의 슬래시 주의 (아래 2번 참조)
          headers: headers,
          body: body,
        );

        // 3. 디버깅을 위해 상태 코드와 바디를 확인하세요.
        print('Status Code: ${response.statusCode}');
        print('Body: ${response.body}');

        if (response.statusCode == 200) {
          final data = json.decode(utf8.decode(response.bodyBytes));
          print(data);
          final serverUser = data != null
              ? UserModel(
                  id: data['id'],
                  name: data['name'],
                  join_path: data['join_path'],
                  password: data['password'],
                  social_id: data['social_id'],
                )
              : UserModel(
                  id: '',
                  name: '',
                  join_path: '',
                  password: '',
                  social_id: '',
                );

          state = [serverUser];
          return serverUser;
        }
      } catch (e) {
        print("front error: $e");
      }
    }

    // 서버 통신 실패 혹은 오프라인일 때, 로컬 데이터의 첫 번째 유저 반환
    return state.isNotEmpty ? state.first : null;
  }

  // 2. 프로젝트 추가
  Future<void> addUser(UserModel user) async {
    await LocalDatabase.instance.insertUser(user);
    // 기존 목록 맨 앞에 새 프로젝트 추가
    state = [user, ...state];
  }

  // 3. 이름(닉네임) 업데이트 (화면 즉시 반영)
  Future<void> updateUsersName(String userId, String newName) async {
    await LocalDatabase.instance.updateUser(userId, name: newName);
    state = [
      for (final p in state)
        if (p.id == userId) p.updateWith(name: newName) else p,
    ];
  }

  // 4. 비밀번호 업데이트 (화면 즉시 반영)
  // 소셜 로그인이 아닌 자체(Local) 로그인일 경우만 가능
  Future<void> updateProjectName(String projectId, String newName) async {
    await LocalDatabase.instance.updateProject(projectId, name: newName);
    state = [
      for (final p in state)
        if (p.id == projectId) p.updateWith(name: newName) else p,
    ];
  }
}
