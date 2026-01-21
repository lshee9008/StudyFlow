import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:study_flow/features/file/file_model.dart';
import 'package:study_flow/features/project/project_model.dart';

// 만약 FileModel 클래스 파일명이 file_model.dart라면 위 import를 수정하세요.

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
    print("DB 저장 위치: $path"); // 디버깅용
    return await openDatabase(path, version: 1, onCreate: _createDB);
  }

  Future _createDB(Database db, int version) async {
    // 1. User 테이블
    await db.execute('''
    CREATE TABLE user (
      id TEXT PRIMARY KEY,
      name TEXT
    )
    ''');

    // 2. Projects 테이블
    await db.execute('''
    CREATE TABLE projects (
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      tags TEXT,
      created_at TEXT NOT NULL
    )
    ''');

    // 3. Files 테이블 (모든 기능의 핵심!)
    await db.execute('''
    CREATE TABLE files (
      id TEXT PRIMARY KEY,
      project_id TEXT, 
      title TEXT NOT NULL,
      content TEXT,
      summary TEXT,
      tags TEXT,
      created_at TEXT NOT NULL,
      updated_at TEXT,
      FOREIGN KEY (project_id) REFERENCES projects (id) ON DELETE CASCADE
    )
    ''');
  }

  // ---------------------------------------------------------------------------
  // [핵심] 파일 관련 CRUD 함수들
  // ---------------------------------------------------------------------------

  // 1. 파일 생성 (Create)
  Future<int> insertFile(FileModel file) async {
    final db = await instance.database;
    return await db.insert('files', file.toMap());
  }

  // 2. 프로젝트의 모든 파일 목록 조회 (Read List) -> ProjectScreen용
  Future<List<FileModel>> selectProjectFiles(String projectId) async {
    final db = await instance.database;
    final result = await db.query(
      'files',
      where: 'project_id = ?',
      whereArgs: [projectId],
      orderBy: 'created_at DESC', // 최신순 정렬
    );
    return result.map((json) => FileModel.fromJson(json)).toList();
  }

  // 3. 특정 파일 하나 내용 조회 (Read One) -> FileScreen용
  Future<FileModel?> getFile(String fileId) async {
    final db = await instance.database;
    final result = await db.query(
      'files',
      where: 'id = ?',
      whereArgs: [fileId],
    );

    if (result.isNotEmpty) {
      return FileModel.fromJson(result.first);
    } else {
      return null;
    }
  }

  // 4. 파일 내용 저장/업데이트 (Update) -> 자동 저장용
  // [NEW] 파일의 제목, 태그, 내용, 수정시간을 모두 업데이트하는 함수
  Future<int> updateFile({
    required String id,
    required String title,
    required String tags,
    required String content,
  }) async {
    final db = await instance.database;
    return await db.update(
      'files',
      {
        'title': title,
        'tags': tags,
        'content': content,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // [NEW] 프로젝트 전체 목록 조회 함수
  Future<List<ProjectModel>> selectProjects() async {
    final db = await instance.database;
    final result = await db.query('projects', orderBy: 'created_at DESC');

    return result.map((json) => ProjectModel.fromJson(json)).toList();
  }
}
