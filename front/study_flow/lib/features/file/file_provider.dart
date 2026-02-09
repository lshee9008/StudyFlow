import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'dart:async';

import '../../core/db_helper/files_db_helper.dart';
import '../../models/block_model.dart';
import '../../core/markdown_parser.dart';
import 'file_model.dart';

class SummaryBlock {
  String content;
  bool isSaved;
  String? relatedBlockId;

  SummaryBlock({
    required this.content,
    this.isSaved = false,
    this.relatedBlockId,
  });

  Map<String, dynamic> toJson() => {
    'content': content,
    'isSaved': isSaved,
    'relatedBlockId': relatedBlockId,
  };

  factory SummaryBlock.fromJson(Map<String, dynamic> json) {
    return SummaryBlock(
      content: json['content'] ?? '',
      isSaved: json['isSaved'] ?? false,
      relatedBlockId: json['relatedBlockId'],
    );
  }
}

final filesProvider = StateNotifierProvider<FilesNotifier, List<FileModel>>((
  ref,
) {
  return FilesNotifier();
});

class FilesNotifier extends StateNotifier<List<FileModel>> {
  FilesNotifier() : super([]);

  Future<void> loadFiles(String projectId) async {
    final files = await FilesDBHelper.selectProjectFiles(projectId);
    state = files;
  }

  Future<void> addFile(FileModel file) async {
    await FilesDBHelper.insertFile(file);
    state = [file, ...state];
  }

  Future<void> deleteFile(String fileId) async {
    await FilesDBHelper.deleteFile(fileId);
    state = state.where((f) => f.id != fileId).toList();
  }

  Future<void> updateFileTitle(String fileId, String newTitle) async {
    await FilesDBHelper.updateFile(fileId, title: newTitle);
    state = [
      for (final f in state)
        if (f.id == fileId) f.updateWith(title: newTitle) else f,
    ];
  }
}

final fileEditorProvider =
    StateNotifierProvider.autoDispose<FileEditorNotifier, FileEditorState>((
      ref,
    ) {
      return FileEditorNotifier();
    });

class FileEditorState {
  final List<Block> blocks;
  final bool isLoading;
  final String? icon;
  final List<SummaryBlock> summaryBlocks;

  FileEditorState({
    required this.blocks,
    this.isLoading = false,
    this.icon,
    this.summaryBlocks = const [],
  });

  FileEditorState copyWith({
    List<Block>? blocks,
    bool? isLoading,
    String? icon,
    List<SummaryBlock>? summaryBlocks,
  }) {
    return FileEditorState(
      blocks: blocks ?? this.blocks,
      isLoading: isLoading ?? this.isLoading,
      icon: icon ?? this.icon,
      summaryBlocks: summaryBlocks ?? this.summaryBlocks,
    );
  }
}

class FileEditorNotifier extends StateNotifier<FileEditorState> {
  FileEditorNotifier() : super(FileEditorState(blocks: []));

  Future<void> loadFileDetail(String fileId) async {
    state = state.copyWith(isLoading: true);
    final fileModel = await FilesDBHelper.getFile(fileId);

    if (fileModel != null) {
      List<Block> loadedBlocks = [];
      if (fileModel.content.isNotEmpty) {
        try {
          final List<dynamic> jsonList = jsonDecode(fileModel.content);
          loadedBlocks = jsonList.map((e) => Block.fromJson(e)).toList();
        } catch (e) {
          final parsedList = MarkdownParser.parse(fileModel.content);
          loadedBlocks = parsedList.asMap().entries.map((entry) {
            return Block(
              id: DateTime.now().toIso8601String() + "${entry.key}",
              type: entry.value['type'],
              content: entry.value['content'],
            );
          }).toList();
          if (loadedBlocks.isEmpty)
            loadedBlocks = [_createBlock(0, content: fileModel.content)];
        }
      } else {
        loadedBlocks = [_createBlock(0)];
      }

      List<SummaryBlock> loadedSummary = [];
      if (fileModel.summary != null && fileModel.summary!.isNotEmpty) {
        try {
          final List<dynamic> jsonList = jsonDecode(fileModel.summary!);
          loadedSummary = jsonList
              .map((e) => SummaryBlock.fromJson(e))
              .toList();
        } catch (e) {
          loadedSummary = [
            SummaryBlock(content: fileModel.summary!, isSaved: false),
          ];
        }
      }

      state = state.copyWith(
        blocks: loadedBlocks,
        isLoading: false,
        icon: fileModel.icon,
        summaryBlocks: loadedSummary,
      );
    } else {
      state = state.copyWith(blocks: [_createBlock(0)], isLoading: false);
    }
  }

  Future<void> saveFile({
    required String fileId,
    required String title,
    required String tags,
    required String prompt,
    required DateTime updateAt,
  }) async {
    final List<Map<String, dynamic>> contentJson = state.blocks
        .map((b) => b.toJson())
        .toList();
    final List<Map<String, dynamic>> summaryJson = state.summaryBlocks
        .map((b) => b.toJson())
        .toList();

    await FilesDBHelper.updateFile(
      fileId,
      updateAt: updateAt,
      title: title,
      tags: tags,
      icon: state.icon,
      prompt: prompt,
      content: jsonEncode(contentJson),
      summary: jsonEncode(summaryJson),
    );
  }

  Future<void> requestAutoAISummary({
    required String title,
    required String tags,
    required String prompt,
    String? activeBlockId,
  }) async {
    String fullContext = state.blocks.map((b) => b.controller.text).join("\n");
    String targetContent = "";

    if (activeBlockId != null) {
      try {
        final targetBlock = state.blocks.firstWhere(
          (b) => b.id == activeBlockId,
        );
        targetContent = targetBlock.controller.text;
      } catch (e) {
        return;
      }
    }

    // 조건 완화: 1글자라도 있으면 요청 (사용자가 테스트 중일 수 있으므로)
    if (fullContext.trim().isEmpty && title.trim().isEmpty) return;
    if (activeBlockId != null && targetContent.trim().isEmpty) return;

    state = state.copyWith(isLoading: true);

    try {
      final String baseUrl = Platform.isAndroid
          ? 'http://10.0.2.2:8000'
          : 'http://localhost:8000';

      // [프롬프트 수정] 명확한 리스트 요구
      final systemPrompt = """
역할: 지능형 노트 어시스턴트.
[지시 사항]
1. 전체 문맥을 참고하여 '타겟 내용'의 핵심을 설명하거나 요약하십시오.
2. 타겟 내용이 단어라면 그 뜻을, 문장이라면 핵심 요약을 제공하십시오.
3. **각 요약 문장은 반드시 '- '(하이픈과 공백)으로 시작하십시오.** (예: - 이것은 요약입니다.)
4. 한국어로 작성하십시오.
""";

      final requestContent =
          """
[전체 문맥]
$fullContext

[타겟 내용]
$targetContent
""";

      final response = await http.post(
        Uri.parse('$baseUrl/api/files/summarize'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "content": requestContent,
          "tags": tags,
          "custom_prompt": systemPrompt,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        String rawSummary = data['summary'];

        print("🔥 [AI 응답]: $rawSummary");

        // [파싱 로직 개선]
        List<String> newLines = [];

        // 줄바꿈으로 나누고 순회
        for (var line in rawSummary.split('\n')) {
          // 불렛 제거 및 공백 제거
          String cleanLine = line.replaceAll(RegExp(r'^[-*•]\s*'), '').trim();

          // 빈 줄이 아니면 추가
          if (cleanLine.isNotEmpty) {
            newLines.add(cleanLine);
          }
        }

        // 해당 블록의 기존 요약 삭제 (새 요약으로 갱신)
        List<SummaryBlock> mergedBlocks = state.summaryBlocks
            .where((b) => b.isSaved || b.relatedBlockId != activeBlockId)
            .toList();

        for (var line in newLines) {
          mergedBlocks.add(
            SummaryBlock(
              content: line,
              isSaved: false,
              relatedBlockId: activeBlockId,
            ),
          );
        }

        state = state.copyWith(summaryBlocks: mergedBlocks);
      }
    } catch (e) {
      print("AI Error: $e");
    } finally {
      state = state.copyWith(isLoading: false);
    }
  }

  void toggleSummaryBlockSaved(int index) {
    if (index >= state.summaryBlocks.length) return;
    final newBlocks = [...state.summaryBlocks];
    newBlocks[index].isSaved = !newBlocks[index].isSaved;
    state = state.copyWith(summaryBlocks: newBlocks);
  }

  void deleteSummaryBlock(int index) {
    if (index >= state.summaryBlocks.length) return;
    final newBlocks = [...state.summaryBlocks];
    newBlocks.removeAt(index);
    state = state.copyWith(summaryBlocks: newBlocks);
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
    blocks[index].type = newType;
    if (newType == BlockType.checkbox) blocks[index].isChecked = false;
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
