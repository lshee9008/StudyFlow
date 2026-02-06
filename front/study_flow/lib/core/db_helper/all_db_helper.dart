import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class LocalDatabase {
  static final LocalDatabase instance = LocalDatabase._init();
  static Database? _database;

  LocalDatabase._init();

  // DB 객체 가져오기 (없으면 초기화)
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('app_notes.db');
    return _database!;
  }

  // DB 파일 경로 설정 및 오픈
  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    print("🍎 [DB Path] 파일 위치: $path");

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB, // 앱 처음 깔았을 때 실행
    );
  }

  // 테이블 생성 (유저, 프로젝트, 파일 3개)
  Future _createDB(Database db, int version) async {
    // 1. users 테이블
    await db.execute('''
      CREATE TABLE users (
        id TEXT NOT NULL PRIMARY KEY,
        name TEXT NOT NULL,
        join_path TEXT NOT NULL,
        password TEXT,
        social_id TEXT
      )
    ''');

    // 2. projects 테이블
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

    // 3. files 테이블
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

  // [유틸] DB 데이터 확인용 (디버깅)
  Future<void> debugPrintDatabase() async {
    final db = await instance.database;
    print("\n🔥 [DEBUG] DB 데이터 확인 시작");

    final tables = ['users', 'projects', 'files'];
    for (var tbl in tables) {
      final rows = await db.query(tbl);
      print("📂 테이블($tbl): ${rows.length}개 데이터");
      for (var row in rows) print("  - $row");
    }
    print("🔥 [DEBUG] 확인 종료\n");
  }

  // [유틸] DB 초기화 (삭제)
  Future<void> deleteAppDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'app_notes.db');

    if (_database != null) {
      await _database!.close();
      _database = null;
    }
    await databaseFactory.deleteDatabase(path);
    print("💥 DB 파일이 삭제되었습니다.");
  }
}
