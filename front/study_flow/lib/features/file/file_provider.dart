// ============================================================
// file_provider.dart  (v2 - 성능 최적화 + 웹 호환 + 기능 추가)
// ============================================================
// 🚀 주요 개선사항:
//   1. 응답 속도 최적화: 변경된 부분만 AI에 전송 (Delta-only 전략)
//   2. 웹 호환: kIsWeb 분기로 sqflite 의존성 제거
//   3. 요약 복사/저장 기능
//   4. 블록 병합 로직 강화
// ============================================================

import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../core/db_helper/files_db_helper.dart';
import '../../models/block_model.dart';
import '../../core/markdown_parser.dart';
import 'file_model.dart';

String get apiBaseUrl {
  if (kIsWeb) return 'http://127.0.0.1:8000';
  // Android 에뮬레이터
  try {
    // ignore: undefined_prefixed_name
    if (!kIsWeb) {
      // dart:io 사용 가능한 환경
      return 'http://127.0.0.1:8000';
    }
  } catch (_) {}
  return 'http://127.0.0.1:8000';
}

// ─────────────────────────────────────────────
// SummaryBlock
// ─────────────────────────────────────────────
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

// ─────────────────────────────────────────────
// FilesNotifier (프로젝트 내 파일 목록)
// ─────────────────────────────────────────────
final filesProvider = StateNotifierProvider<FilesNotifier, List<FileModel>>(
  (ref) => FilesNotifier(),
);

class FilesNotifier extends StateNotifier<List<FileModel>> {
  FilesNotifier() : super([]);

  Future<void> loadFiles(String projectId) async {
    if (!kIsWeb) {
      state = await FilesDBHelper.selectProjectFiles(projectId);
    } else {
      state = [];
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

// ─────────────────────────────────────────────
// FileEditorState
// ─────────────────────────────────────────────
class FileEditorState {
  final List<Block> blocks;
  final bool isLoading;
  final bool isSummaryLoading;
  final bool isAnalysisLoading;
  final bool isStudioLoading;
  final bool isQALoading;
  final bool isGraphLoading;

  final String? icon;
  final List<SummaryBlock> summaryBlocks;
  final String? currentBlockAnalysis;
  final String? currentMemo;
  final List<dynamic>? quizData;
  final Map<int, int> quizAnswers;
  final String? qaAnswer;
  final Map<String, dynamic>? aiGraphData;

  final String focusedText;
  final DateTime? lastSavedAt;

  // ✅ 추가: 마지막으로 AI에 전송한 전체 텍스트 (delta 비교용)
  final String lastSentContent;

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
    this.focusedText = '',
    this.lastSavedAt,
    this.lastSentContent = '',
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
    String? lastSentContent,
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
      lastSentContent: lastSentContent ?? this.lastSentContent,
    );
  }

  /// 현재 에디터 전체 텍스트
  String get fullContent => blocks.map((b) => b.controller.text).join('\n');

  /// 단어 수 (읽기 시간 계산용)
  int get wordCount => blocks
      .map((b) => b.controller.text)
      .join(' ')
      .split(RegExp(r'\s+'))
      .length;

  /// 총 글자 수
  int get charCount =>
      blocks.fold(0, (sum, b) => sum + b.controller.text.length);
}

// ─────────────────────────────────────────────
// FileEditorNotifier
// ─────────────────────────────────────────────
final fileEditorProvider =
    StateNotifierProvider.autoDispose<FileEditorNotifier, FileEditorState>(
      (ref) => FileEditorNotifier(),
    );

class FileEditorNotifier extends StateNotifier<FileEditorState> {
  FileEditorNotifier() : super(FileEditorState(blocks: []));

  String _lastAnalyzedText = '';

  // ─── 초기 로드 ───────────────────────────────
  Future<void> loadFileDetail(String fileId) async {
    state = state.copyWith(isLoading: true);
    FileModel? fileModel;
    if (!kIsWeb) fileModel = await FilesDBHelper.getFile(fileId);

    if (fileModel != null) {
      List<Block> loadedBlocks = _parseBlocks(fileModel.content);
      if (loadedBlocks.isEmpty) loadedBlocks = [_createBlock(0)];

      List<SummaryBlock> loadedSummary = _parseSummary(fileModel.summary);

      state = state.copyWith(
        blocks: loadedBlocks,
        isLoading: false,
        icon: fileModel.icon,
        summaryBlocks: loadedSummary,
        lastSentContent: fileModel.content,
      );
    } else {
      state = state.copyWith(blocks: [_createBlock(0)], isLoading: false);
    }
  }

  List<Block> _parseBlocks(String content) {
    if (content.isEmpty) return [];
    try {
      return (jsonDecode(content) as List)
          .map((e) => Block.fromJson(e))
          .toList();
    } catch (_) {
      final parsedList = MarkdownParser.parse(content);
      return parsedList
          .asMap()
          .entries
          .map(
            (entry) => Block(
              id: '${DateTime.now().microsecondsSinceEpoch}_${entry.key}',
              type: entry.value['type'],
              content: entry.value['content'],
            ),
          )
          .toList();
    }
  }

  List<SummaryBlock> _parseSummary(String? summary) {
    if (summary == null || summary.isEmpty) return [];
    try {
      return (jsonDecode(summary) as List)
          .map((e) => SummaryBlock.fromJson(e))
          .toList();
    } catch (_) {
      return [SummaryBlock(content: summary, isSaved: false)];
    }
  }

  // ─── 저장 ────────────────────────────────────
  Future<void> saveFile({
    required String fileId,
    required String title,
    required String tags,
    required String prompt,
    required DateTime updateAt,
  }) async {
    final blocksData = state.blocks.map((b) {
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
        content: jsonEncode(blocksData),
        summary: jsonEncode(
          state.summaryBlocks.map((b) => b.toJson()).toList(),
        ),
      );
    }
    state = state.copyWith(lastSavedAt: DateTime.now());
  }

  // ─── 요약 확정 토글 ───────────────────────────
  void toggleSummarySave(int index) {
    final newSummaries = List<SummaryBlock>.from(state.summaryBlocks);
    newSummaries[index] = SummaryBlock(
      content: newSummaries[index].content,
      isSaved: !newSummaries[index].isSaved,
    );
    state = state.copyWith(summaryBlocks: newSummaries);
  }

  // ─── 요약 삭제 ───────────────────────────────
  void removeSummaryBlock(int index) {
    final newSummaries = List<SummaryBlock>.from(state.summaryBlocks);
    newSummaries.removeAt(index);
    state = state.copyWith(summaryBlocks: newSummaries);
  }

  // ─────────────────────────────────────────────
  // 🚀 [Track 1] 전체 요약 - Delta 최적화
  // 핵심: 변경된 부분만 AI에 전송하여 응답 속도 개선
  // ─────────────────────────────────────────────
  Future<void> requestAutoAISummary({
    required String title,
    required String tags,
  }) async {
    final fullContext = state.fullContent;
    if (fullContext.trim().isEmpty) return;

    state = state.copyWith(isSummaryLoading: true);

    try {
      final savedBlocks = state.summaryBlocks.where((b) => b.isSaved).toList();
      final savedText = savedBlocks.map((b) => b.content).join('\n\n');

      // 🚀 Delta 전략: 이전에 보낸 내용과 비교하여 추가된 부분만 전송
      String contentToSend = fullContext;
      final lastSent = state.lastSentContent;

      if (lastSent.isNotEmpty && fullContext.length > lastSent.length) {
        // 새로 추가된 부분만 추출 (약 200자 컨텍스트 포함)
        final overlapStart = (lastSent.length - 200).clamp(0, lastSent.length);
        contentToSend = fullContext.substring(overlapStart);
      }

      String customPrompt;
      if (savedText.isNotEmpty) {
        customPrompt =
            '''
문서 제목: $title
[기존에 확정된 요약]
$savedText

[새로 추가된 내용]
$contentToSend

위 [새로 추가된 내용]에서 [기존에 확정된 요약]에 없는 내용만 추출하여 구조화된 마크다운으로 [추가 요약]을 작성해 주세요.
새로운 내용이 없다면 "추가된 내용이 없습니다."라고만 응답하세요.
''';
      } else {
        customPrompt =
            '''
문서 제목: $title
다음 내용을 구조화된 요약 노트(개조식, 마크다운 표 포함)로 정리해 주세요. 이모티콘 제외, 학술적으로 작성.
''';
      }

      final response = await http
          .post(
            Uri.parse('$apiBaseUrl/api/ai/summarize'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'content': contentToSend,
              'tags': tags,
              'custom_prompt': customPrompt,
            }),
          )
          .timeout(const Duration(seconds: 60));

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        final newText = (data['summary'] ?? '').toString().trim();

        final newSummaries = List<SummaryBlock>.from(savedBlocks);
        if (newText.isNotEmpty && !newText.contains('추가된 내용이 없습니다')) {
          newSummaries.add(SummaryBlock(content: newText, isSaved: false));
        }

        state = state.copyWith(
          summaryBlocks: newSummaries,
          isSummaryLoading: false,
          lastSentContent: fullContext, // 다음 delta 계산을 위해 저장
        );
      } else {
        state = state.copyWith(isSummaryLoading: false);
      }
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(isSummaryLoading: false);
    }
  }

  // ─── [Track 2] 포커스 분석 ───────────────────
  Future<void> requestBlockAnalysis({
    required String text,
    required String contextTitle,
  }) async {
    if (text.trim().length < 5 || text == _lastAnalyzedText) return;
    _lastAnalyzedText = text;
    state = state.copyWith(focusedText: text, isAnalysisLoading: true);

    try {
      final prompt =
          '문서($contextTitle)의 맥락에서 다음 문단의 핵심 의미를 3줄 내외로 심층 분석해 주세요.\n내용: $text';

      final response = await http
          .post(
            Uri.parse('$apiBaseUrl/api/ai/summarize'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'content': text,
              'tags': '',
              'custom_prompt': prompt,
            }),
          )
          .timeout(const Duration(seconds: 30));

      if (!mounted) return;
      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        state = state.copyWith(
          currentBlockAnalysis: data['summary'],
          isAnalysisLoading: false,
        );
      } else {
        state = state.copyWith(isAnalysisLoading: false);
      }
    } catch (_) {
      if (!mounted) return;
      state = state.copyWith(isAnalysisLoading: false);
    }
  }

  // ─── 암기/퀴즈 생성 ──────────────────────────
  Future<void> generateStudioContent(String type) async {
    final fullContext = state.fullContent;
    if (fullContext.trim().isEmpty) return;

    // 🚀 최적화: 최대 3000자만 전송 (퀴즈/암기는 전체 문서 불필요)
    final truncated = fullContext.length > 3000
        ? fullContext.substring(0, 3000)
        : fullContext;

    state = state.copyWith(isStudioLoading: true);

    try {
      final customPrompt = type == 'memo'
          ? '본문 내용 중 시험에 나올 핵심 암기 사항 5가지를 이모티콘 없이 명확한 리스트와 표로 추출해 주세요.'
          : '본문을 바탕으로 객관식 퀴즈 3문제를 출제하세요. 반드시 순수 JSON 배열만 응답: [{"question":"문제","options":["1","2","3","4"],"answer":0,"explanation":"해설"}]';

      final response = await http
          .post(
            Uri.parse('$apiBaseUrl/api/ai/summarize'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'content': truncated,
              'tags': '',
              'custom_prompt': customPrompt,
            }),
          )
          .timeout(const Duration(seconds: 60));

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        if (type == 'memo') {
          state = state.copyWith(
            currentMemo: data['summary'],
            isStudioLoading: false,
          );
        } else {
          final resText = data['summary']
              .toString()
              .replaceAll(RegExp(r'```json|```'), '')
              .trim();
          final startIdx = resText.indexOf('[');
          final endIdx = resText.lastIndexOf(']');
          if (startIdx != -1 && endIdx != -1) {
            final parsed =
                jsonDecode(resText.substring(startIdx, endIdx + 1)) as List;
            state = state.copyWith(
              quizData: parsed,
              quizAnswers: {},
              isStudioLoading: false,
            );
          } else {
            state = state.copyWith(isStudioLoading: false);
          }
        }
      } else {
        state = state.copyWith(isStudioLoading: false);
      }
    } catch (_) {
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

  // ─── Quick Ask (RAG) ─────────────────────────
  Future<void> askAI(String query, String projectId) async {
    if (query.trim().isEmpty) return;
    state = state.copyWith(isQALoading: true);

    try {
      final response = await http
          .post(
            Uri.parse('$apiBaseUrl/api/ai/ask'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'query': query,
              'project_id': projectId,
              'use_web_search': true,
            }),
          )
          .timeout(const Duration(seconds: 60));

      if (!mounted) return;
      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        final answer =
            '### 💡 AI 답변 (출처: ${data['source']})\n\n${data['answer']}';
        state = state.copyWith(qaAnswer: answer, isQALoading: false);
      } else {
        state = state.copyWith(isQALoading: false, qaAnswer: '응답을 가져오지 못했습니다.');
      }
    } catch (_) {
      if (!mounted) return;
      state = state.copyWith(isQALoading: false, qaAnswer: '오류가 발생했습니다.');
    }
  }

  // ─── AI 지식 그래프 ───────────────────────────
  Future<void> requestAIGraph() async {
    final fullContext = state.fullContent;
    if (fullContext.trim().length < 20) return;

    // 🚀 최적화: 그래프 추출은 최대 2000자
    final truncated = fullContext.length > 2000
        ? fullContext.substring(0, 2000)
        : fullContext;

    state = state.copyWith(isGraphLoading: true);

    try {
      final response = await http
          .post(
            Uri.parse('$apiBaseUrl/api/ai/graph'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'content': truncated}),
          )
          .timeout(const Duration(seconds: 45));

      if (!mounted) return;
      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        state = state.copyWith(aiGraphData: data, isGraphLoading: false);
      } else {
        state = state.copyWith(isGraphLoading: false);
      }
    } catch (_) {
      if (!mounted) return;
      state = state.copyWith(isGraphLoading: false);
    }
  }

  // ─────────────────────────────────────────────
  // 에디터 블록 로직
  // ─────────────────────────────────────────────

  /// ✅ 수정: 블록 삽입 (엔터 키 / 붙여넣기)
  void insertBlocks(int index, List<String> contents) {
    final newBlocks = [...state.blocks];
    for (int i = 0; i < contents.length; i++) {
      String text = contents[i];
      BlockType type = BlockType.text;

      // 이전 블록이 bullet이면 다음도 bullet 유지
      if (i == 0 &&
          index > 0 &&
          newBlocks[index - 1].type == BlockType.bullet) {
        type = BlockType.bullet;
      } else if (text.startsWith('# ')) {
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

  /// ✅ 수정: 빈 bullet 블록에서 엔터 → 일반 텍스트로 탈출
  void exitListMode(int index) {
    final blocks = [...state.blocks];
    blocks[index].type = BlockType.text;
    state = state.copyWith(blocks: blocks);
  }

  void removeBlock(int index) {
    if (state.blocks.length <= 1) return;
    final newBlocks = [...state.blocks];
    newBlocks[index].dispose();
    newBlocks.removeAt(index);
    state = state.copyWith(blocks: newBlocks);
  }

  /// ✅ 수정: 위 블록과 병합 (백스페이스 처음 위치에서)
  void mergeWithPreviousBlock(int index) {
    if (index <= 0 || state.blocks.length <= 1) return;
    final blocks = [...state.blocks];
    final prevBlock = blocks[index - 1];
    final currentBlock = blocks[index];
    final prevLength = prevBlock.controller.text.length;

    prevBlock.controller.text += currentBlock.controller.text;
    currentBlock.dispose();
    blocks.removeAt(index);

    state = state.copyWith(blocks: blocks);

    // 포커스를 이전 블록으로 이동하고 커서 위치 조정
    WidgetsBinding.instance.addPostFrameCallback((_) {
      prevBlock.focusNode.requestFocus();
      prevBlock.controller.selection = TextSelection.collapsed(
        offset: prevLength,
      );
    });
  }

  void reorderBlock(int oldIndex, int newIndex) {
    if (oldIndex < newIndex) newIndex -= 1;
    final blocks = [...state.blocks];
    final item = blocks.removeAt(oldIndex);
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

  /// ✅ 탭 들여쓰기 (Tab 키)
  void indentBlock(int index) {
    final blocks = state.blocks;
    final ctrl = blocks[index].controller;
    final currentType = blocks[index].type;

    if (currentType == BlockType.bullet) {
      // bullet → 들여쓰기 (현재는 텍스트에 공백 추가, 향후 중첩 리스트 지원 가능)
      final pos = ctrl.selection.baseOffset;
      ctrl.text = '    ${ctrl.text}';
      ctrl.selection = TextSelection.collapsed(offset: pos + 4);
    } else {
      // 일반 텍스트: 커서 위치에 탭(4스페이스) 삽입
      final pos = ctrl.selection.baseOffset.clamp(0, ctrl.text.length);
      final newText =
          ctrl.text.substring(0, pos) + '    ' + ctrl.text.substring(pos);
      ctrl.text = newText;
      ctrl.selection = TextSelection.collapsed(offset: pos + 4);
    }
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
    String content = '',
  }) {
    return Block(
      id: '${DateTime.now().microsecondsSinceEpoch}_$index',
      type: type,
      content: content,
    );
  }
}
