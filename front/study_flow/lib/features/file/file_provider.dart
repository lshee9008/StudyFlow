import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:study_flow/features/file/file_model.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:async';

import '../../models/block_model.dart';

import '../../core/local_db_helper.dart';

// =============================================================================
// 1️⃣ [목록 관리용] filesProvider (List<FileModel>)
// =============================================================================
// 설명: ProjectScreen에서 파일 리스트를 보여주고 추가/삭제하는 용도
final filesProvider = StateNotifierProvider<FilesNotifier, List<FileModel>>((
  ref,
) {
  return FilesNotifier();
});

class FilesNotifier extends StateNotifier<List<FileModel>> {
  FilesNotifier() : super([]);

  // 목록 불러오기
  Future<void> loadFiles(String projectId) async {
    final files = await LocalDatabase.instance.selectProjectFiles(projectId);
    state = files;
  }

  // 파일 추가
  Future<void> addFile(FileModel file) async {
    await LocalDatabase.instance.insertFile(file);
    state = [file, ...state];
  }

  // 파일 삭제
  Future<void> deleteFile(String fileId) async {
    await LocalDatabase.instance.deleteFile(fileId);
    state = state.where((f) => f.id != fileId).toList();
  }

  // (목록 화면에서 제목 수정 시 사용)
  Future<void> updatefileAll(FileModel newFileModel) async {
    await LocalDatabase.instance.updateFile(
      newFileModel.id,
      updateAt: newFileModel.update_at,
      title: newFileModel.title,
      tags: newFileModel.tags,
      icon: newFileModel.icon,
      prompt: newFileModel.prompt,
      content: newFileModel.content,
      summary: newFileModel.summary,
    );
    state = [
      for (final p in state)
        if (p.id == newFileModel.id)
          p.updateWith(
            update_at: newFileModel.update_at,
            title: newFileModel.title,
            tags: newFileModel.tags,
            icon: newFileModel.icon,
            prompt: newFileModel.prompt,
            content: newFileModel.content,
            summary: newFileModel.summary,
          )
        else
          p,
    ];
  }

  Future<void> updateFileTitle(String fileId, String? newTitle) async {
    await LocalDatabase.instance.updateFile(fileId, title: newTitle);
    state = [
      for (final f in state)
        if (f.id == fileId) f.updateWith(title: newTitle) else f,
    ];
  }
}

// =============================================================================
// 2️⃣ [에디터용] fileEditorProvider (FileEditorState) - 기존 Block State 유지!
// =============================================================================
// 설명: FileScreen 안에서 블록을 편집하고, AI 요약을 하고, 저장하는 용도
// [중요] autoDispose를 써서 파일을 닫으면 상태(블록들)를 메모리에서 해제합니다.
final fileEditorProvider =
    StateNotifierProvider.autoDispose<FileEditorNotifier, FileEditorState>((
      ref,
    ) {
      return FileEditorNotifier();
    });

// 🔹 에디터 상태 클래스
class FileEditorState {
  final List<Block> blocks; // 블록 리스트 (기존 로직)
  final bool isLoading;
  final String? icon; // 현재 아이콘
  final String summaryContent; // AI 요약 내용

  FileEditorState({
    required this.blocks,
    this.isLoading = false,
    this.icon,
    this.summaryContent = "",
  });

  FileEditorState copyWith({
    List<Block>? blocks,
    bool? isLoading,
    String? icon,
    String? summaryContent,
  }) {
    return FileEditorState(
      blocks: blocks ?? this.blocks,
      isLoading: isLoading ?? this.isLoading,
      icon: icon ?? this.icon,
      summaryContent: summaryContent ?? this.summaryContent,
    );
  }
}

// 🔹 에디터 로직 클래스
class FileEditorNotifier extends StateNotifier<FileEditorState> {
  FileEditorNotifier() : super(FileEditorState(blocks: []));

  // 1. 파일 상세 내용 불러오기 (JSON -> Block 변환)
  Future<void> loadFileDetail(String fileId) async {
    state = state.copyWith(isLoading: true);
    final fileModel = await LocalDatabase.instance.getFile(fileId);

    if (fileModel != null) {
      List<Block> loadedBlocks = [];
      if (fileModel.content.isNotEmpty) {
        try {
          final List<dynamic> jsonList = jsonDecode(fileModel.content);
          loadedBlocks = jsonList.map((e) => Block.fromJson(e)).toList();
        } catch (e) {
          loadedBlocks = [_createBlock(0)];
        }
      } else {
        loadedBlocks = [_createBlock(0)];
      }

      state = state.copyWith(
        blocks: loadedBlocks,
        isLoading: false,
        icon: fileModel.icon,
        summaryContent: fileModel.summary ?? "",
      );
    } else {
      state = state.copyWith(blocks: [_createBlock(0)], isLoading: false);
    }
  }

  // 2. 파일 저장하기 (Block -> JSON 변환 -> DB 저장)
  Future<void> saveFile({
    required String fileId,
    required String title,
    required String tags,
    required String prompt,
    required DateTime updateAt,
  }) async {
    // 블록들을 JSON으로 직렬화
    final List<Map<String, dynamic>> jsonList = state.blocks
        .map((b) => b.toJson())
        .toList();
    final String contentJson = jsonEncode(jsonList);

    await LocalDatabase.instance.updateFile(
      fileId,
      updateAt: updateAt,
      title: title,
      tags: tags,
      icon: state.icon, // 현재 아이콘 상태
      prompt: prompt,
      content: contentJson, // 변환된 블록 내용
      summary: state.summaryContent, // 현재 요약 상태
    );
  }

  // 3. AI 요약 요청 (기존 로직 유지)
  Future<void> requestAutoAISummary({
    required String tags,
    required String prompt,
  }) async {
    String content = state.blocks.map((b) => b.controller.text).join("\n");

    // 내용이 너무 짧으면 요청 안 함 (오작동 방지)
    if (content.trim().length < 5) return;

    state = state.copyWith(isLoading: true);

    try {
      final String baseUrl = Platform.isAndroid
          ? 'http://10.0.2.2:8000'
          : 'http://localhost:8000';

      // [프롬프트 수정] 한국어 출력 및 형식 강제
      final systemPrompt =
          """
Role: Professional Summarizer.
Task: Summarize the user's notes based on the request: "$prompt".
Context Tags: "$tags".

[Rules]
1. **Must respond in Korean (한국어).**
2. Use valid **Markdown** format.
3. Use bullet points (-) for clarity.
4. **Do NOT** include conversational fillers like "Here is the summary". Just provide the summary directly.
5. If the input is just a single word or too short, define that term or explain it briefly in Korean.
""";

      final response = await http.post(
        Uri.parse('$baseUrl/api/ai/summarize'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "content": content,
          "tags": tags,
          "custom_prompt": systemPrompt,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        String summary = data['summary'];
        state = state.copyWith(summaryContent: summary);
      }
    } catch (e) {
      print("AI Error: $e");
    } finally {
      state = state.copyWith(isLoading: false);
    }
  }

  // 요약 내용 직접 수정
  void updateSummaryContent(String newContent) {
    state = state.copyWith(summaryContent: newContent);
  }

  // --- [블록 조작 메서드들] (기존 로직 유지) ---
  void addBlock(
    int index, {
    BlockType type = BlockType.text,
    String initialContent = "",
  }) {
    final newBlock = _createBlock(index, type: type, content: initialContent);
    final newBlocks = [...state.blocks];
    newBlocks.insert(index, newBlock);
    state = state.copyWith(blocks: newBlocks);
  }

  void removeBlock(int index) {
    if (state.blocks.length <= 1) return;
    final newBlocks = [...state.blocks];
    newBlocks[index].dispose();
    newBlocks.removeAt(index);
    state = state.copyWith(blocks: newBlocks);
  }

  void updateBlockType(int index, BlockType newType) {
    final blocks = [...state.blocks];
    final block = blocks[index];
    block.type = newType;
    block.controller.text = ""; // 타입 변경 시 내용 초기화 (선택사항)
    if (newType == BlockType.checkbox) block.isChecked = false;
    state = state.copyWith(blocks: blocks);
  }

  void toggleCheckbox(int index, bool value) {
    final blocks = [...state.blocks];
    blocks[index].isChecked = value;
    state = state.copyWith(blocks: blocks);
  }

  void updateIcon(String? newIcon) {
    state = state.copyWith(icon: newIcon);
  }

  Block _createBlock(
    int index, {
    BlockType type = BlockType.text,
    String content = "",
  }) {
    return Block(
      id: DateTime.now().toIso8601String() + "$index",
      type: type,
      content: content,
    );
  }
}
