import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
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
  final bool isStudioLoading;
  final String? icon;
  final List<SummaryBlock> summaryBlocks;
  final String? currentBlockAnalysis;
  final String? currentMemo;
  // 💡 인터랙티브 퀴즈용 상태 추가
  final List<dynamic>? quizData;
  final Map<int, int> quizAnswers; // 문제 인덱스 -> 사용자가 선택한 답 인덱스

  final String focusedText;
  final DateTime? lastSavedAt;

  FileEditorState({
    required this.blocks,
    this.isLoading = false,
    this.isAnalysisLoading = false,
    this.isSummaryLoading = false,
    this.isStudioLoading = false,
    this.icon,
    this.summaryBlocks = const [],
    this.currentBlockAnalysis,
    this.currentMemo,
    this.quizData,
    this.quizAnswers = const {},
    this.focusedText = "",
    this.lastSavedAt,
  });

  FileEditorState copyWith({
    List<Block>? blocks,
    bool? isLoading,
    bool? isAnalysisLoading,
    bool? isSummaryLoading,
    bool? isStudioLoading,
    String? icon,
    List<SummaryBlock>? summaryBlocks,
    String? currentBlockAnalysis,
    String? currentMemo,
    List<dynamic>? quizData,
    Map<int, int>? quizAnswers,
    String? focusedText,
    DateTime? lastSavedAt,
  }) {
    return FileEditorState(
      blocks: blocks ?? this.blocks,
      isLoading: isLoading ?? this.isLoading,
      isAnalysisLoading: isAnalysisLoading ?? this.isAnalysisLoading,
      isSummaryLoading: isSummaryLoading ?? this.isSummaryLoading,
      isStudioLoading: isStudioLoading ?? this.isStudioLoading,
      icon: icon ?? this.icon,
      summaryBlocks: summaryBlocks ?? this.summaryBlocks,
      currentBlockAnalysis: currentBlockAnalysis ?? this.currentBlockAnalysis,
      currentMemo: currentMemo ?? this.currentMemo,
      quizData: quizData ?? this.quizData,
      quizAnswers: quizAnswers ?? this.quizAnswers,
      focusedText: focusedText ?? this.focusedText,
      lastSavedAt: lastSavedAt ?? this.lastSavedAt,
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
    final List<Map<String, dynamic>> blocksDataToSave = state.blocks.map((b) {
      var json = b.toJson();
      json['content'] = b.controller.text;
      return json;
    }).toList();

    await FilesDBHelper.updateFile(
      fileId,
      updateAt: updateAt,
      title: title,
      tags: tags,
      icon: state.icon,
      prompt: prompt,
      content: jsonEncode(blocksDataToSave),
      summary: jsonEncode(state.summaryBlocks.map((b) => b.toJson()).toList()),
    );
    state = state.copyWith(lastSavedAt: DateTime.now());
  }

  // 💡 [전체 요약] 표(Table)와 리스트를 스마트하게 판단하여 작성하도록 프롬프트 고도화
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
      final customPrompt = """
사용자가 작성한 본문을 구조화된 최고 품질의 '요약 노트'로 재구성해 주세요.
지시사항:
1. 내용을 스스로 판단하여, 여러 개념을 '비교'하거나 '장단점/특징'을 나열해야 하는 경우 **반드시 마크다운 표(Table)를 생성**하여 한눈에 보기 좋게 정리하세요.
2. 표로 만들기 애매한 줄글은 글머리 기호(-, 1. 등)를 활용하여 구조화하세요.
3. 어떠한 이모티콘(Emoji)도 절대 사용하지 마세요.
4. 전문적이고 학술적인 톤을 유지하며, 중요한 개념은 **굵은 글씨**로 강조하세요.
""";

      final response = await http.post(
        Uri.parse('$baseUrl/api/files/summarize'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "content": fullContext,
          "tags": tags,
          "custom_prompt": customPrompt,
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
      final prompt =
          "전체 문맥([제목]: $documentContext)을 고려하여 선택된 문단의 핵심 의미를 1~3문장으로 아주 명확히 설명하세요. 필요하다면 간결한 표를 사용해도 좋습니다. 이모티콘은 쓰지 마세요.\n[선택된 문단]: $text";

      final response = await http.post(
        Uri.parse('$baseUrl/api/files/summarize'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "content": text,
          "tags": tags,
          "custom_prompt": prompt,
        }),
      );

      if (currentRequestId == _lastAnalysisRequestId &&
          response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        state = state.copyWith(
          currentBlockAnalysis: data['summary'],
          isAnalysisLoading: false,
        );
      } else if (currentRequestId == _lastAnalysisRequestId) {
        state = state.copyWith(isAnalysisLoading: false);
      }
    } catch (e) {
      if (currentRequestId == _lastAnalysisRequestId)
        state = state.copyWith(isAnalysisLoading: false);
    }
  }

  // 💡 [핵심 암기 및 퀴즈 생성] 퀴즈는 프론트가 그릴 수 있도록 JSON 배열을 요청합니다.
  Future<void> generateStudioContent(String type) async {
    String fullContext = state.blocks.map((b) => b.controller.text).join("\n");
    if (fullContext.trim().isEmpty) return;

    state = state.copyWith(isStudioLoading: true);
    try {
      final String baseUrl = Platform.isAndroid
          ? 'http://10.0.2.2:8000'
          : 'http://localhost:8000';

      String customPrompt = "";
      if (type == 'memo') {
        customPrompt =
            "본문 내용 중 시험에 무조건 나올 만한 '핵심 암기 사항' 5가지를 이모티콘 없이 명확한 리스트와 표를 활용하여 추출해 주세요.";
      } else {
        // 💡 퀴즈는 앱에서 버튼으로 렌더링하기 위해 엄격한 JSON 규칙을 부여
        customPrompt = """
본문 내용을 바탕으로 학습을 점검할 수 있는 객관식 퀴즈 3문제를 출제해 주세요.
반드시 아래의 순수 JSON 배열(Array) 형식으로만 응답해야 하며, 마크다운(```json)이나 다른 설명은 절대 넣지 마세요.
[
  {
    "question": "문제 내용",
    "options": ["보기1", "보기2", "보기3", "보기4"],
    "answer": 0, 
    "explanation": "정답인 이유 간략 설명"
  }
]
""";
      }

      final response = await http.post(
        Uri.parse('$baseUrl/api/files/summarize'),
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
          state = state.copyWith(
            currentMemo: data['summary'],
            isStudioLoading: false,
          );
        } else {
          // JSON 파싱 로직 (AI가 마크다운 코드블록을 붙였을 경우를 대비해 전처리)
          String resText = data['summary'].toString();
          resText = resText.replaceAll(RegExp(r'```json|```'), '').trim();

          int startIdx = resText.indexOf('[');
          int endIdx = resText.lastIndexOf(']');
          if (startIdx != -1 && endIdx != -1) {
            String jsonStr = resText.substring(startIdx, endIdx + 1);
            List<dynamic> parsedQuiz = jsonDecode(jsonStr);
            state = state.copyWith(
              quizData: parsedQuiz,
              quizAnswers: {},
              isStudioLoading: false,
            );
          } else {
            state = state.copyWith(isStudioLoading: false); // 파싱 실패 시
          }
        }
      } else {
        state = state.copyWith(isStudioLoading: false);
      }
    } catch (e) {
      state = state.copyWith(isStudioLoading: false);
    }
  }

  // 💡 사용자가 퀴즈 보기 버튼을 눌렀을 때 실행되는 함수
  void answerQuiz(int questionIndex, int selectedOptionIndex) {
    if (state.quizAnswers.containsKey(questionIndex)) return; // 이미 푼 문제는 무시
    final newAnswers = Map<int, int>.from(state.quizAnswers);
    newAnswers[questionIndex] = selectedOptionIndex;
    state = state.copyWith(quizAnswers: newAnswers);
  }

  // 블록 편집 기능들
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
