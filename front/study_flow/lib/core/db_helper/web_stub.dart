// ============================================================
// web_stub.dart
// 웹 환경에서 sqflite import를 대체하는 빈 stub
// ============================================================

// 웹에서는 DB 조작이 없으므로 빈 구현체만 제공
class Database {}

class DatabaseFactory {
  Future<void> deleteDatabase(String path) async {}
}

final DatabaseFactory databaseFactory = DatabaseFactory();

Future<String> getDatabasesPath() async => '';

Future<Database> openDatabase(
  String path, {
  int? version,
  Function? onCreate,
  Function? onUpgrade,
}) async => Database();
