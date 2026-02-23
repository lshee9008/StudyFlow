import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'dart:async';

import '../../core/db_helper/files_db_helper.dart';
import '../../models/block_model.dart';
import '../../core/markdown_parser.dart';
import 'file_model.dart';

// [모델] 요약 블록
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

  // 1. 파일 불러오기
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

  // 2. 저장하기
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

  // 3. AI 요약 요청 (정렬 기능 추가)
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

    // 내용이 너무 짧으면 기존 자동 요약 삭제 (빈 내용 정리)
    if (activeBlockId != null && targetContent.trim().length < 2) {
      final cleanedSummaries = state.summaryBlocks
          .where((s) => s.isSaved || s.relatedBlockId != activeBlockId)
          .toList();
      if (cleanedSummaries.length != state.summaryBlocks.length) {
        state = state.copyWith(summaryBlocks: cleanedSummaries);
      }
      return;
    }

    if (fullContext.trim().isEmpty && title.trim().isEmpty) return;

    state = state.copyWith(isLoading: true);

    try {
      final String baseUrl = Platform.isAndroid
          ? 'http://10.0.2.2:8000'
          : 'http://localhost:8000';

      final systemPrompt = """
역할: 지능형 노트 어시스턴트.
[지시 사항]
1. 전체 문맥을 참고하여 '타겟 내용'의 핵심을 설명하거나 요약하십시오.
2. 답변은 **명확한 문장**으로 작성하십시오. (빈칸이나 의미 없는 특수문자 금지)
3. **각 요약 문장은 반드시 '- '(하이픈과 공백)으로 시작하십시오.**
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

        print("🔥 [AI Raw Summary]: $rawSummary");

        List<String> newLines = rawSummary
            .split('\n')
            .map(
              (line) => line.replaceAll(RegExp(r'^[-*•>0-9.]+\s*'), '').trim(),
            )
            .where((line) => line.length >= 2)
            .toList();

        // 1. 기존 요약 중 '현재 블록'의 저장 안 된 것들은 제외 (새 것으로 교체하기 위해)
        List<SummaryBlock> tempSummaries = state.summaryBlocks
            .where((b) => b.isSaved || b.relatedBlockId != activeBlockId)
            .toList();

        // 2. 새 요약 추가
        for (var line in newLines) {
          tempSummaries.add(
            SummaryBlock(
              content: line,
              isSaved: false,
              relatedBlockId: activeBlockId,
            ),
          );
        }

        // 🔴 [최종 정렬] 블록의 순서대로 요약 카드 재정렬 (Sorting)
        // 블록 ID -> 인덱스 맵 생성
        final blockOrder = {
          for (int i = 0; i < state.blocks.length; i++) state.blocks[i].id: i,
        };

        tempSummaries.sort((a, b) {
          final idxA = blockOrder[a.relatedBlockId] ?? 999999;
          final idxB = blockOrder[b.relatedBlockId] ?? 999999;
          return idxA.compareTo(idxB);
        });

        state = state.copyWith(summaryBlocks: tempSummaries);
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

  // 블록 삭제 시 관련 요약도 삭제
  void removeBlock(int index) {
    if (state.blocks.length <= 1) return;

    final String deletedBlockId = state.blocks[index].id;

    final newBlocks = [...state.blocks];
    newBlocks[index].dispose();
    newBlocks.removeAt(index);

    final newSummaries = state.summaryBlocks
        .where((s) => s.relatedBlockId != deletedBlockId)
        .toList();

    state = state.copyWith(blocks: newBlocks, summaryBlocks: newSummaries);
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
