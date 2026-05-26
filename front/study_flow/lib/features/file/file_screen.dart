// ╔══════════════════════════════════════════════════════╗
// ║  StudyFlow — Premium Editor v7                       ║
// ║  Notion-style UX · Inter font · High-quality UI      ║
// ╚══════════════════════════════════════════════════════╝
import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:lucide_icons/lucide_icons.dart';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_highlighter/flutter_highlighter.dart';
import 'package:flutter_highlighter/themes/atom-one-dark.dart';

import '../../models/block_model.dart';
import '../../core/db_helper/files_db_helper.dart';
import '../../core/provider_config.dart' show baseUrl;
import '../../core/theme.dart';
import '../../core/ui/app_components.dart';
import '../project/project_provider.dart';
import '../../providers/user_provider.dart';
import 'file_provider.dart';
import 'graph_pdf_export.dart';

// ══════════════════ TOKENS (AppTheme aliases) ════════════════
const _bg0 = AppTheme.bgDeep;
const _bg1 = AppTheme.bgPrimary;
const _bg2 = AppTheme.bgSecondary;
const _bg3 = AppTheme.bgTertiary;
const _bg4 = AppTheme.bgQuaternary;
const _bdr = AppTheme.borderSubtle;
const _bdr2 = AppTheme.borderDefault;
const _txt0 = AppTheme.textPrimary;
const _txt1 = AppTheme.textSecondary;
const _txt2 = AppTheme.textTertiary;
const _acc = AppTheme.accent;
const _accD = AppTheme.accentDim;
const _grn = AppTheme.green;
const _red = AppTheme.red;
const _blu = AppTheme.blue;
const _pur = AppTheme.purple;
const _yel = AppTheme.yellow;

// ══════════════════ BLOCK TYPES ═══════════════════════
// 기존 BlockType + table 추가는 block_model.dart 수정 필요
// 여기서는 code 블록을 table 렌더링에 활용

// ══════════════════ SCREEN ════════════════════════════
class FileScreen extends ConsumerStatefulWidget {
  final String fileId, projectId;
  const FileScreen({Key? key, required this.fileId, this.projectId = 'default'})
    : super(key: key);
  @override
  ConsumerState<FileScreen> createState() => _FS();
}

class _FS extends ConsumerState<FileScreen> with TickerProviderStateMixin {
  static const Duration _autoSaveDelay = Duration(milliseconds: 1500);
  static const Duration _summaryDelay = Duration(seconds: 12);
  static const Duration _webSyncInterval = Duration(minutes: 3);

  final _tCtrl = TextEditingController();
  final _gCtrl = TextEditingController();
  final _pCtrl = TextEditingController();
  final _qaCtrl = TextEditingController();
  late TabController _tab;

  Timer? _saveT, _focT, _sumT, _syncT;
  final _savingN = ValueNotifier<bool>(false);
  Timer? _focTextT;
  int _lastSumLen = 0;
  int _view = 0; // 0:split 1:full 2:mindmap

  // 멀티 블록 선택
  final Set<int> _selectedBlocks = {};
  int _focusedIdx = -1; // 현재 포커스된 블록 인덱스

  // 드래그 박스 선택 (좌표는 드래그 레이어 로컬 기준)
  Offset? _dragStart;
  Offset? _dragCurrent;
  bool _isDragging = false;
  final GlobalKey _dragLayerKey = GlobalKey();
  // Pomodoro
  Timer? _pomT;
  int _pomSecs = 25 * 60; // 25분
  bool _pomRunning = false;
  bool _pomIsWork = true; // true=집중, false=휴식
  static const _pomWork = 25 * 60;
  static const _pomRest = 5 * 60;

  // Proofread
  // ignore: unused_field
  bool _proofreadMode = false;
  String _proofreadResult = '';

  // ✅ 인라인 선택 툴바
  OverlayEntry? _selToolbarEntry;
  String _selText = '';
  TextEditingController? _selCtrl;
  GlobalKey? _selBlockKey;
  final Map<int, GlobalKey> _blockKeys = {};

  // Slash
  OverlayEntry? _slash;
  int _slashIdx = 0;
  int _slashBlockIdx = -1; // 슬래시 메뉴가 열린 블록 인덱스
  int _slashGen = 0; // 지연 삽입 경합 방지용 세대 카운터
  List<_Opt> _slashOpts = [];

  late AnimationController _saveAc;
  late Animation<double> _saveAnim;

  static const _opts = [
    // 기본 텍스트
    _Opt('p', '텍스트', Icons.short_text_rounded, '', '일반 텍스트를 작성하세요', '기본 블록'),
    _Opt('h1', '제목 1', Icons.looks_one_rounded, '#', '큰 섹션 제목', '기본 블록'),
    _Opt('h2', '제목 2', Icons.looks_two_rounded, '##', '중간 섹션 제목', '기본 블록'),
    _Opt('h3', '제목 3', Icons.looks_3_rounded, '###', '작은 섹션 제목', '기본 블록'),
    _Opt(
      'quote',
      '인용',
      Icons.format_quote_rounded,
      '>',
      '텍스트를 인용 형식으로',
      '기본 블록',
    ),
    // 목록
    _Opt(
      'bullet',
      '글머리 기호',
      Icons.format_list_bulleted_rounded,
      '-',
      '글머리 기호 목록 작성',
      '목록',
    ),
    _Opt(
      'number',
      '번호 목록',
      Icons.format_list_numbered_rounded,
      '1.',
      '번호가 매겨진 목록',
      '목록',
    ),
    _Opt(
      'todo',
      '할 일 목록',
      Icons.check_box_outlined,
      '[]',
      '할 일을 추적하는 체크리스트',
      '목록',
    ),
    // 특수
    _Opt('code', '코드', Icons.code_rounded, '```', '코드 스니펫 삽입', '특수'),
    _Opt('table', '표', Icons.table_chart_rounded, '', '마크다운 표 삽입', '특수'),
    _Opt(
      'div',
      '구분선',
      Icons.horizontal_rule_rounded,
      '---',
      '섹션을 나누는 수평선',
      '특수',
    ),
    _Opt('image', '이미지', Icons.image_outlined, '', '이미지 파일 삽입', '특수'),
  ];

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 6, vsync: this);
    _saveAc = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _saveAnim = CurvedAnimation(parent: _saveAc, curve: Curves.elasticOut);
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  Future<void> _init() async {
    await ref.read(fileEditorProvider.notifier).loadFileDetail(widget.fileId);
    final st = ref.read(fileEditorProvider);
    if (mounted)
      setState(() {
        _tCtrl.text = st.fileTitle;
        _gCtrl.text = st.fileTags;
        _pCtrl.text = st.filePrompt ?? '';
      });
    if (!kIsWeb) {
      try {
        final f = await FilesDBHelper.getFile(widget.fileId);
        if (f != null && mounted)
          setState(() {
            if (f.title != '제목 없음') _tCtrl.text = f.title;
            _gCtrl.text = f.tags;
            _pCtrl.text = f.prompt ?? st.filePrompt ?? '';
          });
      } catch (_) {}
    }
    if (kIsWeb) {
      _syncT = Timer.periodic(_webSyncInterval, (_) => _syncFromServer());
    }
  }

  // ── 실시간 동기화 ─────────────────────────────────
  Future<void> _syncFromServer() async {
    if (!kIsWeb || !mounted) return;
    if (_savingN.value) return;
    // syncMode: 미저장 summaryBlocks 보존 (30초 동기화로 AI 요약 사라지는 버그 방지)
    await ref
        .read(fileEditorProvider.notifier)
        .loadFileDetail(widget.fileId, syncMode: true);
  }

  @override
  void dispose() {
    _saveT?.cancel();
    _focT?.cancel();
    _sumT?.cancel();
    _focTextT?.cancel();
    _syncT?.cancel();
    _pomT?.cancel();
    _tCtrl.dispose();
    _gCtrl.dispose();
    _pCtrl.dispose();
    _qaCtrl.dispose();
    _tab.dispose();
    _savingN.dispose();
    _saveAc.dispose();
    _selToolbarEntry?.remove();
    _removeSlash();
    super.dispose();
  }

  // ── 저장 ─────────────────────────────────────────
  void _chg({String? ft}) {
    if (ft != null) {
      _focTextT?.cancel();
      _focTextT = Timer(const Duration(milliseconds: 800), () {
        if (mounted)
          // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
          ref.read(fileEditorProvider.notifier).state = ref
              .read(fileEditorProvider)
              .copyWith(focusedText: ft);
      });
    }
    _savingN.value = true;
    _saveT?.cancel();
    _saveT = Timer(_autoSaveDelay, () async {
      await ref
          .read(fileEditorProvider.notifier)
          .saveFile(
            fileId: widget.fileId,
            title: _tCtrl.text,
            tags: _gCtrl.text,
            prompt: _pCtrl.text,
            updateAt: DateTime.now(),
          );
      if (mounted) {
        _savingN.value = false;
        _saveAc.forward(from: 0);
      }
    });
    final editorState = ref.read(fileEditorProvider);
    final mc = editorState.meaningfulCharCount;
    final hasSummary = editorState.summaryBlocks.isNotEmpty;
    if (!hasSummary &&
        !editorState.isSummaryLoading &&
        (mc - _lastSumLen).abs() > 240) {
      _sumT?.cancel();
      _sumT = Timer(_summaryDelay, _doSum);
    }
  }

  void _doSum() {
    if (!ref.read(fileEditorProvider).isSummaryLoading) {
      _lastSumLen = ref.read(fileEditorProvider).meaningfulCharCount;
      ref
          .read(fileEditorProvider.notifier)
          .requestSummary(title: _tCtrl.text, tags: _gCtrl.text);
    }
  }

  Future<void> _suggestTags() async {
    final content = ref.read(fileEditorProvider).blocks
        .map((b) => b.controller.text)
        .join('\n');
    if (content.trim().isEmpty) return;
    final title = _tCtrl.text.trim();
    final existing = _gCtrl.text.trim();
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/api/ai/suggest-tags'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'content': content, 'title': title, 'existing_tags': existing}),
      ).timeout(const Duration(seconds: 10));
      if (!mounted) return;
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final tags = (data['tags'] as List?)?.cast<String>() ?? [];
        if (tags.isEmpty) return;
        // 기존 태그와 합치기
        final current = existing.split(',').map((t) => t.trim()).where((t) => t.isNotEmpty).toList();
        final merged = {...current, ...tags}.join(', ');
        setState(() => _gCtrl.text = merged);
        _chg();
        if (mounted) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(
              content: Text('태그 ${tags.length}개 추천됨'),
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 2),
            ));
        }
      }
    } catch (_) {}
  }

  void _onFocus(String text, {int blockIndex = -1}) {
    _focT?.cancel();
    _focT = Timer(const Duration(milliseconds: 800), () {
      // 마크다운 기호 제거
      final clean = text
          .replaceAll(RegExp(r'\*+'), '')
          .replaceAll(RegExp(r'#+\s?'), '')
          .replaceAll(RegExp(r'~~|__'), '')
          .replaceAll('`', '')
          .trim();
      // ✅ 5자 이상이면 분석 (짧은 블록도 허용)
      if (clean.length >= 5) {
        ref
            .read(fileEditorProvider.notifier)
            .analyzeBlock(text: clean, title: _tCtrl.text, blockIndex: blockIndex);
      }
    });
  }

  // ── 키 핸들러 ─────────────────────────────────────
  KeyEventResult _key(FocusNode n, KeyEvent e, int i) {
    if (e is! KeyDownEvent && e is! KeyRepeatEvent) return KeyEventResult.ignored;
    final meta = HardwareKeyboard.instance.isMetaPressed;
    final ctrl = HardwareKeyboard.instance.isControlPressed;
    final shift = HardwareKeyboard.instance.isShiftPressed;

    // ── 블록 다중 선택 상태 처리 ────────────────────
    if (_selectedBlocks.isNotEmpty) {
      // Backspace / Delete → 선택된 블록 모두 삭제
      if (e.logicalKey == LogicalKeyboardKey.backspace ||
          e.logicalKey == LogicalKeyboardKey.delete) {
        _deleteSelectedBlocks();
        return KeyEventResult.handled;
      }
      // Escape → 선택 해제
      if (e.logicalKey == LogicalKeyboardKey.escape) {
        setState(() => _selectedBlocks.clear());
        return KeyEventResult.handled;
      }
      // 다른 키 → 선택 해제 후 일반 편집 모드 진입
      if (!meta && !ctrl &&
          e.logicalKey != LogicalKeyboardKey.tab &&
          e.logicalKey != LogicalKeyboardKey.arrowUp &&
          e.logicalKey != LogicalKeyboardKey.arrowDown &&
          e.logicalKey != LogicalKeyboardKey.arrowLeft &&
          e.logicalKey != LogicalKeyboardKey.arrowRight) {
        setState(() => _selectedBlocks.clear());
        // 키 이벤트는 그냥 통과시켜 편집 처리
      }
    }

    // Ctrl/Cmd+A: 2단계 선택 (노션 방식)
    if ((meta || ctrl) && e.logicalKey == LogicalKeyboardKey.keyA) {
      final blocks = ref.read(fileEditorProvider).blocks;
      final b = blocks[i];
      final allTextSelected = b.controller.selection ==
          TextSelection(baseOffset: 0, extentOffset: b.controller.text.length);
      if (!allTextSelected || _selectedBlocks.isNotEmpty) {
        // 1단계: 현재 블록 텍스트 전체 선택
        setState(() => _selectedBlocks.clear());
        b.controller.selection = TextSelection(
          baseOffset: 0,
          extentOffset: b.controller.text.length,
        );
      } else {
        // 2단계: 모든 블록 선택
        setState(() {
          _selectedBlocks.clear();
          _selectedBlocks.addAll(List.generate(blocks.length, (idx) => idx));
        });
      }
      return KeyEventResult.handled;
    }

    // Ctrl/Cmd+B: 볼드 토글
    if ((meta || ctrl) && e.logicalKey == LogicalKeyboardKey.keyB) {
      final blocks = ref.read(fileEditorProvider).blocks;
      final bc2 = blocks[i].controller;
      final sel = bc2.selection;
      if (!sel.isCollapsed && sel.isValid) {
        final text = bc2.text;
        final s = sel.start.clamp(0, text.length);
        final end = sel.end.clamp(0, text.length);
        final selected = text.substring(s, end);
        final isBold = selected.startsWith('**') && selected.endsWith('**') && selected.length > 4;
        final newText = isBold ? selected.substring(2, selected.length - 2) : '**$selected**';
        bc2.text = text.substring(0, s) + newText + text.substring(end);
        bc2.selection = TextSelection(baseOffset: s, extentOffset: s + newText.length);
        _chg(ft: bc2.text);
      }
      return KeyEventResult.handled;
    }

    // Ctrl/Cmd+I: 이탤릭 토글
    if ((meta || ctrl) && e.logicalKey == LogicalKeyboardKey.keyI) {
      final blocks = ref.read(fileEditorProvider).blocks;
      final bc2 = blocks[i].controller;
      final sel = bc2.selection;
      if (!sel.isCollapsed && sel.isValid) {
        final text = bc2.text;
        final s = sel.start.clamp(0, text.length);
        final end = sel.end.clamp(0, text.length);
        final selected = text.substring(s, end);
        final isItalic = selected.startsWith('*') && selected.endsWith('*') &&
            !selected.startsWith('**') && selected.length > 2;
        final newText = isItalic ? selected.substring(1, selected.length - 1) : '*$selected*';
        bc2.text = text.substring(0, s) + newText + text.substring(end);
        bc2.selection = TextSelection(baseOffset: s, extentOffset: s + newText.length);
        _chg(ft: bc2.text);
      }
      return KeyEventResult.handled;
    }

    // Ctrl/Cmd+S: 즉시 저장 (브라우저 저장 대화상자 차단)
    if ((meta || ctrl) && !shift && e.logicalKey == LogicalKeyboardKey.keyS) {
      _saveT?.cancel();
      ref.read(fileEditorProvider.notifier).saveFile(
            fileId: widget.fileId,
            title: _tCtrl.text,
            tags: _gCtrl.text,
            prompt: _pCtrl.text,
            updateAt: DateTime.now(),
          );
      _snack('저장되었습니다');
      return KeyEventResult.handled;
    }

    // Ctrl+Shift+S: 취소선 토글
    if ((meta || ctrl) && shift && e.logicalKey == LogicalKeyboardKey.keyS) {
      final bc2 = ref.read(fileEditorProvider).blocks[i].controller;
      final sel = bc2.selection;
      if (!sel.isCollapsed && sel.isValid) {
        final text = bc2.text;
        final s = sel.start.clamp(0, text.length);
        final end = sel.end.clamp(0, text.length);
        final selected = text.substring(s, end);
        final isStrike = selected.startsWith('~~') && selected.endsWith('~~') && selected.length > 4;
        final newText = isStrike ? selected.substring(2, selected.length - 2) : '~~$selected~~';
        bc2.text = text.substring(0, s) + newText + text.substring(end);
        bc2.selection = TextSelection(baseOffset: s, extentOffset: s + newText.length);
        _chg(ft: bc2.text);
      }
      return KeyEventResult.handled;
    }

    // Ctrl+`: 인라인 코드 토글
    if ((meta || ctrl) && e.logicalKey == LogicalKeyboardKey.backquote) {
      final bc2 = ref.read(fileEditorProvider).blocks[i].controller;
      final sel = bc2.selection;
      if (!sel.isCollapsed && sel.isValid) {
        final text = bc2.text;
        final s = sel.start.clamp(0, text.length);
        final end = sel.end.clamp(0, text.length);
        final selected = text.substring(s, end);
        final isCode = selected.startsWith('`') && selected.endsWith('`') &&
            !selected.startsWith('``') && selected.length > 2;
        final newText = isCode ? selected.substring(1, selected.length - 1) : '`$selected`';
        bc2.text = text.substring(0, s) + newText + text.substring(end);
        bc2.selection = TextSelection(baseOffset: s, extentOffset: s + newText.length);
        _chg(ft: bc2.text);
      }
      return KeyEventResult.handled;
    }

    // Ctrl+Alt+1/2/3: 블록 타입 변경
    final alt = HardwareKeyboard.instance.isAltPressed;
    if ((meta || ctrl) && alt) {
      if (e.logicalKey == LogicalKeyboardKey.digit1) {
        ref.read(fileEditorProvider.notifier).setType(i, BlockType.h1);
        _chg(); return KeyEventResult.handled;
      }
      if (e.logicalKey == LogicalKeyboardKey.digit2) {
        ref.read(fileEditorProvider.notifier).setType(i, BlockType.h2);
        _chg(); return KeyEventResult.handled;
      }
      if (e.logicalKey == LogicalKeyboardKey.digit3) {
        ref.read(fileEditorProvider.notifier).setType(i, BlockType.h3);
        _chg(); return KeyEventResult.handled;
      }
      if (e.logicalKey == LogicalKeyboardKey.digit0) {
        ref.read(fileEditorProvider.notifier).setType(i, BlockType.text);
        _chg(); return KeyEventResult.handled;
      }
    }

    // Ctrl/Cmd+D: 블록 복제
    if ((meta || ctrl) && e.logicalKey == LogicalKeyboardKey.keyD) {
      if (e is! KeyRepeatEvent) {
        ref.read(fileEditorProvider.notifier).duplicate(i);
        _chg();
        WidgetsBinding.instance.addPostFrameCallback((_) => _foc(i + 1));
      }
      return KeyEventResult.handled;
    }

    // Ctrl/Cmd+Enter: 아래에 새 블록 추가
    if ((meta || ctrl) && e.logicalKey == LogicalKeyboardKey.enter) {
      if (e is! KeyRepeatEvent) {
        ref.read(fileEditorProvider.notifier).insertAfter(i);
        _chg();
        WidgetsBinding.instance.addPostFrameCallback((_) => _focStart(i + 1));
      }
      return KeyEventResult.handled;
    }

    // Slash 메뉴 네비
    if (_slash != null) {
      if (e.logicalKey == LogicalKeyboardKey.arrowUp) {
        if (_slashIdx > 0) {
          _slashIdx--;
          _slash!.markNeedsBuild();
        }
        return KeyEventResult.handled;
      }
      if (e.logicalKey == LogicalKeyboardKey.arrowDown) {
        if (_slashIdx < _slashOpts.length - 1) {
          _slashIdx++;
          _slash!.markNeedsBuild();
        }
        return KeyEventResult.handled;
      }
      if (e.logicalKey == LogicalKeyboardKey.enter) {
        _applyOpt(i, _slashOpts[_slashIdx]);
        return KeyEventResult.handled;
      }
      if (e.logicalKey == LogicalKeyboardKey.escape) {
        _removeSlash();
        return KeyEventResult.handled;
      }
    }

    final blocks = ref.read(fileEditorProvider).blocks;
    final bc = blocks[i].controller;
    final bt = blocks[i].type;

    // ── Escape: 선택 해제 / 슬래시 닫기 ─────────────
    if (e.logicalKey == LogicalKeyboardKey.escape) {
      if (_selectedBlocks.isNotEmpty) {
        setState(() => _selectedBlocks.clear());
        return KeyEventResult.handled;
      }
      _removeSlash();
      return KeyEventResult.ignored;
    }

    // ── Tab / Shift+Tab ──────────────────────────────
    if (e.logicalKey == LogicalKeyboardKey.tab) {
      if (shift) {
        if (bt == BlockType.bullet || bt == BlockType.checkbox || bt == BlockType.number) {
          // 앞쪽 스페이스 2개 제거 (서브 레벨 감소)
          if (bc.text.startsWith('  ')) {
            final pos = bc.selection.baseOffset.clamp(0, bc.text.length);
            bc.text = bc.text.substring(2);
            bc.selection = TextSelection.collapsed(offset: (pos - 2).clamp(0, bc.text.length));
          } else {
            ref.read(fileEditorProvider.notifier).setType(i, BlockType.text);
          }
        } else {
          ref.read(fileEditorProvider.notifier).dedent(i);
        }
      } else {
        if (bt == BlockType.bullet || bt == BlockType.checkbox || bt == BlockType.number) {
          // 리스트 내에서 Tab → 앞에 스페이스 2개 (서브 리스트 표현)
          final pos = bc.selection.baseOffset.clamp(0, bc.text.length);
          bc.text = '  ${bc.text}';
          bc.selection = TextSelection.collapsed(offset: pos + 2);
        } else if (bt == BlockType.code) {
          // 코드 블록에서 Tab → 스페이스 2개 삽입
          final pos = bc.selection.baseOffset.clamp(0, bc.text.length);
          final text = bc.text;
          bc.text = text.substring(0, pos) + '  ' + text.substring(pos);
          bc.selection = TextSelection.collapsed(offset: pos + 2);
        } else {
          ref.read(fileEditorProvider.notifier).indent(i);
        }
      }
      _chg();
      return KeyEventResult.handled;
    }

    // ── Enter ─────────────────────────────────────────
    if (e.logicalKey == LogicalKeyboardKey.enter && !meta && !ctrl) {
      final text = bc.text;
      final pos = bc.selection.baseOffset.clamp(0, text.length);

      // 코드 블록: Enter → 줄바꿈 (블록 분리 안 함)
      if (bt == BlockType.code) {
        bc.text = '${text.substring(0, pos)}\n${text.substring(pos)}';
        bc.selection = TextSelection.collapsed(offset: pos + 1);
        _chg();
        return KeyEventResult.handled;
      }

      // 빈 리스트 → 탈출 (text로 전환)
      if (text.isEmpty &&
          (bt == BlockType.bullet ||
              bt == BlockType.checkbox ||
              bt == BlockType.number ||
              bt == BlockType.quote)) {
        ref.read(fileEditorProvider.notifier).setType(i, BlockType.text);
        return KeyEventResult.handled;
      }

      // 커서에서 분리
      bc.text = text.substring(0, pos);
      ref.read(fileEditorProvider.notifier).insertBlocks(i + 1, [
        text.substring(pos),
      ]);

      WidgetsBinding.instance.addPostFrameCallback((_) {
        final upd = ref.read(fileEditorProvider).blocks;
        if (i + 1 < upd.length) {
          // ✅ 리스트 타입 유지 (연속 작성)
          if (bt == BlockType.bullet ||
              bt == BlockType.checkbox ||
              bt == BlockType.number ||
              bt == BlockType.quote) {
            ref.read(fileEditorProvider.notifier).setType(i + 1, bt);
            if (bt == BlockType.checkbox) {
              ref.read(fileEditorProvider.notifier).toggleCheck(i + 1, false);
            }
          }
          upd[i + 1].focusNode.requestFocus();
          upd[i + 1].controller.selection = TextSelection.collapsed(offset: 0);
        }
      });
      _chg();
      return KeyEventResult.handled;
    }

    // ── Backspace ─────────────────────────────────────
    if (e.logicalKey == LogicalKeyboardKey.backspace) {
      final sel = bc.selection;
      // ✅ 커서가 맨 앞에 있을 때만 위 블록으로 이동
      if (sel.isCollapsed && sel.baseOffset == 0) {
        if (i > 0) {
          // 빈 블록이면 그냥 삭제 (위로 포커스)
          if (bc.text.isEmpty) {
            ref.read(fileEditorProvider.notifier).removeBlock(i);
            WidgetsBinding.instance.addPostFrameCallback((_) => _foc(i - 1));
            _chg();
            return KeyEventResult.handled;
          }
          // 위 블록과 병합
          ref.read(fileEditorProvider.notifier).mergeWithPrev(i);
          _chg();
          return KeyEventResult.handled;
        }
      }
      // 빈 특수 블록 → text 전환
      if (bc.text.isEmpty &&
          bt != BlockType.text &&
          bt != BlockType.h1 &&
          bt != BlockType.h2 &&
          bt != BlockType.h3) {
        ref.read(fileEditorProvider.notifier).setType(i, BlockType.text);
        return KeyEventResult.handled;
      }
    }

    // ── Delete 키: 앞쪽 삭제 / 다음 블록과 병합 ─────
    if (e.logicalKey == LogicalKeyboardKey.delete) {
      final sel = bc.selection;
      if (sel.isCollapsed && sel.baseOffset == bc.text.length) {
        if (i < blocks.length - 1) {
          final nextText = blocks[i + 1].controller.text;
          final curLen = bc.text.length;
          bc.text = bc.text + nextText;
          bc.selection = TextSelection.collapsed(offset: curLen);
          ref.read(fileEditorProvider.notifier).removeBlock(i + 1);
          _chg();
          return KeyEventResult.handled;
        }
      }
    }

    // ── Home / End 키 ────────────────────────────────
    if (e.logicalKey == LogicalKeyboardKey.home) {
      final text = bc.text;
      final pos = bc.selection.baseOffset.clamp(0, text.length);
      // 현재 줄의 시작으로
      final lineStart = text.lastIndexOf('\n', pos > 0 ? pos - 1 : 0);
      final target = lineStart == -1 ? 0 : lineStart + 1;
      bc.selection = TextSelection.collapsed(offset: target);
      return KeyEventResult.handled;
    }
    if (e.logicalKey == LogicalKeyboardKey.end) {
      final text = bc.text;
      final pos = bc.selection.baseOffset.clamp(0, text.length);
      final lineEnd = text.indexOf('\n', pos);
      final target = lineEnd == -1 ? text.length : lineEnd;
      bc.selection = TextSelection.collapsed(offset: target);
      return KeyEventResult.handled;
    }

    // ── 방향키: 텍스트 경계에서만 블록 이동 ─────────
    if (e.logicalKey == LogicalKeyboardKey.arrowUp && i > 0) {
      final sel = bc.selection;
      if (sel.isCollapsed && sel.baseOffset == 0) {
        _foc(i - 1);
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }
    if (e.logicalKey == LogicalKeyboardKey.arrowDown && i < blocks.length - 1) {
      final sel = bc.selection;
      if (sel.isCollapsed && sel.baseOffset == bc.text.length) {
        _focStart(i + 1);
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }

    return KeyEventResult.ignored;
  }

  // ── 선택된 블록 일괄 삭제 ──────────────────────────
  void _deleteSelectedBlocks() {
    if (_selectedBlocks.isEmpty) return;
    final sorted = _selectedBlocks.toList()..sort((a, b) => b.compareTo(a));
    // 삭제 후 포커스를 줄 인덱스 결정
    final minIdx = (_selectedBlocks.reduce((a, b) => a < b ? a : b) - 1).clamp(0, 9999);
    for (final idx in sorted) {
      ref.read(fileEditorProvider.notifier).removeBlock(idx);
    }
    setState(() => _selectedBlocks.clear());
    _chg();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final upd = ref.read(fileEditorProvider).blocks;
      if (upd.isNotEmpty) {
        final target = minIdx.clamp(0, upd.length - 1);
        upd[target].focusNode.requestFocus();
        upd[target].controller.selection = TextSelection.collapsed(
          offset: upd[target].controller.text.length,
        );
      }
    });
  }

  /// 블록으로 포커스 이동 (커서를 텍스트 끝에)
  void _foc(int i) {
    final b = ref.read(fileEditorProvider).blocks;
    if (i >= 0 && i < b.length) {
      b[i].focusNode.requestFocus();
      final c = b[i].controller;
      c.selection = TextSelection.collapsed(offset: c.text.length);
    }
  }

  /// 블록으로 포커스 이동 (커서를 텍스트 앞에)
  void _focStart(int i) {
    final b = ref.read(fileEditorProvider).blocks;
    if (i >= 0 && i < b.length) {
      b[i].focusNode.requestFocus();
      b[i].controller.selection = const TextSelection.collapsed(offset: 0);
    }
  }

  // ── 텍스트 변경 ────────────────────────────────────
  void _onText(String text, int i) {
    final bt = ref.read(fileEditorProvider).blocks[i].type;
    // 코드/표 블록: 슬래시 메뉴 비활성 + 줄바꿈 허용 (분리 안 함)
    if (bt == BlockType.code || bt == BlockType.table) {
      _removeSlash();
      _chg(ft: text);
      return;
    }
    if (text.contains('\n')) {
      final lines = text.split('\n');
      ref.read(fileEditorProvider).blocks[i].controller.text = lines[0];
      // 빈 줄 제외하지 않고 모두 삽입 (복붙 시 빈 줄도 유지)
      if (lines.length > 1) {
        final remaining = lines.sublist(1);
        ref
            .read(fileEditorProvider.notifier)
            .insertBlocks(i + 1, remaining);
        final lastIdx = i + remaining.length;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final upd = ref.read(fileEditorProvider).blocks;
          if (lastIdx < upd.length) {
            upd[lastIdx].focusNode.requestFocus();
            upd[lastIdx].controller.selection = TextSelection.collapsed(
              offset: upd[lastIdx].controller.text.length,
            );
          }
        });
      }
      _chg(ft: lines[0]);
      return;
    }

    // 마크다운 단축키
    BlockType? _nt;
    String _nc = text;
    if (text.endsWith(' ')) {
      if (text == '# ') {
        _nt = BlockType.h1;
        _nc = '';
      } else if (text == '## ') {
        _nt = BlockType.h2;
        _nc = '';
      } else if (text == '### ') {
        _nt = BlockType.h3;
        _nc = '';
      } else if (text == '- ' || text == '* ') {
        _nt = BlockType.bullet;
        _nc = '';
      } else if (text == '> ') {
        _nt = BlockType.quote;
        _nc = '';
      } else if (text == '1. ') {
        _nt = BlockType.number;
        _nc = '';
      } else if (text == '[] ') {
        _nt = BlockType.checkbox;
        _nc = '';
      }
    }
    // 백틱 3개 → 코드 블록
    if (text.trimRight() == '```') {
      _nt = BlockType.code;
      _nc = '';
    }
    if (_nt != null) {
      final c = ref.read(fileEditorProvider).blocks[i].controller;
      c.text = _nc;
      ref.read(fileEditorProvider.notifier).setType(i, _nt);
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => c.selection = TextSelection.collapsed(offset: _nc.length),
      );
      _chg(ft: _nc);
      return;
    }

    // 슬래시 메뉴
    final si = text.lastIndexOf('/');
    if (si != -1 && si == text.length - 1)
      _showSlash(context, i, '');
    else if (si != -1 && !text.substring(si + 1).contains(' '))
      _showSlash(context, i, text.substring(si + 1));
    else
      _removeSlash();

    _chg(ft: text);
  }

  // ── 슬래시 메뉴 ────────────────────────────────────
  void _showSlash(BuildContext ctx, int i, String q) {
    // 퍼지 검색: 순서 고려 없이 부분 매칭
    _slashOpts = q.isEmpty
        ? _opts
        : _opts
              .where(
                (o) =>
                    o.label.toLowerCase().contains(q.toLowerCase()) ||
                    o.hint.toLowerCase().contains(q.toLowerCase()),
              )
              .toList();
    if (_slashOpts.isEmpty) {
      _removeSlash();
      return;
    }
    // 블록이 바뀌면 인덱스 초기화
    if (_slashBlockIdx != i) _slashIdx = 0;
    _slashBlockIdx = i;
    _slash?.remove();
    _slash = null;
    final gen = ++_slashGen; // 이번 표시 요청의 세대
    final bl = ref.read(fileEditorProvider).blocks;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // 그 사이 메뉴가 닫혔거나(_removeSlash) 다른 요청이 들어오면 삽입 취소
      if (!mounted || gen != _slashGen) return;
      // GlobalKey 기반으로 위치 계산 (더 정확)
      final blkKey = _blockKeys[i];
      double left = 100, top = 200;
      if (blkKey?.currentContext != null) {
        final box = blkKey!.currentContext!.findRenderObject() as RenderBox?;
        if (box != null) {
          final pos = box.localToGlobal(Offset.zero);
          left = (pos.dx + 72).clamp(8.0, MediaQuery.of(ctx).size.width - 300);
          top = (pos.dy + box.size.height + 2).clamp(8.0, MediaQuery.of(ctx).size.height - 420);
        }
      } else {
        final blkCtx = bl[i].focusNode.context;
        if (blkCtx != null) {
          final box = blkCtx.findRenderObject() as RenderBox?;
          if (box != null) {
            final pos = box.localToGlobal(Offset.zero);
            left = (pos.dx + 28).clamp(8.0, MediaQuery.of(ctx).size.width - 300);
            top = (pos.dy + box.size.height + 4).clamp(8.0, MediaQuery.of(ctx).size.height - 420);
          }
        }
      }
      _slash = OverlayEntry(
        builder: (_) => Positioned(
          left: left,
          top: top,
          width: 290,
          child: _SlashMenu(
            opts: _slashOpts,
            sel: _slashIdx,
            isSearching: q.isNotEmpty,
            onSel: (o) => _applyOpt(i, o),
          ),
        ),
      );
      Overlay.of(ctx).insert(_slash!);
    });
  }

  void _applyOpt(int i, _Opt opt) {
    _removeSlash();
    final c = ref.read(fileEditorProvider).blocks[i].controller;
    final si = c.text.lastIndexOf('/');
    if (si != -1) c.text = c.text.substring(0, si);

    switch (opt.id) {
      case 'h1':
        ref.read(fileEditorProvider.notifier).setType(i, BlockType.h1);
        break;
      case 'h2':
        ref.read(fileEditorProvider.notifier).setType(i, BlockType.h2);
        break;
      case 'h3':
        ref.read(fileEditorProvider.notifier).setType(i, BlockType.h3);
        break;
      case 'bullet':
        ref.read(fileEditorProvider.notifier).setType(i, BlockType.bullet);
        break;
      case 'number':
        ref.read(fileEditorProvider.notifier).setType(i, BlockType.number);
        break;
      case 'quote':
        ref.read(fileEditorProvider.notifier).setType(i, BlockType.quote);
        break;
      case 'todo':
        ref.read(fileEditorProvider.notifier).setType(i, BlockType.checkbox);
        break;
      case 'code':
        ref.read(fileEditorProvider.notifier).setType(i, BlockType.code);
        break;
      case 'table':
        c.text = '| 항목 | 설명 | 체크 |\n| --- | --- | --- |\n|  |  |  |';
        ref.read(fileEditorProvider.notifier).setType(i, BlockType.table);
        break;
      case 'div':
        c.text = '────────────────────────────────────';
        ref.read(fileEditorProvider.notifier).setType(i, BlockType.code);
        break;
      case 'image':
        ref.read(fileEditorProvider.notifier).setType(i, BlockType.image);
        break;
      default:
        ref.read(fileEditorProvider.notifier).setType(i, BlockType.text);
    }
    _foc(i);
  }

  void _removeSlash() {
    _slashGen++; // 예약된 지연 삽입 무효화
    _slash?.remove();
    _slash = null;
  }

  // ── 교정 ─────────────────────────────────────────
  Future<void> _proofread(String style) async {
    setState(() {
      _proofreadMode = true;
      _proofreadResult = '';
    });
    await ref.read(fileEditorProvider.notifier).proofreadContent(style: style);
    final result = ref.read(fileEditorProvider).proofreadResult ?? '';
    if (mounted)
      setState(() {
        _proofreadResult = result;
        _proofreadMode = false;
      });
  }

  void _applyProofread() {
    ref.read(fileEditorProvider.notifier).applyProofread();
    setState(() {
      _proofreadMode = false;
      _proofreadResult = '';
    });
    _chg();
  }

  // ── 인라인 선택 툴바 관리 ────────────────────────
  void _onBlockSelChanged(
    String selected,
    TextEditingController ctrl,
    GlobalKey blockKey,
  ) {
    if (selected.isEmpty) {
      _hideSelToolbar();
      return;
    }
    _selText = selected;
    _selCtrl = ctrl;
    _selBlockKey = blockKey;
    _showSelToolbar();
  }

  void _showSelToolbar() {
    _selToolbarEntry?.remove();
    _selToolbarEntry = null;
    if (_selText.isEmpty || _selBlockKey == null || _selCtrl == null) return;

    // ✅ GlobalKey로 절대 위치 계산
    final renderBox =
        _selBlockKey!.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;
    final pos = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;

    // 툴바 높이 48, 너비 최대 380
    final toolbarH = 48.0;
    final toolbarW = 380.0;
    final screenW = MediaQuery.of(context).size.width;

    // 블록 위쪽에 표시, 화면 밖이면 아래에
    double top = pos.dy - toolbarH - 10;
    if (top < 0) top = pos.dy + size.height + 10;

    // 좌우 clamp
    double left = (pos.dx + size.width / 2 - toolbarW / 2).clamp(
      8.0,
      screenW - toolbarW - 8,
    );

    void replace(String newText) {
      _hideSelToolbar();
      final c = _selCtrl!;
      final sel = c.selection;
      if (!sel.isValid || sel.isCollapsed) {
        c.text = newText;
        _chg(ft: newText);
        return;
      }
      final txt = c.text;
      final start = sel.start.clamp(0, txt.length);
      final end = sel.end.clamp(0, txt.length);
      c.text = txt.substring(0, start) + newText + txt.substring(end);
      c.selection = TextSelection.collapsed(offset: start + newText.length);
      _chg(ft: c.text);
    }

    _selToolbarEntry = OverlayEntry(
      builder: (_) => Stack(
        children: [
          // 배경 탭 → 닫기
          Positioned.fill(
            child: GestureDetector(
              onTap: _hideSelToolbar,
              behavior: HitTestBehavior.translucent,
              child: const SizedBox.expand(),
            ),
          ),
          // 툴바 본체 (절대 위치)
          Positioned(
            left: left,
            top: top,
            child: _SelToolbar(
              selectedText: _selText,
              controller: _selCtrl!,
              onDismiss: _hideSelToolbar,
              onReplaceText: replace,
            ),
          ),
        ],
      ),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _selToolbarEntry != null) {
        try {
          Overlay.of(context).insert(_selToolbarEntry!);
        } catch (_) {}
      }
    });
  }

  void _hideSelToolbar() {
    _selToolbarEntry?.remove();
    _selToolbarEntry = null;
    _selText = '';
  }

  void _snack(String msg) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(msg, style: const TextStyle(color: _txt0, fontSize: 13)),
      backgroundColor: _bg3,
      duration: const Duration(milliseconds: 1800),
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  );

  void _applyFmt(String fmt) {
    final blocks = ref.read(fileEditorProvider).blocks;
    if (_focusedIdx < 0 || _focusedIdx >= blocks.length) return;
    final bc = blocks[_focusedIdx].controller;
    final sel = bc.selection;
    if (sel.isCollapsed || !sel.isValid) return;
    final txt = bc.text;
    final s = sel.start.clamp(0, txt.length);
    final end = sel.end.clamp(0, txt.length);
    final selected = txt.substring(s, end);
    String newText;
    switch (fmt) {
      case 'bold':
        final isBold = selected.startsWith('**') && selected.endsWith('**') && selected.length > 4;
        newText = isBold ? selected.substring(2, selected.length - 2) : '**$selected**';
      case 'italic':
        final isItalic = selected.startsWith('*') && selected.endsWith('*') &&
            !selected.startsWith('**') && selected.length > 2;
        newText = isItalic ? selected.substring(1, selected.length - 1) : '*$selected*';
      case 'strike':
        final isStrike = selected.startsWith('~~') && selected.endsWith('~~') && selected.length > 4;
        newText = isStrike ? selected.substring(2, selected.length - 2) : '~~$selected~~';
      case 'code':
        final isCode = selected.startsWith('`') && selected.endsWith('`') &&
            !selected.startsWith('``') && selected.length > 2;
        newText = isCode ? selected.substring(1, selected.length - 1) : '`$selected`';
      default:
        return;
    }
    bc.text = txt.substring(0, s) + newText + txt.substring(end);
    bc.selection = TextSelection(baseOffset: s, extentOffset: s + newText.length);
    _chg(ft: bc.text);
  }

  /// 드래그 박스와 겹치는 블록들을 자동으로 선택합니다.
  void _updateSelectedBlocksFromDrag() {
    if (_dragStart == null || _dragCurrent == null) return;

    // 드래그 좌표는 드래그 레이어 로컬 기준 → 블록과 비교하려면 전역으로 변환
    final layerBox =
        _dragLayerKey.currentContext?.findRenderObject() as RenderBox?;
    final origin = layerBox?.localToGlobal(Offset.zero) ?? Offset.zero;
    final gStart = _dragStart! + origin;
    final gCurrent = _dragCurrent! + origin;

    final left = math.min(gStart.dx, gCurrent.dx);
    final top = math.min(gStart.dy, gCurrent.dy);
    final right = math.max(gStart.dx, gCurrent.dx);
    final bottom = math.max(gStart.dy, gCurrent.dy);
    final dragRect = Rect.fromLTRB(left, top, right, bottom);

    final blocks = ref.read(fileEditorProvider.select((s) => s.blocks));
    _selectedBlocks.clear();

    // 각 블록의 위치를 확인하고 드래그 박스와 교집합 확인
    for (int i = 0; i < blocks.length; i++) {
      final key = _blockKeys[i];
      if (key?.currentContext == null) continue;

      try {
        final renderBox = key!.currentContext!.findRenderObject() as RenderBox?;
        if (renderBox == null) continue;

        // 블록의 전역 위치
        final offset = renderBox.localToGlobal(Offset.zero);
        final blockRect = Rect.fromLTWH(
          offset.dx,
          offset.dy,
          renderBox.size.width,
          renderBox.size.height,
        );

        // 드래그 박스와 블록이 겹치는지 확인
        if (dragRect.overlaps(blockRect)) {
          _selectedBlocks.add(i);
        }
      } catch (e) {
        // 렌더 박스를 얻을 수 없으면 스킵
        continue;
      }
    }
  }

  void _showMobilePanel(BuildContext context, FileEditorState st) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.65,
        minChildSize: 0.35,
        maxChildSize: 0.95,
        snap: true,
        snapSizes: const [0.35, 0.65, 0.95],
        builder: (_, scrollCtrl) => Container(
          decoration: BoxDecoration(
            color: _bg2,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(color: _bdr.withValues(alpha: 0.9)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.22),
                blurRadius: 24,
                offset: const Offset(0, -8),
              ),
            ],
          ),
          child: Column(
            children: [
              // 핸들바 + 드래그 영역
              GestureDetector(
                onTap: () {},
                child: Container(
                  padding: const EdgeInsets.only(top: 12, bottom: 8),
                  child: Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: _bdr2,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ),
              ),
              // 탭 바
              Container(
                height: 46,
                margin: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: _bg3.withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _bdr.withValues(alpha: 0.9)),
                ),
                child: _MobileTabs(ctrl: _tab),
              ),
              const SizedBox(height: 8),
              // 패널 본체
              Expanded(
                child: Consumer(
                  builder: (_, r, __) =>
                      _buildMobilePanel(r.watch(fileEditorProvider)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 모바일용 패널 (BackdropFilter 없이 가볍게)
  Widget _buildMobilePanel(FileEditorState st) {
    return TabBarView(
      controller: _tab,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        _SumPanel(
          st: st,
          ref: ref,
          tCtrl: _tCtrl,
          gCtrl: _gCtrl,
          snack: _snack,
          onChanged: _chg,
        ),
        _AnaPanel(st: st),
        _MemoPanel(st: st, ref: ref, tCtrl: _tCtrl),
        _QuizPanel(
          st: st,
          ref: ref,
          fileId: widget.fileId,
          projectId: widget.projectId,
        ),
        _AskPanel(
          st: st,
          ctrl: _qaCtrl,
          onAsk: (q) =>
              ref.read(fileEditorProvider.notifier).askAI(q, widget.projectId),
        ),
        _NotePanel(st: st, ref: ref, onChanged: _chg),
      ],
    );
  }

  // ── 뽀모도로 ─────────────────────────────────────
  void _pomToggle() {
    if (_pomRunning) {
      _pomT?.cancel();
      setState(() => _pomRunning = false);
    } else {
      setState(() => _pomRunning = true);
      _pomT = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        setState(() {
          if (_pomSecs > 0) {
            _pomSecs--;
          } else {
            _pomT?.cancel();
            _pomRunning = false;
            _pomIsWork = !_pomIsWork;
            _pomSecs = _pomIsWork ? _pomWork : _pomRest;
            _snack(
              _pomIsWork ? '🔔 휴식 종료! 집중 모드를 시작합니다.' : '🔔 집중 완료! 5분 휴식하세요.',
            );
          }
        });
      });
    }
  }

  void _pomReset() {
    _pomT?.cancel();
    setState(() {
      _pomRunning = false;
      _pomIsWork = true;
      _pomSecs = _pomWork;
    });
  }

  String get _pomLabel {
    final m = (_pomSecs ~/ 60).toString().padLeft(2, '0');
    final s = (_pomSecs % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Color get _pomColor {
    if (!_pomIsWork) return _blu;
    if (_pomSecs < 5 * 60) return _red;
    if (_pomSecs < 10 * 60) return _yel;
    return _acc;
  }

  // ══════════════════ BUILD ══════════════════════════
  @override
  Widget build(BuildContext context) {
    final charCount = ref.watch(fileEditorProvider.select((s) => s.charCount));
    final savedAt = ref.watch(fileEditorProvider.select((s) => s.lastSavedAt));
    final projects = ref.watch(projectProvider);
    final panelState = ref.watch(
      fileEditorProvider.select(
        (s) => (
          isSummaryLoading: s.isSummaryLoading,
          summaryBlocks: s.summaryBlocks,
          summaryProgress: s.summaryProgress,
          currentAnalysis: s.currentAnalysis,
          isAnalysisLoading: s.isAnalysisLoading,
          currentMemo: s.currentMemo,
          isMemoLoading: s.isMemoLoading,
          quizData: s.quizData,
          quizAnswers: s.quizAnswers,
          isQuizLoading: s.isQuizLoading,
          qaAnswer: s.qaAnswer,
          isQALoading: s.isQALoading,
          graphData: s.graphData,
          isGraphLoading: s.isGraphLoading,
          proofreadResult: s.proofreadResult,
          isProofreadLoading: s.isProofreadLoading,
          analyzingBlockIndex: s.analyzingBlockIndex,
        ),
      ),
    );
    final projectName = projects
        .where((project) => project.id == widget.projectId)
        .map((project) => project.name)
        .cast<String?>()
        .firstOrNull;
    final fileTitle = _tCtrl.text.trim().isEmpty ? '제목 없음' : _tCtrl.text.trim();

    final isMobile = MediaQuery.of(context).size.width < 700;
    return Scaffold(
      backgroundColor: _bg0,
      resizeToAvoidBottomInset: true,
      // 데스크톱/태블릿에서만 포모도로 FAB 표시 (모바일은 하단바에 통합)
      floatingActionButton: isMobile
          ? null
          : _PomFAB(
              label: _pomLabel,
              color: _pomColor,
              running: _pomRunning,
              onTap: _pomToggle,
              onLongPress: _pomReset,
            ),
      floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
      body: DropTarget(
        onDragDone: (detail) {
          final blocksLen = ref.read(fileEditorProvider).blocks.length;
          final newBlocks = <String>[];
          final types = <BlockType>[];
          for (final xfile in detail.files) {
            final path = xfile.path;
            final lower = path.toLowerCase();
            final isPdf = lower.endsWith('.pdf');
            final isImg = lower.endsWith('.png') || lower.endsWith('.jpg') || lower.endsWith('.jpeg') || lower.endsWith('.gif') || lower.endsWith('.webp');
            if (isPdf) {
              newBlocks.add(path);
              types.add(BlockType.pdf);
            } else if (isImg) {
              newBlocks.add(path);
              types.add(BlockType.image);
            }
          }
          if (newBlocks.isNotEmpty) {
            for (int i = 0; i < newBlocks.length; i++) {
              ref.read(fileEditorProvider.notifier).insertAfter(
                blocksLen - 1 + i,
                type: types[i],
                content: newBlocks[i],
              );
            }
          }
        },
        child: SafeArea(
          bottom: false, // 하단은 _MobileBottomBar의 SafeArea가 처리
          child: Stack(
            children: [
              const RepaintBoundary(child: _AuroraBG()),
              Column(
              children: [
                ValueListenableBuilder<bool>(
                  valueListenable: _savingN,
                  builder: (_, saving, __) => _AppBar(
                    saving: saving,
                    savedAt: savedAt,
                    saveAnim: _saveAnim,
                    charCount: charCount,
                    title: fileTitle,
                    subtitle: projectName ?? '학습 노트',
                    view: _view,
                    onBack: () => Navigator.pop(context),
                    onCopy: () {
                      Clipboard.setData(
                        ClipboardData(
                          text: ref
                              .read(fileEditorProvider)
                              .blocks
                              .map((b) => b.controller.text)
                              .join('\n'),
                        ),
                      );
                      _snack('복사됨');
                    },
                    onMdCopy: () async {
                      await ref
                          .read(fileEditorProvider.notifier)
                          .copyMarkdown(_tCtrl.text, _gCtrl.text);
                      _snack('Markdown 복사됨');
                    },
                    onView: () {
                      _removeSlash();
                      setState(() => _view = _view == 0 ? 1 : 0);
                    },
                    onMindmap: () {
                      _removeSlash();
                      setState(() => _view = _view == 2 ? 0 : 2);
                      if (_view == 2) {
                        ref
                            .read(fileEditorProvider.notifier)
                            .requestGraph()
                            .then((_) {
                              if (mounted) _chg();
                            });
                      }
                    },
                    onProofread: () => _showProofreadMenu(),
                    onPdfExport: () async {
                      final blocks = ref.read(fileEditorProvider).blocks;
                      final blockData = blocks
                          .map((b) => {
                                'type': b.type.name,
                                'content': b.controller.text,
                              })
                          .toList();
                      final title = _tCtrl.text.trim().isEmpty
                          ? '노트'
                          : _tCtrl.text.trim();
                      await exportNotesAsPdf(
                        blockData,
                        title: title,
                        filename: '${title}_노트.pdf',
                      );
                    },
                  ),
                ),
                // 상단 포맷 툴바 제거 — 슬래시(/) 메뉴·단축키·선택 툴바로 대체
                // 블록 선택 시 플로팅 선택 바 (노션 스타일)
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  transitionBuilder: (child, anim) => SizeTransition(
                    sizeFactor: CurvedAnimation(parent: anim, curve: Curves.easeOutCubic),
                    child: FadeTransition(opacity: anim, child: child),
                  ),
                  child: _selectedBlocks.isNotEmpty
                      ? _SelectionBar(
                          key: const ValueKey('sel-bar'),
                          count: _selectedBlocks.length,
                          onDelete: _deleteSelectedBlocks,
                          onClear: () => setState(() => _selectedBlocks.clear()),
                          onCopy: () {
                            final blocks = ref.read(fileEditorProvider).blocks;
                            final sorted = _selectedBlocks.toList()..sort();
                            final text = sorted
                                .where((idx) => idx < blocks.length)
                                .map((idx) => blocks[idx].controller.text)
                                .join('\n');
                            Clipboard.setData(ClipboardData(text: text));
                            _snack('${_selectedBlocks.length}개 블록 복사됨');
                            setState(() => _selectedBlocks.clear());
                          },
                        )
                      : const SizedBox.shrink(key: ValueKey('no-sel')),
                ),
                // 뽀모도로 타이머
                if (_pomRunning || _pomSecs != _pomWork)
                  _PomodoroBar(
                    label: _pomLabel,
                    color: _pomColor,
                    running: _pomRunning,
                    isWork: _pomIsWork,
                    onToggle: _pomToggle,
                    onReset: _pomReset,
                  ),
                // 교정 결과 배너
                if (_proofreadResult.isNotEmpty)
                  _ProofreadBanner(
                    result: _proofreadResult,
                    onApply: _applyProofread,
                    onDismiss: () => setState(() {
                      _proofreadResult = '';
                    }),
                  ),
                Expanded(
                  child: _view == 2
                      ? Consumer(
                          builder: (_, r, __) => _MindmapView(
                            st: r.watch(fileEditorProvider),
                            ref: r,
                            onChanged: _chg,
                          ),
                        )
                      : _view == 1
                      ? _buildEditor()
                      : MediaQuery.of(context).size.width < 700
                      ? _MobileEditorView(
                          editor: _buildEditor(),
                          pomLabel: _pomLabel,
                          pomColor: _pomColor,
                          pomRunning: _pomRunning,
                          onPomTap: _pomToggle,
                          onPomReset: _pomReset,
                          onAiTap: () {
                            final st = ref.read(fileEditorProvider);
                            _showMobilePanel(context, st);
                          },
                        )
                      : _Split(
                          left: RepaintBoundary(child: _buildEditor()),
                          right: RepaintBoundary(
                            child: _buildPanel(
                              FileEditorState(
                                blocks: const [],
                                isSummaryLoading: panelState.isSummaryLoading,
                                summaryBlocks: panelState.summaryBlocks,
                                summaryProgress: panelState.summaryProgress,
                                currentAnalysis: panelState.currentAnalysis,
                                isAnalysisLoading: panelState.isAnalysisLoading,
                                currentMemo: panelState.currentMemo,
                                isMemoLoading: panelState.isMemoLoading,
                                quizData: panelState.quizData,
                                quizAnswers: panelState.quizAnswers,
                                isQuizLoading: panelState.isQuizLoading,
                                qaAnswer: panelState.qaAnswer,
                                isQALoading: panelState.isQALoading,
                                graphData: panelState.graphData,
                                isGraphLoading: panelState.isGraphLoading,
                                proofreadResult: panelState.proofreadResult,
                                isProofreadLoading:
                                    panelState.isProofreadLoading,
                                analyzingBlockIndex:
                                    panelState.analyzingBlockIndex,
                              ),
                            ),
                          ),
                        ),
                ),
              ],
            ),
          ],
        ), // Stack 닫기
      ), // SafeArea 닫기
      ), // DropTarget 닫기
    );
  }

  // ── 교정 메뉴 ────────────────────────────────────
  void _showProofreadMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: _bg3,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _accD,
                    borderRadius: BorderRadius.circular(9),
                    border: Border.all(color: _acc.withValues(alpha: 0.2)),
                  ),
                  child: const Icon(
                    Icons.auto_fix_high_rounded,
                    size: 15,
                    color: _acc,
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '글 교정',
                      style: GoogleFonts.inter(
                        color: _txt0,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      'AI가 맞춤법·문법·표현을 수정합니다.',
                      style: GoogleFonts.inter(color: _txt2, fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                _StyleBtn('학술적', Icons.school_rounded, () {
                  Navigator.pop(context);
                  _proofread('academic');
                }),
                const SizedBox(width: 10),
                _StyleBtn('친근한', Icons.chat_rounded, () {
                  Navigator.pop(context);
                  _proofread('casual');
                }),
                const SizedBox(width: 10),
                _StyleBtn('공식적', Icons.business_rounded, () {
                  Navigator.pop(context);
                  _proofread('formal');
                }),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  // ── 에디터 ───────────────────────────────────────
  Widget _buildEditor() {
    final blocks = ref.watch(fileEditorProvider.select((s) => s.blocks));
    final analyzingIdx = ref.watch(
      fileEditorProvider.select((s) => s.analyzingBlockIndex),
    );
    final editorMeta = ref.watch(
      fileEditorProvider.select(
        (s) => (
          icon: s.icon ?? '',
          blockCount: s.blocks.length,
          charCount: s.charCount,
          wordCount: s.wordCount,
        ),
      ),
    );
    final width = MediaQuery.of(context).size.width;
    final sidePadding = width < 600
        ? 16.0
        : width < 1024
        ? 48.0
        : 72.0;
    final maxWidth = _view == 1 ? 940.0 : 860.0;
    final isMobile = width < 700;

    return Stack(
      children: [
        CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
        SliverToBoxAdapter(
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  sidePadding,
                  isMobile ? 24 : 52,
                  sidePadding,
                  0,
                ),
                child: _DocumentHero(
                  icon: editorMeta.icon,
                  titleController: _tCtrl,
                  tagsController: _gCtrl,
                  promptController: _pCtrl,
                  blockCount: editorMeta.blockCount,
                  charCount: editorMeta.charCount,
                  wordCount: editorMeta.wordCount,
                  onIconChange: (e) {
                    ref.read(fileEditorProvider.notifier).setIcon(e);
                    _chg();
                  },
                  onTitleChange: () => _chg(),
                  onTagsChange: (_) => _chg(),
                  onPromptChange: (v) {
                    ref.read(fileEditorProvider.notifier).setPrompt(v);
                    _chg();
                  },
                  onInsertTemplate: () {
                    if (blocks.isEmpty) return;
                    if (blocks.first.controller.text.trim().isEmpty) {
                      blocks.first.controller.text = '핵심 개념';
                      ref
                          .read(fileEditorProvider.notifier)
                          .setType(0, BlockType.h2);
                      ref
                          .read(fileEditorProvider.notifier)
                          .insertAfter(
                            0,
                            type: BlockType.bullet,
                            content: '개념 정의',
                          );
                      ref
                          .read(fileEditorProvider.notifier)
                          .insertAfter(
                            1,
                            type: BlockType.bullet,
                            content: '중요 예시',
                          );
                      ref
                          .read(fileEditorProvider.notifier)
                          .insertAfter(
                            2,
                            type: BlockType.checkbox,
                            content: '복습할 포인트',
                          );
                      _chg();
                    }
                  },
                  onFocusMode: () {
                    _removeSlash();
                    setState(() => _view = _view == 1 ? 0 : 1);
                  },
                  onGenerateSummary: _doSum,
                  onSuggestTags: _suggestTags,
                ),
              ),
            ),
          ),
        ),
        SliverPadding(
          padding: EdgeInsets.fromLTRB(
            sidePadding,
            0,
            sidePadding,
            isMobile ? 120 : 280,
          ),
          sliver: SliverReorderableList(
            itemCount: blocks.length,
            onReorder: (o, n) {
              ref.read(fileEditorProvider.notifier).reorder(o, n);
              _chg();
            },
            proxyDecorator: (child, index, animation) {
              return AnimatedBuilder(
                animation: animation,
                builder: (context, _) {
                  final eased = Curves.easeOutCubic.transform(animation.value);
                  return Material(
                    type: MaterialType.transparency,
                    child: Transform.scale(
                      scale: 1.0 - (0.015 * (1 - eased)),
                      child: Opacity(
                        opacity: 0.96,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.22),
                                blurRadius: 28,
                                offset: const Offset(0, 14),
                              ),
                            ],
                          ),
                          child: child,
                        ),
                      ),
                    ),
                  );
                },
              );
            },
            itemBuilder: (ctx, i) => Align(
              key: ValueKey(blocks[i].id),
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxWidth),
                child: _NBlock(
                  idx: i,
                  block: blocks[i],
                  prevType: i > 0 ? blocks[i - 1].type : null,
                  isSelected: _selectedBlocks.contains(i),
                  isAnalyzing: analyzingIdx == i,
                  listNumber: blocks[i].type == BlockType.number
                      ? () {
                          int n = 1;
                          for (int j = i - 1; j >= 0; j--) {
                            if (blocks[j].type == BlockType.number) {
                              n++;
                            } else {
                              break;
                            }
                          }
                          return n;
                        }()
                      : 0,
                  onKey: _key,
                  onText: _onText,
                  onDel: () {
                    ref.read(fileEditorProvider.notifier).removeBlock(i);
                    _chg();
                  },
                  onDup: () {
                    ref.read(fileEditorProvider.notifier).duplicate(i);
                    _chg();
                  },
                  onType: (t) {
                    ref.read(fileEditorProvider.notifier).setType(i, t);
                    _chg();
                  },
                  onCheck: (v) {
                    ref.read(fileEditorProvider.notifier).toggleCheck(i, v);
                    _chg();
                  },
                  onFocus: () {
                    // 텍스트 편집 모드 진입 → 블록 다중 선택 해제
                    if (_selectedBlocks.isNotEmpty || _focusedIdx != i) {
                      setState(() { _selectedBlocks.clear(); _focusedIdx = i; });
                    }
                    _chg(ft: blocks[i].controller.text);
                    _onFocus(blocks[i].controller.text, blockIndex: i);
                  },
                  onBlur: _removeSlash,
                  onSelect: () => setState(() {
                    if (_selectedBlocks.contains(i)) {
                      _selectedBlocks.remove(i);
                    } else {
                      _selectedBlocks.add(i);
                    }
                  }),
                  onAddBelow: () {
                    ref.read(fileEditorProvider.notifier).insertAfter(i);
                    _chg();
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      _foc(i + 1);
                    });
                  },
                  onSelChanged: _onBlockSelChanged,
                  blockKey: _blockKeys.putIfAbsent(i, () => GlobalKey()),
                ),
              ),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: sidePadding),
                child: _EditorAddBlock(
                  onTap: () {
                    ref
                        .read(fileEditorProvider.notifier)
                        .insertAfter(blocks.length - 1);
                    _chg();
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      _foc(blocks.length);
                    });
                  },
                ),
              ),
            ),
          ),
        ),
      ],
        ),
        Positioned.fill(
          child: Listener(
            key: _dragLayerKey,
            behavior: HitTestBehavior.translucent,
            onPointerDown: (event) {
              setState(() {
                _dragStart = event.localPosition;
                _dragCurrent = event.localPosition;
                _isDragging = false;
              });
            },
            onPointerMove: (event) {
              if (_dragStart == null) return;
              final moved = (event.localPosition - _dragStart!).distance;
              if (moved < 8 && !_isDragging) return;
              setState(() {
                _isDragging = true;
                _dragCurrent = event.localPosition;
                _updateSelectedBlocksFromDrag();
              });
            },
            onPointerUp: (event) {
              if (_dragStart == null) return;
              setState(() {
                _isDragging = false;
                _dragStart = null;
                _dragCurrent = null;
              });
            },
            child: IgnorePointer(
              child: _isDragging && _dragStart != null && _dragCurrent != null
                  ? CustomPaint(
                      painter: _DragSelectionPainter(
                        startPos: _dragStart!,
                        endPos: _dragCurrent!,
                      ),
                    )
                  : const SizedBox.expand(),
            ),
          ),
        ),
      ],
    );
  }

  // ── AI 패널 ─────────────────────────────────────
  Widget _buildPanel(FileEditorState st) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 12, 12, 12),
      child: Container(
        decoration: BoxDecoration(
          color: _bg2.withValues(alpha: 0.94),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: _bdr.withValues(alpha: 0.9)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 24,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              height: 58,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              decoration: BoxDecoration(
                color: _bg3.withValues(alpha: 0.72),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(22),
                ),
                border: Border(
                  bottom: BorderSide(color: _bdr.withValues(alpha: 0.6)),
                ),
              ),
              child: _Tabs(ctrl: _tab),
            ),
            Expanded(
              child: TabBarView(
                controller: _tab,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _SumPanel(
                    st: st,
                    ref: ref,
                    tCtrl: _tCtrl,
                    gCtrl: _gCtrl,
                    snack: _snack,
                    onChanged: _chg,
                  ),
                  _AnaPanel(st: st),
                  _MemoPanel(st: st, ref: ref, tCtrl: _tCtrl),
                  _QuizPanel(
                    st: st,
                    ref: ref,
                    fileId: widget.fileId,
                    projectId: widget.projectId,
                  ),
                  _AskPanel(
                    st: st,
                    ctrl: _qaCtrl,
                    onAsk: (q) => ref
                        .read(fileEditorProvider.notifier)
                        .askAI(q, widget.projectId),
                  ),
                  _NotePanel(st: st, ref: ref, onChanged: _chg),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════ AURORA BG ═══════════════════════
class _AuroraBG extends StatelessWidget {
  const _AuroraBG();
  @override
  Widget build(BuildContext context) =>
      const SizedBox.expand(child: CustomPaint(painter: _AP(0.42)));
}

class _AP extends CustomPainter {
  final double t;
  const _AP(this.t);
  @override
  void paint(Canvas c, Size s) {
    void b(double cx, double cy, double r, Color col, double a) => c.drawCircle(
      Offset(cx * s.width, cy * s.height),
      r,
      Paint()
        ..color = col.withValues(alpha: a)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 120),
    );
    b(0.15 + t * 0.08, 0.2 + math.sin(t * math.pi) * 0.05, 260, _blu, 0.04);
    b(0.85 - t * 0.06, 0.15 + math.cos(t * math.pi) * 0.04, 200, _acc, 0.03);
    b(0.5 + math.sin(t * math.pi) * 0.1, 0.9, 300, _pur, 0.025);
    b(0.9, 0.7 + t * 0.05, 180, const Color(0xFF4ADE80), 0.02);
  }

  @override
  bool shouldRepaint(_AP o) => (o.t - t).abs() > 0.005;
}

// ══════════════════ APP BAR ═════════════════════════
class _AppBar extends StatelessWidget {
  final bool saving;
  final DateTime? savedAt;
  final Animation<double> saveAnim;
  final int charCount, view;
  final String title;
  final String subtitle;
  final VoidCallback onBack, onCopy, onMdCopy, onView, onMindmap, onProofread, onPdfExport;
  const _AppBar({
    required this.saving,
    this.savedAt,
    required this.saveAnim,
    required this.charCount,
    required this.title,
    required this.subtitle,
    required this.view,
    required this.onBack,
    required this.onCopy,
    required this.onMdCopy,
    required this.onView,
    required this.onMindmap,
    required this.onProofread,
    required this.onPdfExport,
  });

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
      child: Container(
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: _bg2.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _bdr.withValues(alpha: 0.9)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            _CBtn(Icons.arrow_back_rounded, onBack),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      color: _txt0,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.2,
                    ),
                  ),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      color: _txt2,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            _SaveChip(saving: saving, savedAt: savedAt, anim: saveAnim),
            const SizedBox(width: 12),
            // 글자 수
            if (!isMobile)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF161622),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _bdr.withValues(alpha: 0.6)),
                  ),
                  child: Text(
                    '$charCount자',
                    style: GoogleFonts.inter(
                      color: _txt2,
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            // 모바일: 더보기 메뉴
            if (isMobile)
              _MobileMoreBtn(
                view: view,
                onProofread: onProofread,
                onCopy: onCopy,
                onMdCopy: onMdCopy,
                onView: onView,
                onMindmap: onMindmap,
                onPdfExport: onPdfExport,
                charCount: charCount,
              )
            else ...[
              _TBtn(Icons.spellcheck_rounded, '글 교정', onProofread),
              _TBtn(Icons.copy_rounded, '복사', onCopy),
              _TBtn(Icons.download_outlined, 'MD', onMdCopy),
              _TBtn(Icons.picture_as_pdf_rounded, 'PDF', onPdfExport),
              _TBtn(
                view == 0
                    ? Icons.crop_square_rounded
                    : Icons.view_column_rounded,
                view == 0 ? '전체' : '분할',
                onView,
              ),
              _TBtn(Icons.account_tree_outlined, '마인드맵', onMindmap),
            ],
            const SizedBox(width: 2),
          ],
        ),
      ),
    );
  }
}

class _CBtn extends StatefulWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _CBtn(this.icon, this.onTap);
  @override
  State<_CBtn> createState() => _CBtnState();
}

class _CBtnState extends State<_CBtn> {
  bool _h = false;
  @override
  Widget build(BuildContext context) => MouseRegion(
    onEnter: (_) => setState(() => _h = true),
    onExit: (_) => setState(() => _h = false),
    child: GestureDetector(
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: _h ? _bg4 : Colors.transparent,
          shape: BoxShape.circle,
          border: Border.all(color: _h ? _bdr2 : Colors.transparent),
        ),
        child: Icon(widget.icon, size: 17, color: _h ? _txt0 : _txt2),
      ),
    ),
  );
}

class _SaveChip extends StatelessWidget {
  final bool saving;
  final DateTime? savedAt;
  final Animation<double> anim;
  const _SaveChip({required this.saving, this.savedAt, required this.anim});
  @override
  Widget build(BuildContext context) {
    if (saving)
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 10,
            height: 10,
            child: CircularProgressIndicator(
              strokeWidth: 1.2,
              color: _txt2.withValues(alpha: 0.4),
            ),
          ),
          const SizedBox(width: 6),
          Text('저장 중', style: GoogleFonts.inter(color: _txt2, fontSize: 11)),
        ],
      );
    if (savedAt != null)
      return FadeTransition(
        opacity: anim,
        child: ScaleTransition(
          scale: anim,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.check_circle_rounded,
                size: 11,
                color: _grn.withValues(alpha: 0.8),
              ),
              const SizedBox(width: 5),
              Text('저장됨', style: GoogleFonts.inter(color: _txt2, fontSize: 11)),
            ],
          ),
        ),
      );
    return const SizedBox.shrink();
  }
}

class _TBtn extends StatelessWidget {
  final IconData icon;
  final String tip;
  final VoidCallback onTap;
  const _TBtn(this.icon, this.tip, this.onTap);
  @override
  Widget build(BuildContext context) => Tooltip(
    message: tip,
    child: IconButton(
      icon: Icon(icon, size: 16),
      onPressed: onTap,
      color: _txt2,
      hoverColor: _bg4,
      splashRadius: 16,
      padding: const EdgeInsets.all(6),
      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
    ),
  );
}

// ══════════════════ 모바일 더보기 버튼 ══════════════════
class _MobileMoreBtn extends StatelessWidget {
  final int view, charCount;
  final VoidCallback onProofread, onCopy, onMdCopy, onView, onMindmap, onPdfExport;
  const _MobileMoreBtn({
    required this.view,
    required this.charCount,
    required this.onProofread,
    required this.onCopy,
    required this.onMdCopy,
    required this.onView,
    required this.onMindmap,
    required this.onPdfExport,
  });

  @override
  Widget build(BuildContext context) => PopupMenuButton<int>(
    icon: const Icon(Icons.more_horiz_rounded, size: 18, color: _txt2),
    color: _bg3,
    elevation: 8,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(14),
      side: BorderSide(color: _bdr2),
    ),
    padding: EdgeInsets.zero,
    constraints: const BoxConstraints(minWidth: 180),
    itemBuilder: (_) => [
      PopupMenuItem<int>(
        enabled: false,
        height: 32,
        child: Text(
          '$charCount자',
          style: GoogleFonts.inter(color: _txt2, fontSize: 11),
        ),
      ),
      const PopupMenuDivider(height: 1),
      _mi(context, 0, Icons.spellcheck_rounded, '글 교정'),
      _mi(context, 1, Icons.copy_rounded, '복사'),
      _mi(context, 2, Icons.download_outlined, 'MD 복사'),
      _mi(context, 5, Icons.picture_as_pdf_rounded, 'PDF 내보내기'),
      _mi(
        context,
        3,
        view == 0 ? Icons.crop_square_rounded : Icons.view_column_rounded,
        view == 0 ? '전체 화면' : '분할 화면',
      ),
      _mi(context, 4, Icons.account_tree_outlined, '마인드맵'),
    ],
    onSelected: (v) {
      switch (v) {
        case 0:
          onProofread();
          break;
        case 1:
          onCopy();
          break;
        case 2:
          onMdCopy();
          break;
        case 3:
          onView();
          break;
        case 4:
          onMindmap();
          break;
        case 5:
          onPdfExport();
          break;
      }
    },
  );

  PopupMenuItem<int> _mi(BuildContext ctx, int v, IconData ic, String label) =>
      PopupMenuItem<int>(
        value: v,
        height: 44,
        child: Row(
          children: [
            Icon(ic, size: 15, color: _txt1),
            const SizedBox(width: 12),
            Text(
              label,
              style: GoogleFonts.inter(
                color: _txt0,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
}

// ══════════════════ 교정 배너 ════════════════════════
// ══════════════════ 선택 바 (노션 스타일) ════════════
class _SelectionBar extends StatelessWidget {
  final int count;
  final VoidCallback onDelete;
  final VoidCallback onClear;
  final VoidCallback onCopy;
  const _SelectionBar({
    super.key,
    required this.count,
    required this.onDelete,
    required this.onClear,
    required this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
        decoration: BoxDecoration(
          color: _acc.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _acc.withValues(alpha: 0.28)),
        ),
        child: Row(
          children: [
            // 선택 카운트
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: _acc.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '$count개 선택됨',
                style: GoogleFonts.inter(
                  color: _acc,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              'Backspace로 삭제 · Esc로 해제',
              style: GoogleFonts.inter(
                color: _txt2,
                fontSize: 11,
              ),
            ),
            const Spacer(),
            // 복사 버튼
            _SelBarBtn(
              icon: Icons.copy_rounded,
              label: '복사',
              onTap: onCopy,
            ),
            const SizedBox(width: 6),
            // 삭제 버튼
            _SelBarBtn(
              icon: Icons.delete_outline_rounded,
              label: '삭제',
              color: _red,
              onTap: onDelete,
            ),
            const SizedBox(width: 6),
            // 해제 버튼
            GestureDetector(
              onTap: onClear,
              child: Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(7),
                  border: Border.all(color: _bdr.withValues(alpha: 0.5)),
                ),
                child: const Icon(Icons.close_rounded, size: 13, color: _txt2),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SelBarBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _SelBarBtn({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color = _txt1,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: color == _red
              ? _red.withValues(alpha: 0.12)
              : Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: color == _red
                ? _red.withValues(alpha: 0.28)
                : _bdr.withValues(alpha: 0.5),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 5),
            Text(
              label,
              style: GoogleFonts.inter(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProofreadBanner extends StatelessWidget {
  final String result;
  final VoidCallback onApply, onDismiss;
  const _ProofreadBanner({
    required this.result,
    required this.onApply,
    required this.onDismiss,
  });
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: const Color(0xFF0A1A08),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: _acc.withValues(alpha: 0.3)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.auto_fix_high_rounded, size: 14, color: _acc),
            const SizedBox(width: 6),
            const Text(
              '교정 결과',
              style: TextStyle(
                color: _acc,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            const Spacer(),
            GestureDetector(
              onTap: onDismiss,
              child: Icon(Icons.close_rounded, size: 14, color: _txt2),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          result,
          style: const TextStyle(color: _txt1, fontSize: 13, height: 1.6),
          maxLines: 4,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            GestureDetector(
              onTap: onDismiss,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  border: Border.all(color: _bdr2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  '취소',
                  style: TextStyle(color: _txt2, fontSize: 12),
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: onApply,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: _accD,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _acc.withValues(alpha: 0.4)),
                ),
                child: const Text(
                  '적용',
                  style: TextStyle(
                    color: _acc,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

class _DocumentHero extends StatefulWidget {
  final String icon;
  final TextEditingController titleController;
  final TextEditingController tagsController;
  final TextEditingController promptController;
  final int blockCount;
  final int charCount;
  final int wordCount;
  final void Function(String) onIconChange;
  final VoidCallback onTitleChange;
  final void Function(String) onTagsChange;
  final void Function(String) onPromptChange;
  final VoidCallback onInsertTemplate;
  final VoidCallback onFocusMode;
  final VoidCallback onGenerateSummary;
  final VoidCallback? onSuggestTags;

  const _DocumentHero({
    required this.icon,
    required this.titleController,
    required this.tagsController,
    required this.promptController,
    required this.blockCount,
    required this.charCount,
    required this.wordCount,
    required this.onIconChange,
    required this.onTitleChange,
    required this.onTagsChange,
    required this.onPromptChange,
    required this.onInsertTemplate,
    required this.onFocusMode,
    required this.onGenerateSummary,
    this.onSuggestTags,
  });

  @override
  State<_DocumentHero> createState() => _DocumentHeroState();
}

class _DocumentHeroState extends State<_DocumentHero> {
  bool _propCollapsed = false;

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 700;
    return Container(
      padding: EdgeInsets.fromLTRB(22, isMobile ? 20 : 26, 22, 18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: _bg1.withValues(alpha: 0.66),
        border: Border.all(color: _bdr.withValues(alpha: 0.9)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _IconRow(current: widget.icon, onChange: widget.onIconChange),
          const SizedBox(height: 18),
          _GlowTitle(ctrl: widget.titleController, onChange: widget.onTitleChange),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _MiniMetaChip(icon: LucideIcons.files, label: '${widget.blockCount} 블록'),
              _MiniMetaChip(icon: LucideIcons.text, label: '${widget.charCount}자'),
              _MiniMetaChip(
                icon: LucideIcons.alignLeft,
                label: '${widget.wordCount} 단어',
              ),
              _MiniMetaChip(icon: LucideIcons.clock, label: '${(widget.charCount / 300).ceil()}분 읽기'),
            ],
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              Text('속성', style: GoogleFonts.inter(color: _txt2.withValues(alpha: 0.45), fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
              const Spacer(),
              GestureDetector(
                onTap: () => setState(() => _propCollapsed = !_propCollapsed),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_propCollapsed ? '펼치기' : '접기', style: GoogleFonts.inter(color: _txt2.withValues(alpha: 0.45), fontSize: 10)),
                    const SizedBox(width: 3),
                    AnimatedRotation(
                      turns: _propCollapsed ? -0.25 : 0,
                      duration: const Duration(milliseconds: 200),
                      child: const Icon(Icons.expand_more_rounded, size: 13, color: _txt2),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            child: _propCollapsed ? const SizedBox.shrink() : Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _bg0.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: _bdr.withValues(alpha: 0.8)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: _PropRow(
                              icon: Icons.tag_rounded,
                              label: '태그',
                              ctrl: widget.tagsController,
                              hint: '태그',
                              onChange: widget.onTagsChange,
                            ),
                          ),
                          if (widget.onSuggestTags != null)
                            GestureDetector(
                              onTap: widget.onSuggestTags,
                              child: Container(
                                margin: const EdgeInsets.only(left: 8),
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                                decoration: BoxDecoration(
                                  color: _bg3.withValues(alpha: 0.6),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: _bdr.withValues(alpha: 0.7)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.auto_awesome_rounded, size: 11, color: _txt2),
                                    const SizedBox(width: 4),
                                    Text('AI 추천', style: GoogleFonts.inter(fontSize: 10, color: _txt2, fontWeight: FontWeight.w600)),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                      _PropRow(
                        icon: Icons.auto_awesome_rounded,
                        label: '프롬프트',
                        ctrl: widget.promptController,
                        hint: 'AI 지시사항',
                        onChange: widget.onPromptChange,
                      ),
                    ],
                  ),
                ),
                ValueListenableBuilder<TextEditingValue>(
                  valueListenable: widget.promptController,
                  builder: (context, value, child) {
                    if (value.text.isNotEmpty) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: _PromptSugs(
                        onTap: (suggestion) {
                          widget.promptController.text = suggestion;
                          widget.onPromptChange(suggestion);
                        },
                      ),
                    );
                  },
                ),
              ],
            ),
          ),

          const _Div(),
          const SizedBox(height: 10),
          Text(
            '`/` 로 블록 추가 · Enter로 새 줄 · Backspace로 블록 병합\nCtrl+B 볼드 · Ctrl+I 이탤릭 · Ctrl+D 복제 · Ctrl+Enter 아래 추가',
            style: GoogleFonts.inter(
              color: _txt2.withValues(alpha: 0.78),
              fontSize: 11.5,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniMetaChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _MiniMetaChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: _bg3.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _bdr.withValues(alpha: 0.85)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: _txt2),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.inter(
              color: _txt1,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool primary;

  const _HeroActionBtn({
    required this.icon,
    required this.label,
    required this.onTap,
    this.primary = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            gradient: primary
                ? LinearGradient(
                    colors: [
                      _acc.withValues(alpha: 0.24),
                      _acc.withValues(alpha: 0.12),
                    ],
                  )
                : null,
            color: primary ? null : _bg3.withValues(alpha: 0.84),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: primary
                  ? _acc.withValues(alpha: 0.26)
                  : _bdr.withValues(alpha: 0.9),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: primary ? _acc : _txt1),
              const SizedBox(width: 8),
              Text(
                label,
                style: GoogleFonts.inter(
                  color: primary ? _txt0 : _txt1,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EditorAddBlock extends StatelessWidget {
  final VoidCallback onTap;

  const _EditorAddBlock({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: _bg1.withValues(alpha: 0.38),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _bdr.withValues(alpha: 0.7)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.add_rounded, size: 18, color: _acc),
              const SizedBox(width: 10),
              Text(
                '새 블록 추가',
                style: GoogleFonts.inter(
                  color: _txt1,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ══════════════════ 교정 스타일 버튼 ════════════════
class _StyleBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  const _StyleBtn(this.label, this.icon, this.onTap);
  @override
  Widget build(BuildContext context) => Expanded(
    child: GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: _bg4,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _bdr2),
        ),
        child: Column(
          children: [
            Icon(icon, size: 22, color: _acc),
            const SizedBox(height: 6),
            Text(
              label,
              style: const TextStyle(
                color: _txt1,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

// ══════════════════ GLOW TITLE ══════════════════════
class _GlowTitle extends StatefulWidget {
  final TextEditingController ctrl;
  final VoidCallback onChange;
  const _GlowTitle({required this.ctrl, required this.onChange});
  @override
  State<_GlowTitle> createState() => _GTState();
}

class _GTState extends State<_GlowTitle> {
  late FocusNode _fn;
  @override
  void initState() {
    super.initState();
    _fn = FocusNode()
      ..addListener(() {
        if (mounted) setState(() {});
      });
  }

  @override
  void dispose() {
    _fn.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final titleSize = w < 600
        ? 28.0
        : w < 1024
        ? 34.0
        : 40.0;
    return TextField(
      controller: widget.ctrl,
      focusNode: _fn,
      style: GoogleFonts.inter(
        fontSize: titleSize,
        fontWeight: FontWeight.w800,
        color: _txt0,
        height: 1.15,
        letterSpacing: -1.5,
        shadows: const [
          Shadow(color: Color(0x10CCFF66), blurRadius: 40),
          Shadow(color: Color(0x06FFFFFF), blurRadius: 16),
        ],
      ),
      decoration: InputDecoration(
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        filled: true,
        fillColor: Colors.transparent,
        isDense: true,
        contentPadding: EdgeInsets.zero,
        hintText: '제목 없음',
        hintStyle: GoogleFonts.inter(
          fontSize: titleSize,
          fontWeight: FontWeight.w800,
          color: const Color(0xFF1C1C30),
          height: 1.15,
          letterSpacing: -1.5,
        ),
      ),
      onChanged: (_) => widget.onChange(),
    );
  }
}

// ══════════════════ ICON PICKER ═════════════════════
class _IconRow extends StatefulWidget {
  final String current;
  final void Function(String) onChange;
  const _IconRow({required this.current, required this.onChange});
  @override
  State<_IconRow> createState() => _IRState();
}

class _IRState extends State<_IconRow> with SingleTickerProviderStateMixin {
  bool _open = false;
  late AnimationController _ac;
  late Animation<double> _anim;
  static const _emojis = [
    '📚',
    '✏️',
    '💡',
    '🔬',
    '🧮',
    '🌐',
    '🎯',
    '📊',
    '🏗️',
    '🔧',
    '🎓',
    '📝',
    '💻',
    '🧠',
    '⚡',
    '🌟',
    '🔑',
    '🎨',
    '📐',
    '🗺️',
    '🧬',
    '⚗️',
    '🔭',
    '🎵',
  ];
  @override
  void initState() {
    super.initState();
    _ac = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _anim = CurvedAnimation(parent: _ac, curve: Curves.easeOutCubic);
  }

  @override
  void dispose() {
    _ac.dispose();
    super.dispose();
  }

  void _tog() {
    setState(() => _open = !_open);
    _open ? _ac.forward() : _ac.reverse();
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      GestureDetector(
        onTap: _tog,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 130),
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: _open ? _bg4 : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.current.isNotEmpty ? widget.current : '🪄',
                style: const TextStyle(fontSize: 36),
              ),
              const SizedBox(width: 8),
              AnimatedRotation(
                turns: _open ? 0.5 : 0,
                duration: const Duration(milliseconds: 150),
                child: const Icon(
                  Icons.expand_more_rounded,
                  size: 14,
                  color: _txt2,
                ),
              ),
            ],
          ),
        ),
      ),
      SizeTransition(
        sizeFactor: _anim,
        axisAlignment: -1,
        child: Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Wrap(
            spacing: 4,
            runSpacing: 4,
            children: _emojis
                .map(
                  (ic) => GestureDetector(
                    onTap: () {
                      widget.onChange(ic);
                      _tog();
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 100),
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: ic == widget.current ? _accD : _bg3,
                        borderRadius: BorderRadius.circular(9),
                        border: Border.all(
                          color: ic == widget.current
                              ? _acc.withValues(alpha: 0.5)
                              : _bdr,
                        ),
                      ),
                      child: Center(
                        child: Text(ic, style: const TextStyle(fontSize: 20)),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ),
      ),
    ],
  );
}

// ══════════════════ PROP ROW ════════════════════════
class _PropRow extends StatefulWidget {
  final IconData icon;
  final String label;
  final TextEditingController ctrl;
  final String hint;
  final void Function(String) onChange;
  const _PropRow({
    required this.icon,
    required this.label,
    required this.ctrl,
    required this.hint,
    required this.onChange,
  });
  @override
  State<_PropRow> createState() => _PRState();
}

class _PRState extends State<_PropRow> {
  late FocusNode _fn;
  @override
  void initState() {
    super.initState();
    _fn = FocusNode()
      ..addListener(() {
        if (mounted) setState(() {});
      });
  }

  @override
  void dispose() {
    _fn.dispose();
    super.dispose();
  }

  bool get _foc => _fn.hasFocus;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(
          widget.icon,
          size: 12,
          color: _foc
              ? _acc.withValues(alpha: 0.9)
              : _txt2.withValues(alpha: 0.35),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 60,
          child: Text(
            widget.label,
            style: GoogleFonts.inter(
              color: _foc ? _txt1 : _txt2.withValues(alpha: 0.45),
              fontSize: 11,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.2,
            ),
          ),
        ),
        Expanded(
          child: TextField(
            controller: widget.ctrl,
            focusNode: _fn,
            style: GoogleFonts.inter(color: _foc ? _txt0 : _txt1, fontSize: 13),
            decoration: InputDecoration(
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              filled: true,
              fillColor: Colors.transparent,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 4,
                vertical: 4,
              ),
              hintText: widget.hint,
              hintStyle: GoogleFonts.inter(
                color: _txt2.withValues(alpha: 0.25),
                fontSize: 13,
              ),
            ),
            onChanged: widget.onChange,
          ),
        ),
      ],
    ),
  );
}

// ══════════════════ PROMPT SUGGESTIONS ═════════════
class _PromptSugs extends StatefulWidget {
  final void Function(String) onTap;
  const _PromptSugs({required this.onTap});
  @override
  State<_PromptSugs> createState() => _PSState();
}

class _PSState extends State<_PromptSugs> with SingleTickerProviderStateMixin {
  late AnimationController _ac;
  late Animation<double> _fade;
  @override
  void initState() {
    super.initState();
    _ac = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    )..forward();
    _fade = CurvedAnimation(parent: _ac, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _ac.dispose();
    super.dispose();
  }

  static const _sugs = [
    ('핵심 개념 위주로 요약', Icons.lightbulb_outline_rounded),
    ('시험 대비 정리', Icons.school_outlined),
    ('개조식으로 정리', Icons.format_list_bulleted_rounded),
    ('코드 위주 분석', Icons.code_rounded),
    ('표로 비교 정리', Icons.table_chart_outlined),
    ('영어로 요약', Icons.translate_rounded),
  ];

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: _fade,
    child: Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 4, left: 22),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: _sugs
            .map(
              (p) => _PSChip(
                label: p.$1,
                icon: p.$2,
                onTap: () => widget.onTap(p.$1),
              ),
            )
            .toList(),
      ),
    ),
  );
}

class _PSChip extends StatefulWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  const _PSChip({required this.label, required this.icon, required this.onTap});
  @override
  State<_PSChip> createState() => _PSChipState();
}

class _PSChipState extends State<_PSChip> {
  bool _h = false;
  @override
  Widget build(BuildContext context) => MouseRegion(
    onEnter: (_) => setState(() => _h = true),
    onExit: (_) => setState(() => _h = false),
    child: GestureDetector(
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: _h ? _accD : _bg3,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: _h ? _acc.withValues(alpha: 0.4) : _bdr2,
            width: _h ? 1 : 0.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(widget.icon, size: 10, color: _h ? _acc : _txt2),
            const SizedBox(width: 5),
            Text(
              widget.label,
              style: GoogleFonts.inter(
                color: _h ? _acc : _txt1,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

// ══════════════════ POMODORO BAR ═══════════════════
class _PomodoroBar extends StatelessWidget {
  final String label;
  final Color color;
  final bool running, isWork;
  final VoidCallback onToggle, onReset;
  const _PomodoroBar({
    required this.label,
    required this.color,
    required this.running,
    required this.isWork,
    required this.onToggle,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) => Container(
    height: 36,
    padding: const EdgeInsets.symmetric(horizontal: 16),
    decoration: BoxDecoration(
      color: _bg2,
      border: Border(bottom: BorderSide(color: _bdr.withValues(alpha: 0.5))),
    ),
    child: Row(
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            color: running ? color : color.withValues(alpha: 0.3),
            shape: BoxShape.circle,
            boxShadow: running
                ? [
                    BoxShadow(
                      color: color.withValues(alpha: 0.6),
                      blurRadius: 6,
                    ),
                  ]
                : [],
          ),
        ),
        const SizedBox(width: 8),
        Text(
          isWork ? '집중' : '휴식',
          style: GoogleFonts.inter(
            color: _txt2,
            fontSize: 10,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.4,
          ),
        ),
        const SizedBox(width: 10),
        Text(
          label,
          style: GoogleFonts.inter(
            color: color,
            fontSize: 13,
            fontWeight: FontWeight.w700,
            fontFeatures: [const FontFeature.tabularFigures()],
          ),
        ),
        const Spacer(),
        GestureDetector(
          onTap: onToggle,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: running ? _bg4 : color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: running ? _bdr2 : color.withValues(alpha: 0.4),
              ),
            ),
            child: Text(
              running ? '일시정지' : '시작',
              style: GoogleFonts.inter(
                color: running ? _txt1 : color,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: onReset,
          child: Icon(
            Icons.refresh_rounded,
            size: 14,
            color: _txt2.withValues(alpha: 0.5),
          ),
        ),
      ],
    ),
  );
}

// ══════════════════ POMODORO FAB ════════════════════
class _PomFAB extends StatefulWidget {
  final String label;
  final Color color;
  final bool running;
  final VoidCallback onTap, onLongPress;
  const _PomFAB({
    required this.label,
    required this.color,
    required this.running,
    required this.onTap,
    required this.onLongPress,
  });
  @override
  State<_PomFAB> createState() => _PomFABState();
}

class _PomFABState extends State<_PomFAB> {
  bool _h = false;
  @override
  Widget build(BuildContext context) => MouseRegion(
    onEnter: (_) => setState(() => _h = true),
    onExit: (_) => setState(() => _h = false),
    child: GestureDetector(
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: widget.running ? widget.color.withValues(alpha: 0.15) : _bg3,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: widget.running
                ? widget.color.withValues(alpha: 0.5)
                : (_h ? _bdr2 : _bdr),
            width: widget.running ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
            if (widget.running)
              BoxShadow(
                color: widget.color.withValues(alpha: 0.15),
                blurRadius: 16,
              ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              widget.running ? Icons.pause_rounded : Icons.timer_outlined,
              size: 13,
              color: widget.running ? widget.color : _txt2,
            ),
            const SizedBox(width: 6),
            Text(
              widget.label,
              style: GoogleFonts.inter(
                color: widget.running ? widget.color : _txt1,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                fontFeatures: [const FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

// ══════════════════ 모바일 에디터 뷰 ════════════════════
// 에디터 + 하단 액션바 + AI 버튼 통합
// 키보드 표시 시 자동으로 bar 숨김 (tap-to-toggle 제거 → 텍스트 입력 방해 없음)
class _MobileEditorView extends StatelessWidget {
  final Widget editor;
  final String pomLabel;
  final Color pomColor;
  final bool pomRunning;
  final VoidCallback onPomTap, onPomReset, onAiTap;
  const _MobileEditorView({
    required this.editor,
    required this.pomLabel,
    required this.pomColor,
    required this.pomRunning,
    required this.onPomTap,
    required this.onPomReset,
    required this.onAiTap,
  });

  @override
  Widget build(BuildContext context) {
    // 키보드가 100px 이상 올라오면 bar 숨김
    final keyboardUp = MediaQuery.of(context).viewInsets.bottom > 100;
    // bar 높이 = 56px content + 홈 인디케이터
    final barH = 56.0 + MediaQuery.of(context).padding.bottom;
    return Stack(
      children: [
        // 에디터 (전체)
        editor,
        // 하단 액션 바 - 키보드 열리면 자동 hide
        AnimatedPositioned(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          bottom: keyboardUp ? -barH : 0,
          left: 0,
          right: 0,
          child: _MobileBottomBar(
            pomLabel: pomLabel,
            pomColor: pomColor,
            pomRunning: pomRunning,
            onPomTap: onPomTap,
            onPomReset: onPomReset,
            onAiTap: onAiTap,
          ),
        ),
      ],
    );
  }
}

class _MobileBottomBar extends StatelessWidget {
  final String pomLabel;
  final Color pomColor;
  final bool pomRunning;
  final VoidCallback onPomTap, onPomReset, onAiTap;
  const _MobileBottomBar({
    required this.pomLabel,
    required this.pomColor,
    required this.pomRunning,
    required this.onPomTap,
    required this.onPomReset,
    required this.onAiTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _bg2,
        border: const Border(top: BorderSide(color: _bdr, width: 0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 56, // 고정 56px (SafeArea가 홈 인디케이터 처리)
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                // 포모도로 버튼
                GestureDetector(
                  onTap: onPomTap,
                  onLongPress: onPomReset,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: pomRunning
                          ? pomColor.withValues(alpha: 0.12)
                          : _bg3,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: pomRunning
                            ? pomColor.withValues(alpha: 0.4)
                            : _bdr2,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          pomRunning
                              ? Icons.pause_rounded
                              : Icons.timer_outlined,
                          size: 15,
                          color: pomRunning ? pomColor : _txt2,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          pomLabel,
                          style: GoogleFonts.inter(
                            color: pomRunning ? pomColor : _txt1,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            fontFeatures: [const FontFeature.tabularFigures()],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const Spacer(),
                // AI 패널 버튼
                GestureDetector(
                  onTap: onAiTap,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: _accD,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: _acc.withValues(alpha: 0.5),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: _acc.withValues(alpha: 0.15),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.auto_awesome_rounded, size: 15, color: _acc),
                        const SizedBox(width: 7),
                        Text(
                          'AI 패널',
                          style: GoogleFonts.inter(
                            color: _acc,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ══════════════════ 모바일 탭 ════════════════════════
class _MobileTabs extends StatelessWidget {
  final TabController ctrl;
  const _MobileTabs({required this.ctrl});

  static const _tabs = [
    (Icons.auto_awesome_rounded, '요약'),
    (Icons.manage_search_rounded, '분석'),
    (Icons.psychology_rounded, '암기'),
    (Icons.quiz_rounded, '퀴즈'),
    (Icons.chat_bubble_outline_rounded, '질문'),
    (Icons.sticky_note_2_outlined, '메모'),
  ];

  @override
  Widget build(BuildContext context) => TabBar(
    controller: ctrl,
    isScrollable: true,
    tabAlignment: TabAlignment.start,
    dividerColor: Colors.transparent,
    indicator: BoxDecoration(
      gradient: LinearGradient(
        colors: [_acc.withValues(alpha: 0.22), _acc.withValues(alpha: 0.10)],
      ),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: _acc.withValues(alpha: 0.28)),
    ),
    indicatorSize: TabBarIndicatorSize.tab,
    labelColor: _txt0,
    unselectedLabelColor: _txt2,
    labelStyle: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700),
    unselectedLabelStyle: GoogleFonts.inter(
      fontSize: 12,
      fontWeight: FontWeight.w500,
    ),
    labelPadding: const EdgeInsets.symmetric(horizontal: 8),
    tabs: _tabs
        .map(
          (t) => Tab(
            height: 38,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(t.$1, size: 13),
                const SizedBox(width: 5),
                Text(t.$2),
              ],
            ),
          ),
        )
        .toList(),
  );
}

// ══════════════════ IMAGE BLOCK ═════════════════════
class _ImageBlock extends StatefulWidget {
  final TextEditingController controller;
  final ValueChanged<String>? onChanged;
  const _ImageBlock({required this.controller, this.onChanged});
  @override
  State<_ImageBlock> createState() => _IBState();
}

class _IBState extends State<_ImageBlock> {
  bool _hover = false;
  String get _url => widget.controller.text.trim();

  @override
  Widget build(BuildContext context) => MouseRegion(
    onEnter: (_) => setState(() => _hover = true),
    onExit: (_) => setState(() => _hover = false),
    child: Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      constraints: const BoxConstraints(maxWidth: 680, maxHeight: 500),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _hover ? _bdr2 : _bdr.withValues(alpha: 0.5)),
        color: _bg3,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(9),
        child: _url.isEmpty
            ? Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.image_outlined, color: _txt2, size: 28),
                    const SizedBox(height: 12),
                    TextField(
                      controller: widget.controller,
                      autofocus: true,
                      style: GoogleFonts.inter(color: _txt0, fontSize: 14),
                      decoration: InputDecoration(
                        hintText: '이미지 URL 붙여넣기',
                        hintStyle: GoogleFonts.inter(color: _txt2, fontSize: 13),
                        filled: true,
                        fillColor: _bg2,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: _bdr2),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: _bdr2),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: _acc, width: 1.4),
                        ),
                      ),
                      onChanged: widget.onChanged,
                    ),
                  ],
                ),
              )
            : (_url.startsWith('http') || kIsWeb)
                ? Image.network(
                    _url,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.broken_image_outlined, color: _txt2, size: 28),
                          const SizedBox(height: 8),
                          Text(
                            '이미지를 불러올 수 없습니다',
                            style: TextStyle(color: _txt2, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  )
                : Image.file(
                    File(_url),
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.broken_image_outlined, color: _txt2, size: 28),
                          const SizedBox(height: 8),
                          Text(
                            '로컬 이미지를 불러올 수 없습니다',
                            style: TextStyle(color: _txt2, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ),
      ),
    ),
  );
}

class _PdfBlock extends StatelessWidget {
  final TextEditingController controller;
  const _PdfBlock({required this.controller});
  
  @override
  Widget build(BuildContext context) {
    final path = controller.text.trim();
    final filename = path.split('/').last.split('\\').last;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: _bg3,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _bdr),
      ),
      child: Row(
        children: [
          Icon(LucideIcons.fileText, color: _red, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  filename.isEmpty ? 'PDF 문서' : filename,
                  style: GoogleFonts.inter(color: _txt0, fontSize: 14, fontWeight: FontWeight.w500),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (path.isNotEmpty)
                  Text(
                    'PDF 첨부됨',
                    style: GoogleFonts.inter(color: _txt2, fontSize: 12),
                  ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () {
              // PDF 열기 기능 (나중에 구현)
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _bg2,
              foregroundColor: _txt1,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              side: BorderSide(color: _bdr2),
            ),
            child: Text('열기', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }
}

class _CodeBlockWidget extends StatefulWidget {
  final Block block;
  final bool isFocused;
  final ValueChanged<String> onChanged;
  final VoidCallback onFocusRequest;

  const _CodeBlockWidget({
    required this.block,
    required this.isFocused,
    required this.onChanged,
    required this.onFocusRequest,
  });

  @override
  State<_CodeBlockWidget> createState() => _CodeBlockWidgetState();
}

class _CodeBlockWidgetState extends State<_CodeBlockWidget> {
  bool _hover = false;
  final List<String> _languages = ['dart', 'python', 'javascript', 'html', 'css', 'json', 'yaml', 'c', 'cpp', 'java'];
  
  String get _lang => widget.block.metadata?['language'] as String? ?? 'dart';

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E), // Atom One Dark bg
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _bdr.withValues(alpha: 0.5)),
        ),
        clipBehavior: Clip.hardEdge,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 언어 선택 헤더 (항상 표시)
            Container(
                color: Colors.black26,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _languages.contains(_lang) ? _lang : 'dart',
                        dropdownColor: _bg3,
                        icon: Icon(Icons.arrow_drop_down, color: _txt2, size: 16),
                        style: TextStyle(color: _txt2, fontSize: 12),
                        isDense: true,
                        onChanged: (val) {
                          if (val != null) {
                            setState(() {
                              widget.block.metadata ??= {};
                              widget.block.metadata!['language'] = val;
                            });
                            widget.onChanged(widget.block.controller.text); // trigger save
                          }
                        },
                        items: _languages.map((l) => DropdownMenuItem(value: l, child: Text(l))).toList(),
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.copy, size: 14, color: _txt2),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: widget.block.controller.text));
                      },
                    ),
                  ],
                ),
              ),
            // 본문
            GestureDetector(
              onTap: widget.onFocusRequest,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: widget.isFocused
                    ? TextField(
                        controller: widget.block.controller,
                        focusNode: widget.block.focusNode,
                        maxLines: null,
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 13,
                          color: const Color(0xFFD4BBFF),
                          height: 1.5,
                        ),
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                        onChanged: widget.onChanged,
                      )
                    : HighlightView(
                        widget.block.controller.text.isEmpty ? '// 코드를 입력하세요' : widget.block.controller.text,
                        language: _lang,
                        theme: atomOneDarkTheme,
                        padding: EdgeInsets.zero,
                        textStyle: GoogleFonts.jetBrainsMono(fontSize: 13, height: 1.5),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Div extends StatelessWidget {
  const _Div();
  @override
  Widget build(BuildContext context) => Container(
    height: 0.5,
    margin: const EdgeInsets.symmetric(vertical: 4),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [
          Colors.transparent,
          _bdr.withValues(alpha: 0.6),
          Colors.transparent,
        ],
      ),
    ),
  );
}

// ══════════════════ NOTION BLOCK ════════════════════
class _NBlock extends StatefulWidget {
  final int idx;
  final Block block;
  final BlockType? prevType;
  final bool isSelected;
  final bool isAnalyzing;
  final int listNumber;
  final KeyEventResult Function(FocusNode, KeyEvent, int) onKey;
  final Function(String, int) onText;
  final VoidCallback onDel, onDup, onFocus, onBlur, onSelect, onAddBelow;
  final Function(BlockType) onType;
  final Function(bool) onCheck;
  final void Function(String, TextEditingController, GlobalKey)? onSelChanged;
  final GlobalKey? blockKey;
  const _NBlock({
    Key? key,
    required this.idx,
    required this.block,
    this.prevType,
    this.isSelected = false,
    this.isAnalyzing = false,
    this.listNumber = 0,
    required this.onKey,
    required this.onText,
    required this.onDel,
    required this.onDup,
    required this.onType,
    required this.onCheck,
    required this.onFocus,
    required this.onBlur,
    required this.onSelect,
    required this.onAddBelow,
    this.onSelChanged,
    this.blockKey,
  }) : super(key: key);
  @override
  State<_NBlock> createState() => _NBState();
}

class _NBState extends State<_NBlock> {
  bool _foc = false;
  bool _hover = false;
  Timer? _selTimer;

  @override
  void initState() {
    super.initState();
    widget.block.focusNode.addListener(_onFoc);
    // 키보드 selection 감지 (Shift+방향키 등)
    widget.block.controller.addListener(_onCtrlChange);
  }

  @override
  void dispose() {
    widget.block.focusNode.removeListener(_onFoc);
    widget.block.controller.removeListener(_onCtrlChange);
    _selTimer?.cancel();
    super.dispose();
  }

  // 키보드로 selection 변경 시 감지
  void _onCtrlChange() {
    if (!mounted) return;
    final ctrl = widget.block.controller;
    final sel = ctrl.selection;
    // IME 조합 중이면 무시
    if (ctrl.value.composing != TextRange.empty) return;
    // 텍스트가 변경된 경우(타이핑)는 무시, selection만 감지
    // collapsed selection = 그냥 커서 이동, 선택 없음 → 무시
    if (sel.isCollapsed) return;
    // 마우스는 onPointerUp이 처리하므로 여기선 키보드만 처리
    // sel이 collapsed면 툴바 닫기, 아니면 타이머로 표시
    _selTimer?.cancel();
    _selTimer = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      if (!sel.isValid || sel.isCollapsed) {
        widget.onSelChanged?.call('', ctrl, GlobalKey());
        return;
      }
      final txt = ctrl.text;
      final selected = txt.substring(
        sel.start.clamp(0, txt.length),
        sel.end.clamp(0, txt.length),
      );
      if (selected.trim().isNotEmpty) {
        widget.onSelChanged?.call(
          selected,
          ctrl,
          widget.blockKey ?? GlobalKey(),
        );
      } else {
        widget.onSelChanged?.call('', ctrl, GlobalKey());
      }
    });
  }

  void _onFoc() {
    if (!mounted) return;
    final f = widget.block.focusNode.hasFocus;
    if (_foc != f) {
      setState(() => _foc = f);
      if (_foc) {
        widget.onFocus();
      } else {
        widget.onBlur();
      }
    }
  }

  // ── 블록별 스타일 ──────────────────────────────
  TextStyle _style() => switch (widget.block.type) {
    BlockType.h1 => GoogleFonts.inter(
      fontSize: 32,
      fontWeight: FontWeight.w800,
      color: _txt0,
      height: 1.25,
      letterSpacing: -1.0,
      shadows: const [Shadow(color: Color(0x10CCFF66), blurRadius: 24)],
    ),
    BlockType.h2 => GoogleFonts.inter(
      fontSize: 24,
      fontWeight: FontWeight.w700,
      color: _txt0,
      height: 1.3,
      letterSpacing: -0.5,
    ),
    BlockType.h3 => GoogleFonts.inter(
      fontSize: 19,
      fontWeight: FontWeight.w600,
      color: _txt0,
      height: 1.4,
      letterSpacing: -0.2,
    ),
    BlockType.code => GoogleFonts.jetBrainsMono(
      fontSize: 13,
      color: const Color(0xFFD4BBFF),
      height: 1.75,
      letterSpacing: 0.2,
    ),
    BlockType.quote => GoogleFonts.inter(
      fontSize: 15,
      color: _txt1,
      height: 1.8,
      fontStyle: FontStyle.italic,
      fontWeight: FontWeight.w400,
    ),
    BlockType.number => GoogleFonts.inter(
      fontSize: 15,
      color: _txt0.withValues(alpha: 0.85),
      height: 1.85,
      letterSpacing: 0.0,
      fontWeight: FontWeight.w400,
    ),
    BlockType.image => GoogleFonts.inter(fontSize: 14, color: _txt2),
    BlockType.table => GoogleFonts.jetBrainsMono(
      fontSize: 13,
      color: const Color(0xFFA8D4FF),
      height: 1.75,
      letterSpacing: 0.2,
    ),
    BlockType.hr => GoogleFonts.inter(fontSize: 15, color: _txt2),
    BlockType.bullet => GoogleFonts.inter(
      fontSize: 15,
      color: _txt0.withValues(alpha: 0.85),
      height: 1.85,
      letterSpacing: 0.0,
      fontWeight: FontWeight.w400,
    ),
    BlockType.checkbox => GoogleFonts.inter(
      fontSize: 15,
      color: _txt0.withValues(alpha: 0.85),
      height: 1.85,
      letterSpacing: 0.0,
      fontWeight: FontWeight.w400,
    ),
    _ => GoogleFonts.inter(
      fontSize: 15,
      color: _txt0.withValues(alpha: 0.85),
      height: 1.85,
      letterSpacing: 0.0,
      fontWeight: FontWeight.w400,
    ),
  };

  // ── 테이블 감지 (코드 블록 내 마크다운 표) ──────
  bool get _isTable {
    if (widget.block.type == BlockType.table) return true;
    if (widget.block.type != BlockType.code) return false;
    // |로 시작하는 줄이 2줄 이상이면 표로 인식 (--- 구분선 없어도 OK)
    final t = widget.block.controller.text;
    final pipeLines =
        t.split('\n').where((l) => l.trim().startsWith('|')).length;
    return pipeLines >= 2;
  }

  @override
  Widget build(BuildContext context) {
    widget.block.focusNode.onKeyEvent = (n, e) =>
        widget.onKey(n, e, widget.idx);
    final isBul = widget.block.type == BlockType.bullet;
    final isPrevBul = widget.prevType == BlockType.bullet;
    final showControls = _foc || _hover;

    return KeyedSubtree(
      key: widget.blockKey,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          onTap: () {
            widget.block.focusNode.requestFocus();
            final c = widget.block.controller;
            if (c.selection.isCollapsed && c.selection.baseOffset < 0) {
              c.selection = TextSelection.collapsed(offset: c.text.length);
            }
          },
          behavior: HitTestBehavior.translucent,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            margin: const EdgeInsets.symmetric(vertical: 4),
            padding: EdgeInsets.only(
              top: (isBul && isPrevBul) ? 4 : (isBul ? 6 : 5),
              bottom: isBul ? 4 : 5,
              left: widget.block.type == BlockType.quote ? 6 : 10,
              right: 10,
            ),
            // 노션식 클린 블록: 테두리/그림자 없이 미묘한 배경 틴트만
            decoration: BoxDecoration(
              color: widget.isAnalyzing
                  ? _acc.withValues(alpha: 0.10)
                  : widget.isSelected
                  ? _acc.withValues(alpha: 0.12)
                  : widget.block.type == BlockType.code
                  ? _bg2.withValues(alpha: 0.5)
                  : widget.block.type == BlockType.quote
                  ? Colors.white.withValues(alpha: 0.022)
                  : _hover
                  ? Colors.white.withValues(alpha: 0.014)
                  : null,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 72,
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 120),
                    opacity: (showControls || widget.isSelected) ? 1 : 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: widget.isSelected
                            ? _acc.withValues(alpha: 0.14)
                            : _bg3.withValues(alpha: 0.86),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: widget.isSelected
                              ? _acc.withValues(alpha: 0.4)
                              : _bdr.withValues(alpha: 0.82),
                        ),
                      ),
                      child: Row(
                        children: [
                        // 선택 체크 아이콘 or 추가 버튼
                        GestureDetector(
                          onTap: widget.isSelected ? widget.onSelect : widget.onAddBelow,
                          child: Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: widget.isSelected
                                  ? _acc.withValues(alpha: 0.2)
                                  : _bg2.withValues(alpha: 0.92),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: widget.isSelected
                                    ? _acc.withValues(alpha: 0.6)
                                    : _bdr.withValues(alpha: 0.72),
                              ),
                            ),
                            child: Icon(
                              widget.isSelected
                                  ? Icons.check_rounded
                                  : LucideIcons.plus,
                              size: 13,
                              color: widget.isSelected ? _acc : _txt1,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: ReorderableDragStartListener(
                            index: widget.idx,
                            child: PopupMenuButton<String>(
                              padding: EdgeInsets.zero,
                              color: _bg3,
                              offset: const Offset(0, 28),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: const BorderSide(color: _bdr2),
                              ),
                              icon: Icon(
                                LucideIcons.grip,
                                size: 14,
                                color: _txt2,
                              ),
                              iconSize: 15,
                              onSelected: (v) {
                                if (v == 'd') {
                                  widget.onDel();
                                } else if (v == 'c') {
                                  widget.onDup();
                                } else if (v == 's') {
                                  widget.onSelect();
                                } else if (v == 'h1') {
                                  widget.onType(BlockType.h1);
                                } else if (v == 'h2') {
                                  widget.onType(BlockType.h2);
                                } else if (v == 't') {
                                  widget.onType(BlockType.text);
                                } else if (v == 'b') {
                                  widget.onType(BlockType.bullet);
                                } else if (v == 'n') {
                                  widget.onType(BlockType.number);
                                } else if (v == 'q') {
                                  widget.onType(BlockType.quote);
                                } else if (v == 'td') {
                                  widget.onType(BlockType.checkbox);
                                } else if (v == 'cd') {
                                  widget.onType(BlockType.code);
                                }
                              },
                              itemBuilder: (_) => [
                                _mi('s', Icons.check_box_outlined, '선택', _acc),
                                _mi(
                                  'c',
                                  LucideIcons.copy,
                                  '복제',
                                  _txt1,
                                ),
                                _mi(
                                  'd',
                                  LucideIcons.trash2,
                                  '삭제',
                                  _red,
                                ),
                                const PopupMenuDivider(height: 6),
                                _mi(
                                  'h1',
                                  LucideIcons.heading1,
                                  '제목 1',
                                  _txt1,
                                ),
                                _mi(
                                  'h2',
                                  LucideIcons.heading2,
                                  '제목 2',
                                  _txt1,
                                ),
                                _mi(
                                  't',
                                  LucideIcons.text,
                                  '텍스트',
                                  _txt1,
                                ),
                                _mi(
                                  'b',
                                  LucideIcons.list,
                                  '글머리',
                                  _txt1,
                                ),
                                _mi(
                                  'n',
                                  LucideIcons.listOrdered,
                                  '번호 목록',
                                  _txt1,
                                ),
                                _mi(
                                  'td',
                                  Icons.check_box_outlined,
                                  '체크리스트',
                                  _txt1,
                                ),
                                _mi(
                                  'q',
                                  LucideIcons.quote,
                                  '인용',
                                  _txt1,
                                ),
                                _mi('cd', LucideIcons.code2, '코드', _txt1),
                              ],
                            ),
                          ),
                        ),
                        ],
                      ),
                    ),
                  ),
                ),

                if (widget.block.type == BlockType.bullet)
                  Padding(
                    padding: const EdgeInsets.only(top: 14, right: 10),
                    child: Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: _foc ? _acc.withValues(alpha: 0.7) : _txt1.withValues(alpha: 0.45),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),

                // 번호 목록
                if (widget.block.type == BlockType.number)
                  Padding(
                    padding: const EdgeInsets.only(top: 2, right: 10),
                    child: SizedBox(
                      width: 22,
                      child: Text(
                        '${widget.listNumber}.',
                        style: GoogleFonts.inter(
                          color: _txt2,
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          height: 1.85,
                        ),
                        textAlign: TextAlign.right,
                      ),
                    ),
                  ),

                // 인용 좌측 바
                if (widget.block.type == BlockType.quote)
                  Padding(
                    padding: const EdgeInsets.only(right: 14, top: 2, bottom: 2),
                    child: Container(
                      width: 3.5,
                      constraints: const BoxConstraints(minHeight: 24),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [_acc.withValues(alpha: 0.7), _pur.withValues(alpha: 0.5)],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),

                // 체크박스
                if (widget.block.type == BlockType.checkbox)
                  Padding(
                    padding: const EdgeInsets.only(top: 5, right: 10),
                    child: SizedBox(
                      width: 17,
                      height: 17,
                      child: Checkbox(
                        value: widget.block.isChecked,
                        onChanged: (v) => widget.onCheck(v!),
                        activeColor: _acc,
                        checkColor: Colors.black,
                        side: const BorderSide(color: _txt2, width: 1.5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ),

                // (code/table/badge 태그 제거 — 클린 노션 스타일)

                // 수평선 블록 (HR)
                if (widget.block.type == BlockType.hr)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Container(
                        height: 1,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              _bdr.withValues(alpha: 0),
                              _bdr.withValues(alpha: 0.6),
                              _bdr.withValues(alpha: 0),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                // 이미지 블록
                if (widget.block.type == BlockType.image)
                  Expanded(
                    child: _ImageBlock(
                      controller: widget.block.controller,
                      onChanged: (value) => widget.onText(value, widget.idx),
                    ),
                  ),

                // PDF 블록
                if (widget.block.type == BlockType.pdf)
                  Expanded(
                    child: _PdfBlock(controller: widget.block.controller),
                  ),

                // 텍스트 입력 (이미지, PDF, HR 제외)
                if (widget.block.type != BlockType.image && widget.block.type != BlockType.pdf && widget.block.type != BlockType.hr)
                  Expanded(
                    child: Listener(
                      // ✅ onPointerUp: 브라우저 드래그 선택을 Flutter가 직접 감지
                      onPointerUp: (_) {
                        _selTimer?.cancel();
                        _selTimer = Timer(
                          const Duration(milliseconds: 200),
                          () {
                            if (!mounted) return;
                            final ctrl = widget.block.controller;
                            final sel = ctrl.selection;
                            if (!sel.isValid || sel.isCollapsed) {
                              widget.onSelChanged?.call('', ctrl, GlobalKey());
                              return;
                            }
                            final txt = ctrl.text;
                            final selected = txt.substring(
                              sel.start.clamp(0, txt.length),
                              sel.end.clamp(0, txt.length),
                            );
                            if (selected.trim().isNotEmpty) {
                              widget.onSelChanged?.call(
                                selected,
                                ctrl,
                                widget.blockKey ?? GlobalKey(),
                              );
                            }
                          },
                        );
                      },
                      child: CompositedTransformTarget(
                        link: widget.block.layerLink,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildBlockContent(),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    ); // KeyedSubtree > MouseRegion > GestureDetector > Container
  }

  bool get _isTableBlock =>
      _isTable || widget.block.type == BlockType.table;

  bool _hasInlineMarkdown(String t) =>
      t.contains('**') ||
      t.contains('~~') ||
      t.contains('`') ||
      RegExp(r'(?<!\*)\*(?!\*)[^*\n]+\*(?!\*)').hasMatch(t);

  /// 포커스 없음 → 렌더링(표/인라인 마크다운), 포커스 → raw TextField
  Widget _buildBlockContent() {
    final text = widget.block.controller.text;

    // 표 블록: 항상 편집 가능한 표 위젯 (노션식 — 셀 입력 / 행·열 추가·삭제)
    // 코드 검사보다 먼저 → AI가 만든 표(코드+파이프)도 표로 렌더
    if (_isTableBlock && text.trim().isNotEmpty) {
      return _EditableTable(
        // 블록 id 기반 고정 key → 입력 중 재생성/포커스 유실 방지
        key: ValueKey('tbl_${widget.block.id}'),
        source: widget.block.controller,
        onChanged: () =>
            widget.onText(widget.block.controller.text, widget.idx),
      );
    }

    // 코드 블록: 언어 선택 및 구문 강조 지원
    if (widget.block.type == BlockType.code) {
      return _CodeBlockWidget(
        block: widget.block,
        isFocused: _foc,
        onChanged: (val) => widget.onText(val, widget.idx),
        onFocusRequest: () => widget.block.focusNode.requestFocus(),
      );
    }
    if (!_foc && text.trim().isNotEmpty) {
      // 단독 --- / *** / ___ → 구분선
      if (RegExp(r'^(-{3,}|\*{3,}|_{3,})$').hasMatch(text.trim())) {
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => widget.block.focusNode.requestFocus(),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Container(height: 1, color: _bdr.withValues(alpha: 0.6)),
          ),
        );
      }
      if (_hasInlineMarkdown(text)) {
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => widget.block.focusNode.requestFocus(),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Text.rich(
              TextSpan(children: _inlineSpans(text, _style())),
            ),
          ),
        );
      }
    }
    return _buildTextField();
  }

  Widget _buildTextField() {
    return TextField(
      controller: widget.block.controller,
      focusNode: widget.block.focusNode,
      maxLines: null,
      style: _style().copyWith(
        decoration:
            (widget.block.type == BlockType.checkbox && widget.block.isChecked)
            ? TextDecoration.lineThrough
            : null,
        color:
            (widget.block.type == BlockType.checkbox && widget.block.isChecked)
            ? _txt2
            : null,
      ),
      decoration: InputDecoration(
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        filled: true,
        fillColor: Colors.transparent,
        hoverColor: Colors.transparent,
        isDense: true,
        contentPadding: EdgeInsets.zero,
        hintText:
            widget.block.controller.text.isEmpty ? _hint(widget.block.type) : '',
        hintStyle: TextStyle(
          color: _foc
              ? _txt2.withValues(alpha: 0.5)
              : _txt2.withValues(alpha: 0.22),
          fontSize: widget.block.type == BlockType.h1
              ? 28
              : widget.block.type == BlockType.h2
              ? 22
              : widget.block.type == BlockType.h3
              ? 18
              : 15,
        ),
      ),
      onChanged: (t) => widget.onText(t, widget.idx),
    );
  }

  /// 인라인 마크다운(**굵게**, *기울임*, `코드`, ~~취소선~~) → TextSpan
  List<InlineSpan> _inlineSpans(String text, TextStyle base) {
    final spans = <InlineSpan>[];
    final pattern = RegExp(
      r'(\*\*(.+?)\*\*|~~(.+?)~~|`([^`]+)`|\*(.+?)\*)',
      dotAll: true,
    );
    int last = 0;
    for (final m in pattern.allMatches(text)) {
      if (m.start > last) {
        spans.add(TextSpan(text: text.substring(last, m.start), style: base));
      }
      if (m.group(2) != null) {
        spans.add(TextSpan(
          text: m.group(2),
          style: base.copyWith(fontWeight: FontWeight.w800, color: _txt0),
        ));
      } else if (m.group(3) != null) {
        spans.add(TextSpan(
          text: m.group(3),
          style: base.copyWith(
            decoration: TextDecoration.lineThrough,
            color: _txt2,
          ),
        ));
      } else if (m.group(4) != null) {
        spans.add(TextSpan(
          text: m.group(4),
          style: GoogleFonts.jetBrainsMono(
            textStyle: base.copyWith(
              color: const Color(0xFFD4BBFF),
              backgroundColor: const Color(0x22D4BBFF),
            ),
          ),
        ));
      } else if (m.group(5) != null) {
        spans.add(TextSpan(
          text: m.group(5),
          style: base.copyWith(fontStyle: FontStyle.italic),
        ));
      }
      last = m.end;
    }
    if (last < text.length) {
      spans.add(TextSpan(text: text.substring(last), style: base));
    }
    if (spans.isEmpty) spans.add(TextSpan(text: text, style: base));
    return spans;
  }

  /// 마크다운 표 → 실제 Table 위젯
  Widget _renderTable(String raw) {
    final lines = raw
        .trim()
        .split('\n')
        .where((l) => l.trim().startsWith('|'))
        .toList();
    final rows = <List<String>>[];
    for (final l in lines) {
      // 구분선(|---|---|) 건너뛰기
      if (l.contains('-') &&
          RegExp(r'^\s*\|?[\s:|\-]+\|?\s*$').hasMatch(l)) {
        continue;
      }
      final cells = l.split('|').map((c) => c.trim()).toList();
      if (cells.isNotEmpty && cells.first.isEmpty) cells.removeAt(0);
      if (cells.isNotEmpty && cells.last.isEmpty) cells.removeLast();
      if (cells.isEmpty) continue;
      rows.add(cells);
    }
    if (rows.isEmpty) return _buildTextField();
    final colCount = rows.map((r) => r.length).reduce(math.max);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(
          border: Border.all(color: _bdr),
          borderRadius: BorderRadius.circular(10),
        ),
        clipBehavior: Clip.hardEdge,
        child: Table(
          defaultColumnWidth: const IntrinsicColumnWidth(),
          border: TableBorder.symmetric(
            inside: BorderSide(color: _bdr.withValues(alpha: 0.6)),
          ),
          children: [
            for (int i = 0; i < rows.length; i++)
              TableRow(
                decoration: BoxDecoration(
                  color: i == 0
                      ? _bg3.withValues(alpha: 0.9)
                      : (i.isOdd ? Colors.white.withValues(alpha: 0.018) : null),
                ),
                children: [
                  for (int c = 0; c < colCount; c++)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 9,
                      ),
                      child: Text(
                        c < rows[i].length ? rows[i][c] : '',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: i == 0 ? _txt0 : _txt1,
                          fontWeight:
                              i == 0 ? FontWeight.w700 : FontWeight.w400,
                          height: 1.4,
                        ),
                      ),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  String _hint(BlockType t) => switch (t) {
    BlockType.h1 => '제목 1을 입력하세요',
    BlockType.h2 => '제목 2를 입력하세요',
    BlockType.h3 => '제목 3을 입력하세요',
    BlockType.bullet => '항목 입력...',
    BlockType.checkbox => '할 일 추가...',
    BlockType.code => '코드를 입력하세요 (Tab으로 들여쓰기)',
    BlockType.number => '항목 입력...',
    BlockType.quote => '인용 내용을 입력하세요...',
    BlockType.image => 'https://example.com/image.png',
    BlockType.table => '|컬럼1|컬럼2|\n|---|---|\n|데이터|데이터|',
    BlockType.hr => '---',
    _ => _foc ? "내용 입력 또는  /  블록 타입 변경" : "",
  };

  Widget _HandleAction({required IconData icon, required VoidCallback onTap}) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: _bg2.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: _bdr.withValues(alpha: 0.72)),
          ),
          child: Icon(icon, size: 13, color: _txt1),
        ),
      );

  PopupMenuItem<String> _mi(String v, IconData icon, String txt, Color c) =>
      PopupMenuItem(
        value: v,
        height: 34,
        child: Row(
          children: [
            Icon(icon, size: 14, color: c.withValues(alpha: 0.85)),
            const SizedBox(width: 8),
            Text(txt, style: TextStyle(color: c, fontSize: 13)),
          ],
        ),
      );
}

class _BlockTypeBadge extends StatelessWidget {
  final BlockType type;

  const _BlockTypeBadge({required this.type});

  @override
  Widget build(BuildContext context) {
    final data = switch (type) {
      BlockType.h1 => ('Heading 1', LucideIcons.heading1),
      BlockType.h2 => ('Heading 2', LucideIcons.heading2),
      BlockType.h3 => ('Heading 3', LucideIcons.heading3),
      BlockType.quote => ('Quote', LucideIcons.quote),
      BlockType.code => ('Code', LucideIcons.code2),
      BlockType.table => ('Table', LucideIcons.table2),
      BlockType.bullet => ('List', LucideIcons.list),
      BlockType.number => ('Numbered', LucideIcons.listOrdered),
      BlockType.checkbox => ('Todo', LucideIcons.checkSquare),
      BlockType.image => ('Image', LucideIcons.image),
      BlockType.pdf => ('PDF Document', LucideIcons.file),
      BlockType.hr => ('Divider', LucideIcons.minus),
      _ => ('Text', LucideIcons.text),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _bg3.withValues(alpha: 0.86),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _bdr.withValues(alpha: 0.82)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(data.$2, size: 11, color: _txt2),
          const SizedBox(width: 6),
          Text(
            data.$1,
            style: GoogleFonts.inter(
              color: _txt2,
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════ 편집 가능한 표 (노션식) ══════════════════
class _EditableTable extends StatefulWidget {
  final TextEditingController source; // 블록 마크다운
  final VoidCallback onChanged;
  const _EditableTable({super.key, required this.source, required this.onChanged});
  @override
  State<_EditableTable> createState() => _EditableTableState();
}

class _EditableTableState extends State<_EditableTable> {
  late List<List<TextEditingController>> _cells;
  late List<List<FocusNode>> _focus; // 셀별 고정 포커스 노드
  static const double _colW = 160;
  bool _hover = false;

  @override
  void initState() {
    super.initState();
    _parse();
  }

  void _parse() {
    final rows = <List<String>>[];
    for (final l in widget.source.text.split('\n')) {
      final t = l.trim();
      if (!t.startsWith('|')) continue;
      // 구분선(|---|) 건너뛰기
      if (t.contains('-') && RegExp(r'^\|?[\s:|\-]+\|?$').hasMatch(t)) continue;
      final cells = t.split('|').map((c) => c.trim()).toList();
      if (cells.isNotEmpty && cells.first.isEmpty) cells.removeAt(0);
      if (cells.isNotEmpty && cells.last.isEmpty) cells.removeLast();
      if (cells.isEmpty) continue;
      rows.add(cells);
    }
    if (rows.isEmpty) rows.add(['', '']);
    final colCount = rows.map((r) => r.length).reduce(math.max).clamp(1, 99);
    _cells = [
      for (final r in rows)
        [
          for (int c = 0; c < colCount; c++)
            TextEditingController(text: c < r.length ? r[c] : ''),
        ],
    ];
    _focus = [for (final r in _cells) [for (var _ in r) FocusNode()]];
  }

  @override
  void dispose() {
    for (final r in _cells) {
      for (final c in r) c.dispose();
    }
    for (final r in _focus) {
      for (final f in r) f.dispose();
    }
    super.dispose();
  }

  // 셀 → 마크다운 (setState 없음, 커서 보존)
  void _sync() {
    final sb = StringBuffer();
    for (int i = 0; i < _cells.length; i++) {
      final cells = _cells[i]
          .map((c) => c.text.replaceAll('|', r'\|').replaceAll('\n', ' '))
          .join(' | ');
      sb.write('| $cells |\n');
      if (i == 0) {
        sb.write('| ${List.filled(_cells[0].length, '---').join(' | ')} |\n');
      }
    }
    widget.source.text = sb.toString().trimRight();
    widget.onChanged();
  }

  void _addRow() {
    setState(() {
      _cells.add([for (var _ in _cells[0]) TextEditingController()]);
      _focus.add([for (var _ in _cells[0]) FocusNode()]);
    });
    _sync();
  }

  void _addCol() {
    setState(() {
      for (final r in _cells) r.add(TextEditingController());
      for (final r in _focus) r.add(FocusNode());
    });
    _sync();
  }

  void _delRow(int i) {
    if (_cells.length <= 1) return;
    setState(() {
      for (final c in _cells[i]) c.dispose();
      for (final f in _focus[i]) f.dispose();
      _cells.removeAt(i);
      _focus.removeAt(i);
    });
    _sync();
  }

  void _delCol(int j) {
    if (_cells[0].length <= 1) return;
    setState(() {
      for (final r in _cells) {
        r[j].dispose();
        r.removeAt(j);
      }
      for (final r in _focus) {
        r[j].dispose();
        r.removeAt(j);
      }
    });
    _sync();
  }

  static const double _gutter = 22;

  @override
  Widget build(BuildContext context) {
    final rows = _cells.length;
    final cols = _cells.isNotEmpty && _cells[0].isNotEmpty ? _cells[0].length : 1;
    final line = BorderSide(color: _bdr.withValues(alpha: 0.75));
    final showColDel = _hover && cols > 1;
    final showRowDel = _hover && rows > 1;

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── 상단 열 삭제 거터 ──
              SizedBox(
                height: showColDel ? 20 : 4,
                child: showColDel
                    ? Row(
                        children: [
                          const SizedBox(width: _gutter),
                          for (int j = 0; j < cols; j++)
                            SizedBox(
                              width: _colW,
                              child: Center(
                                child: _TableHoverBtn(
                                  icon: LucideIcons.x,
                                  tip: '열 삭제',
                                  onTap: () => _delCol(j),
                                ),
                              ),
                            ),
                        ],
                      )
                    : null,
              ),
              // ── 본문(좌측 행 거터 + 셀) + 우측 열추가 ──
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (int i = 0; i < rows; i++)
                        IntrinsicHeight(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // 좌측 행 삭제 거터
                              SizedBox(
                                width: _gutter,
                                child: showRowDel
                                    ? Center(
                                        child: _TableHoverBtn(
                                          icon: LucideIcons.x,
                                          tip: '행 삭제',
                                          onTap: () => _delRow(i),
                                        ),
                                      )
                                    : null,
                              ),
                              for (int j = 0; j < cols; j++)
                                Container(
                                  width: _colW,
                                  constraints: const BoxConstraints(minHeight: 44),
                                  decoration: BoxDecoration(
                                    color: i == 0
                                        ? _bg3.withValues(alpha: 0.5)
                                        : null,
                                    border: Border(
                                      left: line,
                                      top: line,
                                      right: j == cols - 1 ? line : BorderSide.none,
                                      bottom: i == rows - 1 ? line : BorderSide.none,
                                    ),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 10,
                                  ),
                                  alignment: Alignment.centerLeft,
                                  child: TextField(
                                    controller: _cells[i][j],
                                    focusNode: _focus[i][j],
                                    maxLines: null,
                                    onChanged: (_) => _sync(),
                                    style: GoogleFonts.inter(
                                      fontSize: 13.5,
                                      height: 1.45,
                                      color: i == 0 ? _txt0 : _txt1,
                                      fontWeight: i == 0
                                          ? FontWeight.w700
                                          : FontWeight.w400,
                                    ),
                                    decoration: const InputDecoration(
                                      isDense: true,
                                      border: InputBorder.none,
                                      enabledBorder: InputBorder.none,
                                      focusedBorder: InputBorder.none,
                                      contentPadding: EdgeInsets.zero,
                                      hintText: '',
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  // 우측 열 추가
                  Padding(
                    padding: const EdgeInsets.only(left: 6, top: 0),
                    child: _TableEdgeAddBtn(
                      vertical: true,
                      tip: '새 열 추가',
                      onTap: _addCol,
                    ),
                  ),
                ],
              ),
              // ── 하단 행 추가 ──
              Padding(
                padding: const EdgeInsets.only(top: 6, left: _gutter),
                child: _TableEdgeAddBtn(
                  vertical: false,
                  width: cols * _colW,
                  tip: '새 행 추가',
                  onTap: _addRow,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// 표 가장자리 추가 버튼 (열=세로 막대 / 행=가로 막대)
class _TableEdgeAddBtn extends StatefulWidget {
  final bool vertical;
  final double? width;
  final String tip;
  final VoidCallback onTap;
  const _TableEdgeAddBtn({
    required this.vertical,
    required this.tip,
    required this.onTap,
    this.width,
  });
  @override
  State<_TableEdgeAddBtn> createState() => _TableEdgeAddBtnState();
}

class _TableEdgeAddBtnState extends State<_TableEdgeAddBtn> {
  bool _h = false;
  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.tip,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _h = true),
        onExit: (_) => setState(() => _h = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            width: widget.vertical ? 22 : widget.width,
            height: widget.vertical ? 44 : 22,
            decoration: BoxDecoration(
              color: _h ? _acc.withValues(alpha: 0.14) : _bg3.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: _h ? _acc.withValues(alpha: 0.4) : _bdr.withValues(alpha: 0.7),
              ),
            ),
            child: Icon(LucideIcons.plus,
                size: 14, color: _h ? _acc : _txt2),
          ),
        ),
      ),
    );
  }
}

class _TableHoverBtn extends StatefulWidget {
  final IconData icon;
  final String tip;
  final VoidCallback onTap;
  const _TableHoverBtn({required this.icon, required this.onTap, this.tip = ''});
  @override
  State<_TableHoverBtn> createState() => _TableHoverBtnState();
}

class _TableHoverBtnState extends State<_TableHoverBtn> {
  bool _h = false;
  @override
  Widget build(BuildContext context) {
    final btn = MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _h = true),
      onExit: (_) => setState(() => _h = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: _h
                ? AppTheme.red.withValues(alpha: 0.9)
                : _bg3.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(5),
            border: Border.all(
              color: _h
                  ? AppTheme.red.withValues(alpha: 0.6)
                  : _bdr.withValues(alpha: 0.8),
            ),
          ),
          child: Icon(widget.icon,
              size: 10, color: _h ? Colors.white : _txt2),
        ),
      ),
    );
    return widget.tip.isEmpty ? btn : Tooltip(message: widget.tip, child: btn);
  }
}

class _TableMiniBtn extends StatelessWidget {
  final IconData icon;
  final String tip;
  final VoidCallback onTap;
  const _TableMiniBtn({required this.icon, required this.tip, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(5),
        child: Padding(
          padding: const EdgeInsets.all(3),
          child: Icon(icon, size: 12, color: _txt2.withValues(alpha: 0.6)),
        ),
      ),
    );
  }
}

class _TableAddBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  const _TableAddBtn({required this.label, required this.icon, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: _bg3.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _bdr),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: _txt2),
            const SizedBox(width: 5),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: _txt1,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════ CODE COPY BTN ══════════════════
class _CodeCopyBtn extends StatefulWidget {
  final String text;
  const _CodeCopyBtn({required this.text});
  @override
  State<_CodeCopyBtn> createState() => _CodeCopyBtnState();
}

class _CodeCopyBtnState extends State<_CodeCopyBtn> {
  bool _copied = false;
  Timer? _t;

  @override
  void dispose() { _t?.cancel(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        await Clipboard.setData(ClipboardData(text: widget.text));
        setState(() => _copied = true);
        _t?.cancel();
        _t = Timer(const Duration(seconds: 2), () {
          if (mounted) setState(() => _copied = false);
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(
          color: _copied ? _grn.withValues(alpha: 0.15) : const Color(0xFF1A1A30),
          borderRadius: BorderRadius.circular(5),
          border: Border.all(
            color: _copied
                ? _grn.withValues(alpha: 0.4)
                : const Color(0xFFD4BBFF).withValues(alpha: 0.2),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _copied ? Icons.check_rounded : Icons.copy_rounded,
              size: 9,
              color: _copied ? _grn : const Color(0xFFD4BBFF),
            ),
            const SizedBox(width: 3),
            Text(
              _copied ? '복사됨' : '복사',
              style: GoogleFonts.jetBrainsMono(
                color: _copied ? _grn : const Color(0xFFD4BBFF),
                fontSize: 9,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════ EDITOR FORMAT BAR ══════════════
class _EditorFormatBar extends StatelessWidget {
  final int focusedIdx;
  final List<Block> blocks;
  final void Function(String fmt) onFormat;
  final void Function(BlockType) onTypeChange;

  const _EditorFormatBar({
    required this.focusedIdx,
    required this.blocks,
    required this.onFormat,
    required this.onTypeChange,
  });

  @override
  Widget build(BuildContext context) {
    if (focusedIdx < 0 || focusedIdx >= blocks.length) {
      return const SizedBox.shrink();
    }
    final currentType = blocks[focusedIdx].type;

    return AnimatedSize(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      child: focusedIdx < 0
          ? const SizedBox.shrink()
          : Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
              child: Container(
                height: 38,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: _bg2.withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _bdr.withValues(alpha: 0.7)),
                ),
                child: Row(
                  children: [
                    // 블록 타입 칩들
                    _FmtTypeChip(label: '텍스트', active: currentType == BlockType.text,
                        onTap: () => onTypeChange(BlockType.text)),
                    const SizedBox(width: 2),
                    _FmtTypeChip(label: 'H1', active: currentType == BlockType.h1,
                        onTap: () => onTypeChange(BlockType.h1)),
                    const SizedBox(width: 2),
                    _FmtTypeChip(label: 'H2', active: currentType == BlockType.h2,
                        onTap: () => onTypeChange(BlockType.h2)),
                    const SizedBox(width: 2),
                    _FmtTypeChip(label: 'H3', active: currentType == BlockType.h3,
                        onTap: () => onTypeChange(BlockType.h3)),
                    const SizedBox(width: 2),
                    _FmtTypeChip(label: '•', active: currentType == BlockType.bullet,
                        onTap: () => onTypeChange(BlockType.bullet)),
                    const SizedBox(width: 2),
                    _FmtTypeChip(label: '1.', active: currentType == BlockType.number,
                        onTap: () => onTypeChange(BlockType.number)),
                    const SizedBox(width: 2),
                    _FmtTypeChip(label: '✓', active: currentType == BlockType.checkbox,
                        onTap: () => onTypeChange(BlockType.checkbox)),
                    const SizedBox(width: 2),
                    _FmtTypeChip(label: '"', active: currentType == BlockType.quote,
                        onTap: () => onTypeChange(BlockType.quote)),
                    const SizedBox(width: 2),
                    _FmtTypeChip(label: '<>', active: currentType == BlockType.code,
                        onTap: () => onTypeChange(BlockType.code)),

                    // 구분선
                    Container(width: 1, height: 18, color: _bdr.withValues(alpha: 0.6),
                        margin: const EdgeInsets.symmetric(horizontal: 8)),

                    // 인라인 포맷 버튼
                    _FmtBtn(label: 'B', bold: true, tooltip: '굵게 (⌘B)',
                        onTap: () => onFormat('bold')),
                    const SizedBox(width: 2),
                    _FmtBtn(label: 'I', italic: true, tooltip: '기울임 (⌘I)',
                        onTap: () => onFormat('italic')),
                    const SizedBox(width: 2),
                    _FmtBtn(label: 'S', strike: true, tooltip: '취소선 (⌘⇧S)',
                        onTap: () => onFormat('strike')),
                    const SizedBox(width: 2),
                    _FmtBtn(label: '`', mono: true, tooltip: '인라인 코드 (⌘`)',
                        onTap: () => onFormat('code')),

                    const Spacer(),
                    // 단축키 힌트
                    Text('/ 블록추가  ·  ⌘B/I/⇧S/`',
                        style: GoogleFonts.inter(color: _txt2.withValues(alpha: 0.35), fontSize: 10)),
                  ],
                ),
              ),
            ),
    );
  }
}

class _FmtTypeChip extends StatefulWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _FmtTypeChip({required this.label, required this.active, required this.onTap});
  @override
  State<_FmtTypeChip> createState() => _FmtTypeChipState();
}

class _FmtTypeChipState extends State<_FmtTypeChip> {
  bool _h = false;
  @override
  Widget build(BuildContext context) => MouseRegion(
    onEnter: (_) => setState(() => _h = true),
    onExit: (_) => setState(() => _h = false),
    child: GestureDetector(
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: widget.active
              ? _acc.withValues(alpha: 0.18)
              : _h ? _bg4 : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: widget.active
                ? _acc.withValues(alpha: 0.4)
                : _h ? _bdr2 : Colors.transparent,
          ),
        ),
        child: Text(
          widget.label,
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: widget.active ? _acc : (_h ? _txt1 : _txt2),
          ),
        ),
      ),
    ),
  );
}

class _FmtBtn extends StatefulWidget {
  final String label;
  final String tooltip;
  final VoidCallback onTap;
  final bool bold, italic, strike, mono;
  const _FmtBtn({
    required this.label,
    required this.tooltip,
    required this.onTap,
    this.bold = false,
    this.italic = false,
    this.strike = false,
    this.mono = false,
  });
  @override
  State<_FmtBtn> createState() => _FmtBtnState();
}

class _FmtBtnState extends State<_FmtBtn> {
  bool _h = false;
  @override
  Widget build(BuildContext context) => Tooltip(
    message: widget.tooltip,
    child: MouseRegion(
      onEnter: (_) => setState(() => _h = true),
      onExit: (_) => setState(() => _h = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            color: _h ? _bg4 : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: _h ? _bdr2 : Colors.transparent),
          ),
          child: Center(
            child: Text(
              widget.label,
              style: (widget.mono ? GoogleFonts.jetBrainsMono : GoogleFonts.inter)(
                fontSize: 12,
                fontWeight: widget.bold ? FontWeight.w900 : FontWeight.w500,
                fontStyle: widget.italic ? FontStyle.italic : FontStyle.normal,
                decoration: widget.strike ? TextDecoration.lineThrough : null,
                decorationColor: _txt2,
                color: _h ? _txt0 : _txt2,
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

// ══════════════════ SLASH MENU ══════════════════════
class _Opt {
  final String id, label, hint, desc, group;
  final IconData icon;
  const _Opt(
    this.id,
    this.label,
    this.icon,
    this.hint, [
    this.desc = '',
    this.group = '',
  ]);
}

class _SlashMenu extends StatefulWidget {
  final List<_Opt> opts;
  final int sel;
  final bool isSearching;
  final void Function(_Opt) onSel;
  const _SlashMenu({
    required this.opts,
    required this.sel,
    required this.onSel,
    this.isSearching = false,
  });

  // 그룹 순서 정의
  static const _groupOrder = ['기본 블록', '목록', '특수'];

  @override
  State<_SlashMenu> createState() => _SlashMenuState();
}

class _SlashMenuState extends State<_SlashMenu> {
  final ScrollController _scroll = ScrollController();

  @override
  void didUpdateWidget(covariant _SlashMenu oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sel != widget.sel || oldWidget.opts != widget.opts) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToSelected());
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _scrollToSelected() {
    if (!_scroll.hasClients) return;
    final target = (widget.sel * 54.0 - 120).clamp(
      0.0,
      _scroll.position.maxScrollExtent,
    );
    _scroll.animateTo(
      target,
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];

    if (widget.isSearching || widget.opts.length <= 4) {
      // 검색 모드: 플랫 리스트
      for (int i = 0; i < widget.opts.length; i++) {
        children.add(
          _SI(
            key: ValueKey('slash-${widget.opts[i].id}'),
            opt: widget.opts[i],
            sel: i == widget.sel,
            onTap: () => widget.onSel(widget.opts[i]),
          ),
        );
      }
    } else {
      // 브라우즈 모드: 카테고리별 그룹
      final groups = <String, List<_Opt>>{};
      for (final o in widget.opts) {
        groups.putIfAbsent(o.group, () => []).add(o);
      }
      int globalIdx = 0;
      final orderedKeys = [
        ..._SlashMenu._groupOrder.where((g) => groups.containsKey(g)),
        ...groups.keys.where((g) => !_SlashMenu._groupOrder.contains(g)),
      ];
      for (final groupName in orderedKeys) {
        final groupOpts = groups[groupName]!;
        // 그룹 헤더
        children.add(
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
            child: Text(
              groupName,
              style: GoogleFonts.inter(
                color: _txt2,
                fontSize: 10,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.6,
              ),
            ),
          ),
        );
        for (final opt in groupOpts) {
          final idx = globalIdx;
          children.add(
            _SI(
              key: ValueKey('slash-${opt.id}'),
              opt: opt,
              sel: idx == widget.sel,
              onTap: () => widget.onSel(opt),
            ),
          );
          globalIdx++;
        }
      }
    }

    return Material(
      color: Colors.transparent,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            constraints: const BoxConstraints(maxHeight: 400),
            decoration: BoxDecoration(
              color: _bg2.withValues(alpha: 0.96),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _bdr2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.45),
                  blurRadius: 28,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: SingleChildScrollView(
              controller: _scroll,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 6),
                  ...children,
                  const SizedBox(height: 6),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ══════════════════ 인라인 선택 툴바 (노션 스타일) ══════════════════
class _SelToolbar extends StatefulWidget {
  final String selectedText;
  final TextEditingController controller;
  final VoidCallback onDismiss;
  final void Function(String) onReplaceText;
  const _SelToolbar({
    required this.selectedText,
    required this.controller,
    required this.onDismiss,
    required this.onReplaceText,
  });
  @override
  State<_SelToolbar> createState() => _SelToolbarState();
}

class _SelToolbarState extends State<_SelToolbar>
    with SingleTickerProviderStateMixin {
  late AnimationController _ac;
  late Animation<double> _fade, _scale;
  bool _aiMode = false;
  bool _loading = false;
  String _aiResult = '';

  static const _aiActions = [
    ('개선', 'improve', '더 명확하고 세련된 문장으로 개선해줘'),
    ('교정', 'proofread', '맞춤법과 문법을 교정해줘'),
    ('설명', 'explain', '이 내용을 쉽게 설명해줘. 3줄 이내로'),
    ('요약', 'summarize', '이 내용을 한 문장으로 요약해줘'),
    ('번역', 'translate', '이 내용을 영어로 번역해줘'),
    ('목록', 'bullet', '이 내용을 글머리 기호 목록으로 정리해줘'),
    ('공식체', 'formal', '이 내용을 공식적인 문체로 바꿔줘'),
    ('친근체', 'casual', '이 내용을 친근하고 자연스러운 문체로 바꿔줘'),
  ];

  @override
  void initState() {
    super.initState();
    _ac = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
    );
    _fade = CurvedAnimation(parent: _ac, curve: Curves.easeOut);
    _scale = Tween(
      begin: 0.92,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _ac, curve: Curves.easeOutCubic));
    _ac.forward();
  }

  @override
  void dispose() {
    _ac.dispose();
    super.dispose();
  }

  Future<void> _runAI(String instruction) async {
    setState(() {
      _loading = true;
      _aiResult = '';
    });
    try {
      final res = await http
          .post(
            Uri.parse('$baseUrl/api/ai/edit-selection'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'selected_text': widget.selectedText,
              'instruction': instruction,
            }),
          )
          .timeout(const Duration(seconds: 30));

      if (mounted && res.statusCode == 200) {
        final data = jsonDecode(utf8.decode(res.bodyBytes));
        final result = (data['result'] ?? '').toString().trim();
        setState(() {
          _aiResult = result.isNotEmpty ? result : '결과를 생성하지 못했습니다.';
          _loading = false;
        });
      } else {
        setState(() {
          _loading = false;
          _aiResult = '서버 오류가 발생했습니다.';
        });
      }
    } catch (e) {
      if (mounted)
        setState(() {
          _loading = false;
          _aiResult = '연결 오류';
        });
    }
  }

  // 볼드 토글
  void _toggleBold() {
    final c = widget.controller;
    final sel = c.selection;
    if (!sel.isValid || sel.isCollapsed) return;
    final selected = c.text.substring(sel.start, sel.end);
    final before = c.text.substring(0, sel.start);
    final after = c.text.substring(sel.end);
    final isBold = selected.startsWith('**') && selected.endsWith('**');
    final newText = isBold
        ? selected.substring(2, selected.length - 2)
        : '**$selected**';
    c.text = before + newText + after;
    c.selection = TextSelection(
      baseOffset: sel.start,
      extentOffset: sel.start + newText.length,
    );
    widget.onDismiss();
    widget.onReplaceText(c.text);
  }

  void _toggleItalic() {
    final c = widget.controller;
    final sel = c.selection;
    if (!sel.isValid || sel.isCollapsed) return;
    final selected = c.text.substring(sel.start, sel.end);
    final before = c.text.substring(0, sel.start);
    final after = c.text.substring(sel.end);
    final isItalic =
        selected.startsWith('*') &&
        selected.endsWith('*') &&
        !selected.startsWith('**');
    final newText = isItalic
        ? selected.substring(1, selected.length - 1)
        : '*$selected*';
    c.text = before + newText + after;
    c.selection = TextSelection(
      baseOffset: sel.start,
      extentOffset: sel.start + newText.length,
    );
    widget.onDismiss();
    widget.onReplaceText(c.text);
  }

  @override
  Widget build(BuildContext context) {
    // ✅ 단순 Container 반환 (Overlay에서 Positioned로 배치됨)
    return FadeTransition(
      opacity: _fade,
      child: ScaleTransition(
        scale: _scale,
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: _aiMode ? 340 : 404,
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF131A28),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _bdr.withValues(alpha: 0.9)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.34),
                    blurRadius: 28,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: _aiMode ? _buildAIMode() : _buildMainToolbar(),
            ),
          ),
        ),
      ),
    );
  }

  // ── 메인 툴바 ──────────────────────────────────────
  // Tooltip 없이 순수 버튼 (Overlay 중첩 문제 방지)
  Widget _selBtn(IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: Colors.white.withValues(alpha: 0.03),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: _txt1),
            if (label.isNotEmpty) ...[
              const SizedBox(width: 6),
              Text(
                label,
                style: GoogleFonts.inter(
                  color: _txt1,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMainToolbar() => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _selBtn(LucideIcons.bold, '', _toggleBold),
        const SizedBox(width: 6),
        _selBtn(LucideIcons.italic, '', _toggleItalic),
        const SizedBox(width: 6),
        _selBtn(LucideIcons.underline, '', () {
          final c = widget.controller;
          final sel = c.selection;
          if (!sel.isValid || sel.isCollapsed) return;
          final s = c.text.substring(sel.start, sel.end);
          widget.onReplaceText(
            c.text.substring(0, sel.start) +
                '__${s}__' +
                c.text.substring(sel.end),
          );
          widget.onDismiss();
        }),
        const SizedBox(width: 6),
        _selBtn(LucideIcons.strikethrough, '', () {
          final c = widget.controller;
          final sel = c.selection;
          if (!sel.isValid || sel.isCollapsed) return;
          final s = c.text.substring(sel.start, sel.end);
          widget.onReplaceText(
            c.text.substring(0, sel.start) +
                '~~${s}~~' +
                c.text.substring(sel.end),
          );
          widget.onDismiss();
        }),
        const SizedBox(width: 6),
        _selBtn(LucideIcons.code2, '', () {
          final c = widget.controller;
          final sel = c.selection;
          if (!sel.isValid || sel.isCollapsed) return;
          final s = c.text.substring(sel.start, sel.end);
          widget.onReplaceText(
            c.text.substring(0, sel.start) +
                '`${s}`' +
                c.text.substring(sel.end),
          );
          widget.onDismiss();
        }),
        Container(
          width: 1,
          height: 24,
          color: _bdr2,
          margin: const EdgeInsets.symmetric(horizontal: 8),
        ),
        _selBtn(LucideIcons.copy, '복사', () {
          Clipboard.setData(ClipboardData(text: widget.selectedText));
          widget.onDismiss();
        }),
        Container(
          width: 1,
          height: 24,
          color: _bdr2,
          margin: const EdgeInsets.symmetric(horizontal: 8),
        ),
        InkWell(
          onTap: () => setState(() => _aiMode = true),
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: _acc.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _acc.withValues(alpha: 0.28)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(LucideIcons.sparkles, size: 13, color: _acc),
                const SizedBox(width: 6),
                const Text(
                  'AI 편집',
                  style: TextStyle(
                    color: _acc,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 6),
        InkWell(
          onTap: widget.onDismiss,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: Colors.white.withValues(alpha: 0.03),
            ),
            child: const Icon(LucideIcons.x, size: 14, color: _txt2),
          ),
        ),
      ],
    ),
  );

  // ── AI 모드 ───────────────────────────────────────
  Widget _buildAIMode() => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      // 헤더
      Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 10, 10),
        child: Row(
          children: [
            GestureDetector(
              onTap: () => setState(() {
                _aiMode = false;
                _aiResult = '';
              }),
              child: const Icon(
                Icons.arrow_back_rounded,
                size: 14,
                color: _txt2,
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.auto_awesome_rounded, size: 13, color: _acc),
            const SizedBox(width: 6),
            const Text(
              'AI 편집',
              style: TextStyle(
                color: _acc,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            const Spacer(),
            GestureDetector(
              onTap: widget.onDismiss,
              child: const Icon(Icons.close_rounded, size: 14, color: _txt2),
            ),
          ],
        ),
      ),

      // 선택된 텍스트 미리보기
      Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 10),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: _bg3,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _bdr),
        ),
        child: Text(
          widget.selectedText.length > 80
              ? '${widget.selectedText.substring(0, 80)}...'
              : widget.selectedText,
          style: const TextStyle(color: _txt1, fontSize: 12, height: 1.5),
        ),
      ),

      // AI 결과 or 로딩
      if (_loading)
        const Padding(
          padding: EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 1.5, color: _acc),
              ),
              SizedBox(width: 10),
              Text('AI가 처리 중...', style: TextStyle(color: _txt2, fontSize: 12)),
            ],
          ),
        )
      else if (_aiResult.isNotEmpty)
        Column(
          children: [
            Container(
              margin: const EdgeInsets.fromLTRB(12, 0, 12, 10),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF0A1A06),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _acc.withValues(alpha: 0.3)),
              ),
              child: Text(
                _aiResult,
                style: const TextStyle(color: _txt0, fontSize: 13, height: 1.6),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _aiResult = '';
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          border: Border.all(color: _bdr2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Center(
                          child: Text(
                            '다시',
                            style: TextStyle(color: _txt2, fontSize: 12),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        widget.onReplaceText(_aiResult);
                        widget.onDismiss();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: _accD,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: _acc.withValues(alpha: 0.4),
                          ),
                        ),
                        child: const Center(
                          child: Text(
                            '적용',
                            style: TextStyle(
                              color: _acc,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        )
      else
        // AI 액션 버튼들
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: _aiActions
                .map(
                  (a) => GestureDetector(
                    onTap: () => _runAI(a.$3),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: _bg3,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: _bdr2),
                      ),
                      child: Text(
                        a.$1,
                        style: const TextStyle(
                          color: _txt1,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ),
    ],
  );
}

class _ToolBtn extends StatefulWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  const _ToolBtn({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });
  @override
  State<_ToolBtn> createState() => _ToolBtnState();
}

class _ToolBtnState extends State<_ToolBtn> {
  bool _h = false;
  @override
  Widget build(BuildContext context) => MouseRegion(
    onEnter: (_) => setState(() => _h = true),
    onExit: (_) => setState(() => _h = false),
    // ✅ Tooltip 제거 - CompositedTransformFollower 충돌 방지
    child: GestureDetector(
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
          color: _h ? _bg4 : Colors.transparent,
          borderRadius: BorderRadius.circular(7),
        ),
        child: Icon(widget.icon, size: 15, color: _h ? _txt0 : _txt1),
      ),
    ),
  );
}

class _SI extends StatefulWidget {
  final _Opt opt;
  final bool sel;
  final VoidCallback onTap;
  const _SI({
    super.key,
    required this.opt,
    required this.sel,
    required this.onTap,
  });
  @override
  State<_SI> createState() => _SIS();
}

class _SIS extends State<_SI> {
  bool _h = false;
  @override
  Widget build(BuildContext context) {
    final active = widget.sel || _h;
    return MouseRegion(
      onEnter: (_) => setState(() => _h = true),
      onExit: (_) => setState(() => _h = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: widget.sel
                ? _acc.withValues(alpha: 0.18)
                : _h
                    ? _bg4
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: active
                ? Border.all(
                    color: widget.sel
                        ? _acc.withValues(alpha: 0.8)
                        : _acc.withValues(alpha: 0.4),
                    width: widget.sel ? 2 : 1,
                  )
                : null,
            boxShadow: active
                ? [
                    BoxShadow(
                      color: _acc.withValues(alpha: widget.sel ? 0.22 : 0.12),
                      blurRadius: widget.sel ? 14 : 8,
                      spreadRadius: 0,
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 100),
                width: 3,
                height: 28,
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  color: widget.sel ? _acc : Colors.transparent,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              // 아이콘 컨테이너
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: active ? _accD : _bg3,
                  borderRadius: BorderRadius.circular(7),
                  border: Border.all(
                    color: active ? _acc.withValues(alpha: 0.35) : _bdr,
                  ),
                ),
                child: Icon(
                  widget.opt.icon,
                  size: 14,
                  color: active ? _acc : _txt1,
                ),
              ),
              const SizedBox(width: 10),
              // 라벨 + 설명
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.opt.label,
                      style: GoogleFonts.inter(
                        color: active ? _txt0 : _txt0.withValues(alpha: 0.8),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (widget.opt.desc.isNotEmpty)
                      Text(
                        widget.opt.desc,
                        style: GoogleFonts.inter(color: _txt2, fontSize: 11),
                      ),
                  ],
                ),
              ),
              // 단축키 힌트
              if (widget.opt.hint.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: _bg3,
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(color: _bdr2),
                  ),
                  child: Text(
                    widget.opt.hint,
                    style: GoogleFonts.jetBrainsMono(
                      color: _txt2,
                      fontSize: 10,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ══════════════════ TABS ════════════════════════════
class _Tabs extends StatelessWidget {
  final TabController ctrl;
  const _Tabs({required this.ctrl});
  @override
  Widget build(BuildContext context) => TabBar(
    controller: ctrl,
    isScrollable: true,
    tabAlignment: TabAlignment.start,
    dividerColor: Colors.transparent,
    indicator: BoxDecoration(
      gradient: LinearGradient(
        colors: [_acc.withValues(alpha: 0.22), _acc.withValues(alpha: 0.10)],
      ),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: _acc.withValues(alpha: 0.28)),
    ),
    indicatorSize: TabBarIndicatorSize.tab,
    labelColor: _txt0,
    unselectedLabelColor: _txt2,
    labelStyle: GoogleFonts.inter(
      fontSize: 11.5,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.1,
    ),
    unselectedLabelStyle: GoogleFonts.inter(
      fontSize: 11,
      fontWeight: FontWeight.w400,
    ),
    labelPadding: const EdgeInsets.symmetric(horizontal: 8),
    tabs: [
      _T(Icons.auto_awesome_rounded, '요약'),
      _T(Icons.manage_search_rounded, '분석'),
      _T(Icons.psychology_rounded, '암기'),
      _T(Icons.quiz_rounded, '퀴즈'),
      _T(Icons.chat_bubble_outline_rounded, '질문'),
      _T(Icons.sticky_note_2_outlined, '메모'),
    ],
  );
  Tab _T(IconData i, String t) => Tab(
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [Icon(i, size: 12), const SizedBox(width: 5), Text(t)],
    ),
  );
}

// ══════════════════ 요약 패널 ═══════════════════════
class _SumPanel extends StatelessWidget {
  final FileEditorState st;
  final WidgetRef ref;
  final TextEditingController tCtrl, gCtrl;
  final void Function(String) snack;
  final VoidCallback onChanged;
  const _SumPanel({
    required this.st,
    required this.ref,
    required this.tCtrl,
    required this.gCtrl,
    required this.snack,
    required this.onChanged,
  });
  @override
  Widget build(BuildContext context) => Column(
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 14, 10),
        child: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: _acc.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _acc.withValues(alpha: 0.18)),
              ),
              child: Icon(
                Icons.auto_awesome_rounded,
                size: 14,
                color: st.isSummaryLoading || st.summaryBlocks.isNotEmpty
                    ? _acc
                    : _txt2.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '요약',
                  style: GoogleFonts.inter(
                    color: _txt0,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                  ),
                ),
                if (st.isSummaryLoading && st.summaryProgress.isNotEmpty)
                  Text(
                    st.summaryProgress,
                    style: GoogleFonts.inter(
                      color: _txt2.withValues(alpha: 0.7),
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
              ],
            ),
            const Spacer(),
            if (st.isSummaryLoading)
              Container(
                width: 18,
                height: 18,
                padding: const EdgeInsets.all(3),
                child: CircularProgressIndicator(
                  color: _acc,
                  strokeWidth: 1.6,
                  strokeCap: StrokeCap.round,
                ),
              )
            else
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // PDF 내보내기 버튼
                  if (st.summaryBlocks.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: InkWell(
                        onTap: () async {
                          final content = st.summaryBlocks
                              .map((b) => b.content)
                              .join('\n\n---\n\n');
                          await exportMarkdownAsPdf(
                            content,
                            title: tCtrl.text.isEmpty ? '요약' : tCtrl.text,
                            filename: '${tCtrl.text.isEmpty ? "summary" : tCtrl.text}_요약.pdf',
                          );
                        },
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            color: _bg3.withValues(alpha: 0.82),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: _bdr.withValues(alpha: 0.9)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.picture_as_pdf_rounded,
                                  size: 12,
                                  color: _txt2.withValues(alpha: 0.6)),
                              const SizedBox(width: 4),
                              Text('PDF',
                                style: GoogleFonts.inter(
                                  color: _txt1,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                )),
                            ],
                          ),
                        ),
                      ),
                    ),
                  // 재요약 버튼
                  InkWell(
                    onTap: () async {
                      await ref
                          .read(fileEditorProvider.notifier)
                          .requestSummary(
                            title: tCtrl.text,
                            tags: gCtrl.text,
                            force: true,
                          );
                      onChanged();
                    },
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: _bg3.withValues(alpha: 0.82),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: _bdr.withValues(alpha: 0.9)),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.refresh_rounded,
                              size: 12,
                              color: _txt2.withValues(alpha: 0.6),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '재요약',
                              style: GoogleFonts.inter(
                                color: _txt1,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
      Container(height: 0.5, color: _bdr.withValues(alpha: 0.5)),
      Expanded(
        child: Stack(
          children: [
            if (st.summaryBlocks.isEmpty && !st.isSummaryLoading)
              const _Empty(
                icon: Icons.auto_awesome_rounded,
                title: '자동 요약',
                desc: '노트를 바탕으로\n요약을 생성합니다.',
              ),
            if (st.isSummaryLoading && st.summaryBlocks.isEmpty)
              const _Load('AI가 분석 중...'),
            ListView.builder(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 20),
              itemCount: st.summaryBlocks.length,
              itemBuilder: (_, i) => _SumCard(
                key: ValueKey('sc$i'),
                block: st.summaryBlocks[i],
                index: i,
                onPin: () {
                  ref.read(fileEditorProvider.notifier).toggleSummarySave(i);
                  onChanged();
                },
                onDel: () {
                  ref.read(fileEditorProvider.notifier).removeSummaryBlock(i);
                  onChanged();
                },
                onCopy: () {
                  Clipboard.setData(
                    ClipboardData(text: st.summaryBlocks[i].content),
                  );
                  snack('복사됨');
                },
                onExport: () async {
                  snack('확정 요약이 저장됩니다.');
                  ref.read(fileEditorProvider.notifier).toggleSummarySave(i);
                  onChanged();
                },
                onEdit: (content) {
                  ref
                      .read(fileEditorProvider.notifier)
                      .updateSummaryBlock(i, content);
                  onChanged();
                },
              ),
            ),
            if (st.isSummaryLoading && st.summaryBlocks.isNotEmpty)
              Positioned(
                bottom: 12,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: _bg3,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: _bdr2),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 11,
                          height: 11,
                          child: CircularProgressIndicator(
                            color: _acc,
                            strokeWidth: 1.5,
                            strokeCap: StrokeCap.round,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '업데이트 중...',
                          style: GoogleFonts.inter(color: _txt1, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    ],
  );
}

// ══════════════════ 요약 카드 ═══════════════════════
class _SumCard extends StatefulWidget {
  final SummaryBlock block;
  final int index;
  final VoidCallback onPin, onDel, onCopy, onExport;
  final void Function(String content) onEdit;
  const _SumCard({
    Key? key,
    required this.block,
    required this.index,
    required this.onPin,
    required this.onDel,
    required this.onCopy,
    required this.onExport,
    required this.onEdit,
  }) : super(key: key);
  @override
  State<_SumCard> createState() => _SCState();
}

class _SCState extends State<_SumCard> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    final pinned = widget.block.isSaved;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: pinned ? const Color(0xFF111C2E) : _bg3.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: pinned
              ? _acc.withValues(alpha: 0.34)
              : _bdr.withValues(alpha: 0.9),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
              child: Row(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: pinned ? _acc : _txt2.withValues(alpha: 0.25),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 7),
                  Text(
                    pinned ? 'PINNED' : 'LATEST',
                    style: TextStyle(
                      color: pinned ? _acc : _txt2.withValues(alpha: 0.6),
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const Spacer(),
                  _IB(
                    Icons.edit_outlined,
                    () async {
                      final ctrl = TextEditingController(
                        text: widget.block.content,
                      );
                      await showDialog(
                        context: context,
                        builder: (dialogContext) => StatefulBuilder(
                          builder: (ctx, setSt) => Dialog(
                            backgroundColor: AppTheme.bgSecondary,
                            insetPadding: const EdgeInsets.symmetric(
                              horizontal: 40, vertical: 60),
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(
                                maxWidth: 720, maxHeight: 680),
                              child: Padding(
                                padding: const EdgeInsets.all(24),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // ── 헤더 ─────────────────────
                                    Text('요약 수정', style: AppTheme.headingSmall),
                                    const SizedBox(height: 16),
                                    // ── 에디터 + 미리보기 (좌우 분할) ──
                                    Expanded(
                                      child: Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          // 왼쪽: 편집창
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text('편집',
                                                  style: GoogleFonts.inter(
                                                    color: _txt2,
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w600,
                                                    letterSpacing: 0.5,
                                                  )),
                                                const SizedBox(height: 6),
                                                Expanded(
                                                  child: TextField(
                                                    controller: ctrl,
                                                    maxLines: null,
                                                    expands: true,
                                                    textAlignVertical: TextAlignVertical.top,
                                                    style: GoogleFonts.inter(
                                                      color: AppTheme.textPrimary,
                                                      fontSize: 13,
                                                      height: 1.6,
                                                    ),
                                                    decoration: InputDecoration(
                                                      border: OutlineInputBorder(
                                                        borderSide: BorderSide(color: _bdr2),
                                                        borderRadius: BorderRadius.circular(8),
                                                      ),
                                                      enabledBorder: OutlineInputBorder(
                                                        borderSide: BorderSide(color: _bdr),
                                                        borderRadius: BorderRadius.circular(8),
                                                      ),
                                                      contentPadding: const EdgeInsets.all(12),
                                                    ),
                                                    onChanged: (_) => setSt(() {}),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 14),
                                          // 오른쪽: 마크다운 미리보기
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text('미리보기',
                                                  style: GoogleFonts.inter(
                                                    color: _txt2,
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w600,
                                                    letterSpacing: 0.5,
                                                  )),
                                                const SizedBox(height: 6),
                                                Expanded(
                                                  child: Container(
                                                    decoration: BoxDecoration(
                                                      color: _bg3.withValues(alpha: 0.6),
                                                      borderRadius: BorderRadius.circular(8),
                                                      border: Border.all(color: _bdr),
                                                    ),
                                                    padding: const EdgeInsets.all(12),
                                                    child: SingleChildScrollView(
                                                      child: MarkdownBody(
                                                        data: ctrl.text,
                                                        styleSheet: _md(),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    // ── 버튼 ─────────────────────
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        SFButton(
                                          label: '취소',
                                          outlined: true,
                                          onPressed: () =>
                                              Navigator.pop(dialogContext),
                                        ),
                                        const SizedBox(width: 8),
                                        SFButton(
                                          label: '저장',
                                          onPressed: () {
                                            widget.onEdit(ctrl.text.trim());
                                            Navigator.pop(dialogContext);
                                          },
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                    color: _txt2.withValues(alpha: 0.5),
                    sz: 12,
                  ),
                  const SizedBox(width: 1),
                  _IB(
                    Icons.content_copy_rounded,
                    widget.onCopy,
                    color: _txt2.withValues(alpha: 0.5),
                    sz: 12,
                  ),
                  const SizedBox(width: 1),
                  _IB(
                    Icons.save_outlined,
                    widget.onExport,
                    color: pinned ? _acc : _txt2.withValues(alpha: 0.5),
                    sz: 12,
                  ),
                  const SizedBox(width: 1),
                  _IB(
                    pinned ? Icons.push_pin : Icons.push_pin_outlined,
                    widget.onPin,
                    color: pinned ? _acc : _txt2.withValues(alpha: 0.5),
                    sz: 12,
                  ),
                  const SizedBox(width: 1),
                  _IB(
                    Icons.close_rounded,
                    widget.onDel,
                    color: _txt2.withValues(alpha: 0.5),
                    sz: 12,
                  ),
                  const SizedBox(width: 2),
                  AnimatedRotation(
                    turns: _expanded ? 0 : 0.5,
                    duration: const Duration(milliseconds: 150),
                    child: Icon(
                      Icons.expand_less_rounded,
                      size: 14,
                      color: _txt2.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Container(
            height: 0.5,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.transparent,
                  pinned
                      ? _acc.withValues(alpha: 0.12)
                      : _bdr.withValues(alpha: 0.45),
                  Colors.transparent,
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 180),
            crossFadeState: _expanded
                ? CrossFadeState.showFirst
                : CrossFadeState.showSecond,
            firstChild: Padding(
              padding: const EdgeInsets.all(16),
              child: MarkdownBody(
                data: widget.block.content,
                styleSheet: _md(),
              ),
            ),
            secondChild: const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

// ══════════════════ 분석 패널 ═══════════════════════
class _AnaPanel extends StatelessWidget {
  final FileEditorState st;
  const _AnaPanel({required this.st});
  @override
  Widget build(BuildContext context) => Column(
    children: [
      AnimatedSize(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        child: st.focusedText.trim().isNotEmpty
            ? Container(
                margin: const EdgeInsets.fromLTRB(14, 14, 14, 0),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: st.isAnalysisLoading
                      ? _acc.withValues(alpha: 0.08)
                      : _bg3.withValues(alpha: 0.88),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: st.isAnalysisLoading
                        ? _acc.withValues(alpha: 0.4)
                        : _bdr.withValues(alpha: 0.9),
                    width: st.isAnalysisLoading ? 1.5 : 1.0,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 26,
                          height: 26,
                          decoration: BoxDecoration(
                            color: _acc.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: _acc.withValues(alpha: 0.18),
                            ),
                          ),
                          child: st.isAnalysisLoading
                              ? const Padding(
                                  padding: EdgeInsets.all(6),
                                  child: CircularProgressIndicator(
                                    strokeWidth: 1.8,
                                    color: _acc,
                                  ),
                                )
                              : const Icon(
                                  Icons.manage_search_rounded,
                                  color: _acc,
                                  size: 13,
                                ),
                        ),
                        const SizedBox(width: 9),
                        Text(
                          st.isAnalysisLoading ? 'AI 분석 중...' : '분석한 문단',
                          style: TextStyle(
                            color: st.isAnalysisLoading ? _acc : _txt0,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.1,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      st.focusedText,
                      style: const TextStyle(
                        color: _txt1,
                        fontSize: 13,
                        height: 1.5,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              )
            : const SizedBox.shrink(),
      ),
      Expanded(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          // ✅ key로 강제 리빌드 — isAnalysisLoading 변경 시 AnimatedSwitcher가 새 위젯으로 인식
          child: st.isAnalysisLoading
              ? const _Load('문단 분석 중...')
              : st.currentAnalysis?.isNotEmpty == true
              ? KeyedSubtree(
                  key: ValueKey(st.currentAnalysis),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(14, 16, 14, 40),
                    child: MarkdownBody(
                      data: st.currentAnalysis!,
                      styleSheet: _md(),
                    ),
                  ),
                )
              : const _Empty(
                  icon: Icons.manage_search_rounded,
                  title: '문단 분석',
                  desc: '에디터 문단을 클릭하면\nAI가 즉시 분석합니다.',
                ),
        ),
      ),
    ],
  );
}

// ══════════════════ 암기/퀴즈/ASK ═══════════════════
class _MemoPanel extends StatelessWidget {
  final FileEditorState st;
  final WidgetRef ref;
  final TextEditingController tCtrl;
  const _MemoPanel({required this.st, required this.ref, required this.tCtrl});
  @override
  Widget build(BuildContext context) => Stack(
    children: [
      if (st.currentMemo == null && !st.isMemoLoading)
        const _Empty(
          icon: Icons.psychology_rounded,
          title: '핵심 암기',
          desc: '본문에서 핵심 개념을\n자동 추출합니다.',
        ),
      if (st.currentMemo?.isNotEmpty == true)
        SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 120),
          child: MarkdownBody(data: st.currentMemo!, styleSheet: _md()),
        ),
      _Fade(),
      if (st.currentMemo == null || st.isMemoLoading)
        Positioned(
          bottom: 16,
          left: 14,
          right: 14,
          child: _FABtn(
            loading: st.isMemoLoading,
            label: '암기 노트 생성',
            icon: Icons.lightbulb_rounded,
            onTap: () =>
                ref.read(fileEditorProvider.notifier).generateMemo(tCtrl.text),
          ),
        ),
    ],
  );
}

// ══════════════════ 메모 패널 (자유 입력 노트) ═══════════════════
class _NotePanel extends StatefulWidget {
  final FileEditorState st;
  final WidgetRef ref;
  final VoidCallback onChanged;
  const _NotePanel({
    required this.st,
    required this.ref,
    required this.onChanged,
  });
  @override
  State<_NotePanel> createState() => _NotePanelState();
}

class _NotePanelState extends State<_NotePanel> {
  late final TextEditingController _ctrl;
  final FocusNode _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.st.userMemo);
  }

  @override
  void didUpdateWidget(covariant _NotePanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 서버에서 메모가 늦게 로드되거나 동기화될 때 — 편집 중이 아니면 반영
    final incoming = widget.st.userMemo;
    if (!_focus.hasFocus && incoming != _ctrl.text) {
      _ctrl.text = incoming;
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
      child: TextField(
        controller: _ctrl,
        focusNode: _focus,
        maxLines: null,
        expands: true,
        textAlignVertical: TextAlignVertical.top,
        keyboardType: TextInputType.multiline,
        cursorColor: _acc,
        style: GoogleFonts.inter(
          fontSize: 15,
          height: 1.7,
          color: _txt0,
          letterSpacing: -0.1,
        ),
        decoration: InputDecoration(
          isCollapsed: true,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          filled: false,
          hintText: '이 자료에 대한 메모를 자유롭게 작성하세요.\n언제든 자동 저장됩니다.',
          hintStyle: GoogleFonts.inter(
            fontSize: 15,
            height: 1.7,
            color: _txt2.withValues(alpha: 0.5),
            letterSpacing: -0.1,
          ),
        ),
        onChanged: (v) {
          widget.ref.read(fileEditorProvider.notifier).setMemo(v);
          widget.onChanged(); // 디바운스 저장 트리거
        },
      ),
    );
  }
}

class _QuizPanel extends StatefulWidget {
  final FileEditorState st;
  final WidgetRef ref;
  final String fileId;
  final String projectId;
  const _QuizPanel({
    required this.st,
    required this.ref,
    required this.fileId,
    required this.projectId,
  });
  @override
  State<_QuizPanel> createState() => _QuizPanelState();
}

class _QuizPanelState extends State<_QuizPanel>
    with SingleTickerProviderStateMixin {
  bool _cardMode = false;
  int _cardIdx = 0;
  bool _flipped = false;
  late AnimationController _flipAc;
  late Animation<double> _flipAnim;
  bool _saving = false;
  bool _saved = false;

  @override
  void initState() {
    super.initState();
    _flipAc = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _flipAnim = Tween(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _flipAc, curve: Curves.easeInOutCubic));
  }

  @override
  void dispose() {
    _flipAc.dispose();
    super.dispose();
  }

  void _flip() {
    setState(() => _flipped = !_flipped);
    _flipped ? _flipAc.forward() : _flipAc.reverse();
  }

  void _next() {
    final quiz = widget.st.quizData ?? [];
    if (_cardIdx < quiz.length - 1) {
      setState(() {
        _cardIdx++;
        _flipped = false;
      });
      _flipAc.reverse();
    }
  }

  void _prev() {
    if (_cardIdx > 0) {
      setState(() {
        _cardIdx--;
        _flipped = false;
      });
      _flipAc.reverse();
    }
  }

  Future<void> _saveResult() async {
    final st = widget.st;
    final quiz = st.quizData ?? [];
    final answers = st.quizAnswers;
    if (quiz.isEmpty || _saving || _saved) return;

    // 점수 계산
    int score = 0;
    for (int i = 0; i < quiz.length; i++) {
      final correct = quiz[i]['answer'];
      if (answers[i] != null && answers[i] == correct) score++;
    }

    final userId = widget.ref.read(userProvider)?.id ?? '';
    if (userId.isEmpty) return;

    setState(() => _saving = true);
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/api/flow/quiz-attempt'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_id': userId,
          'file_id': widget.fileId,
          'project_id': widget.projectId,
          'score': score,
          'total': quiz.length,
        }),
      );
      if (res.statusCode == 200 || res.statusCode == 201) {
        setState(() => _saved = true);
      }
    } catch (_) {}
    setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    final st = widget.st;
    final ref = widget.ref;

    if (_cardMode && (st.quizData?.isNotEmpty ?? false)) {
      return _buildCardMode(st);
    }
    return _buildListMode(st, ref);
  }

  Widget _buildCardMode(FileEditorState st) {
    final quiz = st.quizData ?? [];
    if (quiz.isEmpty)
      return const _Empty(
        icon: Icons.quiz_rounded,
        title: '퀴즈 없음',
        desc: '먼저 퀴즈를 생성하세요.',
      );
    final q = quiz[_cardIdx];
    final question = q['question']?.toString() ?? '';
    final answer = q['options'] != null && q['answer'] != null
        ? (q['options'] as List)[q['answer']]?.toString() ?? ''
        : '';
    final explanation = q['explanation']?.toString() ?? '';

    return Column(
      children: [
        // 헤더
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
          child: Row(
            children: [
              Text(
                '${_cardIdx + 1} / ${quiz.length}',
                style: GoogleFonts.inter(
                  color: _txt2,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () => setState(() {
                  _cardMode = false;
                  _cardIdx = 0;
                  _flipped = false;
                }),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _bg3,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: _bdr2),
                  ),
                  child: Text(
                    '목록 보기',
                    style: GoogleFonts.inter(
                      color: _txt2,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        // 진행 바
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: ((_cardIdx + 1) / quiz.length).clamp(0.0, 1.0),
              backgroundColor: _bg4,
              color: _acc,
              minHeight: 3,
            ),
          ),
        ),
        const SizedBox(height: 12),
        // 플래시카드
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 0),
            child: GestureDetector(
              onTap: _flip,
              child: AnimatedBuilder(
                animation: _flipAnim,
                builder: (_, __) {
                  final isBack = _flipAnim.value > 0.5;
                  final angle = _flipAnim.value * math.pi;
                  return Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.identity()
                      ..setEntry(3, 2, 0.001)
                      ..rotateY(angle),
                    child: Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: isBack ? const Color(0xFF1A2508) : _bg3,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: isBack ? _acc.withValues(alpha: 0.4) : _bdr2,
                          width: isBack ? 1.5 : 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                          if (isBack)
                            BoxShadow(
                              color: _acc.withValues(alpha: 0.08),
                              blurRadius: 30,
                            ),
                        ],
                      ),
                      child: isBack
                          ? Transform(
                              alignment: Alignment.center,
                              transform: Matrix4.identity()..rotateY(math.pi),
                              child: Padding(
                                padding: const EdgeInsets.all(24),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.check_circle_outline_rounded,
                                      color: _acc,
                                      size: 22,
                                    ),
                                    const SizedBox(height: 14),
                                    Text(
                                      answer,
                                      textAlign: TextAlign.center,
                                      style: GoogleFonts.inter(
                                        color: _acc,
                                        fontSize: 17,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    if (explanation.isNotEmpty) ...[
                                      const SizedBox(height: 12),
                                      Container(
                                        height: 0.5,
                                        color: _acc.withValues(alpha: 0.2),
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        explanation,
                                        textAlign: TextAlign.center,
                                        style: GoogleFonts.inter(
                                          color: _txt1,
                                          fontSize: 13,
                                          height: 1.6,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            )
                          : Padding(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _accD,
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: _acc.withValues(alpha: 0.3),
                                      ),
                                    ),
                                    child: Text(
                                      'Q',
                                      style: GoogleFonts.inter(
                                        color: _acc,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    question,
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.inter(
                                      color: _txt0,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      height: 1.6,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    '탭하여 답 확인',
                                    style: GoogleFonts.inter(
                                      color: _txt2,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
        // 이전/다음 버튼
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 16),
          child: Row(
            children: [
              GestureDetector(
                onTap: _cardIdx > 0 ? _prev : null,
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _cardIdx > 0 ? _bg3 : _bg2,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _bdr),
                  ),
                  child: Icon(
                    Icons.arrow_back_rounded,
                    size: 16,
                    color: _cardIdx > 0 ? _txt1 : _txt2.withValues(alpha: 0.3),
                  ),
                ),
              ),
              const Spacer(),
              Text(
                _flipped ? '다음 카드로 →' : '탭하여 뒤집기',
                style: GoogleFonts.inter(color: _txt2, fontSize: 11),
              ),
              const Spacer(),
              GestureDetector(
                onTap: _cardIdx < (st.quizData?.length ?? 1) - 1 ? _next : null,
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _cardIdx < (st.quizData?.length ?? 1) - 1
                        ? _bg3
                        : _bg2,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _bdr),
                  ),
                  child: Icon(
                    Icons.arrow_forward_rounded,
                    size: 16,
                    color: _cardIdx < (st.quizData?.length ?? 1) - 1
                        ? _txt1
                        : _txt2.withValues(alpha: 0.3),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildListMode(FileEditorState st, WidgetRef ref) {
    return Stack(
      children: [
        if (st.quizData == null && !st.isQuizLoading)
          const _Empty(
            icon: Icons.quiz_rounded,
            title: '인터랙티브 퀴즈',
            desc: '학습 내용으로 객관식\n퀴즈를 생성합니다.',
          ),
        if (st.quizData != null)
          Column(
            children: [
              // 카드 모드 토글 버튼
              if (st.quizData!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
                  child: Row(
                    children: [
                      Text(
                        '${st.quizData!.length}문제',
                        style: GoogleFonts.inter(color: _txt2, fontSize: 11),
                      ),
                      const Spacer(),
                      GestureDetector(
                        onTap: () => setState(() {
                          _cardMode = true;
                          _cardIdx = 0;
                          _flipped = false;
                        }),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: _accD,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: _acc.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.style_rounded, size: 11, color: _acc),
                              const SizedBox(width: 5),
                              Text(
                                '카드 모드',
                                style: GoogleFonts.inter(
                                  color: _acc,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 120),
                  itemCount: st.quizData!.length,
                  itemBuilder: (_, qi) => _QCard(
                    q: st.quizData![qi],
                    qi: qi,
                    answered: st.quizAnswers[qi],
                    onAns: (oi) => ref
                        .read(fileEditorProvider.notifier)
                        .answerQuiz(qi, oi),
                  ),
                ),
              ),
            ],
          ),
        _Fade(),
        if (st.quizData == null || st.isQuizLoading)
          Positioned(
            bottom: 16,
            left: 14,
            right: 14,
            child: _FABtn(
              loading: st.isQuizLoading,
              label: '퀴즈 생성',
              icon: Icons.quiz_rounded,
              onTap: () => ref.read(fileEditorProvider.notifier).generateQuiz(),
            ),
          ),
        // 모든 문제 답했을 때 결과 저장 버튼
        if (st.quizData != null &&
            st.quizData!.isNotEmpty &&
            st.quizAnswers.length == st.quizData!.length)
          Positioned(
            bottom: 16,
            left: 14,
            right: 14,
            child: _QuizResultBar(
              quiz: st.quizData!,
              answers: st.quizAnswers,
              saving: _saving,
              saved: _saved,
              onSave: _saveResult,
            ),
          ),
      ],
    );
  }
}

class _QCard extends StatelessWidget {
  final dynamic q;
  final int qi;
  final int? answered;
  final void Function(int) onAns;
  const _QCard({
    required this.q,
    required this.qi,
    required this.answered,
    required this.onAns,
  });

  @override
  Widget build(BuildContext context) {
    final correct = q['answer'] ?? 0;
    final options = q['options'] as List;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _bg3.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _bdr.withValues(alpha: 0.9)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Q${qi + 1}.  ${q['question']}',
            style: GoogleFonts.inter(
              color: _txt0,
              fontSize: 14,
              fontWeight: FontWeight.w600,
              height: 1.55,
              letterSpacing: -0.1,
            ),
          ),
          const SizedBox(height: 14),
          ...List.generate(options.length, (oi) {
            Color bg = _bg3, bdr = _bdr, tc = _txt0;
            if (answered != null) {
              if (oi == correct) {
                bg = _grn.withValues(alpha: 0.1);
                bdr = _grn.withValues(alpha: 0.4);
                tc = const Color(0xFFCFF4D8);
              } else if (oi == answered) {
                bg = _red.withValues(alpha: 0.1);
                bdr = _red.withValues(alpha: 0.4);
                tc = const Color(0xFFFFD4CF);
              }
            }
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: GestureDetector(
                onTap: () => onAns(oi),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                    vertical: 12,
                    horizontal: 16,
                  ),
                  decoration: BoxDecoration(
                    color: bg.withValues(alpha: answered == null ? 0.82 : 1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: bdr),
                  ),
                  child: Text(
                    options[oi],
                    style: TextStyle(
                      color: tc,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            );
          }),
          // 해설
          if (answered != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _bg2.withValues(alpha: 0.75),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _bdr.withValues(alpha: 0.85)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        answered == correct
                            ? Icons.check_circle_rounded
                            : Icons.cancel_rounded,
                        size: 14,
                        color: answered == correct ? _grn : _red,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        answered == correct ? '정답' : '오답',
                        style: TextStyle(
                          color: answered == correct ? _grn : _red,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    q['explanation'] ?? '',
                    style: const TextStyle(
                      color: _txt1,
                      fontSize: 12,
                      height: 1.6,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── 퀴즈 결과 저장 바 ──────────────────────────────────────────
class _QuizResultBar extends StatelessWidget {
  final List<dynamic> quiz;
  final Map<int, int> answers;
  final bool saving;
  final bool saved;
  final VoidCallback onSave;
  const _QuizResultBar({
    required this.quiz,
    required this.answers,
    required this.saving,
    required this.saved,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    int correct = 0;
    for (int i = 0; i < quiz.length; i++) {
      if (answers[i] != null && answers[i] == quiz[i]['answer']) correct++;
    }
    final pct = (correct / quiz.length * 100).round();
    final isGood = pct >= 70;
    final color = pct >= 80
        ? _grn
        : pct >= 60
        ? _yel
        : _red;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: _bg2,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.35)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                '$pct%',
                style: GoogleFonts.inter(
                  color: color,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  isGood ? '잘 하셨어요! 🎉' : '조금 더 공부해봐요',
                  style: GoogleFonts.inter(
                    color: _txt0,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$correct / ${quiz.length} 정답',
                  style: GoogleFonts.inter(color: _txt2, fontSize: 11),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: saved ? null : onSave,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: saved
                    ? _grn.withValues(alpha: 0.18)
                    : _acc.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: saved
                      ? _grn.withValues(alpha: 0.4)
                      : _acc.withValues(alpha: 0.4),
                ),
              ),
              child: saving
                  ? SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: _acc,
                      ),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          saved ? Icons.check_rounded : Icons.save_rounded,
                          size: 14,
                          color: saved ? _grn : _acc,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          saved ? '저장됨' : '결과 저장',
                          style: GoogleFonts.inter(
                            color: saved ? _grn : _acc,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AskPanel extends StatelessWidget {
  final FileEditorState st;
  final TextEditingController ctrl;
  final void Function(String) onAsk;
  const _AskPanel({required this.st, required this.ctrl, required this.onAsk});
  @override
  Widget build(BuildContext context) => Column(
    children: [
      Expanded(
        child: st.isQALoading
            ? const _Load('검색 중...')
            : st.qaAnswer != null
            ? SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(14, 16, 14, 20),
                child: MarkdownBody(data: st.qaAnswer!, styleSheet: _md()),
              )
            : const _Empty(
                icon: Icons.chat_bubble_outline_rounded,
                title: '빠른 질문',
                desc: '내 노트 + 웹으로\n무엇이든 답합니다.',
              ),
      ),
      Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
        decoration: BoxDecoration(
          color: _bg2.withValues(alpha: 0.92),
          border: const Border(top: BorderSide(color: _bdr)),
        ),
        child: Row(
          children: [
            Expanded(
              child: AppInput(
                controller: ctrl,
                hintText: '노트에 대해 물어보세요',
                onSubmitted: (v) {
                  onAsk(v);
                  ctrl.clear();
                },
              ),
            ),
            const SizedBox(width: 8),
            AppButton(
              label: '질문',
              icon: LucideIcons.arrowUp,
              onPressed: () {
                onAsk(ctrl.text);
                ctrl.clear();
              },
            ),
          ],
        ),
      ),
    ],
  );
}

// ══════════════════ 마인드맵 뷰 ═════════════════════
class _MindmapView extends StatelessWidget {
  final FileEditorState st;
  final WidgetRef ref;
  final VoidCallback onChanged;
  const _MindmapView({
    required this.st,
    required this.ref,
    required this.onChanged,
  });
  bool get _hasNodes {
    final nodes = st.graphData?['nodes'] as List?;
    return nodes != null && nodes.isNotEmpty;
  }

  void _generate() {
    ref.read(fileEditorProvider.notifier).requestGraph().then((_) {
      onChanged();
    });
  }

  int get _nodeCount => (st.graphData?['nodes'] as List?)?.length ?? 0;

  @override
  Widget build(BuildContext context) {
    final canvas = st.isGraphLoading
        ? const _GraphLoadingCanvas()
        : _hasNodes
            ? _GraphCanvas(data: st.graphData!, ref: ref, onChanged: onChanged)
            : _GraphEmptyState(onGenerate: _generate, errorMessage: st.graphError);

    return Stack(
      children: [
        // ── 풀스크린 캔버스 ────────────────────────────────
        Positioned.fill(child: canvas),

        // ── 좌상단 플로팅 정보 칩 ─────────────────────────
        Positioned(
          top: 14,
          left: 14,
          child: _GraphInfoChip(
            nodeCount: _nodeCount,
            blockCount: st.blocks.length,
          ),
        ),

        // ── 우상단 재생성 버튼 ────────────────────────────
        if (!st.isGraphLoading)
          Positioned(
            top: 14,
            right: 14,
            child: _GraphRegenBtn(
              hasData: _hasNodes,
              onTap: _generate,
            ),
          ),
      ],
    );
  }
}

class _GraphCanvas extends StatefulWidget {
  final Map<String, dynamic> data;
  final WidgetRef ref;
  final VoidCallback onChanged;
  const _GraphCanvas({
    required this.data,
    required this.ref,
    required this.onChanged,
  });
  @override
  State<_GraphCanvas> createState() => _GCS();
}

class _GCS extends State<_GraphCanvas> {
  Size _boardSize = const Size(3000, 2000);
  late final TransformationController _controller;
  final GlobalKey _boardKey = GlobalKey(); // 마인드맵 PDF 캡처용
  List<_GraphNodeLayout> ns = [];
  List<_GE> es = [];
  String? _connectSourceId;
  String? _selectedNodeId;
  bool _isTreeLayout = true;  // 기본값: 트리 레이아웃 (노드 많아도 보기 좋음)
  final Set<String> _collapsed = {}; // 접힌(자식 숨김) 노드 id
  Set<String> _hasKids = {};         // 자식이 있는 노드 id (펼침/접기 토글 표시용)
  bool _initCollapsed = false;       // 최초 1회: 1레벨만 보이도록 전부 접기

  @override
  void initState() {
    super.initState();
    _controller = TransformationController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _build();
      if (mounted) _centerOnCore();
    });
  }

  @override
  void didUpdateWidget(covariant _GraphCanvas oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!mapEquals(oldWidget.data, widget.data)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _build();
      });
    }
  }

  // ── 분할 레벨-정다각형법 ─────────────────────────────────────
  // 노드 물리 크기(반변) — 경계 충돌 판정에 사용
  static double _nodeHalfSide(_GraphCardStyle style) => switch (style) {
    _GraphCardStyle.core      => 140.0,
    _GraphCardStyle.branch    => 112.0,
    _GraphCardStyle.subcluster => 94.0,
    _GraphCardStyle.noteWide  => 94.0,
    _GraphCardStyle.note      => 84.0,
  };

  static _GraphCardStyle _styleForDepth(int depth) {
    if (depth == 0) return _GraphCardStyle.core;
    if (depth == 1) return _GraphCardStyle.branch;
    if (depth == 2) return _GraphCardStyle.subcluster;
    if (depth == 3) return _GraphCardStyle.noteWide;
    return _GraphCardStyle.note;
  }

  // univai 스타일 알약 노드 — 작고 가로로 일정한 크기 (반사형 보조용)
  static Size _sizeForStyle(_GraphCardStyle style) => switch (style) {
    _GraphCardStyle.core       => const Size(210, 60),
    _GraphCardStyle.branch     => const Size(196, 54),
    _GraphCardStyle.subcluster => const Size(188, 50),
    _GraphCardStyle.noteWide   => const Size(188, 50),
    _GraphCardStyle.note       => const Size(180, 48),
  };

  /// 라벨 텍스트를 실제 측정해 알약 크기를 계산한다(글자 잘림 방지).
  /// 우측 펼침/접기 토글 공간도 폭에 포함한다.
  static Size _measureNodeSize(
    String label,
    _GraphCardStyle style,
    bool hasChildren,
  ) {
    final isCore = style == _GraphCardStyle.core;
    final fontSize = isCore ? 15.0 : 13.5;
    const hPad = 14.0; // 좌우 패딩
    const vPad = 9.0;  // 상하 패딩
    final toggleW = hasChildren ? 29.0 : 0.0; // 토글칩(22) + 간격(7)
    const maxContentW = 200.0; // 라벨 최대 폭 → 넘으면 2줄

    final tp = TextPainter(
      text: TextSpan(
        text: label.isEmpty ? ' ' : label,
        style: GoogleFonts.inter(
          fontSize: fontSize,
          fontWeight: isCore ? FontWeight.w800 : FontWeight.w600,
          height: 1.3,
          letterSpacing: -0.3,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 2,
      ellipsis: '…',
    )..layout(maxWidth: maxContentW);

    // 한글 폰트(Inter 폴백) 메트릭 오차로 측정값이 작게 나올 수 있어 여유를 둔다.
    final w = (tp.width + hPad * 2 + toggleW + 8).clamp(110.0, 262.0);
    final h = (tp.height + vPad * 2 + 10).clamp(46.0, 104.0);
    return Size(w, h);
  }

  /// 바텀업: 각 노드의 서브트리 경계 반지름을 계산한다.
  /// 경계 = 해당 노드를 루트로 하는 서브트리 전체를 포함하는
  ///         원의 반지름 (노드 중심 기준).
  static Map<String, double> _computeBoundaries(
    String rootId,
    Map<String, List<String>> childrenMap,
    Map<String, double> halfSide,
  ) {
    final boundary = <String, double>{};
    final visited = <String>{};

    void compute(String id) {
      if (visited.contains(id)) return;
      visited.add(id);

      final a = halfSide[id] ?? 72.0; // 이 노드의 반변
      final children = childrenMap[id] ?? [];

      if (children.isEmpty) {
        // 말단 노드: 경계 = 노드 반대각선 (√2 · a)
        boundary[id] = a * math.sqrt2;
        return;
      }

      for (final cid in children) {
        compute(cid);
      }

      final n = children.length;
      final maxCB = children.fold(0.0, (prev, c) => math.max(prev, boundary[c] ?? a));

      double r;
      if (n == 1) {
        // 자식 1개: 충분한 간격만 확보
        r = math.max(2 * math.sqrt2 * a, a + maxCB * 1.3 + 20);
      } else {
        // n-gon 조건 (분할 다각형법)
        // θ = 2π/n (인접 자식 사이의 각도)
        final theta = 2 * math.pi / n;
        final sinHalf = math.sin(theta / 2); // 반각 사인 — 현의 절반
        // 조건 1: 부모-자식 비겹침 → r > 2√2·a_parent
        final r1 = 2 * math.sqrt2 * a;
        // 조건 2: 인접 자식 서브트리 비겹침 → 2r·sin(θ/2) > 2·maxCB
        //          → r > maxCB / sin(θ/2)
        final r2 = sinHalf > 1e-6 ? maxCB / sinHalf : double.infinity;
        r = math.max(r1, r2) * 1.15; // 15% 여유
        r = r.clamp(80.0, 3000.0);
      }

      boundary[id] = r + maxCB;
    }

    compute(rootId);
    return boundary;
  }

  /// 탑다운: 루트를 (0,0)으로 놓고 재귀적으로 자식 위치를 배정한다.
  static Map<String, Offset> _placeNodes(
    String rootId,
    Map<String, List<String>> childrenMap,
    Map<String, double> halfSide,
    Map<String, double> boundary,
  ) {
    final positions = <String, Offset>{};
    final visited = <String>{};

    void place(String id, Offset pos) {
      if (visited.contains(id)) return;
      visited.add(id);
      positions[id] = pos;

      final children = childrenMap[id] ?? [];
      if (children.isEmpty) return;

      final n = children.length;
      final a = halfSide[id] ?? 72.0;
      final maxCB = children.fold(0.0, (prev, c) => math.max(prev, boundary[c] ?? a));

      double r;
      if (n == 1) {
        r = math.max(2 * math.sqrt2 * a, a + maxCB * 1.3 + 20);
      } else {
        final theta = 2 * math.pi / n;
        final sinHalf = math.sin(theta / 2);
        final r1 = 2 * math.sqrt2 * a;
        final r2 = sinHalf > 1e-6 ? maxCB / sinHalf : double.infinity;
        r = math.max(r1, r2) * 1.15;
        r = r.clamp(80.0, 3000.0);
      }

      for (int k = 0; k < n; k++) {
        // 12시(위쪽)에서 시작해 시계 방향으로 배치
        final angle = k * 2 * math.pi / n - math.pi / 2;
        final childPos = Offset(
          pos.dx + r * math.cos(angle),
          pos.dy + r * math.sin(angle),
        );
        place(children[k], childPos);
      }
    }

    place(rootId, Offset.zero);
    return positions;
  }

  // ════════════════════════════════════════════════════════════════════════
  // 부분트리삽입 방식 (Partial Subtree Insertion)
  //
  // 조건: 같은 레벨 형제 중 어떤 노드의 서브트리 깊이가 3 이상일 때 적용
  //   → 해당 노드에 할당된 이등변삼각형 영역 안에서 직사각형 행 배치
  //
  // 흐름:
  //   1. 바텀업(_computeSubtreeMaxDepths, _computeTriangleNeeded,
  //      _computeBoundariesV2)으로 각 노드의 필요 삼각형 크기 계산
  //   2. 오버플로우 시: 같은 레벨에서 가장 큰 삼각형을 기준으로 r 결정
  //   3. 탑다운(_placeNodesV2, _placeSubtreeLinear)으로 실제 위치 배정
  // ════════════════════════════════════════════════════════════════════════

  /// [바텀업] 각 노드의 서브트리 최대깊이를 계산한다.
  /// 0 = 리프, 1 = 자식만, 2 = 손자까지, 3+ = 부분트리삽입 대상
  static Map<String, int> _computeSubtreeMaxDepths(
    String rootId,
    Map<String, List<String>> childrenMap,
  ) {
    final result = <String, int>{};
    void dfs(String id) {
      if (result.containsKey(id)) return;
      final children = childrenMap[id] ?? [];
      if (children.isEmpty) { result[id] = 0; return; }
      for (final c in children) dfs(c);
      result[id] = 1 + children.fold(0, (m, c) => math.max(m, result[c] ?? 0));
    }
    dfs(rootId);
    return result;
  }

  /// [바텀업] 부분트리삽입에서 필요한 삼각형 영역 크기를 계산한다.
  ///
  /// 반환 레코드:
  ///   r     — 삼각형 y축(깊이) 방향 필요 길이
  ///   halfW — 삼각형 x축(폭) 방향 최대 반폭
  ///
  /// 회전불가 노드 조건 적용: 모든 경계에 ×√2 패딩
  static ({double r, double halfW}) _computeTriangleNeeded(
    String nodeId,
    Map<String, List<String>> childrenMap,
    Map<String, double> halfSide,
  ) {
    // BFS로 레벨별 노드 수집
    final levels = <List<String>>[];
    {
      final q = <String>[nodeId];
      final vis = <String>{nodeId};
      while (q.isNotEmpty) {
        final lvl = List<String>.from(q);
        q.clear();
        levels.add(lvl);
        for (final id in lvl) {
          for (final c in (childrenMap[id] ?? [])) {
            if (!vis.contains(c)) { vis.add(c); q.add(c); }
          }
        }
      }
    }

    const minGap = 20.0; // 노드 간 최소 간격

    // 레벨 0: 루트 자체의 초기 r, halfW
    final a0 = halfSide[nodeId] ?? 84.0;
    double totalR = a0 * math.sqrt2;
    double maxHalfW = a0 * math.sqrt2;

    // 레벨 1 이상: 직사각형 행 배치
    for (int i = 1; i < levels.length; i++) {
      final prev = levels[i - 1];
      final curr = levels[i];

      // 회전불가 조건: ×√2
      final mPrev = prev.fold(0.0, (m, id) => math.max(m, (halfSide[id] ?? 84.0))) * math.sqrt2;
      final mCurr = curr.fold(0.0, (m, id) => math.max(m, (halfSide[id] ?? 84.0))) * math.sqrt2;
      // l_n: 현재 레벨 노드 폭 합 + 간격
      final lCurr = curr.fold(0.0, (s, id) => s + (halfSide[id] ?? 84.0) * 2 * math.sqrt2)
          + minGap * (curr.length - 1).toDouble();

      // r_n ≥ √2·(m_prev + m_curr)/2 (문서 조건, + 최소간격)
      final rn = math.sqrt2 * (mPrev + mCurr) / 2 + minGap;
      totalR += rn + mCurr;        // 레벨 간 거리 + 현 레벨 높이
      maxHalfW = math.max(maxHalfW, lCurr / 2);
    }

    return (r: totalR, halfW: maxHalfW);
  }

  /// [탑다운] 서브트리 노드를 삼각형 y축 방향으로 선형 배치한다.
  ///
  /// [nodeId]    : 서브트리 루트 (이미 basePos에 배치됨)
  /// [basePos]   : 서브트리 루트의 절대 좌표
  /// [axisAngle] : 부모→루트 방향 각도 (radians, cos/sin 좌표계)
  ///
  /// 짝수 레벨: 중심점 양쪽에 Tn/2, Tn/2+1번 노드
  /// 홀수 레벨: (Tn/2)+1번 노드가 중심점에 배치
  static void _placeSubtreeLinear(
    String nodeId,
    Offset basePos,
    double axisAngle,
    Map<String, List<String>> childrenMap,
    Map<String, double> halfSide,
    Map<String, Offset> positions,
    Set<String> visited,
  ) {
    if (visited.contains(nodeId)) return;
    visited.add(nodeId);
    positions[nodeId] = basePos;

    // BFS로 레벨별 노드 수집
    final levels = <List<String>>[];
    {
      final q = <String>[nodeId];
      final vis = <String>{nodeId};
      while (q.isNotEmpty) {
        final lvl = List<String>.from(q);
        q.clear();
        levels.add(lvl);
        for (final id in lvl) {
          for (final c in (childrenMap[id] ?? [])) {
            if (!vis.contains(c)) { vis.add(c); q.add(c); }
          }
        }
      }
    }

    // 삼각형 좌표계: y축 = axisAngle 방향, x축 = 수직 방향
    final ax = math.cos(axisAngle); // y축 단위벡터 x
    final ay = math.sin(axisAngle); // y축 단위벡터 y
    final px = -math.sin(axisAngle); // x축 단위벡터 x (반시계 90°)
    final py = math.cos(axisAngle);  // x축 단위벡터 y

    const minGap = 20.0;
    double cumulativeR = 0.0;

    for (int i = 1; i < levels.length; i++) {
      final prev = levels[i - 1];
      final curr = levels[i];

      final mPrev = prev.fold(0.0, (m, id) => math.max(m, (halfSide[id] ?? 84.0))) * math.sqrt2;
      final mCurr = curr.fold(0.0, (m, id) => math.max(m, (halfSide[id] ?? 84.0))) * math.sqrt2;

      final rn = math.sqrt2 * (mPrev + mCurr) / 2 + minGap;
      cumulativeR += rn + mCurr;

      // 이 레벨의 중심 좌표 (basePos 기준 y축 방향 cumulativeR)
      final cx = basePos.dx + ax * cumulativeR;
      final cy = basePos.dy + ay * cumulativeR;

      final tn = curr.length;
      final nodeWidths = curr.map((id) => (halfSide[id] ?? 84.0) * 2 * math.sqrt2).toList();
      final totalNodeW = nodeWidths.fold(0.0, (s, w) => s + w);
      final lCurr = totalNodeW + minGap * math.max(0, tn - 1).toDouble();

      // 홀수/짝수 문서 조건: 모든 노드를 중심 p 기준으로 균등 배치
      // M = lCurr(사용가능폭 최대값) - totalNodeW → 노드 사이 간격 M/(Tn-1)
      // 여기서 lCurr = totalNodeW + gap*(tn-1) 이므로 gap = M/(Tn-1) ✓
      double xOffset = -lCurr / 2;
      for (int m = 0; m < tn; m++) {
        final id = curr[m];
        if (visited.contains(id)) continue;
        visited.add(id);
        final nodeHW = nodeWidths[m] / 2;
        positions[id] = Offset(
          cx + px * (xOffset + nodeHW),
          cy + py * (xOffset + nodeHW),
        );
        xOffset += nodeWidths[m] + minGap;
      }
    }
  }

  /// [바텀업] 부분트리삽입 지원 경계 계산
  ///
  /// - 서브트리깊이 ≥ 3 이고 형제가 있는 자식 → 삼각형 영역으로 경계 환산
  /// - 삼각형 오버플로우(halfW > r·tan(π/n)) 시 가장 큰 삼각형 기준으로 r 결정
  static Map<String, double> _computeBoundariesV2(
    String rootId,
    Map<String, List<String>> childrenMap,
    Map<String, double> halfSide,
    Map<String, int> subtreeMaxDepths,
  ) {
    final boundary = <String, double>{};
    final visited = <String>{};

    void compute(String id) {
      if (visited.contains(id)) return;
      visited.add(id);

      final a = halfSide[id] ?? 72.0;
      final children = childrenMap[id] ?? [];

      if (children.isEmpty) {
        boundary[id] = a * math.sqrt2;
        return;
      }

      for (final cid in children) compute(cid);

      final n = children.length;
      // 형제가 있어야(n > 1) 부분트리삽입 대상
      final needsIns = <String, bool>{
        for (final c in children)
          c: n > 1 && (subtreeMaxDepths[c] ?? 0) >= 3,
      };
      final hasAny = needsIns.values.any((v) => v);

      double maxEffB = 0.0;

      if (hasAny) {
        // 삼각형 반각 = π/n
        final tanHa = n > 1 ? math.tan(math.pi / n) : 1.0;

        for (final cid in children) {
          double effB;
          if (needsIns[cid] == true) {
            final tri = _computeTriangleNeeded(cid, childrenMap, halfSide);
            // 오버플로우 처리: 필요 r = max(tri.r, tri.halfW / tanHa)
            final rNeeded = tanHa > 1e-6
                ? math.max(tri.r, tri.halfW / tanHa)
                : tri.r;
            // 삼각형을 외접하는 원으로 변환
            effB = math.sqrt(rNeeded * rNeeded + tri.halfW * tri.halfW);
          } else {
            effB = boundary[cid] ?? a * math.sqrt2;
          }
          maxEffB = math.max(maxEffB, effB);
        }
      } else {
        maxEffB = children.fold(0.0, (prev, c) => math.max(prev, boundary[c] ?? a));
      }

      double r;
      if (n == 1) {
        r = math.max(2 * math.sqrt2 * a, a + maxEffB * 1.3 + 20);
      } else {
        final sinHalf = math.sin(math.pi / n);
        final r1 = 2 * math.sqrt2 * a;
        final r2 = sinHalf > 1e-6 ? maxEffB / sinHalf : double.infinity;
        r = math.max(r1, r2) * 1.15;
        r = r.clamp(80.0, 3000.0);
      }
      boundary[id] = r + maxEffB;
    }

    compute(rootId);
    return boundary;
  }

  /// [탑다운] 부분트리삽입 지원 노드 배치
  ///
  /// - 정다각형 기반 방사형 배치를 기본으로
  /// - 서브트리깊이 ≥ 3 이고 형제가 있는 자식: _placeSubtreeLinear 호출
  /// - 삼각형 오버플로우시: 같은 레벨에서 가장 큰 삼각형 r 기준으로 r 통일
  static Map<String, Offset> _placeNodesV2(
    String rootId,
    Map<String, List<String>> childrenMap,
    Map<String, double> halfSide,
    Map<String, double> boundary,
    Map<String, int> subtreeMaxDepths,
  ) {
    final positions = <String, Offset>{};
    final visited = <String>{};

    void place(String id, Offset pos, double incomingAngle) {
      if (visited.contains(id)) return;
      visited.add(id);
      positions[id] = pos;

      final children = childrenMap[id] ?? [];
      if (children.isEmpty) return;

      final n = children.length;
      final a = halfSide[id] ?? 72.0;

      final needsIns = <String, bool>{
        for (final c in children)
          c: n > 1 && (subtreeMaxDepths[c] ?? 0) >= 3,
      };
      final hasAny = needsIns.values.any((v) => v);

      double r;

      if (hasAny) {
        // 삼각형 반각
        final tanHa = math.tan(math.pi / n);
        double maxEffB = 0.0;
        double maxTriR = 0.0; // 가장 큰 삼각형의 r (오버플로우 기준점)

        for (final cid in children) {
          if (needsIns[cid] == true) {
            final tri = _computeTriangleNeeded(cid, childrenMap, halfSide);
            final rNeeded = tanHa > 1e-6
                ? math.max(tri.r, tri.halfW / tanHa)
                : tri.r;
            final effB = math.sqrt(rNeeded * rNeeded + tri.halfW * tri.halfW);
            maxEffB = math.max(maxEffB, effB);
            // 가장 큰 삼각형 기준: 오버플로우시 r 결정에 사용
            maxTriR = math.max(maxTriR, rNeeded);
          } else {
            maxEffB = math.max(maxEffB, boundary[cid] ?? a * math.sqrt2);
          }
        }

        final sinHalf = math.sin(math.pi / n);
        final r1 = 2 * math.sqrt2 * a;
        final r2 = sinHalf > 1e-6 ? maxEffB / sinHalf : double.infinity;
        // 가장 큰 삼각형이 기준: r_polygon과 r_triangle_overflow 중 최대값
        r = math.max(math.max(r1, r2), maxTriR) * 1.15;
        r = r.clamp(80.0, 3000.0);
      } else {
        // 기존 정다각형법
        final maxCB = children.fold(0.0, (prev, c) => math.max(prev, boundary[c] ?? a));
        if (n == 1) {
          r = math.max(2 * math.sqrt2 * a, a + maxCB * 1.3 + 20);
        } else {
          final sinHalf = math.sin(math.pi / n);
          final r1 = 2 * math.sqrt2 * a;
          final r2 = sinHalf > 1e-6 ? maxCB / sinHalf : double.infinity;
          r = math.max(r1, r2) * 1.15;
          r = r.clamp(80.0, 3000.0);
        }
      }

      for (int k = 0; k < n; k++) {
        final cid = children[k];
        // 12시 방향 시작, 시계방향
        final angle = k * 2 * math.pi / n - math.pi / 2;
        final childPos = Offset(
          pos.dx + r * math.cos(angle),
          pos.dy + r * math.sin(angle),
        );

        if (needsIns[cid] == true) {
          // 부분트리삽입: 삼각형 y축 방향(= angle)으로 선형 배치
          _placeSubtreeLinear(
            cid, childPos, angle,
            childrenMap, halfSide, positions, visited,
          );
        } else {
          place(cid, childPos, angle);
        }
      }
    }

    place(rootId, Offset.zero, -math.pi / 2);
    return positions;
  }

  /// 마크다운 심볼 제거 (**bold**, *italic*, #heading 등)
  static String _stripMd(String s) => s
      .replaceAll(RegExp(r'\*{1,3}'), '')
      .replaceAll(RegExp(r'_{1,3}'), '')
      .replaceAll(RegExp(r'^#+\s*', multiLine: true), '')
      .replaceAll(RegExp(r'`'), '')
      .trim();

  /// 수평 계층 트리 배치 (루트 좌측, 리프 우측)
  /// 서브트리 높이를 리프 수로 결정해 부모를 자식들 중앙에 놓는다.
  static Map<String, Offset> _placeTreeNodes(
    String rootId,
    Map<String, List<String>> childrenMap,
  ) {
    // 콤팩트 가로 트리: 노드 폭(≤210)보다 깊이 간격을 크게 잡아 곡선 엣지 공간 확보
    final totalNodes = childrenMap.values.fold(1, (s, l) => s + l.length);

    // xStep: 깊이(가로) 간격 — 가변 노드 폭(최대 250) + 곡선 여백 확보
    final xStep = totalNodes > 50 ? 300.0 : totalNodes > 35 ? 330.0 : 360.0;

    // yUnit: 같은 레벨 내 세로 간격 (알약 높이 ~50 기준 촘촘하게)
    final yUnit = totalNodes > 50 ? 62.0 : totalNodes > 35 ? 70.0 : 78.0;

    // Step 1: 서브트리 내 리프 수 카운트 (바텀업)
    final leafCount = <String, int>{};
    final visited0 = <String>{};
    void countLeaves(String id) {
      if (visited0.contains(id)) return;
      visited0.add(id);
      final ch = childrenMap[id] ?? [];
      if (ch.isEmpty) { leafCount[id] = 1; return; }
      for (final c in ch) countLeaves(c);
      leafCount[id] = ch.fold(0, (s, c) => s + (leafCount[c] ?? 1));
    }
    countLeaves(rootId);

    // Step 2: 탑다운으로 위치 배정
    final positions = <String, Offset>{};
    final visited1 = <String>{};
    void place(String id, int depth, double yTop) {
      if (visited1.contains(id)) return;
      visited1.add(id);
      final lc = leafCount[id] ?? 1;
      final yCenter = yTop + lc * yUnit / 2;
      positions[id] = Offset(depth * xStep, yCenter);
      final children = childrenMap[id] ?? [];
      double y = yTop;
      for (final cid in children) {
        place(cid, depth + 1, y);
        y += (leafCount[cid] ?? 1) * yUnit;
      }
    }
    final totalLeaves = leafCount[rootId] ?? 1;
    place(rootId, 0, -totalLeaves * yUnit / 2);
    return positions;
  }

  void _build() {
    ns.clear();
    es.clear();
    final rn = (widget.data['nodes'] as List?) ?? [];
    final re = (widget.data['edges'] as List?) ?? [];

    if (rn.isEmpty) {
      setState(() {});
      return;
    }

    // ── 1. 노드/엣지 맵 구성 ─────────────────────────────────
    final nodesById = <String, Map<String, dynamic>>{
      for (final raw in rn) raw['id'].toString(): raw as Map<String, dynamic>,
    };

    final childrenMap = <String, List<String>>{};
    final parentOf = <String, String>{};

    for (final raw in re) {
      final edge = raw as Map<String, dynamic>;
      final src = edge['source'].toString();
      final tgt = edge['target'].toString();
      childrenMap.putIfAbsent(src, () => []).add(tgt);
      parentOf[tgt] = src;
      es.add(_GE(src, tgt));
    }

    // ── 2. 루트 탐색 (core 타입 우선, 없으면 in-degree 0) ────
    final rootRaw = rn.cast<Map>().firstWhere(
      (raw) => raw['type']?.toString() == 'core',
      orElse: () => rn.cast<Map>().firstWhere(
        (raw) => !parentOf.containsKey(raw['id'].toString()),
        orElse: () => rn.first as Map,
      ),
    );
    final rootId = rootRaw['id'].toString();

    // ── 3. 깊이 맵 (BFS) ─────────────────────────────────────
    final depthMap = <String, int>{rootId: 0};
    final bfsQueue = [rootId];
    while (bfsQueue.isNotEmpty) {
      final id = bfsQueue.removeAt(0);
      final d = depthMap[id]!;
      for (final cid in (childrenMap[id] ?? [])) {
        if (!depthMap.containsKey(cid)) {
          depthMap[cid] = d + 1;
          bfsQueue.add(cid);
        }
      }
    }

    // ── 4. 노드 스타일 & 반변 계산 ───────────────────────────
    final styleMap = <String, _GraphCardStyle>{
      for (final id in nodesById.keys)
        id: _styleForDepth(depthMap[id] ?? 2),
    };
    final halfSide = <String, double>{
      for (final id in nodesById.keys)
        id: _nodeHalfSide(styleMap[id]!),
    };

    // ── 펼침/접기: 자식 보유 노드 + 숨김(접힌 노드의 후손) 계산 ──
    _hasKids = {
      for (final entry in childrenMap.entries)
        if (entry.value.isNotEmpty) entry.key,
    };
    // 최초 1회: 루트 직계(1레벨)만 보이도록 깊이 ≥ 1 의 노드를 전부 접는다.
    if (!_initCollapsed) {
      for (final id in _hasKids) {
        if ((depthMap[id] ?? 0) >= 1) _collapsed.add(id);
      }
      _initCollapsed = true;
    }
    final hidden = <String>{};
    void hideDescendants(String id) {
      for (final c in (childrenMap[id] ?? const <String>[])) {
        if (hidden.add(c)) hideDescendants(c);
      }
    }
    for (final id in _collapsed) {
      if (childrenMap.containsKey(id)) hideDescendants(id);
    }
    // 접힌 노드는 자식을 비운 형태의 유효 children map 으로 레이아웃
    final effChildren = <String, List<String>>{
      for (final entry in childrenMap.entries)
        entry.key: (_collapsed.contains(entry.key)
            ? const <String>[]
            : entry.value.where((c) => !hidden.contains(c)).toList()),
    };

    // ── 5&6. 레이아웃 모드에 따라 위치 배정 ─────────────────
    final Map<String, Offset> relativePositions;
    if (_isTreeLayout) {
      relativePositions = _placeTreeNodes(rootId, effChildren);
    } else {
      // 부분트리삽입 지원: 서브트리 깊이 ≥ 3 자식은 삼각형 영역 선형 배치
      final subtreeMaxDepths = _computeSubtreeMaxDepths(rootId, effChildren);
      final boundary = _computeBoundariesV2(rootId, effChildren, halfSide, subtreeMaxDepths);
      relativePositions = _placeNodesV2(rootId, effChildren, halfSide, boundary, subtreeMaxDepths);
    }

    // ── 7. 보드 크기 계산 & 루트를 보드 중앙으로 이동 ────────
    const margin = 200.0;
    double minX = 0, minY = 0, maxX = 0, maxY = 0;
    for (final pos in relativePositions.values) {
      minX = math.min(minX, pos.dx);
      minY = math.min(minY, pos.dy);
      maxX = math.max(maxX, pos.dx);
      maxY = math.max(maxY, pos.dy);
    }

    final treeW = maxX - minX + margin * 2;
    final treeH = maxY - minY + margin * 2;
    // 보드 크기: 트리 너비와 높이에 맞춤 (과도한 확장 방지)
    final boardW = math.max(3200.0, treeW);
    final boardH = math.max(2400.0, treeH);
    _boardSize = Size(boardW, boardH);

    final centerX = boardW / 2;
    final centerY = boardH / 2;

    // ── 8. GraphNodeLayout 생성 ───────────────────────────────
    for (final entry in relativePositions.entries) {
      final id = entry.key;
      final rawNode = nodesById[id];
      if (rawNode == null) continue;

      final computedPos = Offset(centerX + entry.value.dx, centerY + entry.value.dy);
      final finalPos = _savedOffset(rawNode, computedPos);

      final style = styleMap[id] ?? _GraphCardStyle.note;
      final label = _stripMd(rawNode['label']?.toString() ?? '');
      // 라벨 길이에 맞춰 노드 크기를 측정 → 글자 잘림 방지
      final size = _measureNodeSize(label, style, _hasKids.contains(id));

      ns.add(
        _GraphNodeLayout(
          id: id,
          label: label,
          description: _stripMd(rawNode['description']?.toString() ?? ''),
          type: rawNode['type']?.toString() ?? 'detail',
          group: rawNode['group']?.toString() ?? '',
          rect: Rect.fromCenter(
            center: finalPos,
            width: size.width,
            height: size.height,
          ),
          style: style,
        ),
      );
    }

    // ── 9. 그래프에 연결되지 않은 고아 노드 처리 ─────────────
    for (final raw in rn) {
      final node = raw as Map<String, dynamic>;
      final id = node['id'].toString();
      if (hidden.contains(id)) continue; // 접힌 노드의 후손은 표시하지 않음
      if (ns.any((n) => n.id == id)) continue;
      final col = ns.length % 5;
      final row = ns.length ~/ 5;
      ns.add(
        _GraphNodeLayout(
          id: id,
          label: _stripMd(node['label']?.toString() ?? ''),
          description: _stripMd(node['description']?.toString() ?? ''),
          type: node['type']?.toString() ?? 'detail',
          group: node['group']?.toString() ?? '',
          rect: Rect.fromCenter(
            center: _savedOffset(node, Offset(boardW - 400 + col * 170.0, 180 + row * 130.0)),
            width: 136,
            height: 104,
          ),
          style: _GraphCardStyle.note,
        ),
      );
    }

    setState(() {});
  }

  String? _parentIdFor(String nodeId) {
    for (final edge in es) {
      if (edge.t == nodeId) {
        return edge.s;
      }
    }
    return null;
  }

  bool _edgeExists(String sourceId, String targetId) =>
      es.any((edge) => edge.s == sourceId && edge.t == targetId);

  void _toggleConnectMode() {
    setState(() {
      _connectSourceId = _connectSourceId == null ? '' : null;
    });
  }

  void _handleNodeTap(_GraphNodeLayout tappedNode) {
    if (_connectSourceId != null) {
      if (_connectSourceId!.isEmpty) {
        setState(() => _connectSourceId = tappedNode.id);
        return;
      }

      final sourceId = _connectSourceId!;
      if (sourceId == tappedNode.id || _edgeExists(sourceId, tappedNode.id)) {
        setState(() => _connectSourceId = null);
        return;
      }

      widget.ref
          .read(fileEditorProvider.notifier)
          .connectGraphNodes(sourceId, tappedNode.id);
      // 접힌 출발 노드면 펼쳐서 연결된 노드가 보이도록 한다.
      _collapsed.remove(sourceId);
      setState(() {
        es.add(_GE(sourceId, tappedNode.id));
        _connectSourceId = null;
      });
      widget.onChanged();
      Future.delayed(const Duration(milliseconds: 80), () {
        if (mounted) _centerOnNodeId(sourceId);
      });
    } else {
      setState(() {
        _selectedNodeId = _selectedNodeId == tappedNode.id ? null : tappedNode.id;
      });
    }
  }

  void _fitBoard() {
    if (ns.isEmpty) return;
    final box = context.findRenderObject() as RenderBox?;
    final viewSize = box?.size ?? const Size(800, 600);

    // 모든 노드의 실제 bounding box 계산
    double minX = double.infinity, minY = double.infinity;
    double maxX = double.negativeInfinity, maxY = double.negativeInfinity;
    for (final n in ns) {
      minX = math.min(minX, n.rect.left);
      minY = math.min(minY, n.rect.top);
      maxX = math.max(maxX, n.rect.right);
      maxY = math.max(maxY, n.rect.bottom);
    }

    final padding = 60.0;
    final contentW = (maxX - minX) + padding * 2;
    final contentH = (maxY - minY) + padding * 2;

    final scale = math.min(
      viewSize.width / contentW,
      viewSize.height / contentH,
    ).clamp(0.12, 1.0);

    // 콘텐츠 중심을 뷰포트 중심에 맞춤
    final cx = (minX - padding) + contentW / 2;
    final cy = (minY - padding) + contentH / 2;

    _controller.value = Matrix4.identity()
      ..translateByDouble(
        viewSize.width / 2 - cx * scale,
        viewSize.height / 2 - cy * scale,
        0, 1,
      )
      ..scaleByDouble(scale, scale, 1, 1);
  }

  void _centerOnCore() {
    if (ns.isEmpty) { _fitBoard(); return; }
    // 초기화 시 항상 전체 노드가 화면에 맞게 표시
    _fitBoard();
  }

  bool _exporting = false;

  /// 마인드맵 보드 전체를 캡처하여 PDF로 다운로드한다.
  Future<void> _exportPdf() async {
    if (_exporting) return;
    final boundary =
        _boardKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) return;
    setState(() => _exporting = true);
    try {
      // 보드가 매우 클 수 있으므로 최대 변 ~3200px 기준으로 배율 조정
      final pr = (3200.0 / math.max(_boardSize.width, _boardSize.height))
          .clamp(0.5, 2.0);
      final image = await boundary.toImage(pixelRatio: pr);
      final byteData = await image.toByteData(format: ImageByteFormat.png);
      if (byteData == null) return;
      final pngBytes = byteData.buffer.asUint8List();
      await exportPngAsPdf(pngBytes, filename: 'mindmap.pdf');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PDF 내보내기에 실패했습니다.')),
        );
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  /// univai식 드릴다운: 특정 노드를 화면 좌측(32%) 지점에 맞춰 이동시켜
  /// 펼쳐진 자식들(오른쪽)이 자연스럽게 보이도록 한다. 현재 배율은 유지.
  void _centerOnNodeId(String id, {double leftBias = 0.32}) {
    _GraphNodeLayout? node;
    for (final n in ns) {
      if (n.id == id) { node = n; break; }
    }
    if (node == null) { _fitBoard(); return; }

    final box = context.findRenderObject() as RenderBox?;
    final viewSize = box?.size ?? const Size(800, 600);

    // 현재 배율 유지 (너무 작거나 크지 않게 클램프)
    final current = _controller.value.getMaxScaleOnAxis();
    final scale = current.clamp(0.45, 1.2);

    final c = node.rect.center;
    final targetX = viewSize.width * leftBias;
    final targetY = viewSize.height / 2;

    _controller.value = Matrix4.identity()
      ..translateByDouble(targetX - c.dx * scale, targetY - c.dy * scale, 0, 1)
      ..scaleByDouble(scale, scale, 1, 1);
  }

  void _zoomIn() {
    final box = context.findRenderObject() as RenderBox?;
    final viewSize = box?.size ?? const Size(800, 600);
    final cx = viewSize.width / 2;
    final cy = viewSize.height / 2;
    final m = Matrix4.copy(_controller.value)
      ..translate(cx, cy)
      ..scale(1.25)
      ..translate(-cx, -cy);
    _controller.value = m;
  }

  void _zoomOut() {
    final box = context.findRenderObject() as RenderBox?;
    final viewSize = box?.size ?? const Size(800, 600);
    final cx = viewSize.width / 2;
    final cy = viewSize.height / 2;
    final m = Matrix4.copy(_controller.value)
      ..translate(cx, cy)
      ..scale(0.8)
      ..translate(-cx, -cy);
    _controller.value = m;
  }

  void _addChildNode(String parentId) {
    final parent = ns.firstWhere((n) => n.id == parentId, orElse: () => ns.first);
    final angle = math.Random().nextDouble() * 2 * math.pi;
    const r = 320.0;
    final position = Offset(
      parent.rect.center.dx + r * math.cos(angle),
      parent.rect.center.dy + r * math.sin(angle),
    );
    // 접힌 부모면 펼쳐서 새 자식이 보이도록 한다.
    _collapsed.remove(parentId);
    widget.ref.read(fileEditorProvider.notifier).addGraphNode(
      label: '새 노드',
      description: '',
      type: 'detail',
      parentId: parentId,
      x: position.dx,
      y: position.dy,
    );
    widget.onChanged();
    // 레이아웃 갱신 후 부모로 포커스
    Future.delayed(const Duration(milliseconds: 80), () {
      if (mounted) _centerOnNodeId(parentId);
    });
  }

  void _resetLayout() {
    _build();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _fitBoard();
    });
  }

  void _addNode() {
    final root = ns.firstWhere(
      (node) => node.style == _GraphCardStyle.core,
      orElse: () => ns.first,
    );
    final position = root.rect.center + const Offset(260, 0);
    _collapsed.remove(root.id); // 루트 펼침 보장
    widget.ref
        .read(fileEditorProvider.notifier)
        .addGraphNode(
          label: '새 메모',
          description: '핵심 개념에 연결된 새 노드입니다.',
          type: 'detail',
          parentId: root.id,
          x: position.dx,
          y: position.dy,
        );
    widget.onChanged();
    Future.delayed(const Duration(milliseconds: 80), () {
      if (mounted) _centerOnNodeId(root.id);
    });
  }

  Offset _savedOffset(Map<String, dynamic>? node, Offset fallback) {
    final x = (node?['x'] as num?)?.toDouble();
    final y = (node?['y'] as num?)?.toDouble();
    if (x == null || y == null) return fallback;
    return Offset(x, y);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        GestureDetector(
          onTap: () => setState(() => _selectedNodeId = null),
          child: InteractiveViewer(
            constrained: false,
            boundaryMargin: const EdgeInsets.all(600),
            minScale: 0.08,
            maxScale: 3.0,
            transformationController: _controller,
            child: RepaintBoundary(
              key: _boardKey,
              child: SizedBox(
              width: _boardSize.width,
              height: _boardSize.height,
              child: Stack(
                children: [
                  const Positioned.fill(child: _GraphBoardBackground()),
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _GraphBoardPainter(nodes: ns, es: es, isTree: _isTreeLayout),
                    ),
                  ),
                  ...ns.map(
                    (node) => Positioned.fromRect(
                      rect: node.rect,
                      child: _GraphCard(
                        node: node,
                        parentId: _parentIdFor(node.id),
                        nodes: ns,
                        isConnectMode: _connectSourceId != null,
                        isConnectSource: _connectSourceId == node.id,
                        isConnectTarget:
                            _connectSourceId != null &&
                            _connectSourceId!.isNotEmpty &&
                            _connectSourceId != node.id,
                        isSelected: _selectedNodeId == node.id,
                        hasChildren: _hasKids.contains(node.id),
                        isCollapsed: _collapsed.contains(node.id),
                        onToggleCollapse: () {
                          if (_collapsed.contains(node.id)) {
                            _collapsed.remove(node.id);
                          } else {
                            _collapsed.add(node.id);
                          }
                          _build(); // 내부에서 setState 호출 (ns 갱신)
                          // 펼친/접은 노드를 화면에 맞춰 드릴다운 포커스
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (mounted) _centerOnNodeId(node.id);
                          });
                        },
                        onSelect: () => _handleNodeTap(node),
                        onAddChild: () => _addChildNode(node.id),
                        onMove: (offset) {
                          final center = node.rect.center + offset;
                          widget.ref
                              .read(fileEditorProvider.notifier)
                              .updateGraphNode(
                                node.id,
                                x: center.dx,
                                y: center.dy,
                              );
                          setState(() {
                            final index = ns.indexWhere(
                              (element) => element.id == node.id,
                            );
                            if (index != -1) {
                              ns[index] = ns[index].copyWith(
                                rect: Rect.fromCenter(
                                  center: center,
                                  width: node.rect.width,
                                  height: node.rect.height,
                                ),
                              );
                            }
                          });
                        },
                        onMoveEnd: widget.onChanged,
                        onEdit: (label, description) {
                          widget.ref
                              .read(fileEditorProvider.notifier)
                              .updateGraphNode(
                                node.id,
                                label: label,
                                description: description,
                              );
                          setState(() {
                            final index = ns.indexWhere(
                              (element) => element.id == node.id,
                            );
                            if (index != -1) {
                              ns[index] = ns[index].copyWith(
                                label: label,
                                description: description,
                              );
                            }
                          });
                          widget.onChanged();
                        },
                        onTapNode: () => _handleNodeTap(node),
                        onEditMeta: ({type, group, parentId}) {
                          widget.ref
                              .read(fileEditorProvider.notifier)
                              .updateGraphNodeMeta(
                                node.id,
                                type: type,
                                group: group,
                                parentId: parentId,
                              );
                          widget.onChanged();
                        },
                        onDelete: () {
                          widget.ref
                              .read(fileEditorProvider.notifier)
                              .removeGraphNode(node.id);
                          setState(() {
                            ns.removeWhere((element) => element.id == node.id);
                            es.removeWhere(
                              (edge) => edge.s == node.id || edge.t == node.id,
                            );
                            if (_selectedNodeId == node.id) _selectedNodeId = null;
                          });
                          widget.onChanged();
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
            ),
          ),
        ),
        Positioned(
          bottom: 16,
          left: 0,
          right: 0,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
              decoration: BoxDecoration(
                color: _bg3.withValues(alpha: 0.96),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _bdr),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.22), blurRadius: 20, offset: const Offset(0, 8))],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _PillBtn(icon: LucideIcons.plus, tip: '노드 추가', onTap: _addNode),
                  const _PillDivider(),
                  _PillBtn(icon: LucideIcons.zoomIn, tip: '확대', onTap: _zoomIn),
                  _PillBtn(icon: LucideIcons.maximize2, tip: '화면 맞춤', onTap: _fitBoard),
                  _PillBtn(icon: LucideIcons.zoomOut, tip: '축소', onTap: _zoomOut),
                  const _PillDivider(),
                  _PillBtn(
                    icon: _isTreeLayout ? LucideIcons.share2 : LucideIcons.gitBranch,
                    tip: _isTreeLayout ? '방사형으로 전환' : '트리형으로 전환',
                    onTap: () => setState(() {
                      _isTreeLayout = !_isTreeLayout;
                      _build();
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted) _fitBoard();
                      });
                    }),
                    isActive: _isTreeLayout,
                  ),
                  const _PillDivider(),
                  _PillBtn(
                    icon: _exporting ? LucideIcons.loader : LucideIcons.download,
                    tip: 'PDF로 다운로드',
                    onTap: _exportPdf,
                  ),
                  const _PillDivider(),
                  _PillBtn(icon: LucideIcons.rotateCcw, tip: '레이아웃 재정렬', onTap: _resetLayout),
                  _PillBtn(
                    icon: LucideIcons.gitBranchPlus,
                    tip: _connectSourceId == null ? '엣지 연결' : '연결 취소',
                    isActive: _connectSourceId != null,
                    onTap: _toggleConnectMode,
                  ),
                ],
              ),
            ),
          ),
        ),
        if (_connectSourceId != null)
          Positioned(
            left: 18,
            top: 18,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: _bg3.withValues(alpha: 0.96),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: _acc.withValues(alpha: 0.32),
                ),
              ),
              child: Text(
                _connectSourceId!.isEmpty
                    ? '연결할 출발 노드를 선택하세요.'
                    : '다음 노드를 눌러 연결을 완성하세요.',
                style: GoogleFonts.inter(
                  color: _txt1,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

enum _GraphCardStyle { core, branch, subcluster, note, noteWide }

class _GraphNodeLayout {
  final String id;
  final String label;
  final String description;
  final String type;
  final String group;
  final Rect rect;
  final _GraphCardStyle style;

  _GraphNodeLayout({
    required this.id,
    required this.label,
    required this.description,
    required this.type,
    required this.group,
    required this.rect,
    required this.style,
  });

  _GraphNodeLayout copyWith({
    String? label,
    String? description,
    String? type,
    String? group,
    Rect? rect,
  }) {
    return _GraphNodeLayout(
      id: id,
      label: label ?? this.label,
      description: description ?? this.description,
      type: type ?? this.type,
      group: group ?? this.group,
      rect: rect ?? this.rect,
      style: style,
    );
  }
}

class _GE {
  String s, t;
  _GE(this.s, this.t);
}

class _GraphBoardPainter extends CustomPainter {
  final List<_GraphNodeLayout> nodes;
  final List<_GE> es;
  final bool isTree;
  const _GraphBoardPainter({required this.nodes, required this.es, this.isTree = false});

  @override
  void paint(Canvas c, Size s) {
    final nodeMap = {for (final node in nodes) node.id: node};

    final linePaint = Paint()
      ..strokeWidth = 1.8
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..color = Colors.white.withValues(alpha: 0.22);

    for (final e in es) {
      final a = nodeMap[e.s];
      final b = nodeMap[e.t];
      if (a == null || b == null) continue;

      if (isTree) {
        // 트리(가로) 모드: 부모 오른쪽 가장자리 → 자식 왼쪽 가장자리 부드러운 S-곡선
        final start = Offset(a.rect.right, a.rect.center.dy);
        final end = Offset(b.rect.left, b.rect.center.dy);
        final dx = end.dx - start.dx;
        final path = Path()
          ..moveTo(start.dx, start.dy)
          ..cubicTo(
            start.dx + dx * 0.5, start.dy,
            end.dx - dx * 0.5, end.dy,
            end.dx, end.dy,
          );
        c.drawPath(path, linePaint);
      } else {
        // 방사형: 중심 → 중심 부드러운 곡선
        final start = a.rect.center;
        final end = b.rect.center;
        final dx = (end.dx - start.dx).abs();
        final ctrl = math.max(60.0, dx * 0.28);
        final path = Path()
          ..moveTo(start.dx, start.dy)
          ..cubicTo(
            start.dx + (end.dx > start.dx ? ctrl : -ctrl) * 0.5,
            start.dy,
            end.dx - (end.dx > start.dx ? ctrl : -ctrl) * 0.5,
            end.dy,
            end.dx,
            end.dy,
          );
        c.drawPath(path, linePaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _GraphBoardPainter oldDelegate) =>
      oldDelegate.nodes.length != nodes.length ||
      oldDelegate.es.length != es.length ||
      oldDelegate.isTree != isTree;
}

class _GraphBoardBackground extends StatelessWidget {
  const _GraphBoardBackground();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _GraphDotsPainter(),
      child: const SizedBox.expand(),
    );
  }
}

class _GraphDotsPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // 진한 배경
    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFF080D18));

    // 중앙 라디알 글로우
    final center = Offset(size.width / 2, size.height / 2);
    final glow = RadialGradient(
      colors: [
        const Color(0xFF1B2E58).withValues(alpha: 0.7),
        const Color(0xFF080D18).withValues(alpha: 0.0),
      ],
      radius: 0.65,
    );
    final glowRect = Rect.fromCenter(
      center: center, width: size.width * 1.4, height: size.height * 1.4);
    canvas.drawRect(Offset.zero & size,
        Paint()..shader = glow.createShader(glowRect));

    // 미묘한 격자 도트
    final dotPaint = Paint()..color = Colors.white.withValues(alpha: 0.045);
    const spacing = 28.0;
    for (double x = 0; x < size.width; x += spacing) {
      for (double y = 0; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), 1.1, dotPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _GraphCard extends StatelessWidget {
  final _GraphNodeLayout node;
  final String? parentId;
  final List<_GraphNodeLayout> nodes;
  final bool isConnectMode;
  final bool isConnectSource;
  final bool isConnectTarget;
  final bool isSelected;
  final VoidCallback onSelect;
  final VoidCallback onAddChild;
  final void Function(Offset offset) onMove;
  final VoidCallback onMoveEnd;
  final VoidCallback onTapNode;
  final void Function(String label, String description) onEdit;
  final void Function({String? type, String? group, String? parentId})
  onEditMeta;
  final VoidCallback onDelete;
  final bool hasChildren;
  final bool isCollapsed;
  final VoidCallback onToggleCollapse;
  const _GraphCard({
    required this.node,
    required this.parentId,
    required this.nodes,
    required this.isConnectMode,
    required this.isConnectSource,
    required this.isConnectTarget,
    this.isSelected = false,
    required this.onSelect,
    required this.onAddChild,
    required this.onMove,
    required this.onMoveEnd,
    required this.onTapNode,
    required this.onEdit,
    required this.onEditMeta,
    required this.onDelete,
    this.hasChildren = false,
    this.isCollapsed = false,
    required this.onToggleCollapse,
  });

  Future<void> _openEditor(BuildContext context) async {
    final labelCtrl = TextEditingController(text: node.label);
    final descCtrl = TextEditingController(text: node.description);
    final groupCtrl = TextEditingController(text: node.group);
    String selectedType = node.type.isEmpty ? 'detail' : node.type;
    String selectedParentId = parentId ?? '';
    await showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => Dialog(
          backgroundColor: AppTheme.bgSecondary,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('그래프 카드 수정', style: AppTheme.headingSmall),
                  const SizedBox(height: 14),
                  SFTextField(
                    hint: '라벨',
                    controller: labelCtrl,
                    autofocus: true,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: descCtrl,
                    maxLines: 5,
                    style: AppTheme.bodyMedium.copyWith(
                      color: AppTheme.textPrimary,
                    ),
                    decoration: const InputDecoration(
                      hintText: '부연 설명',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: selectedType,
                          decoration: const InputDecoration(labelText: '타입'),
                          items: const [
                            DropdownMenuItem(value: 'core', child: Text('Core')),
                            DropdownMenuItem(
                              value: 'branch',
                              child: Text('Branch'),
                            ),
                            DropdownMenuItem(
                              value: 'detail',
                              child: Text('Detail'),
                            ),
                          ],
                          onChanged: (value) {
                            if (value == null) return;
                            setDialogState(() => selectedType = value);
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: selectedParentId,
                          decoration: const InputDecoration(labelText: '부모'),
                          items: [
                            const DropdownMenuItem<String>(
                              value: '',
                              child: Text('없음'),
                            ),
                            ...nodes
                                .where((candidate) => candidate.id != node.id)
                                .map(
                                  (candidate) => DropdownMenuItem(
                                    value: candidate.id,
                                    child: Text(
                                      candidate.label,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                          ],
                          onChanged: (value) {
                            setDialogState(() => selectedParentId = value ?? '');
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: groupCtrl,
                    style: AppTheme.bodyMedium.copyWith(
                      color: AppTheme.textPrimary,
                    ),
                    decoration: const InputDecoration(
                      hintText: '그룹 이름',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      SFButton(
                        label: '자식 추가',
                        outlined: true,
                        onPressed: () {
                          onAddChild();
                          Navigator.pop(dialogContext);
                        },
                      ),
                      const Spacer(),
                      SFButton(
                        label: '삭제',
                        outlined: true,
                        onPressed: () {
                          onDelete();
                          Navigator.pop(dialogContext);
                        },
                      ),
                      const SizedBox(width: 8),
                      SFButton(
                        label: '취소',
                        outlined: true,
                        onPressed: () => Navigator.pop(dialogContext),
                      ),
                      const SizedBox(width: 8),
                      SFButton(
                        label: '저장',
                        onPressed: () {
                          onEdit(labelCtrl.text.trim(), descCtrl.text.trim());
                          onEditMeta(
                            type: selectedType,
                            group: groupCtrl.text.trim(),
                            parentId: selectedParentId.isEmpty
                                ? null
                                : selectedParentId,
                          );
                          Navigator.pop(dialogContext);
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── univai 스타일 팔레트 (정제된 색감) ─────────────────────
  // 슬레이트 + 인디고 — 고급스럽고 가독성 높은 팔레트
  static const _coreGrad = LinearGradient(
    colors: [Color(0xFF5965E0), Color(0xFF7B86FF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const _coreSelGrad = LinearGradient(
    colors: [Color(0xFF6E7BFF), Color(0xFF93A0FF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const _childGrad = LinearGradient(
    colors: [Color(0xFF232B3B), Color(0xFF1A2030)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const _childGradSel = LinearGradient(
    colors: [Color(0xFF2D3858), Color(0xFF232C44)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const _childTxt    = Color(0xFFE6EAF3); // 밝은 슬레이트 화이트(고가독)
  static const _childBorder = Color(0xFF3C4660); // 또렷한 슬레이트 테두리
  static const _violet      = Color(0xFF8497FF); // 선택/펼침 강조(인디고)
  static const _toggleBg    = Color(0xFF11151E); // 토글 칩 배경

  @override
  Widget build(BuildContext context) {
    final isCore = node.style == _GraphCardStyle.core;
    // 액션(편집·자식 추가·삭제)은 더블탭/길게눌러 열리는 편집 다이얼로그로 통합.
    // (노드 위 떠 있는 툴바는 화면을 벗어나거나 클릭이 안 되는 문제로 제거)
    return GestureDetector(
      onTap: onSelect,
      onPanUpdate: (details) => onMove(details.delta),
      onPanEnd: (_) => onMoveEnd(),
      onDoubleTap: () => _openEditor(context),
      onLongPress: () => _openEditor(context),
      child: _buildPill(isCore),
    );
  }

  /// 펼침/접기 토글 칩 — 알약 내부 우측에 배치하여 항상 클릭 가능
  Widget _toggleChip() {
    return GestureDetector(
      onTap: onToggleCollapse,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          color: isCollapsed
              ? _violet.withValues(alpha: 0.18)
              : _toggleBg.withValues(alpha: 0.6),
          shape: BoxShape.circle,
          border: Border.all(
            color: isCollapsed
                ? _violet.withValues(alpha: 0.9)
                : const Color(0xFF3C4660),
          ),
        ),
        child: Icon(
          isCollapsed ? LucideIcons.chevronRight : LucideIcons.chevronLeft,
          size: 13,
          color: isCollapsed ? _violet : const Color(0xFFC2CAD8),
        ),
      ),
    );
  }

  /// ── 깔끔한 알약 노드 (루트=인디고 / 가지=슬레이트) ─────────────
  Widget _buildPill(bool isCore) {
    final highlighted = isSelected || isConnectSource;
    final Color textColor = isCore ? Colors.white : _childTxt;
    final double labelSize = isCore ? 15.0 : 13.5;

    final BoxDecoration deco = isCore
        ? BoxDecoration(
            gradient: highlighted ? _coreSelGrad : _coreGrad,
            borderRadius: BorderRadius.circular(16),
            border: highlighted
                ? Border.all(color: Colors.white.withValues(alpha: 0.92), width: 2)
                : null,
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF6D5CE7).withValues(
                  alpha: highlighted ? 0.55 : 0.40,
                ),
                blurRadius: highlighted ? 26 : 18,
                offset: const Offset(0, 8),
              ),
            ],
          )
        : BoxDecoration(
            gradient: highlighted ? _childGradSel : _childGrad,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: highlighted
                  ? _violet
                  : (isConnectTarget
                      ? Colors.white.withValues(alpha: 0.4)
                      : _childBorder.withValues(alpha: 0.85)),
              width: highlighted ? 2 : 1.3,
            ),
            boxShadow: highlighted
                ? [
                    BoxShadow(
                      color: _violet.withValues(alpha: 0.32),
                      blurRadius: 18,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.30),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
          );

    final label = Text(
      node.label,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      textAlign: TextAlign.center,
      style: GoogleFonts.inter(
        color: textColor,
        fontSize: labelSize,
        fontWeight: isCore ? FontWeight.w800 : FontWeight.w600,
        height: 1.2,
        letterSpacing: -0.3,
      ),
    );

    return Container(
      clipBehavior: Clip.hardEdge,
      decoration: deco,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      child: Row(
        children: [
          Expanded(child: label),
          if (hasChildren) ...[
            const SizedBox(width: 7),
            _toggleChip(),
          ],
        ],
      ),
    );
  }
}

/// 스티키노트 접힌 모서리 페인터
class _StickyFoldPainter extends CustomPainter {
  const _StickyFoldPainter();

  @override
  void paint(Canvas canvas, Size size) {
    // 어두운 삼각형 (접힌 부분 그림자)
    final shadow = Paint()..color = const Color(0xFFCCA010);
    final shadowPath = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width, size.height)
      ..close();
    canvas.drawPath(shadowPath, shadow);

    // 밝은 삼각형 (들린 종이 느낌)
    final lift = Paint()..color = Colors.white.withValues(alpha: 0.22);
    final liftPath = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(liftPath, lift);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

/// 하단 pill 툴바 아이콘 버튼
class _PillBtn extends StatelessWidget {
  final IconData icon;
  final String tip;
  final VoidCallback onTap;
  final bool isActive;
  const _PillBtn({required this.icon, required this.tip, required this.onTap, this.isActive = false});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: isActive ? _acc.withValues(alpha: 0.18) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, size: 16, color: isActive ? _acc : _txt1),
        ),
      ),
    );
  }
}

class _PillDivider extends StatelessWidget {
  const _PillDivider();
  @override
  Widget build(BuildContext context) => Container(
    width: 1, height: 22, margin: const EdgeInsets.symmetric(horizontal: 2),
    color: _bdr.withValues(alpha: 0.7),
  );
}

/// 노드 카드 내 액션 버튼
class _CardActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;
  const _CardActionBtn({required this.icon, required this.label, required this.onTap, required this.color});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 11, color: color),
        const SizedBox(width: 4),
        Text(label, style: GoogleFonts.inter(color: color, fontSize: 10, fontWeight: FontWeight.w600)),
      ]),
    ),
  );
}

class _GraphToolbarButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isActive;

  const _GraphToolbarButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isActive = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          decoration: BoxDecoration(
            color: isActive
                ? _acc.withValues(alpha: 0.16)
                : _bg3.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isActive
                  ? _acc.withValues(alpha: 0.38)
                  : _bdr.withValues(alpha: 0.9),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 13, color: isActive ? _acc : _txt1),
              const SizedBox(width: 6),
              Text(
                label,
                style: GoogleFonts.inter(
                  color: isActive ? _acc : _txt1,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GraphMetaChip extends StatelessWidget {
  final String label;
  final Color color;

  const _GraphMetaChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          color: color.withValues(alpha: 0.66),
          fontSize: 8.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.7,
        ),
      ),
    );
  }
}

// ══════════════════ SPLIT ═══════════════════════════
class _Split extends StatefulWidget {
  final Widget left, right;
  const _Split({required this.left, required this.right});
  @override
  State<_Split> createState() => _SS();
}

class _SS extends State<_Split> {
  double _r = 0.58;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (_, c) {
      final w = c.maxWidth;
      return Row(
        children: [
          SizedBox(width: w * _r, child: widget.left),
          MouseRegion(
            cursor: SystemMouseCursors.resizeColumn,
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onPanUpdate: (d) =>
                  setState(() => _r = (_r + d.delta.dx / w).clamp(0.35, 0.72)),
              child: Container(
                width: 5,
                color: Colors.transparent,
                child: Center(child: Container(width: 1, color: _bdr)),
              ),
            ),
          ),
          Expanded(child: widget.right),
        ],
      );
    },
  );
}

// ══════════════════ 그래프 빈 상태 ══════════════════
class _GraphEmptyState extends StatelessWidget {
  final VoidCallback onGenerate;
  final String? errorMessage;

  const _GraphEmptyState({required this.onGenerate, this.errorMessage});

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      const Positioned.fill(child: _GraphBoardBackground()),
      Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 아이콘
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                gradient: errorMessage != null
                    ? const LinearGradient(
                        colors: [Color(0xFFE53935), Color(0xFFEF5350)],
                        begin: Alignment.topLeft, end: Alignment.bottomRight)
                    : const LinearGradient(
                        colors: [Color(0xFF3D6AFF), Color(0xFF6B8AFF)],
                        begin: Alignment.topLeft, end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: (errorMessage != null
                            ? Colors.red
                            : const Color(0xFF3D6AFF))
                        .withValues(alpha: 0.45),
                    blurRadius: 36,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Icon(
                errorMessage != null
                    ? Icons.error_outline_rounded
                    : Icons.auto_awesome_rounded,
                size: 38,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 28),
            Text(
              errorMessage != null ? '생성 실패' : '지식 그래프 생성',
              style: GoogleFonts.inter(
                color: _txt0,
                fontSize: 22,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              errorMessage ??
                  '노트 내용을 AI가 분석해\n핵심 개념과 관계를 그래프로 시각화합니다',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                color: errorMessage != null
                    ? Colors.red.withValues(alpha: 0.75)
                    : _txt2,
                fontSize: 13,
                height: 1.75,
              ),
            ),
            const SizedBox(height: 36),
            GestureDetector(
              onTap: onGenerate,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF3D6AFF), Color(0xFF6B8AFF)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF3D6AFF).withValues(alpha: 0.50),
                      blurRadius: 22,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.auto_awesome_rounded,
                      size: 16,
                    color: Colors.white,
                  ),
                    const SizedBox(width: 8),
                    Text(
                      errorMessage != null ? '다시 시도' : '그래프 생성하기',
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

// ── 플로팅 정보 칩 ─────────────────────────────────────
class _GraphInfoChip extends StatelessWidget {
  final int nodeCount;
  final int blockCount;
  const _GraphInfoChip({required this.nodeCount, required this.blockCount});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 22, height: 22,
                decoration: BoxDecoration(
                  gradient: AppGradients.accent,
                  borderRadius: BorderRadius.circular(7),
                ),
                child: const Icon(LucideIcons.network, size: 12, color: Colors.white),
              ),
              const SizedBox(width: 9),
              Text(
                '지식 그래프',
                style: GoogleFonts.inter(
                  color: _txt0, fontSize: 13, fontWeight: FontWeight.w700),
              ),
              if (nodeCount > 0) ...[
                const SizedBox(width: 10),
                _InfoBadge('$nodeCount 노드', const Color(0xFF3D6AFF)),
              ],
              const SizedBox(width: 6),
              _InfoBadge('$blockCount 블록', _bdr.withValues(alpha: 2)),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoBadge extends StatelessWidget {
  final String text;
  final Color color;
  const _InfoBadge(this.text, this.color);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: color.withValues(alpha: 0.28)),
    ),
    child: Text(text,
        style: GoogleFonts.inter(
            color: color.withValues(alpha: 0.9),
            fontSize: 10,
            fontWeight: FontWeight.w600)),
  );
}

// ── 재생성 버튼 ───────────────────────────────────────
class _GraphRegenBtn extends StatelessWidget {
  final VoidCallback onTap;
  final bool hasData;
  const _GraphRegenBtn({required this.onTap, required this.hasData});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: hasData ? '그래프 재생성' : '그래프 생성',
      child: GestureDetector(
        onTap: onTap,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(13),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(13),
                border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    hasData ? Icons.refresh_rounded : Icons.auto_awesome_rounded,
                    size: 14, color: _txt1),
                  const SizedBox(width: 6),
                  Text(
                    hasData ? '재생성' : '생성',
                    style: GoogleFonts.inter(
                        color: _txt1, fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── 풀스크린 로딩 캔버스 ──────────────────────────────
class _GraphLoadingCanvas extends StatelessWidget {
  const _GraphLoadingCanvas();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const Positioned.fill(child: _GraphBoardBackground()),
        Center(
          child: AppShimmer(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 88, height: 88,
                  decoration: BoxDecoration(
                    color: _bg3,
                    borderRadius: BorderRadius.circular(26),
                  ),
                ),
                const SizedBox(height: 22),
                Container(width: 220, height: 14, decoration: BoxDecoration(color: _bg3, borderRadius: BorderRadius.circular(999))),
                const SizedBox(height: 10),
                Container(width: 160, height: 10, decoration: BoxDecoration(color: _bg3, borderRadius: BorderRadius.circular(999))),
                const SizedBox(height: 10),
                Container(width: 190, height: 10, decoration: BoxDecoration(color: _bg3, borderRadius: BorderRadius.circular(999))),
              ],
            ),
          ),
        ),
        Positioned(
          bottom: 28, left: 0, right: 0,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              decoration: BoxDecoration(
                color: _bg3.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(99),
                border: Border.all(color: _bdr),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                SizedBox(
                  width: 13, height: 13,
                  child: CircularProgressIndicator(strokeWidth: 1.5, color: _acc),
                ),
                const SizedBox(width: 10),
                Text(
                  'AI가 지식 그래프를 생성하고 있어요...',
                  style: GoogleFonts.inter(
                      color: _txt1, fontSize: 11, fontWeight: FontWeight.w600),
                ),
              ]),
            ),
          ),
        ),
      ],
    );
  }
}

// ══════════════════ 공통 위젯 ═══════════════════════
class _Empty extends StatelessWidget {
  final IconData icon;
  final String title, desc;
  const _Empty({required this.icon, required this.title, required this.desc});
  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: _bg3.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _bdr.withValues(alpha: 0.9)),
          ),
          child: Icon(icon, size: 26, color: _txt2.withValues(alpha: 0.7)),
        ),
        const SizedBox(height: 20),
        Text(
          title,
          style: const TextStyle(
            color: _txt0,
            fontSize: 14,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.2,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          desc,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: _txt2.withValues(alpha: 0.7),
            fontSize: 12,
            height: 1.7,
          ),
        ),
      ],
    ),
  );
}

class _Load extends StatelessWidget {
  final String msg;
  const _Load(this.msg);
  @override
  Widget build(BuildContext context) => Center(
    child: AppShimmer(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 74,
            height: 74,
            decoration: BoxDecoration(
              color: _bg3,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _bdr),
            ),
          ),
          const SizedBox(height: 14),
          Container(
            width: 120,
            height: 12,
            decoration: BoxDecoration(
              color: _bg3,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(height: 10),
          Text(msg, style: const TextStyle(color: _txt2, fontSize: 13)),
        ],
      ),
    ),
  );
}

class _Fade extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Positioned(
    bottom: 0,
    left: 0,
    right: 0,
    height: 90,
    child: IgnorePointer(
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [_bg2.withValues(alpha: 0.98), Colors.transparent],
          ),
        ),
      ),
    ),
  );
}

class _FABtn extends StatefulWidget {
  final bool loading;
  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  const _FABtn({
    required this.loading,
    required this.label,
    required this.icon,
    this.onTap,
  });
  @override
  State<_FABtn> createState() => _FABtnS();
}

class _FABtnS extends State<_FABtn> with SingleTickerProviderStateMixin {
  bool _h = false;
  late AnimationController _ac;
  late Animation<double> _sc;
  @override
  void initState() {
    super.initState();
    _ac = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    _sc = Tween(
      begin: 1.0,
      end: 1.02,
    ).animate(CurvedAnimation(parent: _ac, curve: Curves.easeInOut));
  }

  @override
  void didUpdateWidget(_FABtn old) {
    super.didUpdateWidget(old);
    if (widget.loading && !_ac.isAnimating) _ac.repeat(reverse: true);
    if (!widget.loading && _ac.isAnimating) _ac.stop();
  }

  @override
  void dispose() {
    _ac.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Center(
    child: ScaleTransition(
      scale: widget.loading ? _sc : const AlwaysStoppedAnimation(1.0),
      child: MouseRegion(
        onEnter: (_) => setState(() => _h = true),
        onExit: (_) => setState(() => _h = false),
        child: GestureDetector(
          onTap: widget.loading ? null : widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 13),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: widget.loading
                    ? [
                        _acc.withValues(alpha: 0.24),
                        _acc.withValues(alpha: 0.12),
                      ]
                    : _h
                    ? [_bg3.withValues(alpha: 0.98), _bg2]
                    : [
                        _bg3.withValues(alpha: 0.92),
                        _bg2.withValues(alpha: 0.92),
                      ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(32),
              border: Border.all(
                color: widget.loading
                    ? _acc.withValues(alpha: 0.4)
                    : (_h ? _bdr2 : _bdr),
                width: widget.loading ? 1.5 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: 14,
                  offset: const Offset(0, 5),
                ),
                if (widget.loading)
                  BoxShadow(
                    color: _acc.withValues(alpha: 0.12),
                    blurRadius: 20,
                  ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                widget.loading
                    ? SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 1.5,
                          color: _acc,
                          strokeCap: StrokeCap.round,
                        ),
                      )
                    : Icon(widget.icon, color: _acc, size: 15),
                const SizedBox(width: 9),
                Text(
                  widget.loading ? '생성 중...' : widget.label,
                  style: TextStyle(
                    color: widget.loading ? _acc : (_h ? _txt0 : _txt1),
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _IB extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color? color;
  final double sz;
  const _IB(this.icon, this.onTap, {this.color, this.sz = 14});
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(8),
    child: Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: _bg2.withValues(alpha: 0.52),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _bdr.withValues(alpha: 0.6)),
      ),
      child: Icon(icon, size: sz, color: color ?? _txt2),
    ),
  );
}

class _Stat extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final bool accent;
  const _Stat(this.label, this.value, this.icon, {this.accent = false});
  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: accent ? _accD : _bg3,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent ? _acc.withValues(alpha: 0.3) : _bdr),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: accent ? _acc : _txt2),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(
              color: accent ? _acc : _txt0,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(color: _txt2, fontSize: 11)),
        ],
      ),
    ),
  );
}

// ══════════════════ MARKDOWN STYLE ══════════════════
MarkdownStyleSheet _md() => MarkdownStyleSheet(
  p: GoogleFonts.inter(
    color: _txt0,
    fontSize: 13.5,
    height: 1.85,
    letterSpacing: 0.05,
  ),
  strong: GoogleFonts.inter(
    color: Colors.white,
    fontWeight: FontWeight.w700,
    shadows: const [Shadow(color: Color(0x18CCFF66), blurRadius: 6)],
  ),
  em: GoogleFonts.inter(color: _txt0, fontStyle: FontStyle.italic),
  code: GoogleFonts.jetBrainsMono(
    backgroundColor: const Color(0xFF141428),
    color: const Color(0xFFD4BBFF),
    fontSize: 12.5,
    letterSpacing: 0.15,
  ),
  codeblockDecoration: BoxDecoration(
    color: const Color(0xFF0D1117),
    borderRadius: BorderRadius.circular(10),
    border: Border.all(color: _bdr),
  ),
  tableBorder: TableBorder(
    top: const BorderSide(color: _bdr),
    bottom: const BorderSide(color: _bdr),
    left: const BorderSide(color: _bdr),
    right: const BorderSide(color: _bdr),
    horizontalInside: const BorderSide(color: _bdr),
    verticalInside: BorderSide(color: _bdr, width: 0.5),
  ),
  tableColumnWidth: const FlexColumnWidth(),
  tableHead: const TextStyle(
    fontWeight: FontWeight.w700,
    color: _acc,
    fontSize: 13,
    letterSpacing: 0.2,
  ),
  tableBody: const TextStyle(color: _txt0, fontSize: 13, height: 1.6),
  tableCellsPadding: const EdgeInsets.symmetric(vertical: 11, horizontal: 16),
  blockquoteDecoration: BoxDecoration(
    border: Border(left: BorderSide(color: _acc, width: 3)),
    color: _accD.withValues(alpha: 0.4),
    borderRadius: const BorderRadius.only(
      topRight: Radius.circular(8),
      bottomRight: Radius.circular(8),
    ),
  ),
  blockquotePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
  listBullet: const TextStyle(color: _acc, fontSize: 14),
  listBulletPadding: const EdgeInsets.only(right: 8),
  listIndent: 24,
  h1: const TextStyle(
    fontSize: 19,
    color: Colors.white,
    fontWeight: FontWeight.w800,
    height: 1.5,
    letterSpacing: -0.3,
    shadows: [Shadow(color: Color(0x15FFFFFF), blurRadius: 20)],
  ),
  h2: const TextStyle(
    fontSize: 16,
    color: Colors.white,
    fontWeight: FontWeight.w700,
    height: 1.5,
  ),
  h3: const TextStyle(
    fontSize: 14,
    color: _acc,
    fontWeight: FontWeight.w700,
    height: 1.5,
    letterSpacing: 0.1,
  ),
  horizontalRuleDecoration: BoxDecoration(
    border: Border(top: BorderSide(color: _bdr)),
  ),
  pPadding: const EdgeInsets.only(bottom: 2),
  h1Padding: const EdgeInsets.only(top: 4, bottom: 2),
  h2Padding: const EdgeInsets.only(top: 2, bottom: 2),
  h3Padding: const EdgeInsets.only(top: 2, bottom: 1),
);

// ══════════════════ 드래그 선택 박스 페인터 ══════════════════
class _DragSelectionPainter extends CustomPainter {
  final Offset startPos;
  final Offset endPos;

  _DragSelectionPainter({required this.startPos, required this.endPos});

  @override
  void paint(Canvas canvas, Size size) {
    final left = math.min(startPos.dx, endPos.dx);
    final top = math.min(startPos.dy, endPos.dy);
    final right = math.max(startPos.dx, endPos.dx);
    final bottom = math.max(startPos.dy, endPos.dy);

    final rect = Rect.fromLTRB(left, top, right, bottom);

    // 배경 (반투명 파란색)
    canvas.drawRect(
      rect,
      Paint()
        ..color = const Color(0xFF5D7FFF).withValues(alpha: 0.15)
        ..style = PaintingStyle.fill,
    );

    // 테두리
    canvas.drawRect(
      rect,
      Paint()
        ..color = const Color(0xFF5D7FFF).withValues(alpha: 0.6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0,
    );
  }

  @override
  bool shouldRepaint(covariant _DragSelectionPainter oldDelegate) {
    return oldDelegate.startPos != startPos || oldDelegate.endPos != endPos;
  }
}
