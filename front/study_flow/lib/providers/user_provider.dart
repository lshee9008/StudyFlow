import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import '../../core/db_helper/users_db_helper.dart';
import '../../core/provider_config.dart';
import '../../models/user_model.dart';

final userProvider = StateNotifierProvider<UserNotifier, UserModel?>((ref) {
  return UserNotifier()..loadUser();
});

class UserNotifier extends StateNotifier<UserModel?> {
  // id: '' → 로딩 중 / null → 미로그인 / id 있음 → 로그인됨
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

    // ✅ 웹에서는 로컬 DB 없음 → 바로 null(미로그인) 처리
    if (kIsWeb) {
      state = null;
      return null;
    }

    // 모바일/데스크톱: 로컬 DB에서 로그인된 유저 조회
    try {
      final user = loadUser ?? await UsersDBHelper.selectUser();
      state = user; // null이면 미로그인으로 InitialScreen 표시
    } catch (e) {
      print("loadUser local DB error: $e");
      state = null; // 에러 시에도 미로그인 처리 (무한 로딩 방지)
    }

    print("UserNotifier - state after local load: $state");

    // 서버 동기화 (로그인된 유저가 있을 때만)
    if (isOnlineMode && state != null && (state!.id?.isNotEmpty ?? false)) {
      try {
        final response = await http.get(
          Uri.parse('$baseUrl/api/users/${state!.id}'),
        );
        print('loadUser Status Code: ${response.statusCode}');

        if (response.statusCode == 200) {
          final data = json.decode(utf8.decode(response.bodyBytes));
          final serverUser = UserModel(
            id: data['id'],
            name: data['name'],
            join_path: data['join_path'] ?? '',
            password: state!.password, // 비밀번호는 서버에서 안 내려옴
            social_id: data['social_id'] ?? '',
            is_login: 1,
          );
          state = serverUser;
          return serverUser;
        }
      } catch (e) {
        print("loadUser server sync error: $e");
        // 서버 오류여도 로컬 유저 유지
      }
    }

    return state;
  }

  // ── 회원가입 ───────────────────────────────────
  Future<String?> addUser(UserModel user) async {
    if (isOnlineMode) {
      try {
        final response = await http.post(
          Uri.parse('$baseUrl/api/users/'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({
            'id': user.id,
            'name': user.name,
            'join_path': user.join_path,
            'password': user.password,
            'social_id': user.social_id,
          }),
        );
        print('addUser Status Code: ${response.statusCode}');

        if (response.statusCode == 200) {
          if (!kIsWeb) await UsersDBHelper.insertUser(user);
          state = user;
          return null;
        }
        return response.body;
      } catch (e) {
        print("addUser error: $e");
        return '서버 연결에 실패했습니다.';
      }
    }
    return '인터넷 연결을 확인해주세요.';
  }

  // ── 로그인 ────────────────────────────────────
  Future<String?> loginUser(String userName, String userPassword) async {
    if (isOnlineMode) {
      try {
        final response = await http.post(
          Uri.parse('$baseUrl/api/users/login'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({'name': userName, 'password': userPassword}),
        );
        print('loginUser Status Code: ${response.statusCode}');

        if (response.statusCode == 200) {
          final data = json.decode(utf8.decode(response.bodyBytes));
          final loggedInUser = UserModel(
            id: data['id'],
            name: data['name'],
            join_path: data['join_path'] ?? '',
            password: userPassword,
            social_id: data['social_id'] ?? '',
            is_login: 1,
          );

          if (!kIsWeb) {
            // 로컬 DB 동기화
            try {
              final localUsers = await UsersDBHelper.selectUsers();
              bool found = false;
              if (localUsers != null) {
                for (var local in localUsers) {
                  if (local.id == loggedInUser.id) {
                    await UsersDBHelper.updateUser(local.id!, is_login: '1');
                    found = true;
                    break;
                  }
                }
              }
              if (!found) await UsersDBHelper.insertUser(loggedInUser);
            } catch (e) {
              print("loginUser local DB sync error: $e");
            }
          }

          state = loggedInUser;
          return null;
        }
        return response.body;
      } catch (e) {
        print("loginUser error: $e");
        return '서버 연결에 실패했습니다.';
      }
    }
    return '인터넷 연결을 확인해주세요.';
  }

  // ── 기존 유저 선택 (모바일 전용) ────────────────
  Future<void> loginExistingUser(String userId) async {
    if (kIsWeb) return;
    try {
      await UsersDBHelper.updateUser(userId, is_login: '1');
      state = await UsersDBHelper.selectUser();
    } catch (e) {
      print("loginExistingUser error: $e");
    }
  }

  // ── 로그아웃 ──────────────────────────────────
  Future<void> logoutExistingUser(String userId) async {
    if (!kIsWeb) {
      try {
        await UsersDBHelper.updateUser(userId, is_login: '0');
      } catch (e) {
        print("logoutExistingUser error: $e");
      }
    }
    state = null; // null = 미로그인 → InitialScreen
  }

  // ── 탈퇴 ─────────────────────────────────────
  Future<String?> deleteUser(String userId) async {
    if (isOnlineMode) {
      try {
        final response = await http.delete(
          Uri.parse('$baseUrl/api/users/$userId'),
        );
        if (response.statusCode == 200) {
          if (!kIsWeb) await UsersDBHelper.deleteUser(userId);
          state = null;
          return null;
        }
        return response.body;
      } catch (e) {
        print("deleteUser error: $e");
        return '서버 연결에 실패했습니다.';
      }
    }
    return '인터넷 연결을 확인해주세요.';
  }

  // ── 정보 수정 ─────────────────────────────────
  Future<String?> updateUser(UserModel newUser) async {
    if (isOnlineMode) {
      try {
        final response = await http.put(
          Uri.parse('$baseUrl/api/users/${newUser.id!}'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({
            'name': newUser.name,
            'password': newUser.password,
          }),
        );
        if (response.statusCode == 200) {
          if (!kIsWeb) {
            await UsersDBHelper.updateUser(newUser.id!, name: newUser.name);
          }
          state = state!.updateWith(
            name: newUser.name,
            password: newUser.password,
          );
          return null;
        }
        return response.body;
      } catch (e) {
        print("updateUser error: $e");
        return '서버 연결에 실패했습니다.';
      }
    }
    return '인터넷 연결을 확인해주세요.';
  }
}
