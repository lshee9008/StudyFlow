import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:study_flow/models/project_file_model.dart';

import '../models/project_model.dart';

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
    return await openDatabase(path, version: 1, onCreate: _createDB);
  }

  Future _createDB(Database db, int version) async {
    // PDF 스키마에 맞춘 로컬 테이블
    await db.execute(''' 
    CREATE TABLE user (
      id INTEGER PRIMARY KEY,
      name TEXT
    )
    ''');

    await db.execute('''
    CREATE TABLE projects (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      tags TEXT,
      created_at TEXT NOT NULL
    )
    ''');

    await db.execute('''
    CREATE TABLE files (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      project_id TEXT,
      name TEXT NOT NULL,
      tags TEXT,
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

  Future<List<ProjectFileModel>> selectProjectFiles(int projectId) async {
    final db = await instance.database;
    final result = await db.query('files', where: 'project_id = ?', whereArgs: [projectId]);
    return result.map((files) => ProjectFileModel.fromJson(files)).toList();
  }
}
