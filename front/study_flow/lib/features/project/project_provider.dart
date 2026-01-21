import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import '../../core/provider_config.dart';
import '../../core/local_db_helper.dart';
import 'project_model.dart';

final projectProvider =
    StateNotifierProvider<ProjectNotifier, List<ProjectModel>>((ref) {
      return ProjectNotifier()..loadProjects();
    });

class ProjectNotifier extends StateNotifier<List<ProjectModel>> {
  ProjectNotifier() : super([]);

  // 1. 로드: 로컬 DB -> 화면 표시 -> 서버 동기화
  Future<void> loadProjects() async {
    final db = await LocalDatabase.instance.database;
    final maps = await db.query('projects', orderBy: "created_at DESC");
    state = maps.map((e) => ProjectModel.fromJson(e)).toList();

    if (isOnlineMode) {
      try {
        final response = await http.get(Uri.parse('$baseUrl/projects/'));
        if (response.statusCode == 200) {
          final List<dynamic> data = json.decode(
            utf8.decode(response.bodyBytes),
          );
          final serverProjects = data
              .map((e) => ProjectModel.fromJson(e))
              .toList();
          state = serverProjects;

          // 로컬 DB 최신화 (Batch 처리 권장)
          final batch = db.batch();
          batch.delete('projects');
          for (var p in serverProjects) {
            batch.insert('projects', p.toMap());
          }
          await batch.commit(noResult: true);
        }
      } catch (e) {
        print("front error: $e");
      }
    }

    print("provider");
    print(state.toList().toString());
  }

  // 2. 추가: 화면 즉시 반영(Optimistic) -> 로컬 저장 -> 서버 전송
  Future<void> addProject(ProjectModel newProject) async {
    state = [newProject, ...state]; // 즉시 UI 업데이트

    final db = await LocalDatabase.instance.database;
    await db.insert('projects', {
      'name': newProject.name,
      'tags': newProject.tags,
      'created_at': newProject.createdAt.toIso8601String(),
    });

    if (isOnlineMode) {
      try {
        await http.post(
          Uri.parse('$baseUrl/projects/'),
          headers: {"Content-Type": "application/json"},
          body: json.encode(newProject.toMap()),
        );
      } catch (e) {
        // 실패 시 나중에 Sync하는 로직 필요 (큐잉 등)
        print("Failed to sync with server: $e");
      }
    }
  }

  Future<void> updateProject(ProjectModel project) async {
    state = [
      for (var p in state)
        if (p.id == project.id) project else p,
    ];
    final db = await LocalDatabase.instance.database;
    await db.update(
      'projects',
      project.toMap(),
      where: 'id = ?',
      whereArgs: [project.id],
    );

    if (isOnlineMode) {
      try {
        await http.put(
          Uri.parse('$baseUrl/projects/${project.id}/'),
          headers: {"Content-Type": "application/json"},
          body: json.encode(project.toMap()),
        );
      } catch (e) {
        // 실패 시 나중에 Sync하는 로직 필요 (큐잉 등)
        print("Failed to sync with server: $e");
      }
    }
  }

  Future<void> deleteProject(ProjectModel project) async {
    state = state.where((p) => p.id != project.id).toList(); // 즉시 UI 업데이트

    final db = await LocalDatabase.instance.database;
    await db.delete('projects', where: 'id = ?', whereArgs: [project.id]);

    if (isOnlineMode) {
      try {
        await http.delete(Uri.parse('$baseUrl/projects/${project.id}/'));
      } catch (e) {
        // 실패 시 나중에 Sync하는 로직 필요 (큐잉 등)
        print("Failed to sync with server: $e");
      }
    }
  }
}
