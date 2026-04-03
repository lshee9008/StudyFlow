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
import 'file_model.dart';

const String _api = 'http://127.0.0.1:8000';

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
// State
// ─────────────────────────────────────────────────────────
class FileEditorState {
  final List<Block> blocks;
  final bool isLoading;
  final bool isSummaryLoading;
  final bool isAnalysisLoading;
  final bool isMemoLoading;
  final bool isQuizLoading;
  final bool isQALoading;
  final bool isGraphLoading;

  final String? icon;
  final String? filePrompt;
  final List<SummaryBlock> summaryBlocks;
  final String? currentAnalysis;
  final String? currentMemo;
  final List<dynamic>? quizData;
  final Map<int, int> quizAnswers;
  final String? qaAnswer;
  final Map<String, dynamic>? graphData;

  final String focusedText;
  final DateTime? lastSavedAt;
  final String lastSentContent;
  final String? proofreadResult;
  final bool isProofreadLoading;

  // ✅ title/tags도 state에 보관 (웹 호환)
  final String fileTitle;
  final String fileTags;

  FileEditorState({
    required this.blocks,
    this.isLoading = false,
    this.isSummaryLoading = false,
    this.isAnalysisLoading = false,
    this.isMemoLoading = false,
    this.isQuizLoading = false,
    this.isQALoading = false,
    this.isGraphLoading = false,
    this.icon,
    this.filePrompt,
    this.summaryBlocks = const [],
    this.currentAnalysis,
    this.currentMemo,
    this.quizData,
    this.quizAnswers = const {},
    this.qaAnswer,
    this.graphData,
    this.focusedText = '',
    this.lastSavedAt,
    this.lastSentContent = '',
    this.fileTitle = '',
    this.fileTags = '',
    this.proofreadResult,
    this.isProofreadLoading = false,
  });

  FileEditorState copyWith({
    List<Block>? blocks,
    bool? isLoading,
    bool? isSummaryLoading,
    bool? isAnalysisLoading,
    bool? isMemoLoading,
    bool? isQuizLoading,
    bool? isQALoading,
    bool? isGraphLoading,
    String? icon,
    String? filePrompt,
    List<SummaryBlock>? summaryBlocks,
    String? currentAnalysis,
    String? currentMemo,
    List<dynamic>? quizData,
    Map<int, int>? quizAnswers,
    String? qaAnswer,
    Map<String, dynamic>? graphData,
    String? focusedText,
    DateTime? lastSavedAt,
    String? lastSentContent,
    String? fileTitle,
    String? fileTags,
    String? proofreadResult,
    bool? isProofreadLoading,
  }) => FileEditorState(
    blocks: blocks ?? this.blocks,
    isLoading: isLoading ?? this.isLoading,
    isSummaryLoading: isSummaryLoading ?? this.isSummaryLoading,
    isAnalysisLoading: isAnalysisLoading ?? this.isAnalysisLoading,
    isMemoLoading: isMemoLoading ?? this.isMemoLoading,
    isQuizLoading: isQuizLoading ?? this.isQuizLoading,
    isQALoading: isQALoading ?? this.isQALoading,
    isGraphLoading: isGraphLoading ?? this.isGraphLoading,
    icon: icon ?? this.icon,
    filePrompt: filePrompt ?? this.filePrompt,
    summaryBlocks: summaryBlocks ?? this.summaryBlocks,
    currentAnalysis: currentAnalysis ?? this.currentAnalysis,
    currentMemo: currentMemo ?? this.currentMemo,
    quizData: quizData ?? this.quizData,
    quizAnswers: quizAnswers ?? this.quizAnswers,
    qaAnswer: qaAnswer ?? this.qaAnswer,
    graphData: graphData ?? this.graphData,
    focusedText: focusedText ?? this.focusedText,
    lastSavedAt: lastSavedAt ?? this.lastSavedAt,
    lastSentContent: lastSentContent ?? this.lastSentContent,
    fileTitle: fileTitle ?? this.fileTitle,
    fileTags: fileTags ?? this.fileTags,
    proofreadResult: proofreadResult ?? this.proofreadResult,
    isProofreadLoading: isProofreadLoading ?? this.isProofreadLoading,
  );

  String get fullContent => blocks.map((b) => b.controller.text).join('\n');
  int get charCount => blocks.fold(0, (s, b) => s + b.controller.text.length);
  int get wordCount =>
      fullContent.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
  String get fullContentForAI {
    // JSON 블록 배열 그대로 보내서 백엔드에서 파싱
    return jsonEncode(
      blocks.map((b) {
        final j = b.toJson();
        j['content'] = b.controller.text;
        return j;
      }).toList(),
    );
  }

  int get meaningfulCharCount =>
      blocks.fold(0, (sum, b) => sum + b.controller.text.trim().length);
}

// ─────────────────────────────────────────────────────────
// Provider
// ─────────────────────────────────────────────────────────
final fileEditorProvider =
    StateNotifierProvider.autoDispose<FileEditorNotifier, FileEditorState>(
      (ref) => FileEditorNotifier(),
    );

class FileEditorNotifier extends StateNotifier<FileEditorState> {
  FileEditorNotifier() : super(FileEditorState(blocks: []));

  String _lastAnalyzedText = '';

  // ─── 로드 ────────────────────────────────────────────
  Future<void> loadFileDetail(String fileId) async {
    state = state.copyWith(isLoading: true);
    FileModel? file;

    if (!kIsWeb) {
      file = await FilesDBHelper.getFile(fileId);
    } else {
      try {
        final res = await http
            .get(Uri.parse('$_api/api/files/$fileId'))
            .timeout(const Duration(seconds: 10));
        if (res.statusCode == 200)
          file = FileModel.fromJson(jsonDecode(res.body));
      } catch (e) {
        print('loadFile error: $e');
      }
    }

    if (file != null) {
      final blocks = _parseBlocks(file.content);
      final summary = _parseSummary(file.summary);
      state = state.copyWith(
        blocks: blocks.isEmpty ? [_newBlock(0)] : blocks,
        isLoading: false,
        icon: file.icon,
        filePrompt: file.prompt,
        summaryBlocks: summary,
        lastSentContent: file.content,
        // ✅ title/tags 저장 (웹에서 DB 접근 불가 시 여기서 읽음)
        fileTitle: file.title == '제목 없음' ? '' : file.title,
        fileTags: file.tags,
      );
    } else {
      state = state.copyWith(blocks: [_newBlock(0)], isLoading: false);
    }
  }

  List<Block> _parseBlocks(String content) {
    if (content.isEmpty) return [];
    try {
      final blocks = (jsonDecode(content) as List)
          .map((e) => Block.fromJson(e))
          .toList();
      // ✅ text 블록에 마크다운 헤딩/불릿 있으면 타입 변환
      return blocks.map((b) => _convertMarkdownBlock(b)).toList();
    } catch (_) {
      return MarkdownParser.parse(content)
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

  Block _convertMarkdownBlock(Block b) {
    if (b.type != BlockType.text) return b;
    final t = b.controller.text;
    if (t.startsWith('# ')) {
      b.type = BlockType.h1;
      b.controller.text = t.substring(2);
    } else if (t.startsWith('## ')) {
      b.type = BlockType.h2;
      b.controller.text = t.substring(3);
    } else if (t.startsWith('### ')) {
      b.type = BlockType.h3;
      b.controller.text = t.substring(4);
    } else if (t.startsWith('- ') || t.startsWith('* ')) {
      b.type = BlockType.bullet;
      b.controller.text = t.substring(2);
    } else if (t.startsWith('[] ') || t.startsWith('- [ ] ')) {
      b.type = BlockType.checkbox;
      b.controller.text = t.replaceFirst(RegExp(r'^(\[\] |- \[ \] )'), '');
    }
    return b;
  }

  List<SummaryBlock> _parseSummary(String? s) {
    if (s == null || s.isEmpty) return [];
    try {
      return (jsonDecode(s) as List)
          .map((e) => SummaryBlock.fromJson(e))
          .toList();
    } catch (_) {
      return [SummaryBlock(content: s, isSaved: false)];
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
    final blocksJson = jsonEncode(
      state.blocks.map((b) {
        final j = b.toJson();
        j['content'] = b.controller.text;
        return j;
      }).toList(),
    );
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
        content: blocksJson,
        summary: summaryJson,
      );
    } else {
      try {
        await http
            .put(
              Uri.parse('$_api/api/files/$fileId'),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({
                'title': title,
                'tags': tags,
                'prompt': prompt,
                'content': blocksJson,
                'summary': summaryJson,
                'icon': state.icon,
              }),
            )
            .timeout(const Duration(seconds: 10));
      } catch (e) {
        print('saveFile error: $e');
      }
    }
    state = state.copyWith(lastSavedAt: DateTime.now());
  }

  // ─── 요약 (스마트 — 내용 없으면 건너뜀) ─────────────
  Future<void> requestSummary({
    required String title,
    required String tags,
  }) async {
    // 의미있는 내용이 50자 미만이면 무시
    if (state.meaningfulCharCount < 15) return;

    state = state.copyWith(isSummaryLoading: true);
    try {
      final saved = state.summaryBlocks.where((b) => b.isSaved).toList();
      final savedText = saved.map((b) => b.content).join('\n\n');

      // Delta: 변경된 부분만 전송
      final full = state.fullContentForAI;
      final last = state.lastSentContent;
      String toSend = full;
      if (last.isNotEmpty && full.length > last.length + 100) {
        toSend = full.substring((last.length - 300).clamp(0, last.length));
      }

      // 서버 단 프롬프트 우선 적용
      String? customPrompt;
      final fp = state.filePrompt ?? '';
      if (savedText.isNotEmpty) {
        customPrompt =
            '${fp.isNotEmpty ? "사용자 지시: $fp\n\n" : ""}'
            '기존 요약:\n$savedText\n\n'
            '위에 없는 새 내용만 추가로 요약하세요. 새 내용 없으면 빈 응답.';
      } else if (fp.isNotEmpty) {
        customPrompt = fp;
      }

      final res = await http
          .post(
            Uri.parse('$_api/api/ai/summarize'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'content': toSend,
              'tags': tags,
              'title': title,
              'custom_prompt': customPrompt,
            }),
          )
          .timeout(const Duration(seconds: 90));

      if (!mounted) return;
      if (res.statusCode == 200) {
        final newText =
            (jsonDecode(utf8.decode(res.bodyBytes))['summary'] ?? '')
                .toString()
                .trim();
        final list = List<SummaryBlock>.from(saved);
        if (newText.isNotEmpty)
          list.add(SummaryBlock(content: newText, isSaved: false));
        state = state.copyWith(
          summaryBlocks: list,
          isSummaryLoading: false,
          lastSentContent: full,
        );
      } else {
        state = state.copyWith(isSummaryLoading: false);
      }
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(isSummaryLoading: false);
    }
  }

  void toggleSummarySave(int i) {
    final list = List<SummaryBlock>.from(state.summaryBlocks);
    list[i] = SummaryBlock(content: list[i].content, isSaved: !list[i].isSaved);
    state = state.copyWith(summaryBlocks: list);
  }

  void removeSummaryBlock(int i) {
    final list = List<SummaryBlock>.from(state.summaryBlocks)..removeAt(i);
    state = state.copyWith(summaryBlocks: list);
  }

  // ─── 블록 분석 ──────────────────────────────────────
  Future<void> analyzeBlock({
    required String text,
    required String title,
  }) async {
    if (text.trim().length < 10 || text == _lastAnalyzedText) return;
    _lastAnalyzedText = text;
    state = state.copyWith(focusedText: text, isAnalysisLoading: true);
    try {
      final res = await http
          .post(
            Uri.parse('$_api/api/ai/analyze-block'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'text': text, 'context_title': title}),
          )
          .timeout(const Duration(seconds: 30));
      if (!mounted) return;
      if (res.statusCode == 200) {
        final analysis =
            jsonDecode(utf8.decode(res.bodyBytes))['analysis'] ?? '';
        state = state.copyWith(
          currentAnalysis: analysis.toString().trim(),
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

  // ─── 암기 노트 ──────────────────────────────────────
  Future<void> generateMemo(String title) async {
    if (state.meaningfulCharCount < 15) return;
    state = state.copyWith(isMemoLoading: true);
    try {
      final res = await http
          .post(
            Uri.parse('$_api/api/ai/memo'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'content': state.fullContent.substring(
                0,
                state.fullContent.length.clamp(0, 3000),
              ),
              'title': title,
            }),
          )
          .timeout(const Duration(seconds: 60));
      if (!mounted) return;
      if (res.statusCode == 200) {
        final memo = jsonDecode(utf8.decode(res.bodyBytes))['memo'] ?? '';
        state = state.copyWith(
          currentMemo: memo.toString().trim(),
          isMemoLoading: false,
        );
      } else {
        state = state.copyWith(isMemoLoading: false);
      }
    } catch (_) {
      if (!mounted) return;
      state = state.copyWith(isMemoLoading: false);
    }
  }

  // ─── 퀴즈 ───────────────────────────────────────────
  Future<void> generateQuiz() async {
    if (state.meaningfulCharCount < 10) return;
    state = state.copyWith(isQuizLoading: true);
    try {
      final content = state.fullContent.substring(
        0,
        state.fullContent.length.clamp(0, 3000),
      );
      final res = await http
          .post(
            Uri.parse('$_api/api/ai/quiz'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'content': content, 'count': 3}),
          )
          .timeout(const Duration(seconds: 60));
      if (!mounted) return;
      if (res.statusCode == 200) {
        final quiz =
            jsonDecode(utf8.decode(res.bodyBytes))['quiz'] as List? ?? [];
        state = state.copyWith(
          quizData: quiz,
          quizAnswers: {},
          isQuizLoading: false,
        );
      } else {
        state = state.copyWith(isQuizLoading: false);
      }
    } catch (_) {
      if (!mounted) return;
      state = state.copyWith(isQuizLoading: false);
    }
  }

  void answerQuiz(int qi, int oi) {
    if (state.quizAnswers.containsKey(qi)) return;
    final a = Map<int, int>.from(state.quizAnswers);
    a[qi] = oi;
    state = state.copyWith(quizAnswers: a);
  }

  // ─── Ask AI ─────────────────────────────────────────
  Future<void> askAI(String query, String projectId) async {
    if (query.trim().isEmpty) return;
    state = state.copyWith(isQALoading: true);
    try {
      final res = await http
          .post(
            Uri.parse('$_api/api/ai/ask'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'query': query,
              'project_id': projectId,
              'use_web_search': true,
            }),
          )
          .timeout(const Duration(seconds: 60));
      if (!mounted) return;
      if (res.statusCode == 200) {
        final d = jsonDecode(utf8.decode(res.bodyBytes));
        state = state.copyWith(
          qaAnswer: '**출처: ${d['source']}**\n\n${d['answer']}',
          isQALoading: false,
        );
      } else {
        state = state.copyWith(isQALoading: false, qaAnswer: '응답 실패');
      }
    } catch (_) {
      if (!mounted) return;
      state = state.copyWith(isQALoading: false, qaAnswer: '연결 오류');
    }
  }

  // ─── 지식 그래프 ────────────────────────────────────
  Future<void> requestGraph() async {
    if (state.meaningfulCharCount < 10) return;
    state = state.copyWith(isGraphLoading: true);
    try {
      final content = state.fullContent.substring(
        0,
        state.fullContent.length.clamp(0, 2000),
      );
      final res = await http
          .post(
            Uri.parse('$_api/api/ai/graph'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'content': content}),
          )
          .timeout(const Duration(seconds: 45));
      if (!mounted) return;
      if (res.statusCode == 200) {
        state = state.copyWith(
          graphData: jsonDecode(utf8.decode(res.bodyBytes)),
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

  // ─── Export Markdown ────────────────────────────────
  Future<void> copyMarkdown(String title, String tags) async {
    final sb = StringBuffer();
    if (title.isNotEmpty) sb.writeln('# $title\n');
    if (tags.isNotEmpty) sb.writeln('> $tags\n');
    for (final b in state.blocks) {
      final t = b.controller.text;
      switch (b.type) {
        case BlockType.h1:
          sb.writeln('# $t');
          break;
        case BlockType.h2:
          sb.writeln('## $t');
          break;
        case BlockType.h3:
          sb.writeln('### $t');
          break;
        case BlockType.bullet:
          sb.writeln('- $t');
          break;
        case BlockType.checkbox:
          sb.writeln('- [${b.isChecked ? 'x' : ' '}] $t');
          break;
        case BlockType.code:
          sb.writeln('```\n$t\n```');
          break;
        default:
          sb.writeln(t);
      }
      sb.writeln();
    }
    final saved = state.summaryBlocks.where((b) => b.isSaved);
    if (saved.isNotEmpty) {
      sb.writeln('\n---\n## AI 요약\n');
      for (final s in saved) {
        sb.writeln(s.content);
        sb.writeln();
      }
    }
    await Clipboard.setData(ClipboardData(text: sb.toString()));
  }

  // ─── 블록 편집 ──────────────────────────────────────
  void mergeWithPrev(int index) {
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

  void insertAfter(
    int index, {
    String content = '',
    BlockType type = BlockType.text,
  }) {
    final blocks = [...state.blocks];
    blocks.insert(
      index + 1,
      _newBlock(index + 1, type: type, content: content),
    );
    state = state.copyWith(blocks: blocks);
  }

  void insertBlocks(int index, List<String> lines) {
    final blocks = [...state.blocks];
    for (int i = 0; i < lines.length; i++) {
      String text = lines[i];
      BlockType type = BlockType.text;
      if (i == 0 && index > 0) {
        final prevType = blocks[index - 1].type;
        if (prevType == BlockType.bullet || prevType == BlockType.checkbox) {
          type = prevType;
        }
      }
      blocks.insert(index + i, _newBlock(index + i, type: type, content: text));
    }
    state = state.copyWith(blocks: blocks);
  }

  void removeBlock(int index) {
    if (state.blocks.length <= 1) return;
    final blocks = [...state.blocks];
    blocks[index].dispose();
    blocks.removeAt(index);
    state = state.copyWith(blocks: blocks);
  }

  void exitListMode(int index) {
    final blocks = [...state.blocks];
    blocks[index].type = BlockType.text;
    state = state.copyWith(blocks: blocks);
  }

  void reorder(int from, int to) {
    if (from < to) to -= 1;
    final blocks = [...state.blocks];
    final item = blocks.removeAt(from);
    blocks.insert(to, item);
    state = state.copyWith(blocks: blocks);
  }

  void duplicate(int index) {
    final orig = state.blocks[index];
    final copy = _newBlock(
      index + 1,
      type: orig.type,
      content: orig.controller.text,
    )..isChecked = orig.isChecked;
    final blocks = [...state.blocks];
    blocks.insert(index + 1, copy);
    state = state.copyWith(blocks: blocks);
  }

  void setType(int index, BlockType type) {
    final blocks = [...state.blocks];
    blocks[index].type = type;
    if (type == BlockType.checkbox) blocks[index].isChecked = false;
    state = state.copyWith(blocks: blocks);
  }

  void toggleCheck(int index, bool v) {
    final blocks = [...state.blocks];
    blocks[index].isChecked = v;
    state = state.copyWith(blocks: blocks);
  }

  void indent(int index) {
    final c = state.blocks[index].controller;
    final pos = c.selection.baseOffset.clamp(0, c.text.length);
    c.text = '${c.text.substring(0, pos)}    ${c.text.substring(pos)}';
    c.selection = TextSelection.collapsed(offset: pos + 4);
  }

  void dedent(int index) {
    final c = state.blocks[index].controller;
    if (c.text.startsWith('    ')) {
      c.text = c.text.substring(4);
      c.selection = TextSelection.collapsed(
        offset: (c.selection.baseOffset - 4).clamp(0, c.text.length),
      );
    }
  }

  void setIcon(String? icon) => state = state.copyWith(icon: icon);
  void setPrompt(String prompt) => state = state.copyWith(filePrompt: prompt);

  Block _newBlock(
    int i, {
    BlockType type = BlockType.text,
    String content = '',
  }) => Block(
    id: '${DateTime.now().microsecondsSinceEpoch}_$i',
    type: type,
    content: content,
  );

  // ─── 글 교정 ───────────────────────────────────────
  Future<void> proofreadContent({String style = 'academic'}) async {
    if (state.meaningfulCharCount < 10) return;
    state = state.copyWith(isProofreadLoading: true, proofreadResult: null);
    try {
      final res = await http
          .post(
            Uri.parse('$_api/api/ai/proofread'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'content': state.fullContentForAI,
              'style': style,
            }),
          )
          .timeout(const Duration(seconds: 60));
      if (!mounted) return;
      if (res.statusCode == 200) {
        final data = jsonDecode(utf8.decode(res.bodyBytes));
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

  void applyProofread() {
    if (state.proofreadResult == null) return;
    final parsed = _parseBlocks(state.proofreadResult!);
    for (var b in state.blocks) b.dispose();
    state = state.copyWith(
      blocks: parsed.isEmpty ? [_newBlock(0)] : parsed,
      proofreadResult: null,
    );
  }
}

// ─── FilesNotifier (파일 목록) ───────────────────────────
final filesProvider = StateNotifierProvider<FilesNotifier, List<FileModel>>(
  (ref) => FilesNotifier(),
);

class FilesNotifier extends StateNotifier<List<FileModel>> {
  FilesNotifier() : super([]);

  Future<void> load(String projectId) async {
    if (!kIsWeb) {
      state = await FilesDBHelper.selectProjectFiles(projectId);
      return;
    }
    try {
      final res = await http
          .get(Uri.parse('$_api/api/files/project/$projectId'))
          .timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        state = (jsonDecode(res.body) as List)
            .map((j) => FileModel.fromJson(j))
            .toList();
      }
    } catch (e) {
      print('loadFiles: $e');
    }
  }

  Future<void> add(FileModel f) async {
    if (!kIsWeb)
      await FilesDBHelper.insertFile(f);
    else {
      try {
        await http
            .post(
              Uri.parse('$_api/api/files/'),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode(f.toMap()),
            )
            .timeout(const Duration(seconds: 10));
      } catch (e) {
        print('addFile: $e');
      }
    }
    state = [f, ...state];
  }

  Future<void> remove(String id) async {
    if (!kIsWeb)
      await FilesDBHelper.deleteFile(id);
    else {
      try {
        await http
            .delete(Uri.parse('$_api/api/files/$id'))
            .timeout(const Duration(seconds: 10));
      } catch (e) {
        print('deleteFile: $e');
      }
    }
    state = state.where((f) => f.id != id).toList();
  }
}
