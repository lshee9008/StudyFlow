import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import '../../core/db_helper/projects_db_helper.dart';
import '../../core/provider_config.dart';
import './project_model.dart';
import '../../providers/user_provider.dart';

final projectProvider =
    StateNotifierProvider<ProjectNotifier, List<ProjectModel>>((ref) {
      return ProjectNotifier()..loadProjects(ref.read(userProvider)!.id);
    });

class ProjectNotifier extends StateNotifier<List<ProjectModel>> {
  ProjectNotifier() : super([]);

  // 1. 목록 로드
  Future<void> loadProjects(String? userId) async {
    final projects = await ProjectsDBHelper.selectProjects();
    // 로컬에서만 삭제 된 경우 화면에 표시하지 않음
    state = projects.where((p) => p.is_sync != 2).toList();

    if (isOnlineMode) {
      try {
        final response = await http.get(
          Uri.parse('$baseUrl/api/projects/$userId'),
        );

        print('loadProjects Status Code: ${response.statusCode}');
        print('$baseUrl/api/projects/$userId');
        print('Body: ${response.body}');

        if (response.statusCode == 200) {
          final List<dynamic> data = json.decode(response.body);
          final remoteProjects = data
              .map((json) => ProjectModel.fromJson(json))
              .toList();
          // 로컬 DB와 동기화
          for (final remoteProject in remoteProjects) {
            final localProject = projects.firstWhere(
              (p) => p.id == remoteProject.id,
            );
            if (localProject.is_sync != 2) {
              if (localProject.id.isEmpty) {
                // 로컬에 없는 경우 추가
                await ProjectsDBHelper.insertProject(remoteProject);
              } else if (localProject.update_at.isBefore(
                remoteProject.update_at,
              )) {
                // 로컬이 오래된 경우 업데이트
                await ProjectsDBHelper.updateProject(
                  remoteProject.id,
                  updateAt: remoteProject.update_at.toIso8601String(),
                  name: remoteProject.name,
                  tags: remoteProject.tags,
                  isSync: 1,
                );
              }
            } else {
              // 로컬에서 삭제된 경우 서버에도 삭제 요청
              // 수정할 점 : 여러개 삭제할 수 있는 API 필요 70번째 줄에 한번에 삭제 하는 것이 효율적일 것
              http.delete(
                Uri.parse('$baseUrl/api/projects/${remoteProject.id}'),
              );
              await ProjectsDBHelper.deleteProject(remoteProject.id);
            }
          }

          // 최종적으로 로컬 DB에서 다시 불러오기
          final updatedProjects = await ProjectsDBHelper.selectProjects();
          state = updatedProjects;
        }
      } catch (e) {
        print("front error during loadProjects: $e");
      }
    }
  }

  // 2. 프로젝트 추가
  Future<String?> addProject(ProjectModel project) async {
    if (isOnlineMode) {
      try {
        project.is_sync = 1;
        final headers = {"Content-Type": "application/json"};
        final body = json.encode({
          'id': project.id,
          'user_id': project.user_id,
          'create_at': project.create_at.toIso8601String(),
          'update_at': project.update_at.toIso8601String(),
          'name': project.name,
          'tags': project.tags,
          'is_sync': project.is_sync,
        });

        final response = await http.post(
          Uri.parse('$baseUrl/api/projects/'),
          headers: headers,
          body: body,
        );
        print('addProject Status Code: ${response.statusCode}');
        print('Body: ${response.body}');

        switch (response.statusCode) {
          case 200:
            await ProjectsDBHelper.insertProject(project);
            state = [project, ...state];
            return null;
          default:
            project.is_sync = 0;
            await ProjectsDBHelper.insertProject(project);
            state = [project, ...state];
            return response.body;
        }
      } catch (e) {
        print("front error: $e");
      }
    }
    project.is_sync = 0;
    await ProjectsDBHelper.insertProject(project);
    state = [project, ...state];
    return null;
  }

  Future<String?> deleteProject(ProjectModel project) async {
    if (isOnlineMode) {
      try {
        final response = await http.delete(
          Uri.parse('$baseUrl/api/projects/${project.id}'),
        );

        print('deleteProject Status Code: ${response.statusCode}');
        print('Body: ${response.body}');

        switch (response.statusCode) {
          case 200:
            await ProjectsDBHelper.deleteProject(project.id);
            state = state.where((p) => p.id != project.id).toList();
            return null;
          default:
            project.is_sync = 0;
            return response.body;
        }
      } catch (e) {
        print("front error: $e");
      }
    }
    project.is_sync = 2;
    await ProjectsDBHelper.updateProject(project.id, isSync: project.is_sync);
    state = state.where((p) => p.id != project.id).toList();
    return null;
  }

  // 프로젝트 전체 업데이트 프로젝트 화면 -> 홈 화면
  Future<void> updateProjectAll(ProjectModel newProjectModel) async {
    newProjectModel.is_sync = 0;
    if (isOnlineMode) {
      try {
        final headers = {"Content-Type": "application/json"};
        final body = json.encode({
          'id': newProjectModel.id,
          'user_id': newProjectModel.user_id,
          'create_at': newProjectModel.create_at.toIso8601String(),
          'update_at': newProjectModel.update_at.toIso8601String(),
          'name': newProjectModel.name,
          'tags': newProjectModel.tags,
          'is_sync': newProjectModel.is_sync,
        });

        final response = await http.put(
          Uri.parse('$baseUrl/api/projects/${newProjectModel.id}'),
          headers: headers,
          body: body,
        );
        print('updateProjectAll Status Code: ${response.statusCode}');
        print('Body: ${response.body}');

        switch (response.statusCode) {
          case 200:
            newProjectModel.is_sync = 1;
            break;
          default:
            break;
        }
      } catch (e) {
        print("front error during updateProjectAll: $e");
      }
    }
    await ProjectsDBHelper.updateProject(
      newProjectModel.id,
      updateAt: newProjectModel.update_at.toIso8601String(),
      name: newProjectModel.name,
      tags: newProjectModel.tags,
      isSync: newProjectModel.is_sync,
    );
    state = [
      for (final p in state)
        if (p.id == newProjectModel.id)
          p.updateWith(
            update_at: newProjectModel.update_at,
            name: newProjectModel.name,
            tags: newProjectModel.tags,
            is_sync: newProjectModel.is_sync,
          )
        else
          p,
    ];
  }

  // 4. 이름 업데이트 (화면 즉시 반영)
  Future<void> updateProjectName(String projectId, String newName) async {
    await ProjectsDBHelper.updateProject(projectId, updateAt: DateTime.now().toIso8601String(), name: newName, isSync: 0);
    state = [
      for (final p in state)
        if (p.id == projectId) p.updateWith(name: newName) else p,
    ];
  }

  // 3. 태그 업데이트 (화면 즉시 반영)
  Future<void> updateProjectTags(String projectId, String newTags) async {
    await ProjectsDBHelper.updateProject(projectId, updateAt: DateTime.now().toIso8601String(), tags: newTags, isSync: 0);
    state = [
      for (final p in state)
        if (p.id == projectId) p.updateWith(tags: newTags) else p,
    ];
  }
}
