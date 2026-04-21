// ============================================================
// all_db_helper.dart  (Web-Compatible Version)
// 웹: 로컬 DB 없이 서버 API만 사용 (no-op stub)
// 모바일/데스크톱: 기존 sqflite 그대로 사용
// ============================================================
import 'package:flutter/foundation.dart';

// ⚠️ sqflite는 웹을 지원하지 않으므로 조건부 import 사용
import 'package:sqflite/sqflite.dart' if (dart.library.html) 'web_stub.dart';
// path 패키지 제거 → 문자열 직접 조합으로 대체 (join 함수 웹 호환 문제 해결)

class LocalDatabase {
  static final LocalDatabase instance = LocalDatabase._init();
  static dynamic _database; // web에서는 null

  LocalDatabase._init();

  /// 웹이면 null 반환 (no-op), 모바일이면 sqflite Database 반환
  Future<dynamic> get database async {
    if (kIsWeb) return null;
    if (_database != null) return _database!;
    _database = await _initDB('app_notes.db');
    return _database!;
  }

  Future<dynamic> _initDB(String filePath) async {
    if (kIsWeb) return null;
    final dbPath = await getDatabasesPath();
    final path = '$dbPath/$filePath'; // path 패키지 join() 대신 문자열 조합
    print("🍎 [DB Path] 파일 위치: $path");
    return await openDatabase(
      path,
      version: 3,
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
    );
  }

  Future _createDB(dynamic db, int version) async {
    if (kIsWeb) return;
    await db.execute('''
      CREATE TABLE users (
        id TEXT NOT NULL PRIMARY KEY,
        name TEXT NOT NULL,
        join_path TEXT NOT NULL,
        password TEXT,
        social_id TEXT,
        is_login INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.execute('''
      CREATE TABLE projects (
        id TEXT NOT NULL PRIMARY KEY,
        user_id TEXT NOT NULL,
        create_at TEXT NOT NULL,
        update_at TEXT NOT NULL,
        name TEXT,
        tags TEXT,
        is_sync INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE
      )
    ''');
    await db.execute('''
      CREATE TABLE files (
        id TEXT NOT NULL PRIMARY KEY, 
        project_id TEXT NOT NULL, 
        create_at TEXT NOT NULL, 
        update_at TEXT, 
        title TEXT, 
        tags TEXT, 
        icon TEXT, 
        prompt TEXT, 
        content TEXT, 
        summary TEXT, 
        FOREIGN KEY (project_id) REFERENCES projects (id) ON DELETE CASCADE
      )
    ''');
  }

  Future _onUpgrade(dynamic db, int oldVersion, int newVersion) async {
    if (kIsWeb) return;
    // v1→2 업그레이드 시 files 테이블이 누락된 경우 CREATE IF NOT EXISTS로 복구
    await db.execute('''
      CREATE TABLE IF NOT EXISTS files (
        id TEXT NOT NULL PRIMARY KEY,
        project_id TEXT NOT NULL,
        create_at TEXT NOT NULL,
        update_at TEXT,
        title TEXT,
        tags TEXT,
        icon TEXT,
        prompt TEXT,
        content TEXT,
        summary TEXT,
        FOREIGN KEY (project_id) REFERENCES projects (id) ON DELETE CASCADE
      )
    ''');
    // v2→3: projects 테이블에 is_sync 컬럼 보장
    try {
      await db.execute(
        'ALTER TABLE projects ADD COLUMN is_sync INTEGER NOT NULL DEFAULT 0',
      );
    } catch (_) {}
  }

  Future<void> debugPrintDatabase() async {
    if (kIsWeb) {
      print("🌐 [Web] 로컬 DB 없음 - 서버 API 모드");
      return;
    }
    final db = await instance.database;
    final tables = ['users', 'projects', 'files'];
    for (var tbl in tables) {
      final rows = await db.query(tbl);
      print("📂 테이블($tbl): ${rows.length}개 데이터");
    }
  }

  Future<void> deleteAppDatabase() async {
    if (kIsWeb) return;
    final dbPath = await getDatabasesPath();
    final path = '$dbPath/app_notes.db'; // path 패키지 join() 대신 문자열 조합
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
    await databaseFactory.deleteDatabase(path);
    print("💥 DB 파일이 삭제되었습니다.");
  }
}
