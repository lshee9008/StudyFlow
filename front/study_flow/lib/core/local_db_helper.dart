import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

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
      id TEXT PRIMARY KEY,
      name TEXT
    )
    ''');

    await db.execute('''
    CREATE TABLE projects (
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      tags TEXT,
      created_at TEXT NOT NULL
    )
    ''');

    await db.execute('''
    CREATE TABLE notes (
      id TEXT PRIMARY KEY,
      folder_id TEXT,
      title TEXT NOT NULL,
      content_raw TEXT,
      created_at TEXT NOT NULL,
      FOREIGN KEY (folder_id) REFERENCES folders (id) ON DELETE CASCADE
    )
    ''');
  }

  Future<List<ProjectModel>> selectProjects() async {
    final db = await instance.database;
    final result = await db.query('projects');
    return result.map((projects) => ProjectModel.fromJson(projects)).toList();
  }

  Future<void> deleteProject(ProjectModel project) async {
    final db = await instance.database;
    await db.delete('projects', where: 'id = ?', whereArgs: [project.id]);
  }
}
