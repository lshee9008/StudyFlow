import 'dart:convert';
import 'dart:async';
import 'dart:io' as io;

import 'package:flutter/foundation.dart'; // kIsWeb
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../core/db_helper/files_db_helper.dart';
import '../../models/block_model.dart';
import '../../core/markdown_parser.dart';
import 'file_model.dart';

// API 베이스 URL (웹/안드로이드/iOS 분기)
String get apiBaseUrl {
  if (kIsWeb) return 'http://127.0.0.1:8000';
  if (io.Platform.isAndroid) return 'http://10.0.2.2:8000';
  return 'http://127.0.0.1:8000';
}

class SummaryBlock {
  String content;
  bool isSaved;
  SummaryBlock({required this.content, this.isSaved = false});
  Map<String, dynamic> toJson() => {'content': content, 'isSaved': isSaved};
  factory SummaryBlock.fromJson(Map<String, dynamic> json) => SummaryBlock(
    content: json['content'] ?? '',
    isSaved: json['isSaved'] ?? false,
  );
}

// -----------------------------------------------------------------------------
// [FilesNotifier] 프로젝트 내 파일 목록 관리
// -----------------------------------------------------------------------------
final filesProvider = StateNotifierProvider<FilesNotifier, List<FileModel>>(
  (ref) => FilesNotifier(),
);

class FilesNotifier extends StateNotifier<List<FileModel>> {
  FilesNotifier() : super([]);

  Future<void> loadFiles(String projectId) async {
    if (!kIsWeb) {
      state = await FilesDBHelper.selectProjectFiles(projectId);
    } else {
      state = []; // 🌐 웹에서는 API로 로드 (현재는 로컬 리스트 유지)
    }
  }

  Future<void> addFile(FileModel file) async {
    if (!kIsWeb) await FilesDBHelper.insertFile(file);
    state = [file, ...state];
  }

  Future<void> deleteFile(String fileId) async {
    if (!kIsWeb) await FilesDBHelper.deleteFile(fileId);
    state = state.where((f) => f.id != fileId).toList();
  }

  Future<void> updateFileTitle(String fileId, String newTitle) async {
    if (!kIsWeb) await FilesDBHelper.updateFile(fileId, title: newTitle);
    state = [
      for (final f in state)
        if (f.id == fileId) f.updateWith(title: newTitle) else f,
    ];
  }
}

// -----------------------------------------------------------------------------
// [FileEditorNotifier] 개별 파일 에디터 상태 관리 (AI 스튜디오 포함)
// -----------------------------------------------------------------------------
final fileEditorProvider =
    StateNotifierProvider.autoDispose<FileEditorNotifier, FileEditorState>(
      (ref) => FileEditorNotifier(),
    );

class FileEditorState {
  final List<Block> blocks;
  final bool isLoading;
  final bool isSummaryLoading; // [Track 1] 전체 요약 로딩
  final bool isAnalysisLoading; // [Track 2] 포커스 분석 로딩
  final bool isStudioLoading; // 암기/퀴즈 로딩
  final bool isQALoading; // Quick Ask 로딩
  final bool isGraphLoading; // [Track 3] AI 지식 그래프 로딩

  final String? icon;
  final List<SummaryBlock> summaryBlocks; // 전체 요약
  final String? currentBlockAnalysis; // 포커스 요약
  final String? currentMemo; // 핵심 암기
  final List<dynamic>? quizData; // 인터랙티브 퀴즈
  final Map<int, int> quizAnswers; // 유저 퀴즈 정답
  final String? qaAnswer; // Quick Ask 답변
  final Map<String, dynamic>? aiGraphData; // AI가 추출한 그래프 데이터

  final String focusedText;
  final DateTime? lastSavedAt;

  FileEditorState({
    required this.blocks,
    this.isLoading = false,
    this.isSummaryLoading = false,
    this.isAnalysisLoading = false,
    this.isStudioLoading = false,
    this.isQALoading = false,
    this.isGraphLoading = false,
    this.icon,
    this.summaryBlocks = const [],
    this.currentBlockAnalysis,
    this.currentMemo,
    this.quizData,
    this.quizAnswers = const {},
    this.qaAnswer,
    this.aiGraphData,
    this.focusedText = "",
    this.lastSavedAt,
  });

  FileEditorState copyWith({
    List<Block>? blocks,
    bool? isLoading,
    bool? isSummaryLoading,
    bool? isAnalysisLoading,
    bool? isStudioLoading,
    bool? isQALoading,
    bool? isGraphLoading,
    String? icon,
    List<SummaryBlock>? summaryBlocks,
    String? currentBlockAnalysis,
    String? currentMemo,
    List<dynamic>? quizData,
    Map<int, int>? quizAnswers,
    String? qaAnswer,
    Map<String, dynamic>? aiGraphData,
    String? focusedText,
    DateTime? lastSavedAt,
  }) {
    return FileEditorState(
      blocks: blocks ?? this.blocks,
      isLoading: isLoading ?? this.isLoading,
      isSummaryLoading: isSummaryLoading ?? this.isSummaryLoading,
      isAnalysisLoading: isAnalysisLoading ?? this.isAnalysisLoading,
      isStudioLoading: isStudioLoading ?? this.isStudioLoading,
      isQALoading: isQALoading ?? this.isQALoading,
      isGraphLoading: isGraphLoading ?? this.isGraphLoading,
      icon: icon ?? this.icon,
      summaryBlocks: summaryBlocks ?? this.summaryBlocks,
      currentBlockAnalysis: currentBlockAnalysis ?? this.currentBlockAnalysis,
      currentMemo: currentMemo ?? this.currentMemo,
      quizData: quizData ?? this.quizData,
      quizAnswers: quizAnswers ?? this.quizAnswers,
      qaAnswer: qaAnswer ?? this.qaAnswer,
      aiGraphData: aiGraphData ?? this.aiGraphData,
      focusedText: focusedText ?? this.focusedText,
      lastSavedAt: lastSavedAt ?? this.lastSavedAt,
    );
  }
}

class FileEditorNotifier extends StateNotifier<FileEditorState> {
  FileEditorNotifier() : super(FileEditorState(blocks: []));

  String _lastAnalyzedText = "";

  // 📌 [추가] 요약본 확정(잠금) 상태를 토글하는 함수
  void toggleSummarySave(int index) {
    final newSummaries = List<SummaryBlock>.from(state.summaryBlocks);
    newSummaries[index] = SummaryBlock(
      content: newSummaries[index].content,
      isSaved: !newSummaries[index].isSaved,
    );
    state = state.copyWith(summaryBlocks: newSummaries);
    saveFile(
      fileId: "current_file_id",
      title: "auto",
      tags: "",
      prompt: "",
      updateAt: DateTime.now(),
    );
  }

  Future<void> loadFileDetail(String fileId) async {
    state = state.copyWith(isLoading: true);
    FileModel? fileModel;
    if (!kIsWeb) fileModel = await FilesDBHelper.getFile(fileId);

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
        }
      }
      if (loadedBlocks.isEmpty) loadedBlocks = [_createBlock(0)];

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
    final List<Map<String, dynamic>> blocksDataToSave = state.blocks.map((b) {
      var json = b.toJson();
      json['content'] = b.controller.text;
      return json;
    }).toList();

    if (!kIsWeb) {
      await FilesDBHelper.updateFile(
        fileId,
        updateAt: updateAt,
        title: title,
        tags: tags,
        icon: state.icon,
        prompt: prompt,
        content: jsonEncode(blocksDataToSave),
        summary: jsonEncode(
          state.summaryBlocks.map((b) => b.toJson()).toList(),
        ),
      );
    }
    state = state.copyWith(lastSavedAt: DateTime.now());
  }

  // 🌟 [Track 1] 전체 구조적 요약
  Future<void> requestAutoAISummary({
    required String title,
    required String tags,
  }) async {
    String fullContext = state.blocks.map((b) => b.controller.text).join("\n");
    if (fullContext.trim().isEmpty) return;

    state = state.copyWith(isSummaryLoading: true);

    try {
      List<SummaryBlock> savedBlocks = state.summaryBlocks
          .where((b) => b.isSaved)
          .toList();
      String savedText = savedBlocks.map((b) => b.content).join("\n\n");

      String customPrompt;
      if (savedText.isNotEmpty) {
        customPrompt =
            """
        문서 제목: $title
        [기존에 확정된 요약]
        $savedText
        
        [현재 문서 전체 내용]
        $fullContext
        
        당신은 위 [현재 문서 전체 내용]과 [기존에 확정된 요약]을 꼼꼼히 비교해야 합니다.
        기존 요약에 이미 포함된 내용은 **절대 중복해서 작성하지 말고 제외**하세요.
        문서에 '새롭게 추가되었거나 변경된 핵심 내용'만 추출하여 구조화된 마크다운으로 [추가 요약]을 작성해 주세요.
        만약 새롭게 추가된 내용이 없다면 반드시 "추가된 내용이 없습니다."라고만 대답하세요.
        """;
      } else {
        customPrompt =
            """
        문서 제목: $title
        문서 내용 전체를 구조화된 요약 노트(개조식, 마크다운 표 포함)로 정리해 주세요. 이모티콘은 제외하고 학술적으로 작성하세요.
        """;
      }

      final response = await http.post(
        Uri.parse('$apiBaseUrl/api/ai/summarize'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "content": fullContext,
          "tags": tags,
          "custom_prompt": customPrompt,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        if (!mounted) return;

        String newSummaryText = data['summary'].toString().trim();
        List<SummaryBlock> newSummaries = List.from(savedBlocks);

        if (newSummaryText.isNotEmpty &&
            !newSummaryText.contains("추가된 내용이 없습니다")) {
          newSummaries.add(
            SummaryBlock(content: newSummaryText, isSaved: false),
          );
        }

        state = state.copyWith(
          summaryBlocks: newSummaries,
          isSummaryLoading: false,
        );
      } else {
        if (!mounted) return;
        state = state.copyWith(isSummaryLoading: false);
      }
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(isSummaryLoading: false);
    }
  }

  // 🎯 [Track 2] 포커스 부분 심층 분석
  Future<void> requestBlockAnalysis({
    required String text,
    required String contextTitle,
  }) async {
    if (text.trim().length < 5 || text == _lastAnalyzedText) return;

    _lastAnalyzedText = text;
    state = state.copyWith(focusedText: text, isAnalysisLoading: true);

    try {
      final prompt =
          "문서($contextTitle)의 문맥을 고려하여 다음 문단/문장의 핵심 의미를 3줄 내외로 아주 명확히 심층 분석해 주세요.\n내용: $text";

      final response = await http.post(
        Uri.parse('$apiBaseUrl/api/ai/summarize'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "content": text,
          "tags": "",
          "custom_prompt": prompt,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        if (!mounted) return;
        state = state.copyWith(
          currentBlockAnalysis: data['summary'],
          isAnalysisLoading: false,
        );
      } else {
        if (!mounted) return;
        state = state.copyWith(isAnalysisLoading: false);
      }
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(isAnalysisLoading: false);
    }
  }

  // 💡 [학습 도구] 암기 및 인터랙티브 퀴즈
  Future<void> generateStudioContent(String type) async {
    String fullContext = state.blocks.map((b) => b.controller.text).join("\n");
    if (fullContext.trim().isEmpty) return;

    state = state.copyWith(isStudioLoading: true);
    try {
      String customPrompt = type == 'memo'
          ? "본문 내용 중 시험에 무조건 나올 만한 '핵심 암기 사항' 5가지를 이모티콘 없이 명확한 리스트와 표를 활용하여 추출해 주세요."
          : "본문 내용을 바탕으로 객관식 퀴즈 3문제를 출제해 주세요. 반드시 다음의 순수 JSON 배열 형식으로만 응답해야 합니다: [{\"question\":\"문제\",\"options\":[\"1\",\"2\",\"3\",\"4\"],\"answer\":0,\"explanation\":\"해설\"}]";

      final response = await http.post(
        Uri.parse('$apiBaseUrl/api/ai/summarize'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "content": fullContext,
          "tags": "",
          "custom_prompt": customPrompt,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));

        if (type == 'memo') {
          if (!mounted) return;
          state = state.copyWith(
            currentMemo: data['summary'],
            isStudioLoading: false,
          );
        } else {
          String resText = data['summary']
              .toString()
              .replaceAll(RegExp(r'```json|```'), '')
              .trim();
          int startIdx = resText.indexOf('[');
          int endIdx = resText.lastIndexOf(']');
          if (startIdx != -1 && endIdx != -1) {
            List<dynamic> parsedQuiz = jsonDecode(
              resText.substring(startIdx, endIdx + 1),
            );

            if (!mounted) return;
            state = state.copyWith(
              quizData: parsedQuiz,
              quizAnswers: {},
              isStudioLoading: false,
            );
          } else {
            if (!mounted) return;
            state = state.copyWith(isStudioLoading: false);
          }
        }
      } else {
        if (!mounted) return;
        state = state.copyWith(isStudioLoading: false);
      }
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(isStudioLoading: false);
    }
  }

  void answerQuiz(int questionIndex, int selectedOptionIndex) {
    if (state.quizAnswers.containsKey(questionIndex)) return;
    final newAnswers = Map<int, int>.from(state.quizAnswers);
    newAnswers[questionIndex] = selectedOptionIndex;
    state = state.copyWith(quizAnswers: newAnswers);
  }

  // 🔍 [RAG 시스템] Quick Ask (내 노트 + 웹 검색)
  Future<void> askAI(String query, String projectId) async {
    if (query.trim().isEmpty) return;

    state = state.copyWith(isQALoading: true);
    try {
      final response = await http.post(
        Uri.parse('$apiBaseUrl/api/ai/ask'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "query": query,
          "project_id": projectId,
          "use_web_search": true,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        final finalAnswer =
            "### 💡 AI 답변 (출처: ${data['source']})\n\n${data['answer']}";

        if (!mounted) return;
        state = state.copyWith(qaAnswer: finalAnswer, isQALoading: false);
      } else {
        if (!mounted) return;
        state = state.copyWith(isQALoading: false, qaAnswer: "응답을 가져오지 못했습니다.");
      }
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(isQALoading: false, qaAnswer: "오류가 발생했습니다.");
    }
  }

  // 🌌 [AI 지식 그래프 추출]
  Future<void> requestAIGraph() async {
    String fullContext = state.blocks.map((b) => b.controller.text).join("\n");
    if (fullContext.trim().length < 20) return;

    state = state.copyWith(isGraphLoading: true);

    try {
      final response = await http.post(
        Uri.parse('$apiBaseUrl/api/ai/graph'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"content": fullContext}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        if (!mounted) return;
        state = state.copyWith(aiGraphData: data, isGraphLoading: false);
      } else {
        if (!mounted) return;
        state = state.copyWith(isGraphLoading: false);
      }
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(isGraphLoading: false);
    }
  }

  // [에디터 블록 로직]
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
        text = text.replaceFirst(RegExp(r'^\[\]\s?'), '');
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
    )..isChecked = original.isChecked;
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
