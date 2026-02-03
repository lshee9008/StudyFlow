import 'package:study_flow/features/project/project_model.dart';
import 'all_db_helper.dart';

class ProjectsDBHelper {
  static Future<int> insertProject(ProjectModel project) async {
    final db = await LocalDatabase.instance.database;
    return await db.insert('projects', project.toMap());
  }

  static Future<List<ProjectModel>> selectProjects() async {
    final db = await LocalDatabase.instance.database;
    // 최신순 정렬 (create_at 내림차순)
    final result = await db.query('projects', orderBy: 'create_at DESC');
    return result.map((json) => ProjectModel.fromJson(json)).toList();
  }

  static Future<int> updateProject(
    String id, {
    DateTime? updateAt,
    String? name,
    String? tags,
    int? isSync,
  }) async {
    final db = await LocalDatabase.instance.database;
    final Map<String, dynamic> updates = {};
    if (updateAt != null)
      updates['updateAt'] = updateAt; // DateTime 처리는 모델에서 확인 필요
    if (name != null) updates['name'] = name;
    if (tags != null) updates['tags'] = tags;
    if (isSync != null) updates['isSync'] = isSync;

    if (updates.isEmpty) return 0;
    return await db.update(
      'projects',
      updates,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  static Future<int> deleteProject(String id) async {
    final db = await LocalDatabase.instance.database;
    return await db.delete('projects', where: 'id = ?', whereArgs: [id]);
  }
}
