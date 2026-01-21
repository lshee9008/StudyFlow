import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:study_flow/features/file/file_model.dart';

import '../features/project/project_model.dart';

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
    // ▼ 이 코드를 추가해서 콘솔창을 확인하세요!
    print("DB 저장 위치: $path");
    return await openDatabase(path, version: 1, onCreate: _createDB);
  }

  Future _createDB(Database db, int version) async {
    // 1. user 테이블
    await db.execute(''' 
    CREATE TABLE user (
      id TEXT PRIMARY KEY,
      name TEXT
    )
    ''');

    // 2. projects 테이블
    await db.execute('''
    CREATE TABLE projects (
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      tags TEXT,
      created_at TEXT NOT NULL
    )
    ''');

    // 3. project_files 테이블 (이름 변경: notes -> project_files)
    // 컬럼명 변경: folder_id -> project_id (직관적으로 변경)
    await db.execute('''
    CREATE TABLE project_files (
      id TEXT PRIMARY KEY,
      project_id TEXT, 
      name TEXT NOT NULL,
      content_raw TEXT,
      created_at TEXT NOT NULL,
      FOREIGN KEY (project_id) REFERENCES projects (id) ON DELETE CASCADE
    )
    ''');
  }

  Future<List<ProjectModel>> selectProjects() async {
    final db = await instance.database;
    final result = await db.query('projects');
    return result.map((projects) => ProjectModel.fromJson(projects)).toList();
  }

  // 파일 조회 함수
  Future<List<ProjectFileModel>> selectProjectFiles(String projectId) async {
    final db = await instance.database;
    final result = await db.query(
      'project_files', // ✅ 위에서 만든 테이블 이름과 일치!
      where: 'project_id = ?', // ✅ 컬럼명 일치!
      whereArgs: [projectId],
    );
    return result.map((json) => ProjectFileModel.fromJson(json)).toList();
  }
}
