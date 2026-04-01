// ============================================================
// file_provider.dart v3
// - 웹 파일 동기화 (API 연동)
// - 글 교정 기능
// - 요약 Export (Markdown/텍스트)
// - 프롬프트 서버 단 처리
// - RAG 실시간 인덱싱
// ============================================================

import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../core/db_helper/files_db_helper.dart';
import '../../models/block_model.dart';
import '../../core/markdown_parser.dart';
import '../../core/provider_config.dart';
import 'file_model.dart';

String get apiBaseUrl {
  if (kIsWeb) return 'http://127.0.0.1:8000';
  return 'http://127.0.0.1:8000';
}

// ─────────────────────────────────────────────────────────
// SummaryBlock
// ─────────────────────────────────────────────────────────
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

// ─────────────────────────────────────────────────────────
// FilesNotifier
// ─────────────────────────────────────────────────────────
final filesProvider = StateNotifierProvider<FilesNotifier, List<FileModel>>(
  (ref) => FilesNotifier(),
);

class FilesNotifier extends StateNotifier<List<FileModel>> {
  FilesNotifier() : super([]);

  Future<void> loadFiles(String projectId) async {
    if (!kIsWeb) {
      state = await FilesDBHelper.selectProjectFiles(projectId);
      return;
    }
    // 웹: 서버에서 로드
    try {
      final res = await http.get(
        Uri.parse('$apiBaseUrl/api/files/project/$projectId'),
      );
      if (res.statusCode == 200) {
        final List data = json.decode(res.body);
        state = data.map((j) => FileModel.fromJson(j)).toList();
      }
    } catch (e) {
      print('loadFiles error: $e');
    }
  }

  Future<void> addFile(FileModel file) async {
    if (!kIsWeb) {
      await FilesDBHelper.insertFile(file);
    } else {
      // 웹: 서버에 저장
      try {
        await http.post(
          Uri.parse('$apiBaseUrl/api/files/'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode(file.toMap()),
        );
      } catch (e) {
        print('addFile error: $e');
      }
    }
    state = [file, ...state];
  }

  Future<void> deleteFile(String fileId) async {
    if (!kIsWeb) {
      await FilesDBHelper.deleteFile(fileId);
    } else {
      try {
        await http.delete(Uri.parse('$apiBaseUrl/api/files/$fileId'));
      } catch (e) {
        print('deleteFile error: $e');
      }
    }
    state = state.where((f) => f.id != fileId).toList();
  }

  Future<void> updateFileTitle(String fileId, String newTitle) async {
    if (!kIsWeb) {
      await FilesDBHelper.updateFile(fileId, title: newTitle);
    } else {
      try {
        await http.put(
          Uri.parse('$apiBaseUrl/api/files/$fileId'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({'title': newTitle}),
        );
      } catch (e) {
        print('updateFileTitle error: $e');
      }
    }
    state = [
      for (final f in state)
        if (f.id == fileId) f.updateWith(title: newTitle) else f,
    ];
  }
}

// ─────────────────────────────────────────────────────────
// FileEditorState
// ─────────────────────────────────────────────────────────
class FileEditorState {
  final List<Block> blocks;
  final bool isLoading;
  final bool isSummaryLoading;
  final bool isAnalysisLoading;
  final bool isStudioLoading;
  final bool isQALoading;
  final bool isGraphLoading;
  final bool isProofreadLoading; // 글 교정

  final String? icon;
  final String? filePrompt; // 서버 단 프롬프트
  final List<SummaryBlock> summaryBlocks;
  final String? currentBlockAnalysis;
  final String? currentMemo;
  final List<dynamic>? quizData;
  final Map<int, int> quizAnswers;
  final String? qaAnswer;
  final Map<String, dynamic>? aiGraphData;
  final String? proofreadResult; // 교정 결과

  final String focusedText;
  final DateTime? lastSavedAt;
  final String lastSentContent;

  // 선택된 블록 인덱스들 (멀티 선택)
  final Set<int> selectedBlockIndices;

  FileEditorState({
    required this.blocks,
    this.isLoading = false,
    this.isSummaryLoading = false,
    this.isAnalysisLoading = false,
    this.isStudioLoading = false,
    this.isQALoading = false,
    this.isGraphLoading = false,
    this.isProofreadLoading = false,
    this.icon,
    this.filePrompt,
    this.summaryBlocks = const [],
    this.currentBlockAnalysis,
    this.currentMemo,
    this.quizData,
    this.quizAnswers = const {},
    this.qaAnswer,
    this.aiGraphData,
    this.proofreadResult,
    this.focusedText = '',
    this.lastSavedAt,
    this.lastSentContent = '',
    this.selectedBlockIndices = const {},
  });

  FileEditorState copyWith({
    List<Block>? blocks,
    bool? isLoading,
    bool? isSummaryLoading,
    bool? isAnalysisLoading,
    bool? isStudioLoading,
    bool? isQALoading,
    bool? isGraphLoading,
    bool? isProofreadLoading,
    String? icon,
    String? filePrompt,
    List<SummaryBlock>? summaryBlocks,
    String? currentBlockAnalysis,
    String? currentMemo,
    List<dynamic>? quizData,
    Map<int, int>? quizAnswers,
    String? qaAnswer,
    Map<String, dynamic>? aiGraphData,
    String? proofreadResult,
    String? focusedText,
    DateTime? lastSavedAt,
    String? lastSentContent,
    Set<int>? selectedBlockIndices,
  }) {
    return FileEditorState(
      blocks: blocks ?? this.blocks,
      isLoading: isLoading ?? this.isLoading,
      isSummaryLoading: isSummaryLoading ?? this.isSummaryLoading,
      isAnalysisLoading: isAnalysisLoading ?? this.isAnalysisLoading,
      isStudioLoading: isStudioLoading ?? this.isStudioLoading,
      isQALoading: isQALoading ?? this.isQALoading,
      isGraphLoading: isGraphLoading ?? this.isGraphLoading,
      isProofreadLoading: isProofreadLoading ?? this.isProofreadLoading,
      icon: icon ?? this.icon,
      filePrompt: filePrompt ?? this.filePrompt,
      summaryBlocks: summaryBlocks ?? this.summaryBlocks,
      currentBlockAnalysis: currentBlockAnalysis ?? this.currentBlockAnalysis,
      currentMemo: currentMemo ?? this.currentMemo,
      quizData: quizData ?? this.quizData,
      quizAnswers: quizAnswers ?? this.quizAnswers,
      qaAnswer: qaAnswer ?? this.qaAnswer,
      aiGraphData: aiGraphData ?? this.aiGraphData,
      proofreadResult: proofreadResult ?? this.proofreadResult,
      focusedText: focusedText ?? this.focusedText,
      lastSavedAt: lastSavedAt ?? this.lastSavedAt,
      lastSentContent: lastSentContent ?? this.lastSentContent,
      selectedBlockIndices: selectedBlockIndices ?? this.selectedBlockIndices,
    );
  }

  String get fullContent => blocks.map((b) => b.controller.text).join('\n');
  int get wordCount => fullContent.split(RegExp(r'\s+')).length;
  int get charCount =>
      blocks.fold(0, (sum, b) => sum + b.controller.text.length);
}

// ─────────────────────────────────────────────────────────
// FileEditorNotifier
// ─────────────────────────────────────────────────────────
final fileEditorProvider =
    StateNotifierProvider.autoDispose<FileEditorNotifier, FileEditorState>(
      (ref) => FileEditorNotifier(),
    );

class FileEditorNotifier extends StateNotifier<FileEditorState> {
  FileEditorNotifier() : super(FileEditorState(blocks: []));

  String _lastAnalyzedText = '';
  String _currentFileId = '';

  // ─── 로드 ────────────────────────────────────────────
  Future<void> loadFileDetail(String fileId) async {
    _currentFileId = fileId;
    state = state.copyWith(isLoading: true);

    FileModel? fileModel;

    if (!kIsWeb) {
      fileModel = await FilesDBHelper.getFile(fileId);
    } else {
      // 웹: 서버에서 로드
      try {
        final res = await http.get(Uri.parse('$apiBaseUrl/api/files/$fileId'));
        if (res.statusCode == 200) {
          fileModel = FileModel.fromJson(json.decode(res.body));
        }
      } catch (e) {
        print('loadFileDetail error: $e');
      }
    }

    if (fileModel != null) {
      final loadedBlocks = _parseBlocks(fileModel.content);
      final loadedSummary = _parseSummary(fileModel.summary);

      state = state.copyWith(
        blocks: loadedBlocks.isEmpty ? [_createBlock(0)] : loadedBlocks,
        isLoading: false,
        icon: fileModel.icon,
        filePrompt: fileModel.prompt,
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
      final parsed = MarkdownParser.parse(content);
      return parsed
          .asMap()
          .entries
          .map(
            (e) => Block(
              id: '${DateTime.now().microsecondsSinceEpoch}_${e.key}',
              type: e.value['type'],
              content: e.value['content'],
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

  // ─── 저장 ────────────────────────────────────────────
  Future<void> saveFile({
    required String fileId,
    required String title,
    required String tags,
    required String prompt,
    required DateTime updateAt,
  }) async {
    final blocksData = state.blocks.map((b) {
      final j = b.toJson();
      j['content'] = b.controller.text;
      return j;
    }).toList();

    final contentJson = jsonEncode(blocksData);
    final summaryJson = jsonEncode(
      state.summaryBlocks.map((b) => b.toJson()).toList(),
    );

    if (!kIsWeb) {
      await FilesDBHelper.updateFile(
        fileId,
        updateAt: updateAt,
        title: title,
        tags: tags,
        icon: state.icon,
        prompt: prompt,
        content: contentJson,
        summary: summaryJson,
      );
    } else {
      // 웹: 서버에 저장 + RAG 업데이트
      try {
        await http.put(
          Uri.parse('$apiBaseUrl/api/files/$fileId'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({
            'title': title,
            'tags': tags,
            'prompt': prompt,
            'content': contentJson,
            'summary': summaryJson,
            'icon': state.icon,
          }),
        );
      } catch (e) {
        print('saveFile web error: $e');
      }
    }

    state = state.copyWith(lastSavedAt: DateTime.now());
  }

  // ─── 요약 관련 ──────────────────────────────────────
  void toggleSummarySave(int index) {
    final list = List<SummaryBlock>.from(state.summaryBlocks);
    list[index] = SummaryBlock(
      content: list[index].content,
      isSaved: !list[index].isSaved,
    );
    state = state.copyWith(summaryBlocks: list);
  }

  void removeSummaryBlock(int index) {
    final list = List<SummaryBlock>.from(state.summaryBlocks);
    list.removeAt(index);
    state = state.copyWith(summaryBlocks: list);
  }

  // ─── [Track 1] 전체 요약 (서버 단 프롬프트 적용) ──────
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

      // Delta 전략
      final lastSent = state.lastSentContent;
      String contentToSend = fullContext;
      if (lastSent.isNotEmpty && fullContext.length > lastSent.length) {
        final overlapStart = (lastSent.length - 200).clamp(0, lastSent.length);
        contentToSend = fullContext.substring(overlapStart);
      }

      // 서버 단 커스텀 프롬프트 적용
      String customPrompt;
      final serverPrompt = state.filePrompt ?? '';

      if (savedText.isNotEmpty) {
        customPrompt =
            '''
${serverPrompt.isNotEmpty ? '사용자 지시사항: $serverPrompt\n' : ''}
문서 제목: $title
[기존 확정 요약]
$savedText

[새로 추가된 내용]
$contentToSend

기존 요약에 없는 내용만 마크다운으로 추가 요약하세요. 새 내용이 없으면 "추가된 내용이 없습니다."만 응답.
''';
      } else {
        customPrompt =
            '''
${serverPrompt.isNotEmpty ? '사용자 지시사항: $serverPrompt\n' : ''}
문서 제목: $title
위 내용을 구조화된 요약 노트(개조식, 마크다운 표 포함)로 정리해 주세요. 이모티콘 제외, 학술적으로.
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
          .timeout(const Duration(seconds: 90));

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
          lastSentContent: fullContext,
        );
      } else {
        state = state.copyWith(isSummaryLoading: false);
      }
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(isSummaryLoading: false);
    }
  }

  // ─── [Track 2] 포커스 분석 ────────────────────────────
  Future<void> requestBlockAnalysis({
    required String text,
    required String contextTitle,
  }) async {
    if (text.trim().length < 5 || text == _lastAnalyzedText) return;
    _lastAnalyzedText = text;
    state = state.copyWith(focusedText: text, isAnalysisLoading: true);

    try {
      final prompt =
          '문서($contextTitle)의 맥락에서 다음 문단의 핵심 의미를 3줄 내외로 분석해 주세요.\n내용: $text';
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

  // ─── 암기/퀴즈 ────────────────────────────────────────
  Future<void> generateStudioContent(String type) async {
    final truncated = state.fullContent.length > 3000
        ? state.fullContent.substring(0, 3000)
        : state.fullContent;
    if (truncated.trim().isEmpty) return;

    state = state.copyWith(isStudioLoading: true);

    final customPrompt = type == 'memo'
        ? '본문 내용 중 시험에 나올 핵심 암기 사항 5가지를 이모티콘 없이 명확한 리스트와 표로 추출해 주세요.'
        : '본문을 바탕으로 객관식 퀴즈 3문제를 출제하세요. 반드시 순수 JSON 배열만 응답: [{"question":"문제","options":["1","2","3","4"],"answer":0,"explanation":"해설"}]';

    try {
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
          .timeout(const Duration(seconds: 90));

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

  void answerQuiz(int questionIndex, int optionIndex) {
    if (state.quizAnswers.containsKey(questionIndex)) return;
    final answers = Map<int, int>.from(state.quizAnswers);
    answers[questionIndex] = optionIndex;
    state = state.copyWith(quizAnswers: answers);
  }

  // ─── Quick Ask ────────────────────────────────────────
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
        state = state.copyWith(
          qaAnswer: '### 💡 AI 답변 (출처: ${data['source']})\n\n${data['answer']}',
          isQALoading: false,
        );
      } else {
        state = state.copyWith(isQALoading: false, qaAnswer: '응답을 가져오지 못했습니다.');
      }
    } catch (_) {
      if (!mounted) return;
      state = state.copyWith(isQALoading: false, qaAnswer: '오류가 발생했습니다.');
    }
  }

  // ─── AI 지식 그래프 ───────────────────────────────────
  Future<void> requestAIGraph() async {
    final truncated = state.fullContent.length > 2000
        ? state.fullContent.substring(0, 2000)
        : state.fullContent;
    if (truncated.trim().length < 20) return;

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
        state = state.copyWith(
          aiGraphData: jsonDecode(utf8.decode(response.bodyBytes)),
          isGraphLoading: false,
        );
      } else {
        state = state.copyWith(isGraphLoading: false);
      }
    } catch (_) {
      if (!mounted) return;
      state = state.copyWith(isGraphLoading: false);
    }
  }

  // ─── 글 교정 기능 ─────────────────────────────────────
  Future<void> proofreadContent({String style = 'academic'}) async {
    final content = state.fullContent;
    if (content.trim().isEmpty) return;

    state = state.copyWith(isProofreadLoading: true, proofreadResult: null);
    try {
      final response = await http
          .post(
            Uri.parse('$apiBaseUrl/api/files/proofread'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'content': content, 'style': style}),
          )
          .timeout(const Duration(seconds: 60));

      if (!mounted) return;
      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        state = state.copyWith(
          proofreadResult: data['corrected'],
          isProofreadLoading: false,
        );
      } else {
        state = state.copyWith(isProofreadLoading: false);
      }
    } catch (_) {
      if (!mounted) return;
      state = state.copyWith(isProofreadLoading: false);
    }
  }

  // 교정 결과 에디터에 적용
  void applyProofread() {
    if (state.proofreadResult == null) return;
    final parsed = _parseBlocks(state.proofreadResult!);
    if (parsed.isEmpty) return;
    for (var b in state.blocks) b.dispose();
    state = state.copyWith(
      blocks: parsed.isEmpty ? [_createBlock(0)] : parsed,
      proofreadResult: null,
    );
  }

  // ─── Export ───────────────────────────────────────────

  /// Markdown 형식으로 Export (클립보드)
  Future<String> exportAsMarkdown(String title, String tags) async {
    final sb = StringBuffer();
    sb.writeln('# $title');
    if (tags.isNotEmpty) sb.writeln('> Tags: $tags\n');
    sb.writeln();

    for (final block in state.blocks) {
      final text = block.controller.text;
      switch (block.type) {
        case BlockType.h1:
          sb.writeln('# $text');
          break;
        case BlockType.h2:
          sb.writeln('## $text');
          break;
        case BlockType.h3:
          sb.writeln('### $text');
          break;
        case BlockType.bullet:
          sb.writeln('- $text');
          break;
        case BlockType.checkbox:
          sb.writeln('- [${block.isChecked ? 'x' : ' '}] $text');
          break;
        case BlockType.code:
          sb.writeln('```\n$text\n```');
          break;
        default:
          sb.writeln(text);
      }
      sb.writeln();
    }

    // 저장된 요약 추가
    final savedSummaries = state.summaryBlocks.where((b) => b.isSaved).toList();
    if (savedSummaries.isNotEmpty) {
      sb.writeln('\n---\n## 📝 AI 요약\n');
      for (final s in savedSummaries) {
        sb.writeln(s.content);
        sb.writeln();
      }
    }

    return sb.toString();
  }

  /// 클립보드에 Markdown 복사
  Future<void> copyMarkdownToClipboard(String title, String tags) async {
    final md = await exportAsMarkdown(title, tags);
    await Clipboard.setData(ClipboardData(text: md));
  }

  // ─── 블록 편집 로직 ──────────────────────────────────

  void mergeWithPreviousBlock(int index) {
    if (index <= 0 || state.blocks.length <= 1) return;
    final blocks = [...state.blocks];
    final prev = blocks[index - 1];
    final curr = blocks[index];
    final prevLen = prev.controller.text.length;
    prev.controller.text += curr.controller.text;
    curr.dispose();
    blocks.removeAt(index);
    state = state.copyWith(blocks: blocks);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      prev.focusNode.requestFocus();
      prev.controller.selection = TextSelection.collapsed(offset: prevLen);
    });
  }

  void insertBlocks(int index, List<String> contents) {
    final blocks = [...state.blocks];
    for (int i = 0; i < contents.length; i++) {
      String text = contents[i];
      BlockType type = BlockType.text;
      if (i == 0 && index > 0 && blocks[index - 1].type == BlockType.bullet) {
        type = BlockType.bullet;
      } else if (i == 0 &&
          index > 0 &&
          blocks[index - 1].type == BlockType.checkbox) {
        type = BlockType.checkbox;
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
      blocks.insert(
        index + i,
        _createBlock(index + i, type: type, content: text),
      );
    }
    state = state.copyWith(blocks: blocks);
  }

  void exitListMode(int index) {
    final blocks = [...state.blocks];
    blocks[index].type = BlockType.text;
    state = state.copyWith(blocks: blocks);
  }

  void removeBlock(int index) {
    if (state.blocks.length <= 1) return;
    final blocks = [...state.blocks];
    blocks[index].dispose();
    blocks.removeAt(index);
    state = state.copyWith(blocks: blocks);
  }

  void reorderBlock(int oldIndex, int newIndex) {
    if (oldIndex < newIndex) newIndex -= 1;
    final blocks = [...state.blocks];
    final item = blocks.removeAt(oldIndex);
    blocks.insert(newIndex, item);
    state = state.copyWith(blocks: blocks);
  }

  void duplicateBlock(int index) {
    final orig = state.blocks[index];
    final newBlock = _createBlock(
      index + 1,
      type: orig.type,
      content: orig.controller.text,
    )..isChecked = orig.isChecked;
    final blocks = [...state.blocks];
    blocks.insert(index + 1, newBlock);
    state = state.copyWith(blocks: blocks);
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

  void indentBlock(int index) {
    final ctrl = state.blocks[index].controller;
    final pos = ctrl.selection.baseOffset.clamp(0, ctrl.text.length);
    final newText =
        ctrl.text.substring(0, pos) + '    ' + ctrl.text.substring(pos);
    ctrl.text = newText;
    ctrl.selection = TextSelection.collapsed(offset: pos + 4);
  }

  void updateIcon(String? newIcon) => state = state.copyWith(icon: newIcon);

  void updateFilePrompt(String prompt) =>
      state = state.copyWith(filePrompt: prompt);

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
