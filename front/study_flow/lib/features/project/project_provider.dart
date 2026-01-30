import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:study_flow/features/project/project_model.dart';
import '../../core/local_db_helper.dart';

final projectProvider =
    StateNotifierProvider<ProjectNotifier, List<ProjectModel>>((ref) {
      return ProjectNotifier()..loadProjects();
    });

class ProjectNotifier extends StateNotifier<List<ProjectModel>> {
  ProjectNotifier() : super([]);

  // 1. 목록 로드
  Future<void> loadProjects() async {
    final projects = await LocalDatabase.instance.selectProjects();
    state = projects;
  }

  // 2. 프로젝트 추가
  Future<void> addProject(ProjectModel project) async {
    await LocalDatabase.instance.insertProject(project);
    // 기존 목록 맨 앞에 새 프로젝트 추가
    state = [project, ...state];
  }

  Future<void> updateProjectAll(ProjectModel newProjectModel) async {
    await LocalDatabase.instance.updateProject(
      newProjectModel.id,
      updateAt: newProjectModel.update_at,
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

  Future<void> updateProjectUpdateAt(
    String projectId,
    DateTime newUpadateAt,
  ) async {
    await LocalDatabase.instance.updateProject(
      projectId,
      updateAt: newUpadateAt,
    );
    state = [
      for (final p in state)
        if (p.id == projectId) p.updateWith(update_at: newUpadateAt) else p,
    ];
  }

  // 4. 이름 업데이트 (화면 즉시 반영)
  Future<void> updateProjectName(String projectId, String newName) async {
    await LocalDatabase.instance.updateProject(projectId, name: newName);
    state = [
      for (final p in state)
        if (p.id == projectId) p.updateWith(name: newName) else p,
    ];
  }

  // 3. 태그 업데이트 (화면 즉시 반영)
  Future<void> updateProjectTags(String projectId, String newTags) async {
    await LocalDatabase.instance.updateProject(projectId, tags: newTags);
    state = [
      for (final p in state)
        if (p.id == projectId) p.updateWith(tags: newTags) else p,
    ];
  }

  Future<void> updateProjectIsSync(String projectId, int newIsSync) async {
    await LocalDatabase.instance.updateProject(projectId, isSync: newIsSync);
    state = [
      for (final p in state)
        if (p.id == projectId) p.updateWith(is_sync: newIsSync) else p,
    ];
  }

  // 5. [수정됨] 프로젝트 삭제 (화면 즉시 반영)
  Future<void> deleteProject(String projectId) async {
    // 1) DB에서 삭제 (비동기 처리)
    await LocalDatabase.instance.deleteProject(projectId);

    // 2) [핵심] DB를 다시 읽지 않고, 현재 목록에서 해당 ID만 쏙 빼버림
    // 이렇게 하면 딜레이 없이 즉각적으로 사라집니다.
    state = state.where((project) => project.id != projectId).toList();
  }
}
