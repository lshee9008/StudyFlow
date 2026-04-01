// ╔══════════════════════════════════════════════════════════╗
// ║  file_screen.dart v4  —  Premium Notion-exact Editor     ║
// ╚══════════════════════════════════════════════════════════╝
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import '../../models/block_model.dart';
import 'file_provider.dart';

// ── 색상 팔레트 ────────────────────────────────────────────
const _c = _Colors();

class _Colors {
  const _Colors();
  Color get bg => const Color(0xFF0C0C10);
  Color get surface => const Color(0xFF141418);
  Color get card => const Color(0xFF1A1A22);
  Color get hover => const Color(0xFF202028);
  Color get border => const Color(0xFF252530);
  Color get borderHi => const Color(0xFF323240);
  Color get txt => const Color(0xFFEEEEF8);
  Color get txt2 => const Color(0xFF7878A0);
  Color get txt3 => const Color(0xFF3A3A50);
  Color get acc => const Color(0xFFCCFF66);
  Color get accDim => const Color(0xFF192208);
  Color get accMid => const Color(0xFF88CC00);
  Color get blue => const Color(0xFF5B8DEF);
  Color get green => const Color(0xFF4ADE80);
  Color get red => const Color(0xFFFF5577);
  Color get purple => const Color(0xFFA78BFA);
  Color get yellow => const Color(0xFFFFCC44);
}

// ── 텍스트 스타일 ────────────────────────────────────────────
TextStyle _ts(
  double size, {
  Color? color,
  FontWeight w = FontWeight.w400,
  double h = 1.0,
  double ls = 0,
}) => TextStyle(
  fontSize: size,
  color: color,
  fontWeight: w,
  height: h,
  letterSpacing: ls,
);

// ═══════════════════════════════════════════════════════════
// FileScreen
// ═══════════════════════════════════════════════════════════
class FileScreen extends ConsumerStatefulWidget {
  final String fileId;
  final String projectId;
  const FileScreen({Key? key, required this.fileId, this.projectId = 'default'})
    : super(key: key);
  @override
  ConsumerState<FileScreen> createState() => _FileScreenState();
}

class _FileScreenState extends ConsumerState<FileScreen>
    with TickerProviderStateMixin {
  final _titleCtrl = TextEditingController();
  final _tagsCtrl = TextEditingController();
  final _promptCtrl = TextEditingController();
  final _qaCtrl = TextEditingController();
  late final TabController _tab;

  Timer? _saveT, _focusT, _autoSumT;
  bool _saving = false;
  int _lastSumLen = 0;
  int _viewMode = 0; // 0:split 1:fullscreen 2:graph
  bool _savePending = false; // ← 추가

  // Slash menu
  OverlayEntry? _slashEntry;
  int _slashSel = 0;
  List<_Cmd> _slashOpts = [];

  // Animations
  late final AnimationController _saveAc;
  late final AnimationController _panelAc;
  late final Animation<double> _saveAlpha;
  late final Animation<double> _panelFade;

  static const _cmds = [
    _Cmd('h1', '제목 1', Icons.looks_one_outlined, _CmdCat.text),
    _Cmd('h2', '제목 2', Icons.looks_two_outlined, _CmdCat.text),
    _Cmd('h3', '제목 3', Icons.looks_3_outlined, _CmdCat.text),
    _Cmd('p', '텍스트', Icons.short_text, _CmdCat.text),
    _Cmd('bullet', '글머리 기호', Icons.format_list_bulleted, _CmdCat.list),
    _Cmd('todo', '할 일', Icons.check_box_outline_blank, _CmdCat.list),
    _Cmd('code', '코드 블록', Icons.data_object, _CmdCat.media),
    _Cmd('quote', '인용문', Icons.format_quote, _CmdCat.media),
    _Cmd('divider', '구분선', Icons.horizontal_rule, _CmdCat.media),
  ];

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 5, vsync: this);
    _saveAc = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _panelAc = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _saveAlpha = CurvedAnimation(parent: _saveAc, curve: Curves.easeOut);
    _panelFade = CurvedAnimation(parent: _panelAc, curve: Curves.easeOutCubic);
    _panelAc.value = 1;
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  Future<void> _init() async {
    await ref.read(fileEditorProvider.notifier).loadFileDetail(widget.fileId);
    final st = ref.read(fileEditorProvider);
    if (mounted)
      setState(() {
        _titleCtrl.text = '';
        _tagsCtrl.text = '';
        _promptCtrl.text = st.filePrompt ?? '';
      });
    // 파일 제목/태그는 DB에서 직접 가져옴
    try {
      final f = await _getFileInfo(widget.fileId);
      if (f != null && mounted)
        setState(() {
          _titleCtrl.text = f['title'] ?? '';
          _tagsCtrl.text = f['tags'] ?? '';
        });
    } catch (_) {}
  }

  Future<Map<String, dynamic>?> _getFileInfo(String id) async {
    try {
      // 로컬 DB에서
      final f = await _fetchFileLocal(id);
      return f;
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> _fetchFileLocal(String id) async {
    // FilesDBHelper.getFile(id) 호출해서 title/tags 반환
    return null; // 실제 구현 시 FilesDBHelper 사용
  }

  @override
  void dispose() {
    _saveT?.cancel();
    _focusT?.cancel();
    _autoSumT?.cancel();
    _titleCtrl.dispose();
    _tagsCtrl.dispose();
    _promptCtrl.dispose();
    _qaCtrl.dispose();
    _tab.dispose();
    _saveAc.dispose();
    _panelAc.dispose();
    _removeSlash();
    super.dispose();
  }

  // ── 저장 ─────────────────────────────────────────────────
  void _onChange({String? ft}) {
    if (_savePending) return; // ← 중복 방지
    _savePending = true;

    if (ft != null)
      ref.read(fileEditorProvider.notifier).state = ref
          .read(fileEditorProvider)
          .copyWith(focusedText: ft);
    setState(() => _saving = true);
    _saveT?.cancel();
    _saveT = Timer(const Duration(milliseconds: 800), () async {
      _savePending = false; // ← 타이머 완료 후 해제
      await ref
          .read(fileEditorProvider.notifier)
          .saveFile(
            fileId: widget.fileId,
            title: _titleCtrl.text,
            tags: _tagsCtrl.text,
            prompt: _promptCtrl.text,
            updateAt: DateTime.now(),
          );
      if (mounted) {
        setState(() => _saving = false);
        _saveAc.forward(from: 0);
      }
    });
    final len = ref.read(fileEditorProvider).meaningfulCharCount;
    if ((len - _lastSumLen).abs() > 100) {
      _autoSumT?.cancel();
      _autoSumT = Timer(const Duration(seconds: 8), _triggerSum);
    }
  }

  void _triggerSum() {
    if (_tab.index == 0 && !ref.read(fileEditorProvider).isSummaryLoading) {
      _lastSumLen = ref.read(fileEditorProvider).meaningfulCharCount;
      ref
          .read(fileEditorProvider.notifier)
          .requestSummary(title: _titleCtrl.text, tags: _tagsCtrl.text);
    }
  }

  void _onFocus(String text) {
    _focusT?.cancel();
    _focusT = Timer(const Duration(milliseconds: 1500), () {
      if (text.trim().length > 15) {
        ref
            .read(fileEditorProvider.notifier)
            .analyzeBlock(text: text, title: _titleCtrl.text);
      }
    });
  }

  // ── 키 이벤트 ─────────────────────────────────────────────
  KeyEventResult _onKey(FocusNode node, KeyEvent event, int idx) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final meta = HardwareKeyboard.instance.isMetaPressed;
    final ctrl = HardwareKeyboard.instance.isControlPressed;
    final shift = HardwareKeyboard.instance.isShiftPressed;

    // Ctrl/Cmd+A
    if ((meta || ctrl) && event.logicalKey == LogicalKeyboardKey.keyA) {
      final c = ref.read(fileEditorProvider).blocks[idx].controller;
      c.selection = TextSelection(baseOffset: 0, extentOffset: c.text.length);
      return KeyEventResult.handled;
    }

    // Slash menu nav
    if (_slashEntry != null) {
      if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
        if (_slashSel > 0) {
          _slashSel--;
          _slashEntry!.markNeedsBuild();
        }
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
        if (_slashSel < _slashOpts.length - 1) {
          _slashSel++;
          _slashEntry!.markNeedsBuild();
        }
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.enter) {
        _applyCmd(idx, _slashOpts[_slashSel]);
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.escape) {
        _removeSlash();
        return KeyEventResult.handled;
      }
    }

    final blocks = ref.read(fileEditorProvider).blocks;
    final bc = blocks[idx].controller;
    final bt = blocks[idx].type;

    // Tab / Shift+Tab
    if (event.logicalKey == LogicalKeyboardKey.tab) {
      shift
          ? ref.read(fileEditorProvider.notifier).dedent(idx)
          : ref.read(fileEditorProvider.notifier).indent(idx);
      return KeyEventResult.handled;
    }

    // Enter
    if (event.logicalKey == LogicalKeyboardKey.enter && !meta && !ctrl) {
      final text = bc.text;
      final pos = bc.selection.baseOffset.clamp(0, text.length);

      // 빈 리스트 탈출
      if (text.isEmpty &&
          (bt == BlockType.bullet || bt == BlockType.checkbox)) {
        ref.read(fileEditorProvider.notifier).exitListMode(idx);
        return KeyEventResult.handled;
      }

      // 커서에서 분리
      bc.text = text.substring(0, pos);
      ref.read(fileEditorProvider.notifier).insertBlocks(idx + 1, [
        text.substring(pos),
      ]);

      WidgetsBinding.instance.addPostFrameCallback((_) {
        final upd = ref.read(fileEditorProvider).blocks;
        if (idx + 1 < upd.length) {
          // 리스트 타입 유지
          if (bt == BlockType.bullet || bt == BlockType.checkbox) {
            ref.read(fileEditorProvider.notifier).setType(idx + 1, bt);
          }
          upd[idx + 1].focusNode.requestFocus();
          upd[idx + 1].controller.selection = TextSelection.collapsed(
            offset: 0,
          );
        }
      });
      _onChange();
      return KeyEventResult.handled;
    }

    // Backspace
    if (event.logicalKey == LogicalKeyboardKey.backspace) {
      if (bc.selection.isCollapsed && bc.selection.baseOffset == 0 && idx > 0) {
        ref.read(fileEditorProvider.notifier).mergeWithPrev(idx);
        return KeyEventResult.handled;
      }
      if (bc.text.isEmpty &&
          bt != BlockType.text &&
          bt != BlockType.h1 &&
          bt != BlockType.h2 &&
          bt != BlockType.h3) {
        ref.read(fileEditorProvider.notifier).setType(idx, BlockType.text);
        return KeyEventResult.handled;
      }
    }

    // 방향키
    if (event.logicalKey == LogicalKeyboardKey.arrowUp && idx > 0) {
      _focus(idx - 1);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowDown &&
        idx < blocks.length - 1) {
      _focus(idx + 1);
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  void _focus(int idx) {
    final blocks = ref.read(fileEditorProvider).blocks;
    if (idx >= 0 && idx < blocks.length) {
      blocks[idx].focusNode.requestFocus();
      final c = blocks[idx].controller;
      c.selection = TextSelection.collapsed(offset: c.text.length);
    }
  }

  // ── 텍스트 변경 ───────────────────────────────────────────
  void _onText(String text, int idx) {
    if (text.contains('\n')) {
      final lines = text.split('\n');
      ref.read(fileEditorProvider).blocks[idx].controller.text = lines[0];
      if (lines.length > 1) {
        ref
            .read(fileEditorProvider.notifier)
            .insertBlocks(idx + 1, lines.sublist(1));
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => _focus(idx + lines.length - 1),
        );
      }
      _onChange(ft: lines[0]);
      return;
    }

    // 마크다운 단축키
    if (text.endsWith(' ')) {
      BlockType? nt;
      String nc = text;
      if (text == '# ') {
        nt = BlockType.h1;
        nc = '';
      } else if (text == '## ') {
        nt = BlockType.h2;
        nc = '';
      } else if (text == '### ') {
        nt = BlockType.h3;
        nc = '';
      } else if (text == '- ' || text == '* ') {
        nt = BlockType.bullet;
        nc = '';
      } else if (text == '[] ') {
        nt = BlockType.checkbox;
        nc = '';
      }
      if (nt != null) {
        final c = ref.read(fileEditorProvider).blocks[idx].controller;
        c.text = nc;
        ref.read(fileEditorProvider.notifier).setType(idx, nt);
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => c.selection = TextSelection.collapsed(offset: nc.length),
        );
        _onChange(ft: nc);
        return;
      }
    }

    // 슬래시 메뉴
    final si = text.lastIndexOf('/');
    if (si != -1 && si == text.length - 1)
      _showSlash(context, idx, '');
    else if (si != -1 && !text.substring(si + 1).contains(' '))
      _showSlash(context, idx, text.substring(si + 1));
    else
      _removeSlash();

    _onChange(ft: text);
  }

  // ── 슬래시 메뉴 ──────────────────────────────────────────
  void _showSlash(BuildContext ctx, int idx, String q) {
    _slashOpts = q.isEmpty
        ? _cmds
        : _cmds
              .where((c) => c.label.toLowerCase().contains(q.toLowerCase()))
              .toList();
    if (_slashOpts.isEmpty) {
      _removeSlash();
      return;
    }
    if (_slashEntry == null) _slashSel = 0;
    _slashEntry?.remove();

    final blocks = ref.read(fileEditorProvider).blocks;
    _slashEntry = OverlayEntry(
      builder: (_) => Positioned(
        width: 280,
        child: CompositedTransformFollower(
          link: blocks[idx].layerLink,
          showWhenUnlinked: false,
          offset: const Offset(0, 40),
          child: _SlashMenu(
            cmds: _slashOpts,
            sel: _slashSel,
            onSel: (cmd) => _applyCmd(idx, cmd),
          ),
        ),
      ),
    );
    Overlay.of(ctx).insert(_slashEntry!);
  }

  void _applyCmd(int idx, _Cmd cmd) {
    _removeSlash();
    final c = ref.read(fileEditorProvider).blocks[idx].controller;
    final si = c.text.lastIndexOf('/');
    if (si != -1) c.text = c.text.substring(0, si);

    switch (cmd.id) {
      case 'h1':
        ref.read(fileEditorProvider.notifier).setType(idx, BlockType.h1);
        break;
      case 'h2':
        ref.read(fileEditorProvider.notifier).setType(idx, BlockType.h2);
        break;
      case 'h3':
        ref.read(fileEditorProvider.notifier).setType(idx, BlockType.h3);
        break;
      case 'bullet':
        ref.read(fileEditorProvider.notifier).setType(idx, BlockType.bullet);
        break;
      case 'todo':
        ref.read(fileEditorProvider.notifier).setType(idx, BlockType.checkbox);
        break;
      case 'code':
        ref.read(fileEditorProvider.notifier).setType(idx, BlockType.code);
        break;
      case 'divider':
        c.text = '';
        ref.read(fileEditorProvider.notifier).setType(idx, BlockType.code);
        c.text = '────────────────────────────────────';
        break;
      case 'quote':
        ref.read(fileEditorProvider.notifier).setType(idx, BlockType.h3);
        break;
      default:
        ref.read(fileEditorProvider.notifier).setType(idx, BlockType.text);
    }
    _focus(idx);
  }

  void _removeSlash() {
    _slashEntry?.remove();
    _slashEntry = null;
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: _ts(13, color: _c.txt)),
        backgroundColor: _c.card,
        duration: const Duration(milliseconds: 1800),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  // ═════════════════════════════════════════════════════════
  // BUILD
  // ═════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final st = ref.watch(fileEditorProvider);
    return Scaffold(
      backgroundColor: _c.bg,
      appBar: _appBar(st),
      body: FadeTransition(
        opacity: _panelFade,
        child: switch (_viewMode) {
          1 => _editor(st),
          2 => _graph(st),
          _ => _SplitPane(left: _editor(st), right: _panel(st)),
        },
      ),
    );
  }

  // ── AppBar ────────────────────────────────────────────────
  PreferredSizeWidget _appBar(FileEditorState st) => PreferredSize(
    preferredSize: const Size.fromHeight(52),
    child: Container(
      color: _c.bg,
      child: Column(
        children: [
          const SizedBox(height: 8),
          Row(
            children: [
              const SizedBox(width: 8),
              // 뒤로가기
              IconButton(
                icon: Icon(Icons.arrow_back_rounded, size: 18, color: _c.txt3),
                onPressed: () => Navigator.pop(context),
                splashRadius: 18,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              ),
              const SizedBox(width: 8),
              // 저장 상태
              _SaveStatus(
                saving: _saving,
                savedAt: st.lastSavedAt,
                anim: _saveAlpha,
              ),
              const Spacer(),
              // 글자 수
              Text('${st.charCount}자', style: _ts(11, color: _c.txt3)),
              const SizedBox(width: 12),
              // 툴바 버튼들
              _TBtn(Icons.copy_outlined, '복사', () {
                Clipboard.setData(
                  ClipboardData(
                    text: st.blocks.map((b) => b.controller.text).join('\n'),
                  ),
                );
                _snack('복사됨');
              }),
              _TBtn(Icons.download_outlined, 'MD 복사', () async {
                await ref
                    .read(fileEditorProvider.notifier)
                    .copyMarkdown(_titleCtrl.text, _tagsCtrl.text);
                _snack('Markdown 복사됨');
              }),
              _TBtn(
                _viewMode == 0
                    ? Icons.crop_square_rounded
                    : Icons.view_column_rounded,
                _viewMode == 0 ? '전체화면' : '분할 뷰',
                () {
                  setState(() => _viewMode = _viewMode == 0 ? 1 : 0);
                },
              ),
              _TBtn(Icons.account_tree_outlined, '지식 그래프', () {
                setState(() => _viewMode = _viewMode == 2 ? 0 : 2);
                if (_viewMode == 2)
                  ref.read(fileEditorProvider.notifier).requestGraph();
              }),
              const SizedBox(width: 12),
            ],
          ),
          Container(height: 1, color: _c.border),
        ],
      ),
    ),
  );

  // ── 에디터 ────────────────────────────────────────────────
  Widget _editor(FileEditorState st) {
    final blocks = st.blocks;
    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(80, 56, 80, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 아이콘
                _EmojiPicker(
                  current: st.icon ?? '',
                  onChange: (e) {
                    ref.read(fileEditorProvider.notifier).setIcon(e);
                    _onChange();
                  },
                ),
                const SizedBox(height: 20),
                // 제목
                TextField(
                  controller: _titleCtrl,
                  style: _ts(
                    38,
                    color: _c.txt,
                    w: FontWeight.w800,
                    h: 1.15,
                    ls: -1.0,
                  ),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    filled: false,
                    hintText: '제목 없음',
                    hintStyle: _ts(
                      38,
                      color: _c.txt3,
                      w: FontWeight.w800,
                      h: 1.15,
                      ls: -1.0,
                    ),
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                  onChanged: (_) => _onChange(),
                ),
                const SizedBox(height: 28),
                // 프로퍼티
                _Prop(
                  icon: Icons.tag_rounded,
                  label: 'Tags',
                  ctrl: _tagsCtrl,
                  hint: '태그를 추가하세요',
                  onChange: (_) => _onChange(),
                ),
                _Prop(
                  icon: Icons.auto_awesome_rounded,
                  label: 'Prompt',
                  ctrl: _promptCtrl,
                  hint: 'AI 요약 지시사항...',
                  onChange: (v) {
                    ref.read(fileEditorProvider.notifier).setPrompt(v);
                    _onChange();
                  },
                ),
                const SizedBox(height: 24),
                Divider(height: 1, color: _c.border),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(80, 0, 80, 240),
          sliver: SliverReorderableList(
            itemCount: blocks.length,
            onReorder: (o, n) =>
                ref.read(fileEditorProvider.notifier).reorder(o, n),
            itemBuilder: (ctx, i) => _Block(
              key: ValueKey(blocks[i].id),
              index: i,
              block: blocks[i],
              prevType: i > 0 ? blocks[i - 1].type : null,
              onKey: _onKey,
              onText: _onText,
              onDelete: () =>
                  ref.read(fileEditorProvider.notifier).removeBlock(i),
              onDup: () => ref.read(fileEditorProvider.notifier).duplicate(i),
              onType: (t) =>
                  ref.read(fileEditorProvider.notifier).setType(i, t),
              onCheck: (v) =>
                  ref.read(fileEditorProvider.notifier).toggleCheck(i, v),
              onFocus: () {
                _onChange(ft: blocks[i].controller.text);
                _onFocus(blocks[i].controller.text);
              },
            ),
          ),
        ),
      ],
    );
  }

  // ── AI 패널 ───────────────────────────────────────────────
  Widget _panel(FileEditorState st) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0F0F16),
        border: Border(left: BorderSide(color: _c.border)),
      ),
      child: Column(
        children: [
          // 탭바
          Container(
            height: 52,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: _c.border)),
            ),
            child: TabBar(
              controller: _tab,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              dividerColor: Colors.transparent,
              indicator: BoxDecoration(
                color: _c.hover,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _c.borderHi),
              ),
              labelColor: _c.txt,
              unselectedLabelColor: _c.txt2,
              labelStyle: _ts(12, w: FontWeight.w600),
              unselectedLabelStyle: _ts(12),
              labelPadding: const EdgeInsets.symmetric(horizontal: 14),
              tabs: [
                _tab_(Icons.auto_awesome_rounded, '요약'),
                _tab_(Icons.manage_search_rounded, '분석'),
                _tab_(Icons.psychology_rounded, '암기'),
                _tab_(Icons.quiz_rounded, '퀴즈'),
                _tab_(Icons.chat_bubble_outline, 'Ask'),
              ],
            ),
          ),
          // 탭 내용
          Expanded(
            child: TabBarView(
              controller: _tab,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _SumTab(
                  state: st,
                  ref: ref,
                  onGenerate: _triggerSum,
                  titleCtrl: _titleCtrl,
                  tagsCtrl: _tagsCtrl,
                  snack: _snack,
                ),
                _AnaTab(state: st),
                _MemoTab(state: st, ref: ref, titleCtrl: _titleCtrl),
                _QuizTab(state: st, ref: ref),
                _AskTab(
                  state: st,
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
    );
  }

  Tab _tab_(IconData icon, String txt) => Tab(
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [Icon(icon, size: 13), const SizedBox(width: 5), Text(txt)],
    ),
  );

  // ── 지식 그래프 ───────────────────────────────────────────
  Widget _graph(FileEditorState st) {
    if (st.graphData == null && !st.isGraphLoading) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => ref.read(fileEditorProvider.notifier).requestGraph(),
      );
    }
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.hub_rounded, color: _c.acc, size: 18),
              const SizedBox(width: 8),
              Text(
                'AI Semantic Graph',
                style: _ts(18, color: _c.txt, w: FontWeight.w700, ls: -0.3),
              ),
              const Spacer(),
              _TBtn(
                Icons.refresh_rounded,
                '재생성',
                () => ref.read(fileEditorProvider.notifier).requestGraph(),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Gemma3 모델이 개념 간 의미적 연결을 도출합니다.',
            style: _ts(12, color: _c.txt2),
          ),
          const SizedBox(height: 20),
          // 통계 카드 4개
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
                color: _c.card,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _c.border),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: st.isGraphLoading
                    ? Center(
                        child: CircularProgressIndicator(
                          color: _c.acc,
                          strokeWidth: 2,
                        ),
                      )
                    : st.graphData != null
                    ? _GraphViz(data: st.graphData!)
                    : Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.hub_outlined, size: 48, color: _c.txt3),
                            const SizedBox(height: 12),
                            Text(
                              '충분한 내용을 작성하면 그래프가 생성됩니다.',
                              style: _ts(13, color: _c.txt2),
                            ),
                          ],
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// 요약 탭  (핵심 — 완전 리디자인)
// ═══════════════════════════════════════════════════════════
class _SumTab extends StatelessWidget {
  final FileEditorState state;
  final WidgetRef ref;
  final VoidCallback onGenerate;
  final TextEditingController titleCtrl, tagsCtrl;
  final void Function(String) snack;
  const _SumTab({
    required this.state,
    required this.ref,
    required this.onGenerate,
    required this.titleCtrl,
    required this.tagsCtrl,
    required this.snack,
  });

  @override
  Widget build(BuildContext context) {
    final c = _c;
    return Stack(
      children: [
        // 배경 — 내용 없을 때
        if (state.summaryBlocks.isEmpty && !state.isSummaryLoading)
          _Empty(
            icon: Icons.auto_awesome_rounded,
            title: '스마트 요약',
            desc: '50자 이상 작성하면 AI가 자동으로\n구조화된 요약 노트를 생성합니다.',
          ),

        // 로딩 중
        if (state.isSummaryLoading && state.summaryBlocks.isEmpty)
          const _Loader('AI가 내용을 분석하고 있어요...'),

        // 요약 카드 목록
        ListView.builder(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 120),
          itemCount: state.summaryBlocks.length,
          itemBuilder: (_, i) => _SumCard(
            key: ValueKey('sum_$i'),
            block: state.summaryBlocks[i],
            index: i,
            onPin: () =>
                ref.read(fileEditorProvider.notifier).toggleSummarySave(i),
            onDel: () =>
                ref.read(fileEditorProvider.notifier).removeSummaryBlock(i),
            onCopy: () {
              Clipboard.setData(
                ClipboardData(text: state.summaryBlocks[i].content),
              );
              snack('복사됨');
            },
          ),
        ),

        // 하단 페이드
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          height: 100,
          child: IgnorePointer(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [const Color(0xFF0F0F16), Colors.transparent],
                ),
              ),
            ),
          ),
        ),

        // 플로팅 버튼
        Positioned(
          bottom: 20,
          left: 14,
          right: 14,
          child: _FloatBtn(
            loading: state.isSummaryLoading,
            label: state.summaryBlocks.any((b) => b.isSaved)
                ? '추가 분석'
                : '요약 생성',
            icon: Icons.auto_fix_high_rounded,
            onTap: () => ref
                .read(fileEditorProvider.notifier)
                .requestSummary(title: titleCtrl.text, tags: tagsCtrl.text),
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════
// 요약 카드 — 고급 디자인
// ═══════════════════════════════════════════════════════════
class _SumCard extends StatefulWidget {
  final SummaryBlock block;
  final int index;
  final VoidCallback onPin, onDel, onCopy;
  const _SumCard({
    Key? key,
    required this.block,
    required this.index,
    required this.onPin,
    required this.onDel,
    required this.onCopy,
  }) : super(key: key);
  @override
  State<_SumCard> createState() => _SumCardState();
}

class _SumCardState extends State<_SumCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ac;
  late final Animation<double> _fade, _scale;

  @override
  void initState() {
    super.initState();
    _ac = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 350 + widget.index * 60),
    );
    _fade = CurvedAnimation(parent: _ac, curve: Curves.easeOut);
    _scale = Tween(
      begin: 0.96,
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
    final c = _c;
    return FadeTransition(
      opacity: _fade,
      child: ScaleTransition(
        scale: _scale,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: pinned ? const Color(0xFF0F1A06) : c.card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: pinned ? c.acc.withOpacity(0.35) : c.border,
              width: pinned ? 1.5 : 1,
            ),
            boxShadow: pinned
                ? [
                    BoxShadow(
                      color: c.acc.withOpacity(0.07),
                      blurRadius: 20,
                      spreadRadius: 0,
                    ),
                  ]
                : [],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 헤더
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
                child: Row(
                  children: [
                    // 상태 인디케이터
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: pinned ? c.acc : c.txt3,
                        shape: BoxShape.circle,
                        boxShadow: pinned
                            ? [
                                BoxShadow(
                                  color: c.acc.withOpacity(0.6),
                                  blurRadius: 5,
                                ),
                              ]
                            : [],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      pinned ? 'PINNED' : 'LATEST',
                      style: _ts(
                        10,
                        color: pinned ? c.acc : c.txt3,
                        w: FontWeight.w700,
                        ls: 0.8,
                      ),
                    ),
                    const Spacer(),
                    // 액션 버튼들
                    _IBtn(
                      Icons.content_copy_outlined,
                      widget.onCopy,
                      color: c.txt3,
                      size: 14,
                    ),
                    const SizedBox(width: 2),
                    _IBtn(
                      pinned ? Icons.push_pin : Icons.push_pin_outlined,
                      widget.onPin,
                      color: pinned ? c.acc : c.txt3,
                      size: 14,
                    ),
                    const SizedBox(width: 2),
                    _IBtn(
                      Icons.close_rounded,
                      widget.onDel,
                      color: c.txt3,
                      size: 14,
                    ),
                  ],
                ),
              ),
              // 구분선
              Container(
                height: 0.5,
                color: pinned ? c.acc.withOpacity(0.15) : c.border,
              ),
              // 마크다운 본문
              Padding(
                padding: const EdgeInsets.all(16),
                child: MarkdownBody(
                  data: widget.block.content,
                  styleSheet: _md(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// 분석 탭
// ═══════════════════════════════════════════════════════════
class _AnaTab extends StatelessWidget {
  final FileEditorState state;
  const _AnaTab({required this.state});
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 포커스 텍스트 카드
        AnimatedSize(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          child: state.focusedText.trim().isNotEmpty
              ? Container(
                  margin: const EdgeInsets.fromLTRB(14, 14, 14, 0),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0E1508),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _c.acc.withOpacity(0.2)),
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
                              color: _c.acc,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: _c.acc.withOpacity(0.8),
                                  blurRadius: 4,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 7),
                          Text(
                            '현재 분석 중',
                            style: _ts(
                              10,
                              color: _c.acc,
                              w: FontWeight.w700,
                              ls: 0.5,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        state.focusedText,
                        style: _ts(13, color: _c.txt2, h: 1.5),
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
            child: state.isAnalysisLoading
                ? const _Loader('문단의 핵심 의미를 파악 중...')
                : state.currentAnalysis?.isNotEmpty == true
                ? SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(14, 16, 14, 40),
                    child: MarkdownBody(
                      data: state.currentAnalysis!,
                      styleSheet: _md(),
                    ),
                  )
                : const _Empty(
                    icon: Icons.manage_search_rounded,
                    title: '문단 분석',
                    desc: '에디터의 문단을 클릭하면\nAI가 즉시 심층 분석합니다.',
                  ),
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════
// 암기 탭
// ═══════════════════════════════════════════════════════════
class _MemoTab extends StatelessWidget {
  final FileEditorState state;
  final WidgetRef ref;
  final TextEditingController titleCtrl;
  const _MemoTab({
    required this.state,
    required this.ref,
    required this.titleCtrl,
  });
  @override
  Widget build(BuildContext context) => Stack(
    children: [
      if (state.currentMemo == null && !state.isMemoLoading)
        const _Empty(
          icon: Icons.psychology_rounded,
          title: '핵심 암기',
          desc: '본문에서 시험에 꼭 나올\n핵심 개념을 추출합니다.',
        ),
      if (state.currentMemo?.isNotEmpty == true)
        SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 120),
          child: MarkdownBody(data: state.currentMemo!, styleSheet: _md()),
        ),
      Positioned(
        bottom: 0,
        left: 0,
        right: 0,
        height: 100,
        child: IgnorePointer(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [const Color(0xFF0F0F16), Colors.transparent],
              ),
            ),
          ),
        ),
      ),
      if (state.currentMemo == null || state.isMemoLoading)
        Positioned(
          bottom: 20,
          left: 14,
          right: 14,
          child: _FloatBtn(
            loading: state.isMemoLoading,
            label: '암기 노트 생성',
            icon: Icons.lightbulb_rounded,
            onTap: () => ref
                .read(fileEditorProvider.notifier)
                .generateMemo(titleCtrl.text),
          ),
        ),
    ],
  );
}

// ═══════════════════════════════════════════════════════════
// 퀴즈 탭
// ═══════════════════════════════════════════════════════════
class _QuizTab extends StatelessWidget {
  final FileEditorState state;
  final WidgetRef ref;
  const _QuizTab({required this.state, required this.ref});
  @override
  Widget build(BuildContext context) => Stack(
    children: [
      if (state.quizData == null && !state.isQuizLoading)
        const _Empty(
          icon: Icons.quiz_rounded,
          title: '인터랙티브 퀴즈',
          desc: '학습 내용으로 객관식 퀴즈를\n즉시 생성합니다.',
        ),
      if (state.quizData != null)
        ListView.builder(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 120),
          itemCount: state.quizData!.length,
          itemBuilder: (_, qi) => _QItem(
            q: state.quizData![qi],
            qi: qi,
            answered: state.quizAnswers[qi],
            onAns: (oi) =>
                ref.read(fileEditorProvider.notifier).answerQuiz(qi, oi),
          ),
        ),
      Positioned(
        bottom: 0,
        left: 0,
        right: 0,
        height: 100,
        child: IgnorePointer(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [const Color(0xFF0F0F16), Colors.transparent],
              ),
            ),
          ),
        ),
      ),
      if (state.quizData == null || state.isQuizLoading)
        Positioned(
          bottom: 20,
          left: 14,
          right: 14,
          child: _FloatBtn(
            loading: state.isQuizLoading,
            label: '퀴즈 생성',
            icon: Icons.quiz_rounded,
            onTap: () => ref.read(fileEditorProvider.notifier).generateQuiz(),
          ),
        ),
    ],
  );
}

class _QItem extends StatelessWidget {
  final dynamic q;
  final int qi;
  final int? answered;
  final void Function(int) onAns;
  const _QItem({
    required this.q,
    required this.qi,
    required this.answered,
    required this.onAns,
  });
  @override
  Widget build(BuildContext context) {
    final correct = q['answer'] ?? 0;
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Q${qi + 1}.  ${q['question']}',
            style: _ts(14, color: _c.txt, w: FontWeight.w600, h: 1.5),
          ),
          const SizedBox(height: 12),
          ...List.generate((q['options'] as List).length, (oi) {
            Color bg = _c.card, bdr = _c.border, tc = _c.txt;
            if (answered != null) {
              if (oi == correct) {
                bg = _c.green.withOpacity(0.1);
                bdr = _c.green.withOpacity(0.4);
                tc = _c.green;
              } else if (oi == answered) {
                bg = _c.red.withOpacity(0.1);
                bdr = _c.red.withOpacity(0.4);
                tc = _c.red;
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
                    q['options'][oi],
                    style: _ts(13, color: tc, w: FontWeight.w500),
                  ),
                ),
              ),
            );
          }),
          if (answered != null) ...[
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _c.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _c.border),
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
                        color: answered == correct ? _c.green : _c.red,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        answered == correct ? '정답' : '오답',
                        style: _ts(
                          12,
                          color: answered == correct ? _c.green : _c.red,
                          w: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    q['explanation'] ?? '',
                    style: _ts(12, color: _c.txt2, h: 1.6),
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

// ═══════════════════════════════════════════════════════════
// Ask 탭
// ═══════════════════════════════════════════════════════════
class _AskTab extends StatelessWidget {
  final FileEditorState state;
  final TextEditingController ctrl;
  final void Function(String) onAsk;
  const _AskTab({required this.state, required this.ctrl, required this.onAsk});
  @override
  Widget build(BuildContext context) => Column(
    children: [
      Expanded(
        child: state.isQALoading
            ? const _Loader('노트 + 웹 검색 중...')
            : state.qaAnswer != null
            ? SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(14, 16, 14, 20),
                child: MarkdownBody(data: state.qaAnswer!, styleSheet: _md()),
              )
            : const _Empty(
                icon: Icons.chat_bubble_outline_rounded,
                title: 'Quick Ask',
                desc: '내 노트 + 실시간 웹 검색으로\n어떤 질문이든 답합니다.',
              ),
      ),
      Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: _c.border)),
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: ctrl,
                style: _ts(13, color: _c.txt),
                decoration: InputDecoration(
                  hintText: '질문을 입력하세요...',
                  hintStyle: _ts(13, color: _c.txt3),
                  filled: true,
                  fillColor: _c.card,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide(color: _c.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide(color: _c.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide(color: _c.acc),
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
                  color: _c.acc,
                  shape: BoxShape.circle,
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

// ═══════════════════════════════════════════════════════════
// 노션 블록
// ═══════════════════════════════════════════════════════════
class _Block extends StatefulWidget {
  final int index;
  final Block block;
  final BlockType? prevType;
  final KeyEventResult Function(FocusNode, KeyEvent, int) onKey;
  final Function(String, int) onText;
  final VoidCallback onDelete, onDup;
  final Function(BlockType) onType;
  final Function(bool) onCheck;
  final VoidCallback onFocus;
  const _Block({
    Key? key,
    required this.index,
    required this.block,
    this.prevType,
    required this.onKey,
    required this.onText,
    required this.onDelete,
    required this.onDup,
    required this.onType,
    required this.onCheck,
    required this.onFocus,
  }) : super(key: key);
  @override
  State<_Block> createState() => _BlockState();
}

class _BlockState extends State<_Block> with SingleTickerProviderStateMixin {
  bool _hov = false, _foc = false;
  late final AnimationController _ac;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    widget.block.focusNode.addListener(_onFocChange);
    _ac = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
    );
    _fade = CurvedAnimation(parent: _ac, curve: Curves.easeOut);
    _slide = Tween(
      begin: const Offset(0, -.04),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ac, curve: Curves.easeOut));
    _ac.forward();
  }

  @override
  void dispose() {
    widget.block.focusNode.removeListener(_onFocChange);
    _ac.dispose();
    super.dispose();
  }

  void _onFocChange() {
    if (mounted) {
      setState(() => _foc = widget.block.focusNode.hasFocus);
      if (_foc) widget.onFocus();
    }
  }

  TextStyle _style() {
    switch (widget.block.type) {
      case BlockType.h1:
        return _ts(32, color: _c.txt, w: FontWeight.w800, h: 1.3, ls: -0.7);
      case BlockType.h2:
        return _ts(24, color: _c.txt, w: FontWeight.w700, h: 1.35, ls: -0.3);
      case BlockType.h3:
        return _ts(19, color: _c.txt, w: FontWeight.w600, h: 1.4);
      case BlockType.code:
        return _ts(
          14,
          color: const Color(0xFFDDD6FE),
          h: 1.6,
        ).copyWith(fontFamily: 'Courier');
      default:
        return _ts(16, color: _c.txt, h: 1.75, ls: 0.1);
    }
  }

  Color? _bgColor() {
    if (widget.block.type == BlockType.code) return const Color(0xFF0D1117);
    return null;
  }

  @override
  Widget build(BuildContext context) {
    widget.block.focusNode.onKeyEvent = (n, e) =>
        widget.onKey(n, e, widget.index);
    final isBullet = widget.block.type == BlockType.bullet;
    final isPrevBullet = widget.prevType == BlockType.bullet;
    final topPad = (isBullet && isPrevBullet) ? 1.0 : (isBullet ? 3.0 : 2.0);

    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: MouseRegion(
          onEnter: (_) => setState(() => _hov = true),
          onExit: (_) => setState(() => _hov = false),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 100),
            padding: EdgeInsets.only(
              top: topPad,
              bottom: isBullet ? 1 : 2,
              left: 8,
              right: 8,
            ),
            decoration: BoxDecoration(
              color: _foc ? Colors.white.withOpacity(0.02) : _bgColor(),
              borderRadius: BorderRadius.circular(5),
              border: widget.block.type == BlockType.code
                  ? Border.all(color: _c.border)
                  : null,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 드래그 핸들
                SizedBox(
                  width: 24,
                  height: 24,
                  child: AnimatedOpacity(
                    opacity: _hov ? 1 : 0,
                    duration: const Duration(milliseconds: 120),
                    child: ReorderableDragStartListener(
                      index: widget.index,
                      child: PopupMenuButton<String>(
                        padding: EdgeInsets.zero,
                        color: _c.card,
                        offset: const Offset(0, 28),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: BorderSide(color: _c.border),
                        ),
                        icon: Icon(
                          Icons.drag_indicator_rounded,
                          size: 15,
                          color: _c.txt3,
                        ),
                        iconSize: 15,
                        onSelected: (v) {
                          if (v == 'd')
                            widget.onDelete();
                          else if (v == 'c')
                            widget.onDup();
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
                          _mi('d', Icons.delete_outline_rounded, '삭제', _c.red),
                          _mi('c', Icons.content_copy_rounded, '복제', _c.txt),
                          const PopupMenuDivider(height: 6),
                          _mi('h1', Icons.looks_one_outlined, '제목 1', _c.txt),
                          _mi('h2', Icons.looks_two_outlined, '제목 2', _c.txt),
                          _mi('t', Icons.short_text, '텍스트', _c.txt),
                          _mi('b', Icons.format_list_bulleted, '글머리', _c.txt),
                          _mi('cd', Icons.data_object, '코드', _c.txt),
                        ],
                      ),
                    ),
                  ),
                ),

                // bullet
                if (widget.block.type == BlockType.bullet)
                  Padding(
                    padding: const EdgeInsets.only(top: 12, right: 10),
                    child: Icon(Icons.circle, size: 4, color: _c.txt2),
                  ),

                // checkbox
                if (widget.block.type == BlockType.checkbox)
                  Padding(
                    padding: const EdgeInsets.only(top: 5, right: 10),
                    child: SizedBox(
                      width: 17,
                      height: 17,
                      child: Checkbox(
                        value: widget.block.isChecked,
                        onChanged: (v) => widget.onCheck(v!),
                        activeColor: _c.acc,
                        checkColor: Colors.black,
                        side: BorderSide(color: _c.txt3, width: 1.5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ),

                // 코드 태그
                if (widget.block.type == BlockType.code)
                  Padding(
                    padding: const EdgeInsets.only(top: 3, right: 8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: _c.border,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'code',
                        style: _ts(
                          9,
                          color: _c.txt3,
                          w: FontWeight.w600,
                          ls: 0.3,
                        ),
                      ),
                    ),
                  ),

                // TextField
                Expanded(
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
                            ? _c.txt3
                            : null,
                      ),
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                        filled: false,
                        hintText: (_foc && widget.block.controller.text.isEmpty)
                            ? _hintFor(widget.block.type)
                            : '',
                        hintStyle: _ts(16, color: _c.txt3.withOpacity(0.5)),
                      ),
                      onChanged: (t) => widget.onText(t, widget.index),
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

  String _hintFor(BlockType t) => switch (t) {
    BlockType.h1 => '제목 1',
    BlockType.h2 => '제목 2',
    BlockType.h3 => '제목 3',
    BlockType.code => '코드를 입력하세요...',
    BlockType.bullet => '리스트 항목',
    BlockType.checkbox => '할 일 추가',
    _ => "입력하거나  '/'  로 블록 추가",
  };

  PopupMenuItem<String> _mi(String v, IconData icon, String txt, Color c) =>
      PopupMenuItem(
        value: v,
        height: 34,
        child: Row(
          children: [
            Icon(icon, size: 14, color: c.withOpacity(0.8)),
            const SizedBox(width: 8),
            Text(txt, style: _ts(13, color: c)),
          ],
        ),
      );
}

// ═══════════════════════════════════════════════════════════
// 슬래시 메뉴
// ═══════════════════════════════════════════════════════════
enum _CmdCat { text, list, media }

class _Cmd {
  final String id, label;
  final IconData icon;
  final _CmdCat cat;
  const _Cmd(this.id, this.label, this.icon, this.cat);
}

class _SlashMenu extends StatelessWidget {
  final List<_Cmd> cmds;
  final int sel;
  final void Function(_Cmd) onSel;
  const _SlashMenu({
    required this.cmds,
    required this.sel,
    required this.onSel,
  });

  @override
  Widget build(BuildContext context) {
    // 카테고리 그룹핑
    final cats = {for (var c in cmds) c.cat: true};
    return Material(
      elevation: 20,
      color: _c.card,
      borderRadius: BorderRadius.circular(12),
      shadowColor: Colors.black.withOpacity(0.5),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 280),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _c.borderHi),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
              child: Row(
                children: [
                  Icon(
                    Icons.add_circle_outline_rounded,
                    size: 12,
                    color: _c.acc,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '블록 추가',
                    style: _ts(10, color: _c.txt2, w: FontWeight.w600, ls: 0.5),
                  ),
                ],
              ),
            ),
            ...cmds.asMap().entries.map(
              (e) => _CmdItem(
                cmd: e.value,
                sel: e.key == sel,
                onTap: () => onSel(e.value),
              ),
            ),
            const SizedBox(height: 6),
          ],
        ),
      ),
    );
  }
}

class _CmdItem extends StatefulWidget {
  final _Cmd cmd;
  final bool sel;
  final VoidCallback onTap;
  const _CmdItem({required this.cmd, required this.sel, required this.onTap});
  @override
  State<_CmdItem> createState() => _CmdItemState();
}

class _CmdItemState extends State<_CmdItem> {
  bool _h = false;
  @override
  Widget build(BuildContext context) => MouseRegion(
    onEnter: (_) => setState(() => _h = true),
    onExit: (_) => setState(() => _h = false),
    child: GestureDetector(
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 80),
        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: (widget.sel || _h) ? _c.hover : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(
              widget.cmd.icon,
              size: 15,
              color: (widget.sel || _h) ? _c.acc : _c.txt2,
            ),
            const SizedBox(width: 10),
            Text(
              widget.cmd.label,
              style: _ts(
                13,
                color: (widget.sel || _h) ? _c.txt : _c.txt2,
                w: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

// ═══════════════════════════════════════════════════════════
// 공통 작은 위젯들
// ═══════════════════════════════════════════════════════════
class _SplitPane extends StatefulWidget {
  final Widget left, right;
  const _SplitPane({required this.left, required this.right});
  @override
  State<_SplitPane> createState() => _SplitPaneState();
}

class _SplitPaneState extends State<_SplitPane> {
  double _ratio = 0.58;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (_, c) {
      final w = c.maxWidth;
      return Row(
        children: [
          SizedBox(width: w * _ratio, child: widget.left),
          MouseRegion(
            cursor: SystemMouseCursors.resizeColumn,
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onPanUpdate: (d) => setState(
                () => _ratio = (_ratio + d.delta.dx / w).clamp(0.35, 0.72),
              ),
              child: Container(
                width: 5,
                color: Colors.transparent,
                child: Center(child: Container(width: 1, color: _c.border)),
              ),
            ),
          ),
          Expanded(child: widget.right),
        ],
      );
    },
  );
}

class _Prop extends StatefulWidget {
  final IconData icon;
  final String label;
  final TextEditingController ctrl;
  final String hint;
  final void Function(String) onChange;
  const _Prop({
    required this.icon,
    required this.label,
    required this.ctrl,
    required this.hint,
    required this.onChange,
  });
  @override
  State<_Prop> createState() => _PropState();
}

class _PropState extends State<_Prop> {
  bool _foc = false;
  late FocusNode _fn;
  @override
  void initState() {
    super.initState();
    _fn = FocusNode()..addListener(() => setState(() => _foc = _fn.hasFocus));
  }

  @override
  void dispose() {
    _fn.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      children: [
        Icon(widget.icon, size: 14, color: _foc ? _c.acc : _c.txt3),
        const SizedBox(width: 10),
        SizedBox(
          width: 60,
          child: Text(widget.label, style: _ts(12, color: _c.txt3)),
        ),
        Expanded(
          child: TextField(
            controller: widget.ctrl,
            focusNode: _fn,
            style: _ts(13, color: _c.txt2),
            decoration: InputDecoration(
              border: InputBorder.none,
              filled: true,
              fillColor: _foc ? _c.hover : Colors.transparent,
              hoverColor: _c.hover,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 6,
              ),
              hintText: widget.hint,
              hintStyle: _ts(13, color: _c.txt3.withOpacity(0.5)),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: BorderSide(color: _c.border),
              ),
            ),
            onChanged: widget.onChange,
          ),
        ),
      ],
    ),
  );
}

class _EmojiPicker extends StatefulWidget {
  final String current;
  final void Function(String) onChange;
  const _EmojiPicker({required this.current, required this.onChange});
  @override
  State<_EmojiPicker> createState() => _EmojiPickerState();
}

class _EmojiPickerState extends State<_EmojiPicker> {
  bool _open = false;
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
  ];
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      GestureDetector(
        onTap: () => setState(() => _open = !_open),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 130),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: _open ? _c.hover : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.current.isNotEmpty ? widget.current : '🪄',
                style: const TextStyle(fontSize: 32),
              ),
              const SizedBox(width: 6),
              Text(_open ? '닫기' : '', style: _ts(11, color: _c.txt3)),
            ],
          ),
        ),
      ),
      if (_open) ...[
        const SizedBox(height: 8),
        Wrap(
          spacing: 4,
          runSpacing: 4,
          children: _emojis
              .map(
                (e) => GestureDetector(
                  onTap: () {
                    widget.onChange(e);
                    setState(() => _open = false);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 100),
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: e == widget.current ? _c.accDim : _c.card,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: e == widget.current
                            ? _c.acc.withOpacity(0.4)
                            : _c.border,
                      ),
                    ),
                    child: Center(
                      child: Text(e, style: const TextStyle(fontSize: 20)),
                    ),
                  ),
                ),
              )
              .toList(),
        ),
      ],
    ],
  );
}

class _FloatBtn extends StatefulWidget {
  final bool loading;
  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  const _FloatBtn({
    required this.loading,
    required this.label,
    required this.icon,
    this.onTap,
  });
  @override
  State<_FloatBtn> createState() => _FloatBtnState();
}

class _FloatBtnState extends State<_FloatBtn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ac;
  late final Animation<double> _pulse;
  @override
  void initState() {
    super.initState();
    _ac = AnimationController(vsync: this, duration: const Duration(seconds: 2))
      ..repeat(reverse: true);
    _pulse = Tween(
      begin: 1.0,
      end: 1.025,
    ).animate(CurvedAnimation(parent: _ac, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ac.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Center(
    child: ScaleTransition(
      scale: widget.loading ? _pulse : const AlwaysStoppedAnimation(1.0),
      child: GestureDetector(
        onTap: widget.loading ? null : widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 13),
          decoration: BoxDecoration(
            color: widget.loading ? _c.accDim : _c.card,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color: widget.loading ? _c.acc.withOpacity(0.35) : _c.borderHi,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.35),
                blurRadius: 14,
                offset: const Offset(0, 5),
              ),
              if (widget.loading)
                BoxShadow(color: _c.acc.withOpacity(0.12), blurRadius: 20),
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
                        color: _c.acc,
                      ),
                    )
                  : Icon(widget.icon, color: _c.acc, size: 15),
              const SizedBox(width: 9),
              Text(
                widget.loading ? '생성 중...' : widget.label,
                style: _ts(13, color: _c.txt, w: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

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
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: _c.card, shape: BoxShape.circle),
          child: Icon(icon, size: 28, color: _c.txt3),
        ),
        const SizedBox(height: 16),
        Text(
          title,
          style: _ts(15, color: _c.txt, w: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Text(
          desc,
          textAlign: TextAlign.center,
          style: _ts(13, color: _c.txt2, h: 1.6),
        ),
      ],
    ),
  );
}

class _Loader extends StatelessWidget {
  final String msg;
  const _Loader(this.msg);
  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 26,
          height: 26,
          child: CircularProgressIndicator(color: _c.acc, strokeWidth: 2),
        ),
        const SizedBox(height: 14),
        Text(msg, style: _ts(13, color: _c.txt2)),
      ],
    ),
  );
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
      color: _c.txt3,
      hoverColor: _c.hover,
      splashRadius: 16,
      padding: const EdgeInsets.all(6),
      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
    ),
  );
}

class _IBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color? color;
  final double size;
  const _IBtn(this.icon, this.onTap, {this.color, this.size = 14});
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(5),
    child: Padding(
      padding: const EdgeInsets.all(5),
      child: Icon(icon, size: size, color: color ?? _c.txt3),
    ),
  );
}

class _SaveStatus extends StatelessWidget {
  final bool saving;
  final DateTime? savedAt;
  final Animation<double> anim;
  const _SaveStatus({
    required this.saving,
    required this.savedAt,
    required this.anim,
  });
  @override
  Widget build(BuildContext context) {
    if (saving)
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 10,
            height: 10,
            child: CircularProgressIndicator(strokeWidth: 1.2, color: _c.txt3),
          ),
          const SizedBox(width: 6),
          Text('저장 중', style: _ts(11, color: _c.txt3)),
        ],
      );
    if (savedAt != null)
      return FadeTransition(
        opacity: anim,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.check_rounded,
              size: 12,
              color: _c.green.withOpacity(0.7),
            ),
            const SizedBox(width: 5),
            Text('저장됨', style: _ts(11, color: _c.txt3)),
          ],
        ),
      );
    return const SizedBox.shrink();
  }
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
        color: accent ? _c.accDim : _c.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: accent ? _c.acc.withOpacity(0.25) : _c.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: accent ? _c.acc : _c.txt3),
          const SizedBox(height: 10),
          Text(
            value,
            style: _ts(18, color: accent ? _c.acc : _c.txt, w: FontWeight.w700),
          ),
          const SizedBox(height: 2),
          Text(label, style: _ts(11, color: _c.txt2)),
        ],
      ),
    ),
  );
}

class _GraphViz extends StatefulWidget {
  final Map<String, dynamic> data;
  const _GraphViz({required this.data});
  @override
  State<_GraphViz> createState() => _GVState();
}

class _GVState extends State<_GraphViz> with SingleTickerProviderStateMixin {
  late final AnimationController _ac;
  List<_N> nodes = [];
  List<_E> edges = [];
  double t = 0;
  @override
  void initState() {
    super.initState();
    _ac = AnimationController(vsync: this, duration: const Duration(days: 1))
      ..addListener(
        () => setState(() {
          t += 0.007;
          _tick();
        }),
      )
      ..forward();
    WidgetsBinding.instance.addPostFrameCallback((_) => _build());
  }

  void _build() {
    final sz = context.size ?? const Size(800, 500);
    final cx = sz.width / 2, cy = sz.height / 2;
    nodes.clear();
    edges.clear();
    final rn = widget.data['nodes'] as List? ?? [];
    final re = widget.data['edges'] as List? ?? [];
    for (int i = 0; i < rn.length; i++) {
      final ic = i == 0;
      nodes.add(
        _N(
          id: rn[i]['id'].toString(),
          label: rn[i]['label'].toString(),
          r: ic ? 13 : 7,
          color: ic ? _c.acc : _c.blue,
          br: ic ? 0 : 60 + math.Random().nextDouble() * 110,
          ba: ic ? 0 : (2 * math.pi / (rn.length - 1)) * i,
          x: cx,
          y: cy,
          core: ic,
        ),
      );
    }
    for (var e in re)
      edges.add(_E(e['source'].toString(), e['target'].toString()));
  }

  void _tick() {
    final sz = context.size ?? const Size(800, 500);
    final cx = sz.width / 2, cy = sz.height / 2;
    for (var n in nodes) {
      if (n.core) {
        n.x = cx;
        n.y = cy;
        continue;
      }
      final tx = cx + math.cos(n.ba + t * 0.3) * n.br;
      final ty =
          cy + math.sin(n.ba + t * 0.3) * n.br + math.sin(t * 1.2 + n.ba) * 12;
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
      CustomPaint(painter: _GP(nodes, edges), size: Size.infinite);
}

class _N {
  String id;
  String label;
  double r;
  Color color;
  double x, y, br, ba;
  bool core;
  _N({
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

class _E {
  String s, t;
  _E(this.s, this.t);
}

class _GP extends CustomPainter {
  final List<_N> nodes;
  final List<_E> edges;
  _GP(this.nodes, this.edges);
  @override
  void paint(Canvas canvas, Size size) {
    final lp = Paint()
      ..strokeWidth = 0.8
      ..style = PaintingStyle.stroke
      ..color = const Color(0xFF252535);
    final hp = Paint()
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke
      ..color = _c.acc.withOpacity(0.2);
    for (var e in edges) {
      final s = nodes.where((n) => n.id == e.s).firstOrNull;
      final t = nodes.where((n) => n.id == e.t).firstOrNull;
      if (s != null && t != null)
        canvas.drawLine(Offset(s.x, s.y), Offset(t.x, t.y), s.core ? hp : lp);
    }
    for (var n in nodes) {
      canvas.drawCircle(
        Offset(n.x, n.y),
        n.r,
        Paint()
          ..color = n.color
          ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 3),
      );
      if (n.label.isNotEmpty) {
        final lbl = n.label.length > 8
            ? '${n.label.substring(0, 8)}…'
            : n.label;
        final tp = TextPainter(
          text: TextSpan(
            text: lbl,
            style: TextStyle(
              color: n.core ? Colors.white : _c.txt2,
              fontSize: n.core ? 11 : 9,
              fontWeight: n.core ? FontWeight.w800 : FontWeight.w500,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(n.x - tp.width / 2, n.y + n.r + 4));
      }
    }
  }

  @override
  bool shouldRepaint(_) => true;
}

// ── Markdown 스타일 ───────────────────────────────────────
MarkdownStyleSheet _md() => MarkdownStyleSheet(
  p: _ts(14, color: _c.txt, h: 1.8, ls: 0.1),
  strong: _ts(14, color: Colors.white, w: FontWeight.w700),
  em: _ts(14, color: _c.txt).copyWith(fontStyle: FontStyle.italic),
  code: _ts(
    13,
    color: const Color(0xFFBBAFF8),
    h: 1.6,
  ).copyWith(fontFamily: 'Courier', backgroundColor: const Color(0xFF1A1A2E)),
  codeblockDecoration: BoxDecoration(
    color: const Color(0xFF0D1117),
    borderRadius: BorderRadius.circular(10),
    border: Border.all(color: _c.border),
  ),
  tableBorder: TableBorder(
    horizontalInside: BorderSide(color: _c.border),
    bottom: BorderSide(color: _c.border),
  ),
  tableHead: _ts(12, color: _c.txt2, w: FontWeight.w700),
  tableBody: _ts(13, color: _c.txt),
  tableCellsPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
  blockquoteDecoration: BoxDecoration(
    border: Border(left: BorderSide(color: _c.acc, width: 3)),
    color: _c.accDim.withOpacity(0.5),
  ),
  blockquotePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
  listBullet: _ts(14, color: _c.txt2),
  h1: _ts(19, color: Colors.white, w: FontWeight.w800, h: 1.5, ls: -0.3),
  h2: _ts(16, color: Colors.white, w: FontWeight.w700, h: 1.5),
  h3: _ts(14, color: Colors.white, w: FontWeight.w600, h: 1.5),
  horizontalRuleDecoration: BoxDecoration(
    border: Border(top: BorderSide(color: _c.border)),
  ),
);
