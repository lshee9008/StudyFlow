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
  factory SummaryBlock.fromJson(Map<String, dynamic> json) => SummaryBlock(
    content: json['content'] ?? '',
    isSaved: json['isSaved'] ?? false,
    relatedBlockId: json['relatedBlockId'],
  );
}

final filesProvider = StateNotifierProvider<FilesNotifier, List<FileModel>>(
  (ref) => FilesNotifier(),
);

class FilesNotifier extends StateNotifier<List<FileModel>> {
  FilesNotifier() : super([]);
  Future<void> loadFiles(String projectId) async {
    state = await FilesDBHelper.selectProjectFiles(projectId);
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
    StateNotifierProvider.autoDispose<FileEditorNotifier, FileEditorState>(
      (ref) => FileEditorNotifier(),
    );

class FileEditorState {
  final List<Block> blocks;
  final bool isLoading;
  final bool isAnalysisLoading;
  final bool isSummaryLoading;
  final String? icon;
  final List<SummaryBlock> summaryBlocks;
  final String? currentBlockAnalysis;
  final String focusedText;

  FileEditorState({
    required this.blocks,
    this.isLoading = false,
    this.isAnalysisLoading = false,
    this.isSummaryLoading = false,
    this.icon,
    this.summaryBlocks = const [],
    this.currentBlockAnalysis,
    this.focusedText = "",
  });

  FileEditorState copyWith({
    List<Block>? blocks,
    bool? isLoading,
    bool? isAnalysisLoading,
    bool? isSummaryLoading,
    String? icon,
    List<SummaryBlock>? summaryBlocks,
    String? currentBlockAnalysis,
    String? focusedText,
  }) {
    return FileEditorState(
      blocks: blocks ?? this.blocks,
      isLoading: isLoading ?? this.isLoading,
      isAnalysisLoading: isAnalysisLoading ?? this.isAnalysisLoading,
      isSummaryLoading: isSummaryLoading ?? this.isSummaryLoading,
      icon: icon ?? this.icon,
      summaryBlocks: summaryBlocks ?? this.summaryBlocks,
      currentBlockAnalysis: currentBlockAnalysis ?? this.currentBlockAnalysis,
      focusedText: focusedText ?? this.focusedText,
    );
  }
}

class FileEditorNotifier extends StateNotifier<FileEditorState> {
  FileEditorNotifier() : super(FileEditorState(blocks: []));
  int _lastAnalysisRequestId = 0;

  Future<void> loadFileDetail(String fileId) async {
    state = state.copyWith(isLoading: true);
    final fileModel = await FilesDBHelper.getFile(fileId);

    if (fileModel != null) {
      List<Block> loadedBlocks = [];
      if (fileModel.content.isNotEmpty) {
        try {
          loadedBlocks = (jsonDecode(fileModel.content) as List)
              .map((e) => Block.fromJson(e))
              .toList();
        } catch (e) {
          final parsedList = MarkdownParser.parse(fileModel.content);
          loadedBlocks = parsedList
              .asMap()
              .entries
              .map(
                (entry) => Block(
                  id: DateTime.now().toIso8601String() + "${entry.key}",
                  type: entry.value['type'],
                  content: entry.value['content'],
                ),
              )
              .toList();
          if (loadedBlocks.isEmpty)
            loadedBlocks = [_createBlock(0, content: fileModel.content)];
        }
      } else {
        loadedBlocks = [_createBlock(0)];
      }

      List<SummaryBlock> loadedSummary = [];
      if (fileModel.summary != null && fileModel.summary!.isNotEmpty) {
        try {
          loadedSummary = (jsonDecode(fileModel.summary!) as List)
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
    await FilesDBHelper.updateFile(
      fileId,
      updateAt: updateAt,
      title: title,
      tags: tags,
      icon: state.icon,
      prompt: prompt,
      content: jsonEncode(state.blocks.map((b) => b.toJson()).toList()),
      summary: jsonEncode(state.summaryBlocks.map((b) => b.toJson()).toList()),
    );
  }

  Future<void> requestAutoAISummary({
    required String title,
    required String tags,
    required String prompt,
  }) async {
    String fullContext = state.blocks.map((b) => b.controller.text).join("\n");
    if (fullContext.trim().isEmpty) return;

    state = state.copyWith(isSummaryLoading: true);
    try {
      final String baseUrl = Platform.isAndroid
          ? 'http://10.0.2.2:8000'
          : 'http://localhost:8000';
      final response = await http.post(
        Uri.parse('$baseUrl/api/files/summarize'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "content": fullContext,
          "tags": tags,
          "custom_prompt": "전체 문서의 핵심 내용을 3줄 이내로 아주 간결하게 요약하세요.",
        }),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        List<SummaryBlock> keptBlocks = state.summaryBlocks
            .where((b) => b.isSaved)
            .toList();
        keptBlocks.insert(
          0,
          SummaryBlock(content: data['summary'], isSaved: false),
        );
        state = state.copyWith(
          summaryBlocks: keptBlocks,
          isSummaryLoading: false,
        );
      } else {
        state = state.copyWith(isSummaryLoading: false);
      }
    } catch (e) {
      state = state.copyWith(isSummaryLoading: false);
    }
  }

  // 💡 [수정] 프롬프트 최적화: TMI를 없애고 핵심 의미만 묻기
  Future<void> requestBlockAnalysis({
    required String text,
    required String tags,
    required String documentContext,
  }) async {
    state = state.copyWith(focusedText: text);
    if (text.trim().length < 2) {
      state = state.copyWith(
        currentBlockAnalysis: null,
        isAnalysisLoading: false,
      );
      return;
    }

    final currentRequestId = ++_lastAnalysisRequestId;
    state = state.copyWith(isAnalysisLoading: true);

    try {
      final String baseUrl = Platform.isAndroid
          ? 'http://10.0.2.2:8000'
          : 'http://localhost:8000';

      // 💡 여기가 핵심입니다. AI가 딴소리하지 못하도록 강력하게 제한합니다.
      final prompt =
          """
전체 문맥([제목/주제]: $documentContext)을 고려했을 때, 
사용자가 선택한 아래 문단이 무슨 의미인지 핵심만 파악하세요.
[선택된 문단]: $text

지시사항:
1. 불필요한 배경 설명(TMI), 인사말, 서론은 모두 제외하세요.
2. 이 문단이 뜻하는 핵심 개념이나 목적만 1~3문장 이내로 아주 간결하게 답변하세요.
3. 보기 좋게 마크다운(예: 굵은 글씨, 짧은 리스트)을 활용하세요.
""";

      final response = await http.post(
        Uri.parse('$baseUrl/api/files/summarize'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "content": text,
          "tags": tags,
          "custom_prompt": prompt,
        }),
      );

      if (currentRequestId == _lastAnalysisRequestId) {
        if (response.statusCode == 200) {
          final data = jsonDecode(utf8.decode(response.bodyBytes));
          state = state.copyWith(
            currentBlockAnalysis: data['summary'],
            isAnalysisLoading: false,
          );
        } else {
          state = state.copyWith(isAnalysisLoading: false);
        }
      }
    } catch (e) {
      if (currentRequestId == _lastAnalysisRequestId)
        state = state.copyWith(isAnalysisLoading: false);
    }
  }

  void toggleSummaryBlockSaved(int index) {
    if (index >= state.summaryBlocks.length) return;
    final newBlocks = [...state.summaryBlocks];
    newBlocks[index].isSaved = !newBlocks[index].isSaved;
    state = state.copyWith(summaryBlocks: newBlocks);
  }

  void deleteSummaryBlock(int index) {
    final newBlocks = [...state.summaryBlocks];
    newBlocks.removeAt(index);
    state = state.copyWith(summaryBlocks: newBlocks);
  }

  void insertBlocks(int index, List<String> contents) {
    final newBlocks = [...state.blocks];
    for (int i = 0; i < contents.length; i++) {
      String text = contents[i];
      BlockType type = BlockType.text;
      if (text.startsWith('# ')) {
        type = BlockType.h1;
        text = text.substring(2);
      } else if (text.startsWith('## ')) {
        type = BlockType.h2;
        text = text.substring(3);
      } else if (text.startsWith('- ')) {
        type = BlockType.bullet;
        text = text.substring(2);
      } else if (text.startsWith('[] ')) {
        type = BlockType.checkbox;
        text = text.replaceFirst(RegExp(r'\[\s?\]\s?'), '');
      }
      newBlocks.insert(
        index + i,
        _createBlock(index + i, type: type, content: text),
      );
    }
    state = state.copyWith(blocks: newBlocks);
  }

  void removeBlock(int index) {
    if (state.blocks.length <= 1) return;
    final newBlocks = [...state.blocks];
    newBlocks[index].dispose();
    newBlocks.removeAt(index);
    state = state.copyWith(blocks: newBlocks);
  }

  void reorderBlock(int oldIndex, int newIndex) {
    if (oldIndex < newIndex) newIndex -= 1;
    final blocks = [...state.blocks];
    final Block item = blocks.removeAt(oldIndex);
    blocks.insert(newIndex, item);
    state = state.copyWith(blocks: blocks);
  }

  void duplicateBlock(int index) {
    final original = state.blocks[index];
    final newBlock = _createBlock(
      index + 1,
      type: original.type,
      content: original.controller.text,
    );
    newBlock.isChecked = original.isChecked;
    final newBlocks = [...state.blocks];
    newBlocks.insert(index + 1, newBlock);
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
