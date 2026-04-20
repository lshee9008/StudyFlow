// ╔══════════════════════════════════════════════════════╗
// ║  StudyFlow — Premium Editor v7                       ║
// ║  Notion-style UX · Inter font · High-quality UI      ║
// ╚══════════════════════════════════════════════════════╝
import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/foundation.dart';

import '../../models/block_model.dart';
import '../../core/db_helper/files_db_helper.dart';
import 'file_provider.dart';

// ══════════════════ TOKENS ════════════════════════════
const _bg0 = Color(0xFF111111);
const _bg1 = Color(0xFF191919);
const _bg2 = Color(0xFF222222);
const _bg3 = Color(0xFF2B2B2B);
const _bg4 = Color(0xFF353535);
const _bdr = Color(0xFF2E2E2E);
const _bdr2 = Color(0xFF3A3A3A);
const _txt0 = Color(0xFFE8E8E8);
const _txt1 = Color(0xFF9A9A9A);
const _txt2 = Color(0xFF666666);
const _acc = Color(0xFFCCFF66);
const _accD = Color(0xFF1A2508);
const _grn = Color(0xFF4ADE80);
const _red = Color(0xFFFF4F6A);
const _blu = Color(0xFF5B8EFF);
const _pur = Color(0xFFA78BFA);
const _yel = Color(0xFFFFD166);

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
  bool _isDragging = false;
  int? _dragStart;

  // Pomodoro
  Timer? _pomT;
  int _pomSecs = 25 * 60; // 25분
  bool _pomRunning = false;
  bool _pomIsWork = true; // true=집중, false=휴식
  static const _pomWork = 25 * 60;
  static const _pomRest = 5 * 60;

  // Proofread
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
  List<_Opt> _slashOpts = [];

  // Animations
  late AnimationController _bgAc, _saveAc, _sumAc;
  late Animation<double> _bgAnim, _saveAnim, _sumPulse;

  static const _opts = [
    // 기본 텍스트
    _Opt('p', '텍스트', Icons.short_text_rounded, '',
        '일반 텍스트를 작성하세요', '기본 블록'),
    _Opt('h1', '제목 1', Icons.looks_one_rounded, '#',
        '큰 섹션 제목', '기본 블록'),
    _Opt('h2', '제목 2', Icons.looks_two_rounded, '##',
        '중간 섹션 제목', '기본 블록'),
    _Opt('h3', '제목 3', Icons.looks_3_rounded, '###',
        '작은 섹션 제목', '기본 블록'),
    _Opt('quote', '인용', Icons.format_quote_rounded, '>',
        '텍스트를 인용 형식으로', '기본 블록'),
    // 목록
    _Opt('bullet', '글머리 기호', Icons.format_list_bulleted_rounded, '-',
        '글머리 기호 목록 작성', '목록'),
    _Opt('number', '번호 목록', Icons.format_list_numbered_rounded, '1.',
        '번호가 매겨진 목록', '목록'),
    _Opt('todo', '할 일 목록', Icons.check_box_outlined, '[]',
        '할 일을 추적하는 체크리스트', '목록'),
    // 특수
    _Opt('code', '코드', Icons.code_rounded, '```',
        '코드 스니펫 삽입', '특수'),
    _Opt('table', '표', Icons.table_chart_rounded, '',
        '마크다운 표 삽입', '특수'),
    _Opt('div', '구분선', Icons.horizontal_rule_rounded, '---',
        '섹션을 나누는 수평선', '특수'),
    _Opt('image', '이미지', Icons.image_outlined, '',
        '이미지 파일 삽입', '특수'),
  ];

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 5, vsync: this);
    _bgAc = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 30),
    )..repeat(reverse: true);
    _saveAc = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _sumAc = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _bgAnim = CurvedAnimation(parent: _bgAc, curve: Curves.easeInOut);
    _saveAnim = CurvedAnimation(parent: _saveAc, curve: Curves.elasticOut);
    _sumPulse = Tween(
      begin: 0.6,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _sumAc, curve: Curves.easeInOut));
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
    // 실시간 동기화 (30초마다 서버에서 최신 데이터 체크)
    _syncT = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _syncFromServer(),
    );
  }

  // ── 실시간 동기화 ─────────────────────────────────
  Future<void> _syncFromServer() async {
    if (!kIsWeb || !mounted) return;
    // 저장 중이면 건너뜀
    if (_savingN.value) return;
    await ref.read(fileEditorProvider.notifier).loadFileDetail(widget.fileId);
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
    _bgAc.dispose();
    _saveAc.dispose();
    _sumAc.dispose();
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
          ref.read(fileEditorProvider.notifier).state = ref
              .read(fileEditorProvider)
              .copyWith(focusedText: ft);
      });
    }
    _savingN.value = true;
    _saveT?.cancel();
    _saveT = Timer(const Duration(milliseconds: 1500), () async {
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
    final mc = ref.read(fileEditorProvider).meaningfulCharCount;
    if ((mc - _lastSumLen).abs() > 80) {
      _sumT?.cancel();
      _sumT = Timer(const Duration(seconds: 8), _doSum);
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

  void _onFocus(String text) {
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
            .analyzeBlock(text: clean, title: _tCtrl.text);
      }
    });
  }

  // ── 키 핸들러 ─────────────────────────────────────
  KeyEventResult _key(FocusNode n, KeyEvent e, int i) {
    if (e is! KeyDownEvent) return KeyEventResult.ignored;
    final meta = HardwareKeyboard.instance.isMetaPressed;
    final ctrl = HardwareKeyboard.instance.isControlPressed;
    final shift = HardwareKeyboard.instance.isShiftPressed;

    // Ctrl/Cmd+A: 전체 선택
    if ((meta || ctrl) && e.logicalKey == LogicalKeyboardKey.keyA) {
      final blocks = ref.read(fileEditorProvider).blocks;
      setState(() {
        _selectedBlocks.clear();
        _selectedBlocks.addAll(List.generate(blocks.length, (i) => i));
      });
      // 현재 블록의 텍스트도 전체 선택
      final b = blocks[i];
      b.controller.selection = TextSelection(
        baseOffset: 0,
        extentOffset: b.controller.text.length,
      );
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

    // ── Tab / Shift+Tab ──────────────────────────────
    if (e.logicalKey == LogicalKeyboardKey.tab) {
      if (shift) {
        // Shift+Tab: 내어쓰기 또는 리스트 레벨 감소
        if (bt == BlockType.bullet || bt == BlockType.checkbox) {
          // 리스트 레벨 감소 → text로 전환
          ref.read(fileEditorProvider.notifier).setType(i, BlockType.text);
        } else {
          ref.read(fileEditorProvider.notifier).dedent(i);
        }
      } else {
        // Tab: 들여쓰기 또는 리스트 레벨 증가
        if (bt == BlockType.bullet || bt == BlockType.checkbox) {
          // 리스트 내에서 Tab → 앞에 스페이스 2개 (서브 리스트 표현)
          final pos = bc.selection.baseOffset.clamp(0, bc.text.length);
          bc.text = '  ${bc.text}';
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

      // 빈 리스트 → 탈출 (text로 전환)
      if (text.isEmpty &&
          (bt == BlockType.bullet || bt == BlockType.checkbox ||
           bt == BlockType.number || bt == BlockType.quote)) {
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
          if (bt == BlockType.bullet || bt == BlockType.checkbox ||
              bt == BlockType.number || bt == BlockType.quote) {
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
          // 위 블록과 병합
          ref.read(fileEditorProvider.notifier).mergeWithPrev(i);
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

    // ── 방향키 ───────────────────────────────────────
    if (e.logicalKey == LogicalKeyboardKey.arrowUp && i > 0) {
      _foc(i - 1);
      return KeyEventResult.handled;
    }
    if (e.logicalKey == LogicalKeyboardKey.arrowDown && i < blocks.length - 1) {
      _foc(i + 1);
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  void _foc(int i) {
    final b = ref.read(fileEditorProvider).blocks;
    if (i >= 0 && i < b.length) {
      b[i].focusNode.requestFocus();
      final c = b[i].controller;
      c.selection = TextSelection.collapsed(offset: c.text.length);
    }
  }

  // ── 텍스트 변경 ────────────────────────────────────
  void _onText(String text, int i) {
    if (text.contains('\n')) {
      final lines = text.split('\n');
      ref.read(fileEditorProvider).blocks[i].controller.text = lines[0];
      if (lines.length > 1) {
        ref
            .read(fileEditorProvider.notifier)
            .insertBlocks(i + 1, lines.sublist(1));
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => _foc(i + lines.length - 1),
        );
      }
      _chg(ft: lines[0]);
      return;
    }

    // 마크다운 단축키
    BlockType? _nt;
    String _nc = text;
    if (text.endsWith(' ')) {
      if (text == '# ') {
        _nt = BlockType.h1; _nc = '';
      } else if (text == '## ') {
        _nt = BlockType.h2; _nc = '';
      } else if (text == '### ') {
        _nt = BlockType.h3; _nc = '';
      } else if (text == '- ' || text == '* ') {
        _nt = BlockType.bullet; _nc = '';
      } else if (text == '> ') {
        _nt = BlockType.quote; _nc = '';
      } else if (text == '1. ') {
        _nt = BlockType.number; _nc = '';
      } else if (text == '[] ') {
        _nt = BlockType.checkbox; _nc = '';
      }
    }
    // 백틱 3개 → 코드 블록
    if (text.trimRight() == '```') {
      _nt = BlockType.code; _nc = '';
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
    _slashOpts = q.isEmpty
        ? _opts
        : _opts
              .where((o) => o.label.toLowerCase().contains(q.toLowerCase()))
              .toList();
    if (_slashOpts.isEmpty) {
      _removeSlash();
      return;
    }
    if (_slash == null) _slashIdx = 0;
    _slash?.remove();
    final bl = ref.read(fileEditorProvider).blocks;
    // ✅ CompositedTransformFollower 제거 → RenderBox 기반 절대 위치
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _slash != null) return;
      final blkCtx = bl[i].focusNode.context;
      double left = 100, top = 200;
      if (blkCtx != null) {
        final box = blkCtx.findRenderObject() as RenderBox?;
        if (box != null) {
          final pos = box.localToGlobal(Offset.zero);
          left = (pos.dx + 28).clamp(8.0, MediaQuery.of(ctx).size.width - 290);
          top = pos.dy + box.size.height + 4;
        }
      }
      _slash = OverlayEntry(
        builder: (_) => Positioned(
          left: left,
          top: top,
          width: 280,
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
        // 테이블 기본 템플릿 삽입
        c.text = '| 항목 | 내용 | 비고 |\n|------|------|------|\n| | | |';
        ref.read(fileEditorProvider.notifier).setType(i, BlockType.code);
        break;
      case 'div':
        c.text = '────────────────────────────────────';
        ref.read(fileEditorProvider.notifier).setType(i, BlockType.code);
        break;
      case 'image':
        _pickImage(i);
        break;
      default:
        ref.read(fileEditorProvider.notifier).setType(i, BlockType.text);
    }
    _foc(i);
  }

  Future<void> _pickImage(int blockIdx) async {
    if (!kIsWeb) {
      _snack('이미지 삽입은 웹에서만 지원됩니다.');
      return;
    }
    // URL 입력 방식 (가장 범용적)
    final ctrl = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _bg3,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: _bdr2),
        ),
        title: Text(
          '이미지 URL 입력',
          style: GoogleFonts.inter(color: _txt0, fontSize: 16, fontWeight: FontWeight.w700),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: ctrl,
              autofocus: true,
              style: GoogleFonts.inter(color: _txt0, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'https://example.com/image.png',
                hintStyle: GoogleFonts.inter(color: _txt2, fontSize: 13),
                filled: true,
                fillColor: _bg2,
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
                  borderSide: BorderSide(color: _acc, width: 1.5),
                ),
              ),
              onSubmitted: (v) => Navigator.pop(ctx, v),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('취소', style: GoogleFonts.inter(color: _txt2)),
          ),
          GestureDetector(
            onTap: () => Navigator.pop(ctx, ctrl.text),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: _acc,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text('삽입', style: GoogleFonts.inter(color: Colors.black, fontWeight: FontWeight.w700, fontSize: 13)),
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
    );
    if (result != null && result.isNotEmpty) {
      final blocks = ref.read(fileEditorProvider).blocks;
      if (blockIdx < blocks.length) {
        blocks[blockIdx].controller.text = result.trim();
        ref.read(fileEditorProvider.notifier).setType(blockIdx, BlockType.image);
        _chg();
      }
    }
  }

  void _removeSlash() {
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
    final screenH = MediaQuery.of(context).size.height;
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
            _snack(_pomIsWork
                ? '🔔 휴식 종료! 집중 모드를 시작합니다.'
                : '🔔 집중 완료! 5분 휴식하세요.');
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

    return Scaffold(
      backgroundColor: _bg0,
      floatingActionButton: _PomFAB(
        label: _pomLabel,
        color: _pomColor,
        running: _pomRunning,
        onTap: _pomToggle,
        onLongPress: _pomReset,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
      body: Stack(
        children: [
          RepaintBoundary(child: _AuroraBG(anim: _bgAnim)),
          Column(
            children: [
              ValueListenableBuilder<bool>(
                valueListenable: _savingN,
                builder: (_, saving, __) => _AppBar(
                  saving: saving,
                  savedAt: savedAt,
                  saveAnim: _saveAnim,
                  charCount: charCount,
                  view: _view,
                  selectedCount: _selectedBlocks.length,
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
                  onView: () => setState(() => _view = _view == 0 ? 1 : 0),
                  onMindmap: () {
                    setState(() => _view = _view == 2 ? 0 : 2);
                    if (_view == 2)
                      ref.read(fileEditorProvider.notifier).requestGraph();
                  },
                  onProofread: () => _showProofreadMenu(),
                  onDeleteSel: _selectedBlocks.isEmpty
                      ? null
                      : () {
                          final sorted = _selectedBlocks.toList()
                            ..sort((a, b) => b.compareTo(a));
                          for (final idx in sorted)
                            ref
                                .read(fileEditorProvider.notifier)
                                .removeBlock(idx);
                          setState(() => _selectedBlocks.clear());
                          _chg();
                        },
                ),
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
                        ),
                      )
                    : _view == 1
                    ? _buildEditor()
                    : _Split(
                        left: _buildEditor(),
                        right: Consumer(
                          builder: (_, r, __) =>
                              _buildPanel(r.watch(fileEditorProvider)),
                        ),
                      ),
              ),
            ],
          ),
        ],
      ),
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
                    border: Border.all(color: _acc.withOpacity(0.2)),
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
    final icon = ref.read(fileEditorProvider).icon ?? '';

    return GestureDetector(
      // 드래그 블록 선택
      onPanStart: (d) {
        setState(() {
          _isDragging = true;
          _selectedBlocks.clear();
        });
      },
      onPanEnd: (_) => setState(() => _isDragging = false),
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(96, 80, 96, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _IconRow(
                    current: icon,
                    onChange: (e) {
                      ref.read(fileEditorProvider.notifier).setIcon(e);
                      _chg();
                    },
                  ),
                  const SizedBox(height: 28),
                  _GlowTitle(ctrl: _tCtrl, onChange: () => _chg()),
                  const SizedBox(height: 32),
                  _PropRow(
                    icon: Icons.tag_rounded,
                    label: 'Tags',
                    ctrl: _gCtrl,
                    hint: '태그',
                    onChange: (_) => _chg(),
                  ),
                  _PropRow(
                    icon: Icons.auto_awesome_rounded,
                    label: 'Prompt',
                    ctrl: _pCtrl,
                    hint: 'AI 지시사항',
                    onChange: (v) {
                      ref.read(fileEditorProvider.notifier).setPrompt(v);
                      _chg();
                    },
                  ),
                  ValueListenableBuilder<TextEditingValue>(
                    valueListenable: _pCtrl,
                    builder: (_, v, __) => v.text.isEmpty
                        ? _PromptSugs(
                            onTap: (s) {
                              _pCtrl.text = s;
                              ref
                                  .read(fileEditorProvider.notifier)
                                  .setPrompt(s);
                              _chg();
                            },
                          )
                        : const SizedBox.shrink(),
                  ),
                  const SizedBox(height: 28),
                  const _Div(),
                  const SizedBox(height: 14),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(96, 0, 96, 280),
            sliver: SliverReorderableList(
              itemCount: blocks.length,
              onReorder: (o, n) {
                ref.read(fileEditorProvider.notifier).reorder(o, n);
                _chg();
              },
              itemBuilder: (ctx, i) => _NBlock(
                key: ValueKey(blocks[i].id),
                idx: i,
                block: blocks[i],
                prevType: i > 0 ? blocks[i - 1].type : null,
                isSelected: _selectedBlocks.contains(i),
                listNumber: blocks[i].type == BlockType.number
                    ? () {
                        int n = 1;
                        for (int j = i - 1; j >= 0; j--) {
                          if (blocks[j].type == BlockType.number) n++;
                          else break;
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
                  _chg(ft: blocks[i].controller.text);
                  _onFocus(blocks[i].controller.text);
                },
                onSelect: () => setState(() {
                  if (_selectedBlocks.contains(i))
                    _selectedBlocks.remove(i);
                  else
                    _selectedBlocks.add(i);
                }),
                // ✅ 선택 변경 → _FS에서 툴바 처리
                onSelChanged: _onBlockSelChanged,
                blockKey: _blockKeys.putIfAbsent(i, () => GlobalKey()),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── AI 패널 ─────────────────────────────────────
  Widget _buildPanel(FileEditorState st) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: BoxDecoration(
            color: _bg2.withOpacity(0.85),
            border: const Border(left: BorderSide(color: _bdr)),
          ),
          child: Column(
            children: [
              Container(
                height: 50,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: _bdr.withOpacity(0.6)),
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
                      pulse: _sumPulse,
                    ),
                    Consumer(
                      builder: (_, r, __) =>
                          _AnaPanel(st: r.watch(fileEditorProvider)),
                    ),
                    _MemoPanel(st: st, ref: ref, tCtrl: _tCtrl),
                    _QuizPanel(st: st, ref: ref),
                    _AskPanel(
                      st: st,
                      ctrl: _qaCtrl,
                      onAsk: (q) => ref
                          .read(fileEditorProvider.notifier)
                          .askAI(q, widget.projectId),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ══════════════════ AURORA BG ═══════════════════════
class _AuroraBG extends StatelessWidget {
  final Animation<double> anim;
  const _AuroraBG({required this.anim});
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: anim,
    builder: (_, __) =>
        SizedBox.expand(child: CustomPaint(painter: _AP(anim.value))),
  );
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
        ..color = col.withOpacity(a)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 120),
    );
    b(0.15 + t * 0.08, 0.2 + math.sin(t * math.pi) * 0.05, 260, _blu, 0.04);
    b(0.85 - t * 0.06, 0.15 + math.cos(t * math.pi) * 0.04, 200, _acc, 0.03);
    b(0.5 + math.sin(t * math.pi) * 0.1, 0.9, 300, _pur, 0.025);
    b(0.9, 0.7 + t * 0.05, 180, Color(0xFF4ADE80), 0.02);
  }

  @override
  bool shouldRepaint(_AP o) => (o.t - t).abs() > 0.005;
}

// ══════════════════ APP BAR ═════════════════════════
class _AppBar extends StatelessWidget {
  final bool saving;
  final DateTime? savedAt;
  final Animation<double> saveAnim;
  final int charCount, view, selectedCount;
  final VoidCallback onBack, onCopy, onMdCopy, onView, onMindmap, onProofread;
  final VoidCallback? onDeleteSel;
  const _AppBar({
    required this.saving,
    this.savedAt,
    required this.saveAnim,
    required this.charCount,
    required this.view,
    required this.selectedCount,
    required this.onBack,
    required this.onCopy,
    required this.onMdCopy,
    required this.onView,
    required this.onMindmap,
    required this.onProofread,
    this.onDeleteSel,
  });

  @override
  Widget build(BuildContext context) => Container(
    height: 50,
    decoration: BoxDecoration(
      border: Border(
        bottom: BorderSide(
          color: const Color(0xFF1C1C2C).withOpacity(0.8),
          width: 0.5,
        ),
      ),
    ),
    child: Row(
      children: [
        const SizedBox(width: 6),
        _CBtn(Icons.arrow_back_rounded, onBack),
        const SizedBox(width: 10),
        // 저장 상태
        _SaveChip(saving: saving, savedAt: savedAt, anim: saveAnim),
        const Spacer(),
        // 다중 선택 시 삭제 버튼
        if (selectedCount > 0) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _red.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _red.withOpacity(0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$selectedCount개 선택',
                  style: const TextStyle(
                    color: _red,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: onDeleteSel,
                  child: const Icon(
                    Icons.delete_outline_rounded,
                    size: 14,
                    color: _red,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
        ],
        // 글자 수
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFF161622),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _bdr.withOpacity(0.6)),
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
        const SizedBox(width: 6),
        _TBtn(Icons.spellcheck_rounded, '글 교정', onProofread),
        _TBtn(Icons.copy_rounded, '복사', onCopy),
        _TBtn(Icons.download_outlined, 'MD', onMdCopy),
        _TBtn(
          view == 0 ? Icons.crop_square_rounded : Icons.view_column_rounded,
          view == 0 ? '전체' : '분할',
          onView,
        ),
        _TBtn(Icons.account_tree_outlined, '마인드맵', onMindmap),
        const SizedBox(width: 8),
      ],
    ),
  );
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
              color: _txt2.withOpacity(0.4),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '저장 중',
            style: GoogleFonts.inter(color: _txt2, fontSize: 11),
          ),
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
                color: _grn.withOpacity(0.8),
              ),
              const SizedBox(width: 5),
              Text(
                '저장됨',
                style: GoogleFonts.inter(color: _txt2, fontSize: 11),
              ),
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

// ══════════════════ 교정 배너 ════════════════════════
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
      border: Border.all(color: _acc.withOpacity(0.3)),
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
                  border: Border.all(color: _acc.withOpacity(0.4)),
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

  bool get _foc => _fn.hasFocus;
  @override
  Widget build(BuildContext context) => TextField(
    controller: widget.ctrl,
    focusNode: _fn,
    style: GoogleFonts.inter(
      fontSize: 40,
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
        fontSize: 40,
        fontWeight: FontWeight.w800,
        color: const Color(0xFF1C1C30),
        height: 1.15,
        letterSpacing: -1.5,
      ),
    ),
    onChanged: (_) => widget.onChange(),
  );
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
                              ? _acc.withOpacity(0.5)
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
          color: _foc ? _acc.withOpacity(0.9) : _txt2.withOpacity(0.35),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 60,
          child: Text(
            widget.label,
            style: GoogleFonts.inter(
              color: _foc ? _txt1 : _txt2.withOpacity(0.45),
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
            style: GoogleFonts.inter(
              color: _foc ? _txt0 : _txt1,
              fontSize: 13,
            ),
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
                color: _txt2.withOpacity(0.25),
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
  const _PSChip({
    required this.label,
    required this.icon,
    required this.onTap,
  });
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
            color: _h ? _acc.withOpacity(0.4) : _bdr2,
            width: _h ? 1 : 0.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              widget.icon,
              size: 10,
              color: _h ? _acc : _txt2,
            ),
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
      border: Border(
        bottom: BorderSide(color: _bdr.withOpacity(0.5)),
      ),
    ),
    child: Row(
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            color: running ? color : color.withOpacity(0.3),
            shape: BoxShape.circle,
            boxShadow: running
                ? [BoxShadow(color: color.withOpacity(0.6), blurRadius: 6)]
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
              color: running ? _bg4 : color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: running ? _bdr2 : color.withOpacity(0.4),
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
          child: Icon(Icons.refresh_rounded, size: 14, color: _txt2.withOpacity(0.5)),
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
          color: widget.running
              ? widget.color.withOpacity(0.15)
              : _bg3,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: widget.running
                ? widget.color.withOpacity(0.5)
                : (_h ? _bdr2 : _bdr),
            width: widget.running ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
            if (widget.running)
              BoxShadow(
                color: widget.color.withOpacity(0.15),
                blurRadius: 16,
              ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              widget.running
                  ? Icons.pause_rounded
                  : Icons.timer_outlined,
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

// ══════════════════ IMAGE BLOCK ═════════════════════
class _ImageBlock extends StatefulWidget {
  final String url;
  const _ImageBlock({required this.url});
  @override
  State<_ImageBlock> createState() => _IBState();
}

class _IBState extends State<_ImageBlock> {
  bool _hover = false;
  @override
  Widget build(BuildContext context) => MouseRegion(
    onEnter: (_) => setState(() => _hover = true),
    onExit: (_) => setState(() => _hover = false),
    child: Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      constraints: const BoxConstraints(maxWidth: 680, maxHeight: 500),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: _hover ? _bdr2 : _bdr.withOpacity(0.5),
        ),
        color: _bg3,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(9),
        child: widget.url.isEmpty
            ? Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.image_outlined, color: _txt2, size: 28),
                    const SizedBox(height: 8),
                    Text('이미지 URL이 없습니다', style: TextStyle(color: _txt2, fontSize: 12)),
                  ],
                ),
              )
            : Image.network(
                widget.url,
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
              ),
      ),
    ),
  );
}

class _Div extends StatelessWidget {
  const _Div();
  @override
  Widget build(BuildContext context) => Container(
    height: 0.5,
    margin: const EdgeInsets.symmetric(vertical: 4),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [Colors.transparent, _bdr.withOpacity(0.6), Colors.transparent],
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
  final int listNumber;
  final KeyEventResult Function(FocusNode, KeyEvent, int) onKey;
  final Function(String, int) onText;
  final VoidCallback onDel, onDup, onFocus, onSelect;
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
    this.listNumber = 0,
    required this.onKey,
    required this.onText,
    required this.onDel,
    required this.onDup,
    required this.onType,
    required this.onCheck,
    required this.onFocus,
    required this.onSelect,
    this.onSelChanged,
    this.blockKey,
  }) : super(key: key);
  @override
  State<_NBlock> createState() => _NBState();
}

class _NBState extends State<_NBlock> {
  bool _foc = false;
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
      if (_foc) widget.onFocus();
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
      color: _txt0.withOpacity(0.85),
      height: 1.85,
      letterSpacing: 0.0,
      fontWeight: FontWeight.w400,
    ),
    BlockType.image => GoogleFonts.inter(fontSize: 14, color: _txt2),
    _ => GoogleFonts.inter(
      fontSize: 15,
      color: _txt0.withOpacity(0.85),
      height: 1.85,
      letterSpacing: 0.0,
      fontWeight: FontWeight.w400,
    ),
  };

  // ── 테이블 감지 (코드 블록 내 마크다운 표) ──────
  bool get _isTable {
    if (widget.block.type != BlockType.code) return false;
    final t = widget.block.controller.text;
    return t.contains('|') && t.contains('---');
  }

  @override
  Widget build(BuildContext context) {
    widget.block.focusNode.onKeyEvent = (n, e) =>
        widget.onKey(n, e, widget.idx);
    final isBul = widget.block.type == BlockType.bullet;
    final isPrevBul = widget.prevType == BlockType.bullet;

    return KeyedSubtree(
      key: widget.blockKey,
      child: GestureDetector(
        onTap: () {
          // 공백 영역 클릭 시 TextField 포커스
          widget.block.focusNode.requestFocus();
          final c = widget.block.controller;
          if (c.selection.isCollapsed && c.selection.baseOffset < 0) {
            c.selection = TextSelection.collapsed(offset: c.text.length);
          }
        },
        behavior: HitTestBehavior.translucent,
        child: Container(
          padding: EdgeInsets.only(
            top: (isBul && isPrevBul) ? 1 : (isBul ? 3 : 2),
            bottom: isBul ? 1 : 2,
            left: widget.block.type == BlockType.quote ? 4 : 8,
            right: 8,
          ),
          decoration: BoxDecoration(
            color: widget.isSelected
                ? _acc.withOpacity(0.07)
                : widget.block.type == BlockType.code
                ? const Color(0xFF161616)
                : widget.block.type == BlockType.quote
                ? Colors.white.withOpacity(0.025)
                : _foc
                ? Colors.white.withOpacity(0.012)
                : null,
            borderRadius: BorderRadius.circular(8),
            border: widget.isSelected
                ? Border.all(color: _acc.withOpacity(0.3))
                : widget.block.type == BlockType.code
                ? Border.all(color: _bdr.withOpacity(0.8))
                : null,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 드래그 핸들 + 선택
              SizedBox(
                width: 24,
                height: 24,
                child: Opacity(
                  opacity: _foc ? 0.5 : 0,
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
                        Icons.drag_indicator_rounded,
                        size: 15,
                        color: _txt2,
                      ),
                      iconSize: 15,
                      onSelected: (v) {
                        if (v == 'd')
                          widget.onDel();
                        else if (v == 'c')
                          widget.onDup();
                        else if (v == 's')
                          widget.onSelect();
                        else if (v == 'h1')
                          widget.onType(BlockType.h1);
                        else if (v == 'h2')
                          widget.onType(BlockType.h2);
                        else if (v == 't')
                          widget.onType(BlockType.text);
                        else if (v == 'b')
                          widget.onType(BlockType.bullet);
                        else if (v == 'cd')
                          widget.onType(BlockType.code);
                      },
                      itemBuilder: (_) => [
                        _mi('s', Icons.check_box_outlined, '선택', _acc),
                        _mi('d', Icons.delete_outline_rounded, '삭제', _red),
                        _mi('c', Icons.content_copy_rounded, '복제', _txt1),
                        const PopupMenuDivider(height: 6),
                        _mi('h1', Icons.looks_one_outlined, '제목 1', _txt1),
                        _mi('h2', Icons.looks_two_outlined, '제목 2', _txt1),
                        _mi('t', Icons.short_text_rounded, '텍스트', _txt1),
                        _mi('b', Icons.format_list_bulleted, '글머리', _txt1),
                        _mi('cd', Icons.code_rounded, '코드', _txt1),
                      ],
                    ),
                  ),
                ),
              ),

              // 불릿
              if (widget.block.type == BlockType.bullet)
                Padding(
                  padding: const EdgeInsets.only(top: 13, right: 12),
                  child: Container(
                    width: 5,
                    height: 5,
                    decoration: BoxDecoration(
                      color: _txt1.withOpacity(0.5),
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
                  padding: const EdgeInsets.only(right: 12),
                  child: Container(
                    width: 3,
                    decoration: BoxDecoration(
                      color: _txt2.withOpacity(0.4),
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

              // 코드 태그
              if (widget.block.type == BlockType.code && !_isTable)
                Padding(
                  padding: const EdgeInsets.only(top: 3, right: 7),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A1A30),
                      borderRadius: BorderRadius.circular(5),
                      border: Border.all(
                        color: const Color(0xFFD4BBFF).withOpacity(0.2),
                      ),
                    ),
                    child: Text(
                      'code',
                      style: GoogleFonts.jetBrainsMono(
                        color: const Color(0xFFD4BBFF),
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                ),

              // 테이블 태그
              if (_isTable)
                Padding(
                  padding: const EdgeInsets.only(top: 3, right: 7),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: _accD,
                      borderRadius: BorderRadius.circular(5),
                      border: Border.all(color: _acc.withOpacity(0.25)),
                    ),
                    child: Text(
                      'table',
                      style: GoogleFonts.inter(
                        color: _acc,
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                ),

              // 이미지 블록 (URL)
              if (widget.block.type == BlockType.image)
                Expanded(
                  child: _ImageBlock(url: widget.block.controller.text),
                ),

              // 텍스트 입력 (이미지 제외)
              if (widget.block.type != BlockType.image)
              Expanded(
                child: Listener(
                  // ✅ onPointerUp: 브라우저 드래그 선택을 Flutter가 직접 감지
                  onPointerUp: (_) {
                    _selTimer?.cancel();
                    _selTimer = Timer(const Duration(milliseconds: 200), () {
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
                    });
                  },
                  child: CompositedTransformTarget(
                    link: widget.block.layerLink,
                    child: TextField(
                      controller: widget.block.controller,
                      focusNode: widget.block.focusNode,
                      maxLines: null,
                      style: _style().copyWith(
                        decoration:
                            (widget.block.type == BlockType.checkbox &&
                                widget.block.isChecked)
                            ? TextDecoration.lineThrough
                            : null,
                        color:
                            (widget.block.type == BlockType.checkbox &&
                                widget.block.isChecked)
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
                        hintText: (_foc && widget.block.controller.text.isEmpty)
                            ? _hint(widget.block.type)
                            : '',
                        hintStyle: TextStyle(
                          color: _txt2.withOpacity(0.4),
                          fontSize: 16,
                        ),
                      ),
                      onChanged: (t) => widget.onText(t, widget.idx),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ); // KeyedSubtree > GestureDetector > Container
  }

  String _hint(BlockType t) => switch (t) {
    BlockType.h1 => '제목 1',
    BlockType.h2 => '제목 2',
    BlockType.h3 => '제목 3',
    BlockType.bullet => '항목 입력...',
    BlockType.checkbox => '할 일 추가...',
    BlockType.code => '코드 또는 표 입력...',
    BlockType.number => '항목 입력...',
    BlockType.quote => '인용 입력...',
    BlockType.image => 'https://... 이미지 URL',
    _ => "내용을 입력하거나  /  로 블록 추가",
  };

  PopupMenuItem<String> _mi(String v, IconData icon, String txt, Color c) =>
      PopupMenuItem(
        value: v,
        height: 34,
        child: Row(
          children: [
            Icon(icon, size: 14, color: c.withOpacity(0.85)),
            const SizedBox(width: 8),
            Text(txt, style: TextStyle(color: c, fontSize: 13)),
          ],
        ),
      );
}

// ══════════════════ SLASH MENU ══════════════════════
class _Opt {
  final String id, label, hint, desc, group;
  final IconData icon;
  const _Opt(this.id, this.label, this.icon, this.hint,
      [this.desc = '', this.group = '']);
}

class _SlashMenu extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final children = <Widget>[];

    if (isSearching || opts.length <= 4) {
      // 검색 모드: 플랫 리스트
      for (int i = 0; i < opts.length; i++) {
        children.add(_SI(opt: opts[i], sel: i == sel, onTap: () => onSel(opts[i])));
      }
    } else {
      // 브라우즈 모드: 카테고리별 그룹
      final groups = <String, List<_Opt>>{};
      for (final o in opts) {
        groups.putIfAbsent(o.group, () => []).add(o);
      }
      int globalIdx = 0;
      final orderedKeys = [
        ..._groupOrder.where((g) => groups.containsKey(g)),
        ...groups.keys.where((g) => !_groupOrder.contains(g)),
      ];
      for (final groupName in orderedKeys) {
        final groupOpts = groups[groupName]!;
        // 그룹 헤더
        children.add(Padding(
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
        ));
        for (final opt in groupOpts) {
          final idx = globalIdx;
          children.add(_SI(
            opt: opt,
            sel: idx == sel,
            onTap: () => onSel(opt),
          ));
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
              color: _bg2.withOpacity(0.96),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _bdr2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.45),
                  blurRadius: 28,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: SingleChildScrollView(
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
    ('✨ 개선', 'improve', '더 명확하고 세련된 문장으로 개선해줘'),
    ('✏️ 교정', 'proofread', '맞춤법과 문법을 교정해줘'),
    ('💡 설명', 'explain', '이 내용을 쉽게 설명해줘. 3줄 이내로'),
    ('📝 요약', 'summarize', '이 내용을 한 문장으로 요약해줘'),
    ('🔄 번역(영어)', 'translate', '이 내용을 영어로 번역해줘'),
    ('📋 항목화', 'bullet', '이 내용을 글머리 기호 목록으로 정리해줘'),
    ('💼 공식체', 'formal', '이 내용을 공식적인 문체로 바꿔줘'),
    ('🗣️ 친근체', 'casual', '이 내용을 친근하고 자연스러운 문체로 바꿔줘'),
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
            Uri.parse('http://127.0.0.1:8000/api/ai/edit-selection'),
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
            width: _aiMode ? 320 : 380,
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF1C1C28),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _bdr2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.5),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                  BoxShadow(color: _acc.withOpacity(0.04), blurRadius: 40),
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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
        child: Icon(icon, size: 15, color: _txt1),
      ),
    );
  }

  Widget _buildMainToolbar() => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 서식 버튼들 (Tooltip 없음 — Overlay 안에서 Tooltip 사용 금지)
        _selBtn(Icons.format_bold_rounded, 'B', _toggleBold),
        _selBtn(Icons.format_italic_rounded, 'I', _toggleItalic),
        _selBtn(Icons.format_underline_rounded, 'U', () {
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
        _selBtn(Icons.format_strikethrough_rounded, 'S', () {
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
        _selBtn(Icons.code_rounded, '<>', () {
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
          height: 20,
          color: _bdr2,
          margin: const EdgeInsets.symmetric(horizontal: 2),
        ),
        _selBtn(Icons.copy_rounded, '복사', () {
          Clipboard.setData(ClipboardData(text: widget.selectedText));
          widget.onDismiss();
        }),
        Container(
          width: 1,
          height: 20,
          color: _bdr2,
          margin: const EdgeInsets.symmetric(horizontal: 2),
        ),
        // AI 버튼
        GestureDetector(
          onTap: () => setState(() => _aiMode = true),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: _accD,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _acc.withOpacity(0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.auto_awesome_rounded, size: 13, color: _acc),
                const SizedBox(width: 5),
                const Text(
                  'AI 편집',
                  style: TextStyle(
                    color: _acc,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 3),
                const Icon(
                  Icons.keyboard_arrow_right_rounded,
                  size: 14,
                  color: _acc,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 4),
        // 닫기
        GestureDetector(
          onTap: widget.onDismiss,
          child: const Padding(
            padding: EdgeInsets.all(6),
            child: Icon(Icons.close_rounded, size: 14, color: _txt2),
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
                border: Border.all(color: _acc.withOpacity(0.3)),
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
                          border: Border.all(color: _acc.withOpacity(0.4)),
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
  const _SI({required this.opt, required this.sel, required this.onTap});
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
          duration: const Duration(milliseconds: 80),
          margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: active ? _bg4 : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              // 아이콘 컨테이너
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: active ? _accD : _bg3,
                  borderRadius: BorderRadius.circular(7),
                  border: Border.all(
                    color: active ? _acc.withOpacity(0.35) : _bdr,
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
                        color: active ? _txt0 : _txt0.withOpacity(0.8),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (widget.opt.desc.isNotEmpty)
                      Text(
                        widget.opt.desc,
                        style: GoogleFonts.inter(
                          color: _txt2,
                          fontSize: 11,
                        ),
                      ),
                  ],
                ),
              ),
              // 단축키 힌트
              if (widget.opt.hint.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6, vertical: 2),
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
      color: _accD,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: _acc.withOpacity(0.3)),
    ),
    indicatorSize: TabBarIndicatorSize.tab,
    labelColor: _acc,
    unselectedLabelColor: _txt2,
    labelStyle: GoogleFonts.inter(
      fontSize: 11,
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
      _T(Icons.chat_bubble_outline_rounded, 'Ask'),
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
  final Animation<double> pulse;
  const _SumPanel({
    required this.st,
    required this.ref,
    required this.tCtrl,
    required this.gCtrl,
    required this.snack,
    required this.pulse,
  });
  @override
  Widget build(BuildContext context) => Column(
    children: [
      // 미니 헤더
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 10, 8),
        child: Row(
          children: [
            Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(
                color: st.isSummaryLoading
                    ? _acc.withOpacity(0.6)
                    : st.summaryBlocks.isNotEmpty
                    ? _acc
                    : _txt2.withOpacity(0.3),
                shape: BoxShape.circle,
                boxShadow: st.summaryBlocks.isNotEmpty && !st.isSummaryLoading
                    ? [BoxShadow(color: _acc.withOpacity(0.6), blurRadius: 6)]
                    : [],
              ),
            ),
            const SizedBox(width: 7),
            Text(
              '자동 요약',
              style: GoogleFonts.inter(
                color: _txt2,
                fontSize: 10,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.4,
              ),
            ),
            const Spacer(),
            if (st.isSummaryLoading)
              SizedBox(
                width: 13,
                height: 13,
                child: CircularProgressIndicator(
                  color: _acc,
                  strokeWidth: 1.5,
                  strokeCap: StrokeCap.round,
                ),
              )
            else
              InkWell(
                onTap: () => ref
                    .read(fileEditorProvider.notifier)
                    .requestSummary(title: tCtrl.text, tags: gCtrl.text),
                borderRadius: BorderRadius.circular(6),
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.refresh_rounded, size: 12, color: _txt2.withOpacity(0.6)),
                      const SizedBox(width: 4),
                      Text(
                        '재요약',
                        style: GoogleFonts.inter(
                          color: _txt2.withOpacity(0.6),
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
      Container(
        height: 0.5,
        color: _bdr.withOpacity(0.5),
      ),
      Expanded(
        child: Stack(
          children: [
            if (st.summaryBlocks.isEmpty && !st.isSummaryLoading)
              const _Empty(
                icon: Icons.auto_awesome_rounded,
                title: '자동 요약',
                desc: '글을 작성하면\nAI가 자동으로 요약합니다.',
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
                onPin: () => ref
                    .read(fileEditorProvider.notifier)
                    .toggleSummarySave(i),
                onDel: () => ref
                    .read(fileEditorProvider.notifier)
                    .removeSummaryBlock(i),
                onCopy: () {
                  Clipboard.setData(
                    ClipboardData(text: st.summaryBlocks[i].content),
                  );
                  snack('복사됨');
                },
                onExport: () async {
                  snack('확정 요약이 저장됩니다.');
                  ref
                      .read(fileEditorProvider.notifier)
                      .toggleSummarySave(i);
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
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
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
                          style: GoogleFonts.inter(
                            color: _txt1,
                            fontSize: 11,
                          ),
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
  const _SumCard({
    Key? key,
    required this.block,
    required this.index,
    required this.onPin,
    required this.onDel,
    required this.onCopy,
    required this.onExport,
  }) : super(key: key);
  @override
  State<_SumCard> createState() => _SCState();
}

class _SCState extends State<_SumCard> with SingleTickerProviderStateMixin {
  late AnimationController _ac;
  late Animation<double> _fade, _scale;
  bool _expanded = true;
  @override
  void initState() {
    super.initState();
    _ac = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: widget.index == 0 ? 250 : 0),
    );
    _fade = CurvedAnimation(parent: _ac, curve: Curves.easeOut);
    _scale = Tween(
      begin: widget.index == 0 ? 0.97 : 1.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _ac, curve: Curves.easeOutCubic));
    _ac.forward();
  }

  @override
  void dispose() {
    _ac.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pinned = widget.block.isSaved;
    return FadeTransition(
      opacity: _fade,
      child: ScaleTransition(
        scale: _scale,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: pinned ? const Color(0xFF0A1505) : _bg3,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: pinned ? _acc.withOpacity(0.4) : _bdr,
              width: pinned ? 1.5 : 1,
            ),
            boxShadow: pinned
                ? [BoxShadow(color: _acc.withOpacity(0.07), blurRadius: 24)]
                : [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.12),
                      blurRadius: 6,
                    ),
                  ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 헤더
              GestureDetector(
                onTap: () => setState(() => _expanded = !_expanded),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
                  child: Row(
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: pinned ? _acc : _txt2.withOpacity(0.25),
                          shape: BoxShape.circle,
                          boxShadow: pinned
                              ? [
                                  BoxShadow(
                                    color: _acc.withOpacity(0.8),
                                    blurRadius: 6,
                                  ),
                                ]
                              : [],
                        ),
                      ),
                      const SizedBox(width: 7),
                      Text(
                        pinned ? '확정' : '최신 분석',
                        style: TextStyle(
                          color: pinned ? _acc : _txt2.withOpacity(0.6),
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const Spacer(),
                      // 액션 버튼들
                      _IB(
                        Icons.content_copy_rounded,
                        widget.onCopy,
                        color: _txt2.withOpacity(0.5),
                        sz: 12,
                      ),
                      const SizedBox(width: 1),
                      _IB(
                        Icons.save_outlined,
                        widget.onExport,
                        color: pinned ? _acc : _txt2.withOpacity(0.5),
                        sz: 12,
                      ),
                      const SizedBox(width: 1),
                      _IB(
                        pinned ? Icons.push_pin : Icons.push_pin_outlined,
                        widget.onPin,
                        color: pinned ? _acc : _txt2.withOpacity(0.5),
                        sz: 12,
                      ),
                      const SizedBox(width: 1),
                      _IB(
                        Icons.close_rounded,
                        widget.onDel,
                        color: _txt2.withOpacity(0.5),
                        sz: 12,
                      ),
                      const SizedBox(width: 2),
                      AnimatedRotation(
                        turns: _expanded ? 0 : 0.5,
                        duration: const Duration(milliseconds: 150),
                        child: Icon(
                          Icons.expand_less_rounded,
                          size: 14,
                          color: _txt2.withOpacity(0.5),
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
                      pinned ? _acc.withOpacity(0.15) : _bdr.withOpacity(0.5),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
              // 내용 (접기/펼치기)
              AnimatedCrossFade(
                duration: const Duration(milliseconds: 200),
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
        ),
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
                  color: const Color(0xFF070E03),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _acc.withOpacity(0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 4,
                          height: 4,
                          decoration: BoxDecoration(
                            color: _acc,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: _acc.withOpacity(0.8),
                                blurRadius: 6,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 7),
                        const Text(
                          '분석 중인 문단',
                          style: TextStyle(
                            color: _acc,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
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

class _QuizPanel extends StatefulWidget {
  final FileEditorState st;
  final WidgetRef ref;
  const _QuizPanel({required this.st, required this.ref});
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

  @override
  void initState() {
    super.initState();
    _flipAc = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _flipAnim = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _flipAc, curve: Curves.easeInOutCubic),
    );
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
    if (quiz.isEmpty) return const _Empty(icon: Icons.quiz_rounded, title: '퀴즈 없음', desc: '먼저 퀴즈를 생성하세요.');
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
                style: GoogleFonts.inter(color: _txt2, fontSize: 11, fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () => setState(() { _cardMode = false; _cardIdx = 0; _flipped = false; }),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _bg3,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: _bdr2),
                  ),
                  child: Text('목록 보기', style: GoogleFonts.inter(color: _txt2, fontSize: 10, fontWeight: FontWeight.w600)),
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
                        color: isBack
                            ? const Color(0xFF1A2508)
                            : _bg3,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: isBack ? _acc.withOpacity(0.4) : _bdr2,
                          width: isBack ? 1.5 : 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                          if (isBack)
                            BoxShadow(color: _acc.withOpacity(0.08), blurRadius: 30),
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
                                    Icon(Icons.check_circle_outline_rounded, color: _acc, size: 22),
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
                                        color: _acc.withOpacity(0.2),
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
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: _accD,
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: _acc.withOpacity(0.3)),
                                    ),
                                    child: Text('Q', style: GoogleFonts.inter(color: _acc, fontSize: 11, fontWeight: FontWeight.w800)),
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
                    color: _cardIdx > 0 ? _txt1 : _txt2.withOpacity(0.3),
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
                    color: _cardIdx < (st.quizData?.length ?? 1) - 1 ? _bg3 : _bg2,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _bdr),
                  ),
                  child: Icon(
                    Icons.arrow_forward_rounded,
                    size: 16,
                    color: _cardIdx < (st.quizData?.length ?? 1) - 1 ? _txt1 : _txt2.withOpacity(0.3),
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
                        onTap: () => setState(() { _cardMode = true; _cardIdx = 0; _flipped = false; }),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: _accD,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: _acc.withOpacity(0.3)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.style_rounded, size: 11, color: _acc),
                              const SizedBox(width: 5),
                              Text('카드 모드', style: GoogleFonts.inter(color: _acc, fontSize: 10, fontWeight: FontWeight.w700)),
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
                    onAns: (oi) =>
                        ref.read(fileEditorProvider.notifier).answerQuiz(qi, oi),
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
      margin: const EdgeInsets.only(bottom: 24),
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
          const SizedBox(height: 12),
          // 보기들
          ...List.generate(options.length, (oi) {
            Color bg = _bg3, bdr = _bdr, tc = _txt0;
            if (answered != null) {
              if (oi == correct) {
                bg = _grn.withOpacity(0.1);
                bdr = _grn.withOpacity(0.4);
                tc = _grn;
              } else if (oi == answered) {
                bg = _red.withOpacity(0.1);
                bdr = _red.withOpacity(0.4);
                tc = _red;
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
                    color: bg,
                    borderRadius: BorderRadius.circular(10),
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
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _bg2,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _bdr),
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
                title: 'Quick Ask',
                desc: '내 노트 + 웹으로\n무엇이든 답합니다.',
              ),
      ),
      Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: _bdr)),
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: ctrl,
                style: GoogleFonts.inter(color: _txt0, fontSize: 13),
                decoration: InputDecoration(
                  hintText: '노트에 대해 무엇이든 물어보세요...',
                  hintStyle: GoogleFonts.inter(color: _txt2, fontSize: 13),
                  filled: true,
                  fillColor: _bg3,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: _bdr),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: _bdr),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: _acc, width: 1.5),
                  ),
                ),
                onSubmitted: (v) {
                  onAsk(v);
                  ctrl.clear();
                },
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () {
                onAsk(ctrl.text);
                ctrl.clear();
              },
              child: Container(
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  color: _acc,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: _acc.withOpacity(0.4),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.arrow_upward_rounded,
                  color: Colors.black,
                  size: 17,
                ),
              ),
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
  const _MindmapView({required this.st, required this.ref});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(28),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _accD,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(color: _acc.withOpacity(0.2), blurRadius: 12),
                ],
              ),
              child: const Icon(
                Icons.account_tree_rounded,
                color: _acc,
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '마인드맵',
                  style: TextStyle(
                    color: _txt0,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                ),
                const Text(
                  'AI가 개념 간 연결을 시각화합니다',
                  style: TextStyle(color: _txt2, fontSize: 12),
                ),
              ],
            ),
            const Spacer(),
            _TBtn(
              Icons.refresh_rounded,
              '재생성',
              () => ref.read(fileEditorProvider.notifier).requestGraph(),
            ),
          ],
        ),
        const SizedBox(height: 20),
        // 통계
        Row(
          children: [
            _Stat('블록', '${st.blocks.length}개', Icons.article_outlined),
            const SizedBox(width: 12),
            _Stat('글자', '${st.charCount}자', Icons.text_fields_rounded),
            const SizedBox(width: 12),
            _Stat(
              '확정 요약',
              '${st.summaryBlocks.where((b) => b.isSaved).length}개',
              Icons.bookmark_rounded,
              accent: true,
            ),
            const SizedBox(width: 12),
            _Stat(
              '읽기',
              '${(st.wordCount / 200).ceil()}분',
              Icons.timer_outlined,
            ),
          ],
        ),
        const SizedBox(height: 20),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: _bg3,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: _bdr),
              boxShadow: [
                BoxShadow(color: _acc.withOpacity(0.03), blurRadius: 40),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: st.isGraphLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: _acc,
                        strokeWidth: 2,
                      ),
                    )
                  : st.graphData != null
                  ? _GraphCanvas(data: st.graphData!)
                  : const _Empty(
                      icon: Icons.account_tree_outlined,
                      title: '마인드맵',
                      desc: '충분한 내용 작성 시\n자동으로 생성됩니다.',
                    ),
            ),
          ),
        ),
      ],
    ),
  );
}

class _GraphCanvas extends StatefulWidget {
  final Map<String, dynamic> data;
  const _GraphCanvas({required this.data});
  @override
  State<_GraphCanvas> createState() => _GCS();
}

class _GCS extends State<_GraphCanvas> with SingleTickerProviderStateMixin {
  late AnimationController _ac;
  List<_GN> ns = [];
  List<_GE> es = [];
  double _t = 0;
  @override
  void initState() {
    super.initState();
    _ac = AnimationController(vsync: this, duration: const Duration(days: 1))
      ..addListener(
        () => setState(() {
          _t += 0.006;
          _tick();
        }),
      )
      ..forward();
    WidgetsBinding.instance.addPostFrameCallback((_) => _build());
  }

  void _build() {
    final sz = context.size ?? const Size(800, 500);
    final cx = sz.width / 2, cy = sz.height / 2;
    ns.clear();
    es.clear();
    final rn = widget.data['nodes'] as List ?? [];
    final re = widget.data['edges'] as List ?? [];
    for (int i = 0; i < rn.length; i++) {
      final ic = i == 0;
      final tp = rn[i]['type'] ?? 'sub';
      ns.add(
        _GN(
          id: rn[i]['id'].toString(),
          label: rn[i]['label'].toString(),
          r: ic
              ? 14
              : tp == 'sub'
              ? 8
              : 6,
          color: ic
              ? _acc
              : tp == 'sub'
              ? _blu
              : _pur,
          br: ic ? 0 : 60 + math.Random().nextDouble() * 110,
          ba: ic ? 0 : (2 * math.pi / (math.max(rn.length - 1, 1))) * i,
          x: cx,
          y: cy,
          core: ic,
        ),
      );
    }
    for (var e in re)
      es.add(_GE(e['source'].toString(), e['target'].toString()));
  }

  void _tick() {
    final sz = context.size ?? const Size(800, 500);
    final cx = sz.width / 2, cy = sz.height / 2;
    for (var n in ns) {
      if (n.core) {
        n.x = cx;
        n.y = cy;
        continue;
      }
      final tx = cx + math.cos(n.ba + _t * 0.3) * n.br;
      final ty =
          cy +
          math.sin(n.ba + _t * 0.3) * n.br +
          math.sin(_t * 1.1 + n.ba) * 12;
      n.x += (tx - n.x) * 0.04;
      n.y += (ty - n.y) * 0.04;
    }
  }

  @override
  void dispose() {
    _ac.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      CustomPaint(painter: _GP(ns, es), size: Size.infinite);
}

class _GN {
  String id, label;
  double r, x, y, br, ba;
  Color color;
  bool core;
  _GN({
    required this.id,
    required this.label,
    required this.r,
    required this.color,
    required this.br,
    required this.ba,
    required this.x,
    required this.y,
    this.core = false,
  });
}

class _GE {
  String s, t;
  _GE(this.s, this.t);
}

class _GP extends CustomPainter {
  final List<_GN> ns;
  final List<_GE> es;
  _GP(this.ns, this.es);
  @override
  void paint(Canvas c, Size s) {
    final lp = Paint()
      ..strokeWidth = 0.7
      ..style = PaintingStyle.stroke
      ..color = const Color(0xFF252538);
    final hp = Paint()
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke
      ..color = _acc.withOpacity(0.18);
    for (var e in es) {
      final a = ns.where((n) => n.id == e.s).firstOrNull;
      final b = ns.where((n) => n.id == e.t).firstOrNull;
      if (a != null && b != null)
        c.drawLine(Offset(a.x, a.y), Offset(b.x, b.y), a.core ? hp : lp);
    }
    for (var n in ns) {
      c.drawCircle(
        Offset(n.x, n.y),
        n.r,
        Paint()
          ..color = n.color
          ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 4),
      );
      if (n.label.isNotEmpty) {
        final lbl = n.label.length > 9
            ? '${n.label.substring(0, 9)}…'
            : n.label;
        final tp = TextPainter(
          text: TextSpan(
            text: lbl,
            style: TextStyle(
              color: n.core ? Colors.white : _txt1,
              fontSize: n.core ? 11 : 9,
              fontWeight: n.core ? FontWeight.w800 : FontWeight.w500,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(c, Offset(n.x - tp.width / 2, n.y + n.r + 4));
      }
    }
  }

  @override
  bool shouldRepaint(_) => true;
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
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: _bg3,
            shape: BoxShape.circle,
            border: Border.all(color: _bdr, width: 0.5),
          ),
          child: Icon(icon, size: 26, color: _txt2.withOpacity(0.7)),
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
            color: _txt2.withOpacity(0.7),
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
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 26,
          height: 26,
          child: CircularProgressIndicator(
            color: _acc,
            strokeWidth: 2,
            strokeCap: StrokeCap.round,
          ),
        ),
        const SizedBox(height: 14),
        Text(msg, style: const TextStyle(color: _txt2, fontSize: 13)),
      ],
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
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [Color(0xFF191919), Colors.transparent],
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
  final Animation<double>? pulse;
  const _FABtn({
    required this.loading,
    required this.label,
    required this.icon,
    this.onTap,
    this.pulse,
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
              gradient: widget.loading
                  ? LinearGradient(colors: [_accD, const Color(0xFF1A2A0A)])
                  : null,
              color: widget.loading ? null : (_h ? _bg4 : _bg3),
              borderRadius: BorderRadius.circular(32),
              border: Border.all(
                color: widget.loading
                    ? _acc.withOpacity(0.4)
                    : (_h ? _bdr2 : _bdr),
                width: widget.loading ? 1.5 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.35),
                  blurRadius: 14,
                  offset: const Offset(0, 5),
                ),
                if (widget.loading)
                  BoxShadow(color: _acc.withOpacity(0.12), blurRadius: 20),
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
    borderRadius: BorderRadius.circular(6),
    child: Padding(
      padding: const EdgeInsets.all(5),
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
        border: Border.all(color: accent ? _acc.withOpacity(0.3) : _bdr),
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
    color: _accD.withOpacity(0.4),
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
