import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:study_flow/features/file/file_model.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:async';

import '../../models/block_model.dart';

import '../../core/local_db_helper.dart';

class FileState {
  final List<Block> blocks;
  final bool isLoading;
  final String? icon;
  final String summaryContent;

  FileState({
    required this.blocks,
    this.isLoading = false,
    this.icon,
    this.summaryContent = "",
  });

  FileState copyWith({
    List<Block>? blocks,
    bool? isLoading,
    String? icon,
    String? summaryContent,
  }) {
    return FileState(
      blocks: blocks ?? this.blocks,
      isLoading: isLoading ?? this.isLoading,
      icon: icon ?? this.icon,
      summaryContent: summaryContent ?? this.summaryContent,
    );
  }
}

final fileProvider = StateNotifierProvider.autoDispose<FileNotifier, FileState>(
  (ref) => FileNotifier(),
);

class FileNotifier extends StateNotifier<FileState> {
  FileNotifier() : super(FileState(blocks: []));

  // 1. 파일 불러오기
  Future<FileModel?> loadFile(String fileId) async {
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
        summaryContent: fileModel.summary ?? "", // 요약 내용 복원
      );
      return fileModel; // [중요] FileModel 반환 (프롬프트 정보 포함됨)
    } else {
      state = state.copyWith(blocks: [_createBlock(0)], isLoading: false);
      return null;
    }
  }

  // 2. 파일 저장하기 (프롬프트 포함)
  Future<void> saveFile({
    required String fileId,
    required String title,
    required String tags,
    required String prompt, // [NEW] 프롬프트 인자 추가
  }) async {
    final List<Map<String, dynamic>> jsonList = state.blocks
        .map((b) => b.toJson())
        .toList();
    final String contentJson = jsonEncode(jsonList);

    await LocalDatabase.instance.updateFile(
      id: fileId,
      title: title,
      tags: tags,
      content: contentJson,
      icon: state.icon,
      summary: state.summaryContent, // 현재 요약 상태 저장
      prompt: prompt, // [NEW] 프롬프트 내용 저장
    );
  }

  // 3. AI 요약 요청
  Future<void> requestAutoAISummary({
    required String tags,
    required String prompt,
  }) async {
    String content = state.blocks.map((b) => b.controller.text).join("\n");
    if (content.trim().length < 5) return;

    state = state.copyWith(isLoading: true);

    try {
      final String baseUrl = Platform.isAndroid
          ? 'http://10.0.2.2:8000'
          : 'http://localhost:8000';

      final systemPrompt =
          """
Role: Professional Summarizer.
Task: Summarize the user's notes based on the request: "$prompt".
Context Tags: "$tags".

[Rules]
1. **Must respond in Korean (한국어).**
2. Use valid **Markdown** format.
3. Use bullet points (-) for clarity.
4. **Do NOT** include conversational fillers like "Here is the summary".
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

  void updateSummaryContent(String newContent) {
    state = state.copyWith(summaryContent: newContent);
  }

  // --- Block Methods ---
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
    block.controller.text = "";
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
}
