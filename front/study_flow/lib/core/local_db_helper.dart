// import 'package:sqflite/sqflite.dart';
// import 'package:path/path.dart';
// import 'package:study_flow/features/file/file_model.dart';
// import 'package:study_flow/features/project/project_model.dart';
// import 'package:study_flow/models/user_model.dart';

// class LocalDatabase {
//   static final LocalDatabase instance = LocalDatabase._init();
//   static Database? _database;

//   LocalDatabase._init();

//   Future<Database> get database async {
//     if (_database != null) return _database!;
//     _database = await _initDB('app_notes.db');
//     return _database!;
//   }

//   Future<Database> _initDB(String filePath) async {
//     final dbPath = await getDatabasesPath();
//     final path = join(dbPath, filePath);

//     // 👇 [이거 한 줄 추가하세요!] 👇
//     print("🍎 [macOS DB Path] 파일 위치: $path");

//     return await openDatabase(
//       path,
//       version: 1,
//       onCreate: _createDB,
//       onUpgrade: _onUpgrade,
//     );
//   }

//   // [ERD 반영] 테이블 생성 쿼리
//   Future _createDB(Database db, int version) async {
//     // 1. users 테이블
//     await db.execute('''
//       CREATE TABLE users (
//         id TEXT NOT NULL PRIMARY KEY,
//         name TEXT NOT NULL,
//         join_path TEXT NOT NULL,
//         password TEXT,
//         social_id TEXT
//       )
//     ''');

//     // 2. projects 테이블 (user_id FK 추가, create_at 명칭 변경, is_sync 추가)
//     // is_sync -> server의 postgreSQL 에서 bool 형식 주의!!!
//     await db.execute('''
//       CREATE TABLE projects (
//         id TEXT NOT NULL PRIMARY KEY,
//         user_id TEXT NOT NULL,
//         create_at TEXT NOT NULL,
//         update_at TEXT NOT NULL,
//         name TEXT,
//         tags TEXT,
//         is_sync INTEGER NOT NULL DEFAULT 0,
//         FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE
//       )
//     ''');

//     // 3. files 테이블 (create_at, update_at 명칭 변경)
//     await db.execute('''
//       CREATE TABLE files (
//         id TEXT NOT NULL PRIMARY KEY, 
//         project_id TEXT NOT NULL, 
//         create_at TEXT NOT NULL, 
//         update_at TEXT, 
//         title TEXT, 
//         tags TEXT, 
//         icon TEXT, 
//         prompt TEXT, 
//         content TEXT, 
//         summary TEXT, 
//         FOREIGN KEY (project_id) REFERENCES projects (id) ON DELETE CASCADE
//       )
//     ''');
//   }

//   Future _onUpgrade(Database db, int oldVersion, int newVersion) async {}

//   // --- Project CRUD (기존 동일) ---
//   Future<int> insertUser(UserModel project) async {
//     final db = await instance.database;
//     return await db.insert('users', project.toMap());
//   }

//   Future<List<UserModel>> selectUser() async {
//     final db = await instance.database;
//     final result = await db.query('users');
//     return result.map((json) => UserModel.fromJson(json)).toList();
//   }

//   // 상황에 맞게 수정
//   Future<int> updateUser(String id, {String? name, String? password}) async {
//     final db = await instance.database;
//     final Map<String, dynamic> updates = {};
//     if (name != null) updates['name'] = name;
//     if (password != null) updates['password'] = password;
//     if (updates.isEmpty) return 0;
//     return await db.update('users', updates, where: 'id = ?', whereArgs: [id]);
//   }

//   Future<int> deleteUser(String id) async {
//     final db = await instance.database;
//     return await db.delete('users', where: 'id = ?', whereArgs: [id]);
//   }

//   // --- Project CRUD (기존 동일) ---
//   Future<int> insertProject(ProjectModel project) async {
//     final db = await instance.database;
//     return await db.insert('projects', project.toMap());
//   }

//   Future<List<ProjectModel>> selectProjects() async {
//     final db = await instance.database;
//     final result = await db.query('projects', orderBy: 'create_at DESC');
//     return result.map((json) => ProjectModel.fromJson(json)).toList();
//   }

//   Future<ProjectModel?> getProject(String projectId) async {
//     final db = await instance.database;
//     final result = await db.query(
//       'projects',
//       where: 'id = ?',
//       whereArgs: [projectId],
//     );
//     if (result.isNotEmpty) return ProjectModel.fromJson(result.first);
//     return null;
//   }

//   Future<int> updateProject(
//     String id, {
//     DateTime? updateAt,
//     String? name,
//     String? tags,
//     int? isSync,
//   }) async {
//     final db = await instance.database;
//     final Map<String, dynamic> updates = {};
//     if (updateAt != null) updates['updateAt'] = updateAt;
//     if (name != null) updates['name'] = name;
//     if (tags != null) updates['tags'] = tags;
//     if (isSync != null) updates['isSync'] = isSync;
//     if (updates.isEmpty) return 0;
//     return await db.update(
//       'projects',
//       updates,
//       where: 'id = ?',
//       whereArgs: [id],
//     );
//   }

//   Future<int> deleteProject(String id) async {
//     final db = await instance.database;
//     return await db.delete('projects', where: 'id = ?', whereArgs: [id]);
//   }

//   // --- File CRUD ---
//   Future<int> insertFile(FileModel file) async {
//     final db = await instance.database;
//     return await db.insert('files', file.toMap());
//   }

//   Future<List<FileModel>> selectProjectFiles(String projectId) async {
//     final db = await instance.database;
//     final result = await db.query(
//       'files',
//       where: 'project_id = ?',
//       whereArgs: [projectId],
//       orderBy: 'create_at DESC',
//     );
//     return result.map((json) => FileModel.fromJson(json)).toList();
//   }

//   Future<FileModel?> getFile(String fileId) async {
//     final db = await instance.database;
//     final result = await db.query(
//       'files',
//       where: 'id = ?',
//       whereArgs: [fileId],
//     );
//     if (result.isNotEmpty) return FileModel.fromJson(result.first);
//     return null;
//   }

//   // [수정] prompt 업데이트 추가
//   Future<int> updateFile(
//     String id, {
//     DateTime? updateAt,
//     String? title,
//     String? tags,
//     String? icon,
//     String? prompt,
//     String? content,
//     String? summary,
//   }) async {
//     final db = await instance.database;
//     final Map<String, dynamic> updates = {};
//     if (updateAt != null) updates['updateAt'] = updateAt;
//     if (title != null) updates['title'] = title;
//     if (tags != null) updates['tags'] = tags;
//     if (icon != null) updates['icon'] = icon;
//     if (prompt != null) updates['prompt'] = prompt;
//     if (content != null) updates['content'] = content;
//     if (summary != null) updates['summary'] = summary;
//     if (updates.isEmpty) return 0;

//     return await db.update('files', updates, where: 'id = ?', whereArgs: [id]);
//   }

//   Future<int> deleteFile(String id) async {
//     final db = await instance.database;
//     return await db.delete('files', where: 'id = ?', whereArgs: [id]);
//   }

//   // [NEW] 🛠️ DB 구조 및 데이터 확인용 디버그 함수
//   Future<void> debugPrintDatabase() async {
//     final db = await instance.database;

//     print("\n\n🔥 [DEBUG] DATABASE INSPECTION START 🔥");
//     print("==========================================");

//     // 1. 테이블 구조(스키마) 출력
//     print("[1] 🏗️ Table Structures (Schema)");
//     // sqlite_master 테이블에서 생성 쿼리를 가져옵니다.
//     final tableSchemas = await db.rawQuery(
//       "SELECT name, sql FROM sqlite_master WHERE type='table'",
//     );

//     for (var schema in tableSchemas) {
//       print("------------------------------------------");
//       print("📌 Table: ${schema['name']}");
//       print("📝 SQL: ${schema['sql']}");
//     }

//     print("\n==========================================");

//     // 2. 테이블 데이터 출력
//     print("[2] 📦 Table Data Rows");
//     // 현재 존재하는 테이블 목록 (최신 스키마 기준)
//     final targetTables = ['users', 'projects', 'files'];

//     for (var tableName in targetTables) {
//       print("------------------------------------------");
//       // 해당 테이블의 모든 데이터 조회
//       final rows = await db.query(tableName);
//       print("📂 Table: $tableName (Count: ${rows.length})");

//       if (rows.isEmpty) {
//         print("   (Empty)");
//       } else {
//         for (var i = 0; i < rows.length; i++) {
//           print("   Row[$i]: ${rows[i]}");
//         }
//       }
//     }

//     print("==========================================");
//     print("🔥 [DEBUG] INSPECTION END 🔥\n\n");
//   }

//   // [NEW] 🗑️ DB 파일 완전 삭제 및 초기화
//   Future<void> deleteAppDatabase() async {
//     final dbPath = await getDatabasesPath();
//     final path = join(dbPath, 'app_notes_v2.db'); // 현재 사용 중인 DB 이름

//     // 1. 기존 연결이 있다면 닫기 (에러 방지)
//     if (_database != null) {
//       await _database!.close();
//       _database = null; // 인스턴스 초기화
//     }

//     // 2. 파일 삭제 (요청하신 databaseFactory 사용)
//     await databaseFactory.deleteDatabase(path);

//     print("💥 [RESET] Database file deleted successfully!");
//   }
// }
