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

  // 🤖 [AI 핵심] 퀄리티의 끝판왕, 백과사전 수준의 프롬프트 튜닝
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

      // 🚨 AI가 교수님 수준으로 완벽하게 정리하도록 강제하는 프롬프트
      final systemPrompt =
          """
당신은 IT 및 학문 분야의 '최고 수준 전문가'이자 '백과사전 집필진'입니다.

[배경 지식 도메인]
- 문서 제목: "$title"
- 관련 태그: "$tags"

[절대 규칙 - 위반 시 치명적 오류 발생]
1. 인사말, 서론, 부연 설명("알겠습니다", "설명해 드릴게요" 등)은 절대 출력하지 마세요. 즉시 본론만 출력하세요.
2. [문서 제목]이나 [태그] 자체의 의미를 설명하지 마세요. 오직 문맥을 파악하는 용도로만 사용하세요.
3. 사용자가 작성한 **[분석 대상 텍스트]**에 대해 단순 사전적 의미를 넘어, 실무적/학술적 관점에서 **매우 깊이 있고 상세하게** 분석하세요.
4. 분석 대상이 짧은 단어(예: insert, print)일지라도, 해당 도메인 내에서의 동작 원리, 사용 목적, 중요성 등을 백과사전 수준으로 확장하여 설명하세요.

[필수 작성 포맷 (마크다운 적극 활용)]
응답은 반드시 아래의 구조화된 마크다운(Markdown) 포맷을 사용하여 가독성을 극대화하세요.
- **📌 핵심 정의**: 대상 텍스트의 명확한 개념 설명 (굵은 글씨 활용)
- **💡 주요 특징 및 원리**: 글머리 기호(-)를 활용한 상세한 리스트 나열
- **💻 활용 예시 / 코드**: 구체적인 예시나 상황 (코드 블록 ` ``` ` 적극 활용)
- **📊 비교 / 참고 (선택)**: 관련된 다른 개념이나 속성이 있다면 마크다운 표(Table)로 시각화

다양한 시각적 요소(리스트, 표, 코드, 인용구 등)를 총동원하여 사용자에게 압도적인 퀄리티의 정보 카드를 제공하세요.
""";

      final requestContent =
          """
[전체 흐름 참고용]
$fullContext

[분석 대상 텍스트 (이것을 상세하고 깊이 있게 분석/설명하세요)]
$targetContent
""";

      final response = await http.post(
        Uri.parse('$baseUrl/api/files/summarize'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "content": requestContent,
          "tags": "",
          "custom_prompt": systemPrompt,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        String rawSummary = data['summary'];

        print("🔥 [AI Raw Summary]: \n$rawSummary");

        // 🧹 마크다운 포맷 정리 (가끔 AI가 최상단에 ```markdown 을 붙이는 오류 방지)
        String cleanSummary = rawSummary.trim();
        cleanSummary = cleanSummary.replaceFirst(
          RegExp(r'^```(markdown)?\n?'),
          '',
        );
        cleanSummary = cleanSummary.replaceFirst(RegExp(r'\n?```$'), '');
        cleanSummary = cleanSummary.trim();

        List<SummaryBlock> tempSummaries = state.summaryBlocks
            .where((b) => b.isSaved || b.relatedBlockId != activeBlockId)
            .toList();

        if (cleanSummary.isNotEmpty) {
          tempSummaries.add(
            SummaryBlock(
              content: cleanSummary,
              isSaved: false,
              relatedBlockId: activeBlockId,
            ),
          );
        }

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
