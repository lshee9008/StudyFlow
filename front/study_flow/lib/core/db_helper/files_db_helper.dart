import 'package:study_flow/features/file/file_model.dart';
import 'all_db_helper.dart';

class FilesDBHelper {
  static Future<int> insertFile(FileModel file) async {
    final db = await LocalDatabase.instance.database;
    return await db.insert('files', file.toMap());
  }

  // 특정 프로젝트의 파일들만 가져오기
  static Future<List<FileModel>> selectProjectFiles(String projectId) async {
    final db = await LocalDatabase.instance.database;
    final result = await db.query(
      'files',
      where: 'project_id = ?',
      whereArgs: [projectId],
      orderBy: 'create_at DESC',
    );
    return result.map((json) => FileModel.fromJson(json)).toList();
  }

  // 파일 1개 상세 조회
  static Future<FileModel?> getFile(String fileId) async {
    final db = await LocalDatabase.instance.database;
    final result = await db.query(
      'files',
      where: 'id = ?',
      whereArgs: [fileId],
    );
    if (result.isNotEmpty) return FileModel.fromJson(result.first);
    return null;
  }

  static Future<int> updateFile(
    String id, {
    DateTime? updateAt,
    String? title,
    String? tags,
    String? icon,
    String? prompt,
    String? content,
    String? summary,
  }) async {
    final db = await LocalDatabase.instance.database;
    final Map<String, dynamic> updates = {};
    if (updateAt != null) updates['updateAt'] = updateAt;
    if (title != null) updates['title'] = title;
    if (tags != null) updates['tags'] = tags;
    if (icon != null) updates['icon'] = icon;
    if (prompt != null) updates['prompt'] = prompt;
    if (content != null) updates['content'] = content;
    if (summary != null) updates['summary'] = summary;

    if (updates.isEmpty) return 0;
    return await db.update('files', updates, where: 'id = ?', whereArgs: [id]);
  }

  static Future<int> deleteFile(String id) async {
    final db = await LocalDatabase.instance.database;
    return await db.delete('files', where: 'id = ?', whereArgs: [id]);
  }
}
