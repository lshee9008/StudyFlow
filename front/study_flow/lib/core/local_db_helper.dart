import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:study_flow/features/file/file_model.dart';
import 'package:study_flow/features/project/project_model.dart';

class LocalDatabase {
  static final LocalDatabase instance = LocalDatabase._init();
  static Database? _database;

  LocalDatabase._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('app_notes.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);
    // 버전을 3으로 올려서 강제로 초기화 로직을 태울 수도 있지만, 앱 삭제가 더 깔끔합니다.
    return await openDatabase(
      path,
      version: 2,
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
    );
  }

  Future _createDB(Database db, int version) async {
    await db.execute('CREATE TABLE user (id TEXT PRIMARY KEY, name TEXT)');
    await db.execute(
      'CREATE TABLE projects (id TEXT PRIMARY KEY, name TEXT NOT NULL, tags TEXT, created_at TEXT NOT NULL)',
    );
    await db.execute(
      'CREATE TABLE files (id TEXT PRIMARY KEY, project_id TEXT, title TEXT NOT NULL, content TEXT, summary TEXT, tags TEXT, icon TEXT, created_at TEXT NOT NULL, updated_at TEXT, FOREIGN KEY (project_id) REFERENCES projects (id) ON DELETE CASCADE)',
    );
  }

  Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute("ALTER TABLE files ADD COLUMN icon TEXT");
    }
  }

  // --- Projects ---
  Future<int> insertProject(ProjectModel project) async {
    final db = await instance.database;
    return await db.insert('projects', project.toMap());
  }

  Future<List<ProjectModel>> selectProjects() async {
    final db = await instance.database;
    final result = await db.query('projects', orderBy: 'created_at DESC');
    return result.map((json) => ProjectModel.fromJson(json)).toList();
  }

  Future<int> updateProject(String id, {String? name, String? tags}) async {
    final db = await instance.database;
    final Map<String, dynamic> updates = {};
    if (name != null) updates['name'] = name;
    if (tags != null) updates['tags'] = tags;
    if (updates.isEmpty) return 0;
    return await db.update(
      'projects',
      updates,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteProject(String id) async {
    final db = await instance.database;
    return await db.delete('projects', where: 'id = ?', whereArgs: [id]);
  }

  // --- Files (여기가 핵심) ---
  Future<int> insertFile(FileModel file) async {
    final db = await instance.database;
    return await db.insert('files', file.toMap());
  }

  // [중요] 특정 프로젝트 ID(projectId)를 가진 파일만 가져오는지 확인
  Future<List<FileModel>> selectProjectFiles(String projectId) async {
    final db = await instance.database;
    final result = await db.query(
      'files',
      where: 'project_id = ?', // 이 조건이 핵심
      whereArgs: [projectId],
      orderBy: 'created_at DESC',
    );
    return result.map((json) => FileModel.fromJson(json)).toList();
  }

  Future<FileModel?> getFile(String fileId) async {
    final db = await instance.database;
    final result = await db.query(
      'files',
      where: 'id = ?',
      whereArgs: [fileId],
    );
    if (result.isNotEmpty) return FileModel.fromJson(result.first);
    return null;
  }

  Future<int> updateFile({
    required String id,
    required String title,
    required String tags,
    required String content,
    String? icon,
  }) async {
    final db = await instance.database;
    return await db.update(
      'files',
      {
        'title': title,
        'tags': tags,
        'content': content,
        'icon': icon,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
