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

    // 3. files 테이블 (이름 변경: notes -> project_files)
    // 컬럼명 변경: folder_id -> project_id (직관적으로 변경)
    await db.execute('''
    CREATE TABLE files (
      id TEXT PRIMARY KEY,
      project_id TEXT, 
      
      title TEXT NOT NULL,      -- name 대신 title (문서 제목에 더 어울림)
      
      content TEXT,             -- content_raw 대신 content (블록 데이터를 JSON 문자열로 저장)
      summary TEXT,             -- AI가 요약한 내용을 저장할 곳 (매번 요청하면 느리니까)
      
      tags TEXT,                -- 파일별 태그 (예: "중요, 복습")
      
      created_at TEXT NOT NULL, -- 생성 시간
      updated_at TEXT,          -- 수정 시간 (최근 수정된 순 정렬용)
      
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
  Future<List<FileModel>> selectProjectFiles(String projectId) async {
    final db = await instance.database;
    final result = await db.query(
      'files', // ✅ 위에서 만든 테이블 이름과 일치!
      where: 'project_id = ?', // ✅ 컬럼명 일치!
      whereArgs: [projectId],
    );
    return result.map((json) => FileModel.fromJson(json)).toList();
  }

  // [NEW] 파일 생성 (추가)
  Future<int> insertFile(FileModel file) async {
    final db = await instance.database;
    return await db.insert('files', file.toMap());
  }

  // 파일 하나만 가져오기
  Future<FileModel?> getFile(String fileId) async {
    final db = await instance.database;
    final result = await db.query(
      'files',
      where: 'id = ?',
      whereArgs: [fileId],
    );
    if (result.isNotEmpty) {
      return FileModel.fromJson(result.first);
    }
    return null;
  }

  // LocalDatabase 클래스 내부
  Future<void> updateFileContent(String fileId, String contentJson) async {
    final db = await instance.database;
    await db.update(
      'files',
      {'content': contentJson, 'updated_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [fileId],
    );
  }
}
