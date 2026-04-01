import 'package:flutter/foundation.dart';
import 'package:study_flow/features/project/project_model.dart';
import 'all_db_helper.dart';

class ProjectsDBHelper {
  static Future<int> insertProject(ProjectModel project) async {
    if (kIsWeb) return 0;
    final db = await LocalDatabase.instance.database;
    return await db.insert('projects', project.toMap());
  }

  static Future<List<ProjectModel>> selectProjects() async {
    if (kIsWeb) return [];
    final db = await LocalDatabase.instance.database;
    final result = await db.query('projects', orderBy: 'create_at DESC');
    return result.map((json) => ProjectModel.fromJson(json)).toList();
  }

  static Future<int> updateProject(
    String id, {
    String? updateAt,
    String? name,
    String? tags,
    int? isSync,
  }) async {
    if (kIsWeb) return 0;
    final db = await LocalDatabase.instance.database;
    final Map<String, dynamic> updates = {};
    if (updateAt != null) updates['update_at'] = updateAt;
    if (name != null) updates['name'] = name;
    if (tags != null) updates['tags'] = tags;
    if (isSync != null) updates['is_sync'] = isSync;
    if (updates.isEmpty) return 0;
    return await db.update(
      'projects',
      updates,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  static Future<int> deleteProject(String id) async {
    if (kIsWeb) return 0;
    final db = await LocalDatabase.instance.database;
    return await db.delete('projects', where: 'id = ?', whereArgs: [id]);
  }
}
