import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/folder_model.dart';
import '../core/local_db_helper.dart';

// API 주소 (Android Emulator: 10.0.2.2, iOS/Web: localhost)
const String baseUrl = "http://localhost:8000";

class ProjectNotifier extends StateNotifier<List<FolderModel>> {
  ProjectNotifier() : super([]);

  // 1. 로드: 로컬 DB -> 화면 표시 -> 서버 동기화
  Future<void> loadProjects() async {
    final db = await LocalDatabase.instance.database;
    final maps = await db.query('folders', orderBy: "created_at DESC");
    state = maps.map((e) => FolderModel.fromJson(e)).toList();

    try {
      final response = await http.get(Uri.parse('$baseUrl/projects/'));
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(utf8.decode(response.bodyBytes));
        final serverProjects = data
            .map((e) => FolderModel.fromJson(e))
            .toList();
        state = serverProjects;

        // 로컬 DB 최신화 (Batch 처리 권장)
        final batch = db.batch();
        batch.delete('folders');
        for (var p in serverProjects) batch.insert('folders', p.toMap());
        await batch.commit(noResult: true);
      }
    } catch (e) {
      print("Offline mode: $e");
    }
  }

  // 2. 추가: 화면 즉시 반영(Optimistic) -> 로컬 저장 -> 서버 전송
  Future<void> addProject(String name) async {
    final newProject = FolderModel(
      id: const Uuid().v4(),
      name: name,
      createdAt: DateTime.now(),
    );

    state = [newProject, ...state]; // 즉시 UI 업데이트

    final db = await LocalDatabase.instance.database;
    await db.insert('folders', newProject.toMap());

    try {
      await http.post(
        Uri.parse('$baseUrl/projects/'),
        headers: {"Content-Type": "application/json"},
        body: json.encode(newProject.toMap()),
      );
    } catch (e) {
      // 실패 시 나중에 Sync하는 로직 필요 (큐잉 등)
      print("Failed to sync with server: $e");
    }
  }
}

final projectProvider =
    StateNotifierProvider<ProjectNotifier, List<FolderModel>>((ref) {
      return ProjectNotifier()..loadProjects();
    });
