import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../core/db_helper/files_db_helper.dart';
import '../../core/provider_config.dart' show baseUrl;
import '../../models/block_model.dart';
import '../../core/markdown_parser.dart';
import 'file_model.dart';

// ─────────────────────────────────────────────────────────
// QA 채팅 메시지 모델
// ─────────────────────────────────────────────────────────
class QAMessage {
  final String role; // 'user' | 'assistant'
  final String content;
  final DateTime timestamp;

  QAMessage({required this.role, required this.content, required this.timestamp});

  Map<String, dynamic> toJson() => {
    'role': role,
    'content': content,
    'timestamp': timestamp.toIso8601String(),
  };

  factory QAMessage.fromJson(Map<String, dynamic> j) => QAMessage(
    role: j['role'] as String? ?? 'assistant',
    content: j['content'] as String? ?? '',
    timestamp: j['timestamp'] != null
        ? DateTime.tryParse(j['timestamp'] as String) ?? DateTime.now()
        : DateTime.now(),
  );
}

// provider_config.dart 의 baseUrl 을 사용 (dart-define API_BASE 로 주입 가능)
const String _api = baseUrl;

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
  final List<QAMessage> qaMessages; // 채팅 히스토리 (user + assistant)
  final Map<String, dynamic>? graphData;
  final String? graphError;

  final String focusedText;
  final DateTime? lastSavedAt;
  final String lastSentContent;
  final String? proofreadResult;
  final bool isProofreadLoading;

  // ✅ title/tags도 state에 보관 (웹 호환)
  final String fileTitle;
  final String fileTags;

  // 요약 스트리밍 진행 메시지 ("3개 섹션 분석 중..." 등)
  final String summaryProgress;

  // 현재 분석 중인 블록 인덱스 (-1 = 없음)
  final int analyzingBlockIndex;

  // 사용자 자유 입력 메모 (서버 동기화 — files.memo)
  final String userMemo;

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
    this.qaMessages = const [],
    this.graphData,
    this.graphError,
    this.focusedText = '',
    this.lastSavedAt,
    this.lastSentContent = '',
    this.fileTitle = '',
    this.fileTags = '',
    this.proofreadResult,
    this.isProofreadLoading = false,
    this.summaryProgress = '',
    this.analyzingBlockIndex = -1,
    this.userMemo = '',
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
    List<QAMessage>? qaMessages,
    Map<String, dynamic>? graphData,
    String? graphError,
    bool clearGraphError = false,
    String? focusedText,
    DateTime? lastSavedAt,
    String? lastSentContent,
    String? fileTitle,
    String? fileTags,
    String? proofreadResult,
    bool? isProofreadLoading,
    String? summaryProgress,
    int? analyzingBlockIndex,
    String? userMemo,
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
    qaMessages: qaMessages ?? this.qaMessages,
    graphData: graphData ?? this.graphData,
    graphError: clearGraphError ? null : (graphError ?? this.graphError),
    focusedText: focusedText ?? this.focusedText,
    lastSavedAt: lastSavedAt ?? this.lastSavedAt,
    lastSentContent: lastSentContent ?? this.lastSentContent,
    fileTitle: fileTitle ?? this.fileTitle,
    fileTags: fileTags ?? this.fileTags,
    proofreadResult: proofreadResult ?? this.proofreadResult,
    isProofreadLoading: isProofreadLoading ?? this.isProofreadLoading,
    summaryProgress: summaryProgress ?? this.summaryProgress,
    analyzingBlockIndex: analyzingBlockIndex ?? this.analyzingBlockIndex,
    userMemo: userMemo ?? this.userMemo,
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

  // ignore: unused_field
  String _lastAnalyzedText = '';
  // 마지막으로 요약에 사용된 콘텐츠 해시 (변경 없으면 skip)
  int _lastSummaryHash = 0;

  // ─── 로드 ────────────────────────────────────────────
  /// [syncMode] = true 이면 30초 주기 서버 동기화 호출 —
  /// 미저장 summaryBlocks가 있으면 덮어쓰지 않음
  Future<void> loadFileDetail(String fileId, {bool syncMode = false}) async {
    if (!syncMode) state = state.copyWith(isLoading: true);
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

      // syncMode: 현재 summaryBlocks가 있으면 서버 값으로 덮어쓰지 않음
      // (30초 동기화가 미저장 AI 요약을 날리는 버그 방지)
      final summaryToUse = (syncMode && state.summaryBlocks.isNotEmpty)
          ? state.summaryBlocks
          : summary;

      // syncMode: 로컬에서 편집 중인 메모가 있으면 서버 값으로 덮어쓰지 않음
      final memoToUse = (syncMode && state.userMemo.isNotEmpty)
          ? state.userMemo
          : (file.memo ?? '');

      state = state.copyWith(
        blocks: blocks.isEmpty ? [_newBlock(0)] : blocks,
        isLoading: false,
        icon: file.icon,
        filePrompt: file.prompt,
        summaryBlocks: summaryToUse,
        graphData: _parseGraph(file.graph),
        lastSentContent: file.content,
        fileTitle: file.title == '제목 없음' ? '' : file.title,
        fileTags: file.tags,
        userMemo: memoToUse,
      );
    } else {
      if (!syncMode)
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

  Map<String, dynamic>? _parseGraph(String? s) {
    if (s == null || s.isEmpty) return null;
    try {
      final parsed = jsonDecode(s);
      return parsed is Map<String, dynamic> ? parsed : null;
    } catch (_) {
      return null;
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
    final graphJson = state.graphData == null
        ? null
        : jsonEncode(state.graphData);

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
        graph: graphJson,
        memo: state.userMemo,
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
                'graph': graphJson,
                'icon': state.icon,
                'memo': state.userMemo,
              }),
            )
            .timeout(const Duration(seconds: 30));
      } catch (e) {
        print('saveFile error: $e');
      }
    }
    if (mounted) state = state.copyWith(lastSavedAt: DateTime.now());
  }

  // ─── 콘텐츠 해시 (변경 감지용) ─────────────────────
  int _hashContent(String content) {
    var h = 0;
    for (var i = 0; i < content.length; i++) {
      h = (h * 31 + content.codeUnitAt(i)) & 0x7FFFFFFF;
    }
    return h;
  }

  // ─── 요약 (SSE 스트리밍 — 메인) ──────────────────────
  /// [force] = true 이면 내용 미변경이어도 강제 재요약 (재요약 버튼)
  Future<void> requestSummary({
    required String title,
    required String tags,
    bool force = false,
  }) async {
    if (state.meaningfulCharCount < 15) return;
    if (state.isSummaryLoading) return; // 이미 실행 중이면 중복 방지

    final full = state.fullContentForAI;
    final hash = _hashContent(full);

    // ── 핵심 fix: 내용 미변경 시 무조건 skip (force 제외) ──
    // 이전: saved.length 비교로 미저장 블록 있으면 skip 안 됨 → 재호출 시 덮어써서 사라짐
    if (!force && hash == _lastSummaryHash) return;

    // 저장된 블록만 기준으로 사용
    final saved = state.summaryBlocks.where((b) => b.isSaved).toList();

    // ── 로딩 시작: summaryBlocks는 건드리지 않음 ────────
    // 이전 요약이 있으면 새 요약 완료 전까지 계속 보여줌
    state = state.copyWith(
      isSummaryLoading: true,
      summaryProgress: '요약 준비 중...',
    );

    final fp = state.filePrompt ?? '';
    final savedText = saved.map((b) => b.content).join('\n\n');
    String? customPrompt;
    if (savedText.isNotEmpty) {
      customPrompt =
          '${fp.isNotEmpty ? "사용자 지시: $fp\n\n" : ""}'
          '기존 요약:\n$savedText\n\n'
          '기존 요약을 참고하되 전체 본문을 다시 읽고, 문단 흐름과 순서를 유지한 하나의 완성된 학습 노트로 재정리하세요. '
          '새 내용만 따로 쓰지 말고 전체 흐름을 자연스럽게 이어주세요.';
    } else if (fp.isNotEmpty) {
      customPrompt =
          '$fp\n\n문단 순서와 설명 흐름을 유지하고, 중요한 세부 내용이 날아가지 않게 충분히 자세히 정리하세요.';
    }

    final body = jsonEncode({
      'content': full,
      'tags': tags,
      'title': title,
      'custom_prompt': customPrompt,
    });

    // ── SSE 스트리밍 시도 ───────────────────────────────
    final client = http.Client();
    try {
      final request = http.Request(
        'POST',
        Uri.parse('$_api/api/ai/summarize-stream'),
      );
      request.headers['Content-Type'] = 'application/json';
      request.headers['Accept'] = 'text/event-stream';
      request.body = body;

      final streamed = await client
          .send(request)
          .timeout(const Duration(seconds: 120));

      String streamText = '';
      // 첫 토큰 도착 전까지 이전 요약 유지 → 도착 시 교체
      bool firstTokenReceived = false;

      final lines = streamed.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter());

      await for (final line in lines) {
        if (!mounted) break;
        if (!line.startsWith('data: ')) continue;
        final data = line.substring(6).trim();
        if (data == '[DONE]') break;
        final evt = jsonDecode(data) as Map<String, dynamic>;
        switch (evt['type']) {
          case 'progress':
            state = state.copyWith(
              summaryProgress: evt['message'] as String? ?? '',
            );
            break;

          case 'token':
            streamText += evt['text'] as String? ?? '';
            if (!firstTokenReceived) {
              // 첫 토큰 도착 시점에만 이전 요약 교체 (그 전까지는 유지)
              firstTokenReceived = true;
            }
            state = state.copyWith(
              summaryBlocks: [
                ...saved,
                SummaryBlock(content: streamText, isSaved: false),
              ],
            );
            break;

          case 'done':
            final finalText = ((evt['text'] as String?) ?? streamText).trim();
            if (finalText.isNotEmpty) {
              _lastSummaryHash = hash;
              state = state.copyWith(
                summaryBlocks: [
                  ...saved,
                  SummaryBlock(content: finalText, isSaved: false),
                ],
                isSummaryLoading: false,
                summaryProgress: '',
                lastSentContent: full,
              );
            } else {
              // 완전히 비어있으면 로딩만 종료, 블록은 현재 상태 유지
              state = state.copyWith(
                isSummaryLoading: false,
                summaryProgress: '',
              );
            }
            break;

          case 'error':
            final message =
                (evt['message'] as String?) ?? '요약 스트리밍에 실패했습니다.';
            throw Exception(message);
        }
      }

      // [DONE] 없이 스트림 끝난 경우
      if (mounted && state.isSummaryLoading) {
        if (streamText.trim().isNotEmpty) {
          _lastSummaryHash = hash;
          state = state.copyWith(
            summaryBlocks: [
              ...saved,
              SummaryBlock(content: streamText.trim(), isSaved: false),
            ],
            isSummaryLoading: false,
            summaryProgress: '',
            lastSentContent: full,
          );
        } else {
          state = state.copyWith(isSummaryLoading: false, summaryProgress: '');
        }
      }
    } catch (_) {
      // ── SSE 실패 → 비스트리밍 폴백 ──────────────────
      if (!mounted) return;
      state = state.copyWith(summaryProgress: '요약 생성 중...');
      try {
        final res = await http
            .post(
              Uri.parse('$_api/api/ai/summarize'),
              headers: {'Content-Type': 'application/json'},
              body: body,
            )
            .timeout(const Duration(seconds: 90));
        if (!mounted) return;
        if (res.statusCode == 200) {
          final newText =
              (jsonDecode(utf8.decode(res.bodyBytes))['summary'] ?? '')
                  .toString()
                  .trim();
          if (newText.isNotEmpty) {
            _lastSummaryHash = hash;
            state = state.copyWith(
              summaryBlocks: [
                ...saved,
                SummaryBlock(content: newText, isSaved: false),
              ],
              isSummaryLoading: false,
              summaryProgress: '',
              lastSentContent: full,
            );
          } else {
            state = state.copyWith(
              isSummaryLoading: false,
              summaryProgress: '',
            );
          }
        } else {
          final message = utf8.decode(res.bodyBytes);
          state = state.copyWith(
            summaryBlocks: [
              ...saved,
              SummaryBlock(
                content: '요약 생성에 실패했습니다.\n\n서버 응답: $message',
                isSaved: false,
              ),
            ],
            isSummaryLoading: false,
            summaryProgress: '',
          );
        }
      } catch (error) {
        if (mounted) {
          state = state.copyWith(
            summaryBlocks: [
              ...saved,
              SummaryBlock(
                content: '요약 생성에 실패했습니다.\n\n$error',
                isSaved: false,
              ),
            ],
            isSummaryLoading: false,
            summaryProgress: '',
          );
        }
      }
    } finally {
      client.close();
    }
  }

  void toggleSummarySave(int i) {
    final list = List<SummaryBlock>.from(state.summaryBlocks);
    list[i] = SummaryBlock(content: list[i].content, isSaved: !list[i].isSaved);
    state = state.copyWith(summaryBlocks: list);
  }

  void updateSummaryBlock(int i, String content) {
    final list = List<SummaryBlock>.from(state.summaryBlocks);
    list[i] = SummaryBlock(content: content, isSaved: list[i].isSaved);
    state = state.copyWith(summaryBlocks: list);
  }

  void removeSummaryBlock(int i) {
    final list = List<SummaryBlock>.from(state.summaryBlocks)..removeAt(i);
    state = state.copyWith(summaryBlocks: list);
  }

  void setGraphData(Map<String, dynamic>? graph) {
    state = state.copyWith(graphData: graph);
  }

  List<dynamic> _normalizeQuiz(List<dynamic> quiz) {
    return quiz.whereType<Map>().map((raw) {
      final question = (raw['question']?.toString() ?? '').trim();
      final explanation = (raw['explanation']?.toString() ?? '').trim();
      final options = ((raw['options'] as List?) ?? [])
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .toList();
      while (options.length < 4) {
        options.add('본문을 다시 확인해보세요.');
      }
      int answer = 0;
      final rawAnswer = raw['answer'];
      if (rawAnswer is int) {
        answer = rawAnswer;
      } else if (rawAnswer is String) {
        answer = int.tryParse(rawAnswer) ?? 0;
      }
      answer = answer.clamp(0, options.length - 1);
      return {
        'question': question.isEmpty ? '본문 내용과 가장 잘 맞는 설명은?' : question,
        'options': options.take(4).toList(),
        'answer': answer,
        'explanation': explanation.isEmpty ? options[answer] : explanation,
      };
    }).toList();
  }

  Map<String, dynamic>? _normalizeGraph(Map<String, dynamic>? graph) {
    if (graph == null) return null;
    final rawNodes = (graph['nodes'] as List?) ?? [];
    final rawEdges = (graph['edges'] as List?) ?? [];
    final nodes = rawNodes
        .whereType<Map>()
        .map(
          (raw) => {
            'id': raw['id']?.toString() ?? '',
            'label': (raw['label']?.toString() ?? '').trim(),
            'description': (raw['description']?.toString() ?? '').trim(),
            'type': (raw['type']?.toString() ?? 'detail').trim(),
            'group': (raw['group']?.toString() ?? '').trim(),
            'x': raw['x'],
            'y': raw['y'],
          },
        )
        .where(
          (node) =>
              (node['id'] as String).isNotEmpty &&
              (node['label'] as String).isNotEmpty,
        )
        .toList();
    final ids = nodes.map((e) => e['id'] as String).toSet();
    final edges = rawEdges
        .whereType<Map>()
        .map(
          (raw) => {
            'source': raw['source']?.toString() ?? '',
            'target': raw['target']?.toString() ?? '',
            'label': (raw['label']?.toString() ?? '').trim(),
          },
        )
        .where(
          (edge) =>
              ids.contains(edge['source']) && ids.contains(edge['target']),
        )
        .toList();
    return {'nodes': nodes, 'edges': edges};
  }

  void updateGraphNode(
    String nodeId, {
    String? label,
    String? description,
    double? x,
    double? y,
    String? type,
    String? group,
  }) {
    if (state.graphData == null) return;
    final graph = Map<String, dynamic>.from(state.graphData!);
    final nodes = (graph['nodes'] as List? ?? []).map((raw) {
      final node = Map<String, dynamic>.from(raw as Map);
      if (node['id'].toString() != nodeId) return node;
      if (label != null) node['label'] = label;
      if (description != null) node['description'] = description;
      if (x != null) node['x'] = x;
      if (y != null) node['y'] = y;
      if (type != null) node['type'] = type;
      if (group != null) node['group'] = group;
      return node;
    }).toList();
    graph['nodes'] = nodes;
    state = state.copyWith(graphData: graph);
  }

  List<Map<String, dynamic>> _sanitizeGraphEdges(
    List<Map<String, dynamic>> edges,
    Set<String> validIds,
  ) {
    final seen = <String>{};
    return edges.where((edge) {
      final source = edge['source']?.toString() ?? '';
      final target = edge['target']?.toString() ?? '';
      if (source.isEmpty ||
          target.isEmpty ||
          source == target ||
          !validIds.contains(source) ||
          !validIds.contains(target)) {
        return false;
      }
      final key = '$source->$target';
      if (seen.contains(key)) {
        return false;
      }
      seen.add(key);
      edge['label'] = (edge['label']?.toString() ?? '').trim();
      return true;
    }).toList();
  }

  void addGraphNode({
    required String label,
    String description = '',
    String type = 'detail',
    String group = '',
    String? parentId,
    double? x,
    double? y,
  }) {
    if (state.graphData == null) {
      return;
    }
    final graph = Map<String, dynamic>.from(state.graphData!);
    final nodes = List<Map<String, dynamic>>.from(
      (graph['nodes'] as List? ?? []).whereType<Map>().map(
        (raw) => Map<String, dynamic>.from(raw),
      ),
    );
    final edges = List<Map<String, dynamic>>.from(
      (graph['edges'] as List? ?? []).whereType<Map>().map(
        (raw) => Map<String, dynamic>.from(raw),
      ),
    );
    final nodeId = 'node_${DateTime.now().millisecondsSinceEpoch}';
    nodes.add({
      'id': nodeId,
      'label': label,
      'description': description,
      'type': type,
      'group': group,
      'x': x,
      'y': y,
    });
    if (parentId != null && parentId.isNotEmpty) {
      edges.add({'source': parentId, 'target': nodeId, 'label': '메모'});
    }
    graph['nodes'] = nodes;
    graph['edges'] = _sanitizeGraphEdges(
      edges,
      nodes.map((node) => node['id'].toString()).toSet(),
    );
    state = state.copyWith(graphData: graph);
  }

  void removeGraphNode(String nodeId) {
    if (state.graphData == null) {
      return;
    }
    final graph = Map<String, dynamic>.from(state.graphData!);
    final nodes = (graph['nodes'] as List? ?? [])
        .whereType<Map>()
        .map((raw) => Map<String, dynamic>.from(raw))
        .where((node) => node['id'].toString() != nodeId)
        .toList();
    final edges = (graph['edges'] as List? ?? [])
        .whereType<Map>()
        .map((raw) => Map<String, dynamic>.from(raw))
        .where(
          (edge) =>
              edge['source'].toString() != nodeId &&
              edge['target'].toString() != nodeId,
        )
        .toList();
    graph['nodes'] = nodes;
    graph['edges'] = _sanitizeGraphEdges(
      edges,
      nodes.map((node) => node['id'].toString()).toSet(),
    );
    state = state.copyWith(graphData: graph);
  }

  void connectGraphNodes(
    String sourceId,
    String targetId, {
    String label = '연결',
  }) {
    if (state.graphData == null || sourceId == targetId) {
      return;
    }
    final graph = Map<String, dynamic>.from(state.graphData!);
    final nodes = List<Map<String, dynamic>>.from(
      (graph['nodes'] as List? ?? []).whereType<Map>().map(
        (raw) => Map<String, dynamic>.from(raw),
      ),
    );
    final validIds = nodes.map((node) => node['id'].toString()).toSet();
    final edges = List<Map<String, dynamic>>.from(
      (graph['edges'] as List? ?? []).whereType<Map>().map(
        (raw) => Map<String, dynamic>.from(raw),
      ),
    )..add({'source': sourceId, 'target': targetId, 'label': label});
    graph['edges'] = _sanitizeGraphEdges(edges, validIds);
    state = state.copyWith(graphData: graph);
  }

  void reparentGraphNode(String nodeId, String? parentId) {
    if (state.graphData == null) {
      return;
    }
    final graph = Map<String, dynamic>.from(state.graphData!);
    final nodes = List<Map<String, dynamic>>.from(
      (graph['nodes'] as List? ?? []).whereType<Map>().map(
        (raw) => Map<String, dynamic>.from(raw),
      ),
    );
    final validIds = nodes.map((node) => node['id'].toString()).toSet();
    final edges = List<Map<String, dynamic>>.from(
      (graph['edges'] as List? ?? []).whereType<Map>().map(
        (raw) => Map<String, dynamic>.from(raw),
      ),
    ).where((edge) => edge['target']?.toString() != nodeId).toList();
    if (parentId != null &&
        parentId.isNotEmpty &&
        parentId != nodeId &&
        validIds.contains(parentId) &&
        validIds.contains(nodeId)) {
      edges.add({'source': parentId, 'target': nodeId, 'label': '구조'});
    }
    graph['edges'] = _sanitizeGraphEdges(edges, validIds);
    state = state.copyWith(graphData: graph);
  }

  void updateGraphNodeMeta(
    String nodeId, {
    String? type,
    String? group,
    String? parentId,
  }) {
    if (state.graphData == null) {
      return;
    }
    updateGraphNode(nodeId, type: type, group: group);
    if (parentId != null) {
      reparentGraphNode(nodeId, parentId);
    }
  }

  // ─── 블록 분석 ──────────────────────────────────────
  Future<void> analyzeBlock({
    required String text,
    required String title,
    int blockIndex = -1,
  }) async {
    if (text.trim().length < 5) return;
    _lastAnalyzedText = text;
    // ✅ currentAnalysis를 null로 리셋해서 이전 결과 지우기
    // 이전 분석 결과 초기화 후 로딩 시작
    // copyWith 는 null을 "미제공"으로 처리해 currentAnalysis를 null로 못 내리므로
    // 직접 생성하되 userMemo 등 모든 필드를 명시적으로 유지한다.
    state = FileEditorState(
      blocks: state.blocks,
      isLoading: state.isLoading,
      isSummaryLoading: state.isSummaryLoading,
      isAnalysisLoading: true,
      isMemoLoading: state.isMemoLoading,
      isQuizLoading: state.isQuizLoading,
      isQALoading: state.isQALoading,
      isGraphLoading: state.isGraphLoading,
      icon: state.icon,
      filePrompt: state.filePrompt,
      summaryBlocks: state.summaryBlocks,
      currentAnalysis: null, // ✅ 완전 초기화
      currentMemo: state.currentMemo,
      quizData: state.quizData,
      quizAnswers: state.quizAnswers,
      qaMessages: state.qaMessages,
      graphData: state.graphData,
      focusedText: text,
      lastSavedAt: state.lastSavedAt,
      lastSentContent: state.lastSentContent,
      fileTitle: state.fileTitle,
      fileTags: state.fileTags,
      proofreadResult: state.proofreadResult,
      isProofreadLoading: state.isProofreadLoading,
      summaryProgress: state.summaryProgress,
      analyzingBlockIndex: blockIndex,
      userMemo: state.userMemo, // ✅ 메모 유실 방지
    );
    try {
      final res = await http
          .post(
            Uri.parse('$_api/api/ai/analyze-block'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'text': text, 'context_title': title}),
          )
          .timeout(const Duration(seconds: 20));
      if (!mounted) return;
      if (res.statusCode == 200) {
        final payload = jsonDecode(utf8.decode(res.bodyBytes));
        final analysis = payload is Map ? payload['analysis'] ?? '' : '';
        state = state.copyWith(
          currentAnalysis: analysis.toString().trim(),
          isAnalysisLoading: false,
          analyzingBlockIndex: -1,
        );
      } else {
        state = state.copyWith(isAnalysisLoading: false, analyzingBlockIndex: -1);
      }
    } catch (_) {
      if (!mounted) return;
      state = state.copyWith(isAnalysisLoading: false, analyzingBlockIndex: -1);
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
              'content': state.fullContentForAI,
              'title': title,
            }),
          )
          .timeout(const Duration(seconds: 60));
      if (!mounted) return;
      if (res.statusCode == 200) {
        final payload = jsonDecode(utf8.decode(res.bodyBytes));
        final memo = payload is Map ? payload['memo'] ?? '' : '';
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
      final res = await http
          .post(
            Uri.parse('$_api/api/ai/quiz'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'content': state.fullContentForAI, 'count': 8}),
          )
          .timeout(const Duration(seconds: 60));
      if (!mounted) return;
      if (res.statusCode == 200) {
        final payload = jsonDecode(utf8.decode(res.bodyBytes));
        final rawQuiz = payload is Map ? payload['quiz'] : null;
        final quiz = _normalizeQuiz(
          rawQuiz is List ? rawQuiz : [],
        );
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
    // 사용자 메시지 즉시 추가
    final userMsg = QAMessage(
      role: 'user',
      content: query.trim(),
      timestamp: DateTime.now(),
    );
    state = state.copyWith(
      isQALoading: true,
      qaMessages: [...state.qaMessages, userMsg],
    );
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
        final src = d['source'] as String?;
        final answer = d['answer'] as String? ?? '';
        final assistantContent = src != null && src.isNotEmpty
            ? '$answer\n\n_출처: ${src}_'
            : answer;
        final assistantMsg = QAMessage(
          role: 'assistant',
          content: assistantContent,
          timestamp: DateTime.now(),
        );
        state = state.copyWith(
          qaMessages: [...state.qaMessages, assistantMsg],
          isQALoading: false,
        );
      } else {
        final errMsg = QAMessage(
          role: 'assistant',
          content: '응답에 실패했습니다. 잠시 후 다시 시도해주세요.',
          timestamp: DateTime.now(),
        );
        state = state.copyWith(
          isQALoading: false,
          qaMessages: [...state.qaMessages, errMsg],
        );
      }
    } catch (_) {
      if (!mounted) return;
      final errMsg = QAMessage(
        role: 'assistant',
        content: '연결 오류가 발생했습니다.',
        timestamp: DateTime.now(),
      );
      state = state.copyWith(
        isQALoading: false,
        qaMessages: [...state.qaMessages, errMsg],
      );
    }
  }

  // ─── 지식 그래프 ────────────────────────────────────
  Future<void> requestGraph() async {
    debugPrint(
      '[Graph] requestGraph() called, meaningfulCharCount=${state.meaningfulCharCount}',
    );
    if (state.meaningfulCharCount < 10) {
      debugPrint('[Graph] skipped: too short');
      state = state.copyWith(
        isGraphLoading: false,
        graphError: '노트 내용이 너무 짧습니다. 내용을 더 작성한 후 시도해주세요.',
      );
      return;
    }
    state = state.copyWith(isGraphLoading: true, clearGraphError: true);
    try {
      final content = state.fullContent.substring(
        0,
        state.fullContent.length.clamp(0, 6000),
      );
      debugPrint(
        '[Graph] POST $_api/api/ai/graph (content=${content.length}chars)',
      );
      final res = await http
          .post(
            Uri.parse('$_api/api/ai/graph'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'content': content,
              'title': state.fileTitle,
              'tags': state.fileTags,
              'summary': state.summaryBlocks.map((b) => b.content).join('\n\n'),
            }),
          )
          .timeout(const Duration(seconds: 60));
      if (!mounted) return;
      debugPrint('[Graph] response status=${res.statusCode}');
      if (res.statusCode == 200) {
        final payload = jsonDecode(utf8.decode(res.bodyBytes));
        final decoded = _normalizeGraph(
          payload is Map<String, dynamic> ? payload : null,
        );
        final nodes = (decoded?['nodes'] as List?) ?? [];
        debugPrint('[Graph] parsed nodes=${nodes.length}');
        if (nodes.isEmpty) {
          state = state.copyWith(
            isGraphLoading: false,
            graphError: '그래프를 생성하지 못했습니다. 노트 내용을 더 자세히 작성한 후 다시 시도해주세요.',
          );
        } else {
          state = state.copyWith(
            graphData: decoded,
            isGraphLoading: false,
            clearGraphError: true,
          );
        }
      } else {
        debugPrint('[Graph] error body: ${res.body}');
        state = state.copyWith(
          isGraphLoading: false,
          graphError: '서버 오류 (${res.statusCode}). 잠시 후 다시 시도해주세요.',
        );
      }
    } catch (e) {
      debugPrint('[Graph] exception: $e');
      if (!mounted) return;
      state = state.copyWith(
        isGraphLoading: false,
        graphError: '연결 실패. 백엔드 서버가 실행 중인지 확인해주세요.\n($e)',
      );
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
    final parsed = _parseLines(lines);
    for (int i = 0; i < parsed.length; i++) {
      blocks.insert(index + i, parsed[i]);
    }
    state = state.copyWith(blocks: blocks);
  }

  /// 붙여넣기 텍스트를 블록으로 파싱 (노션 복붙 호환)
  List<Block> _parseLines(List<String> lines) {
    final result = <Block>[];
    bool inCode = false;
    final codeBuf = StringBuffer();

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      final trimmed = line.trim();

      // 코드 블록 시작/끝 감지
      if (trimmed.startsWith('```') && !inCode) {
        inCode = true;
        final lang = trimmed.substring(3).trim();
        if (lang.isNotEmpty) codeBuf.writeln('// $lang');
        continue;
      }
      if (trimmed == '```' && inCode) {
        inCode = false;
        result.add(
          _newBlock(
            result.length,
            type: BlockType.code,
            content: codeBuf.toString().trimRight(),
          ),
        );
        codeBuf.clear();
        continue;
      }
      if (inCode) {
        codeBuf.writeln(line);
        continue;
      }

      // 빈 줄 스킵
      if (trimmed.isEmpty) continue;

      // 마크다운 타입 감지
      BlockType type = BlockType.text;
      String content = trimmed;

      if (trimmed.startsWith('### ')) {
        type = BlockType.h3;
        content = trimmed.substring(4);
      } else if (trimmed.startsWith('## ')) {
        type = BlockType.h2;
        content = trimmed.substring(3);
      } else if (trimmed.startsWith('# ')) {
        type = BlockType.h1;
        content = trimmed.substring(2);
      } else if (trimmed.startsWith('> ')) {
        type = BlockType.quote;
        content = trimmed.substring(2);
      } else if (trimmed.startsWith('- ') || trimmed.startsWith('* ')) {
        type = BlockType.bullet;
        content = trimmed.substring(2);
      } else if (RegExp(r'^\d+\. ').hasMatch(trimmed)) {
        type = BlockType.number;
        content = trimmed.replaceFirst(RegExp(r'^\d+\. '), '');
      } else if (trimmed.startsWith('[ ] ') || trimmed.startsWith('[] ')) {
        type = BlockType.checkbox;
        content = trimmed.replaceFirst(RegExp(r'^\[.?\] '), '');
      } else if (trimmed.startsWith('[x] ') || trimmed.startsWith('[X] ')) {
        type = BlockType.checkbox;
        content = trimmed.substring(4);
      }

      result.add(_newBlock(result.length, type: type, content: content));
    }

    // 코드 블록이 닫히지 않은 경우 처리
    if (inCode && codeBuf.isNotEmpty) {
      result.add(
        _newBlock(
          result.length,
          type: BlockType.code,
          content: codeBuf.toString().trimRight(),
        ),
      );
    }

    return result.isEmpty ? [_newBlock(0)] : result;
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
  void setMemo(String memo) => state = state.copyWith(userMemo: memo);

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
            .map<FileModel>(
              (j) => FileModel.fromJson(Map<String, dynamic>.from(j as Map)),
            )
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

  Future<bool> remove(String id) async {
    if (!kIsWeb) {
      await FilesDBHelper.deleteFile(id);
      state = state.where((f) => f.id != id).toList();
      return true;
    }
    // 웹: 낙관적 제거 후 서버 요청 — 실패 시 복원
    final prev = List<FileModel>.from(state);
    state = state.where((f) => f.id != id).toList();
    try {
      final res = await http
          .delete(Uri.parse('$_api/api/files/$id'))
          .timeout(const Duration(seconds: 15));
      if (res.statusCode == 200 || res.statusCode == 204) return true;
      // 서버 오류: 복원
      state = prev;
      return false;
    } catch (e) {
      print('deleteFile: $e');
      state = prev; // 복원
      return false;
    }
  }
}
