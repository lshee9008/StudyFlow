import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import '../../core/db_helper/projects_db_helper.dart';
import '../../core/provider_config.dart';
import './project_model.dart';
import '../../providers/user_provider.dart';

final projectProvider =
    StateNotifierProvider<ProjectNotifier, List<ProjectModel>>((ref) {
      final userId = ref.read(userProvider)?.id ?? '';
      return ProjectNotifier()..loadProjects(userId);
    });

class ProjectNotifier extends StateNotifier<List<ProjectModel>> {
  ProjectNotifier() : super([]);

  // ── 목록 로드 ─────────────────────────────────
  Future<void> loadProjects(String? userId) async {
    if (userId == null || userId.isEmpty) return;

    // 로컬 먼저 (모바일/데스크톱)
    if (!kIsWeb) {
      try {
        final local = await ProjectsDBHelper.selectProjects();
        state = local.where((p) => p.is_sync != 2).toList();
      } catch (e) {
        print('loadProjects local error: $e');
      }
    }

    // 서버 동기화
    if (isOnlineMode) {
      try {
        final res = await http.get(Uri.parse('$baseUrl/api/projects/$userId'));
        print('loadProjects Status: ${res.statusCode}');

        if (res.statusCode == 200) {
          final List<dynamic> data = json.decode(res.body);
          final remote = data.map((j) => ProjectModel.fromJson(j)).toList();

          if (kIsWeb) {
            // 웹: 서버 데이터를 그대로 사용
            state = remote;
          } else {
            // 모바일: 로컬 DB와 머지
            await _mergeWithLocal(remote);
            final updated = await ProjectsDBHelper.selectProjects();
            state = updated.where((p) => p.is_sync != 2).toList();
          }
        }
      } catch (e) {
        print('loadProjects server error: $e');
      }
    }
  }

  Future<void> _mergeWithLocal(List<ProjectModel> remote) async {
    final local = await ProjectsDBHelper.selectProjects();
    for (final r in remote) {
      final found = local.where((l) => l.id == r.id).toList();
      if (found.isEmpty) {
        await ProjectsDBHelper.insertProject(r);
      } else if (found.first.is_sync != 2 &&
          found.first.update_at.isBefore(r.update_at)) {
        await ProjectsDBHelper.updateProject(
          r.id,
          updateAt: r.update_at.toIso8601String(),
          name: r.name,
          tags: r.tags,
          isSync: 1,
        );
      } else if (found.first.is_sync == 2) {
        await http.delete(Uri.parse('$baseUrl/api/projects/${r.id}'));
        await ProjectsDBHelper.deleteProject(r.id);
      }
    }
  }

  // ── 추가 ──────────────────────────────────────
  Future<String?> addProject(ProjectModel project) async {
    // 낙관적 업데이트 (즉시 화면 반영)
    state = [project, ...state];

    if (isOnlineMode) {
      try {
        final res = await http.post(
          Uri.parse('$baseUrl/api/projects/'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({
            'id': project.id,
            'user_id': project.user_id,
            'create_at': project.create_at.toIso8601String(),
            'update_at': project.update_at.toIso8601String(),
            'name': project.name,
            'tags': project.tags,
            'is_sync': 1,
          }),
        );
        print('addProject Status: ${res.statusCode}');

        if (res.statusCode == 200) {
          project.is_sync = 1;
        } else {
          project.is_sync = 0;
        }
      } catch (e) {
        print('addProject error: $e');
        project.is_sync = 0;
      }
    }

    if (!kIsWeb) {
      try {
        await ProjectsDBHelper.insertProject(project);
      } catch (e) {
        print('addProject local error: $e');
      }
    }
    return null;
  }

  // ── 삭제 ──────────────────────────────────────
  Future<String?> deleteProject(ProjectModel project) async {
    // 낙관적 업데이트
    state = state.where((p) => p.id != project.id).toList();

    if (isOnlineMode) {
      try {
        final res = await http.delete(
          Uri.parse('$baseUrl/api/projects/${project.id}'),
        );
        print('deleteProject Status: ${res.statusCode}');
        if (res.statusCode == 200 && !kIsWeb) {
          await ProjectsDBHelper.deleteProject(project.id);
        }
      } catch (e) {
        print('deleteProject error: $e');
        if (!kIsWeb) {
          await ProjectsDBHelper.updateProject(project.id, isSync: 2);
        }
      }
    } else if (!kIsWeb) {
      await ProjectsDBHelper.updateProject(project.id, isSync: 2);
    }
    return null;
  }

  // ── 전체 업데이트 ──────────────────────────────
  Future<void> updateProjectAll(ProjectModel p) async {
    if (isOnlineMode) {
      try {
        final res = await http.put(
          Uri.parse('$baseUrl/api/projects/${p.id}'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({
            'id': p.id,
            'user_id': p.user_id,
            'create_at': p.create_at.toIso8601String(),
            'update_at': p.update_at.toIso8601String(),
            'name': p.name,
            'tags': p.tags,
            'is_sync': 1,
          }),
        );
        print('updateProjectAll Status: ${res.statusCode}');
        if (res.statusCode == 200) p.is_sync = 1;
      } catch (e) {
        print('updateProjectAll error: $e');
      }
    }

    if (!kIsWeb) {
      try {
        await ProjectsDBHelper.updateProject(
          p.id,
          updateAt: p.update_at.toIso8601String(),
          name: p.name,
          tags: p.tags,
          isSync: p.is_sync,
        );
      } catch (e) {
        print('updateProjectAll local error: $e');
      }
    }

    state = [
      for (final item in state)
        if (item.id == p.id)
          item.updateWith(update_at: p.update_at, name: p.name, tags: p.tags)
        else
          item,
    ];
  }

  // ── 이름 업데이트 ──────────────────────────────
  Future<void> updateProjectName(String id, String name) async {
    if (!kIsWeb) {
      await ProjectsDBHelper.updateProject(
        id,
        updateAt: DateTime.now().toIso8601String(),
        name: name,
        isSync: 0,
      );
    }
    state = [
      for (final p in state)
        if (p.id == id) p.updateWith(name: name) else p,
    ];
  }

  // ── 태그 업데이트 ──────────────────────────────
  Future<void> updateProjectTags(String id, String tags) async {
    if (!kIsWeb) {
      await ProjectsDBHelper.updateProject(
        id,
        updateAt: DateTime.now().toIso8601String(),
        tags: tags,
        isSync: 0,
      );
    }
    state = [
      for (final p in state)
        if (p.id == id) p.updateWith(tags: tags) else p,
    ];
  }
}
