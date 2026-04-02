// ╔══════════════════════════════════════════════════════╗
// ║  StudyFlow — Premium File Editor  v5                 ║
// ║  Aurora BG · Glow Cards · Micro-interactions         ║
// ╚══════════════════════════════════════════════════════╝
import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import '../../models/block_model.dart';
import '../../core/db_helper/files_db_helper.dart';
import 'file_provider.dart';

// ══════════════════ DESIGN TOKENS ══════════════════════
const _bg0 = Color(0xFF07070E); // 최심층
const _bg1 = Color(0xFF0D0D16); // 메인 배경
const _bg2 = Color(0xFF12121C); // 패널
const _bg3 = Color(0xFF181826); // 카드
const _bg4 = Color(0xFF1E1E30); // hover
const _bdr = Color(0xFF232336);
const _bdr2 = Color(0xFF2E2E48);
const _txt0 = Color(0xFFF0F0FA);
const _txt1 = Color(0xFFAAAACC);
const _txt2 = Color(0xFF555575);
const _acc = Color(0xFFCCFF66); // lime
const _accD = Color(0xFF0F1A04);
const _accG = Color(0xFF88CC00);
const _blu = Color(0xFF4F8EFF);
const _grn = Color(0xFF4ADE80);
const _red = Color(0xFFFF4F6A);
const _pur = Color(0xFFA78BFA);
const _yel = Color(0xFFFFD166);

// ══════════════════ MAIN SCREEN ════════════════════════
class FileScreen extends ConsumerStatefulWidget {
  final String fileId, projectId;
  const FileScreen({Key? key, required this.fileId, this.projectId = 'default'})
    : super(key: key);
  @override
  ConsumerState<FileScreen> createState() => _FS();
}

class _FS extends ConsumerState<FileScreen> with TickerProviderStateMixin {
  final _tCtrl = TextEditingController();
  final _gCtrl = TextEditingController(); // tags
  final _pCtrl = TextEditingController(); // prompt
  final _qaCtrl = TextEditingController();
  late TabController _tab;

  // Timers
  Timer? _saveT, _focT, _sumT;
  bool _saving = false;
  int _lastSumLen = 0;

  // View
  int _view = 0; // 0:split 1:full 2:graph
  bool _panelCollapsed = false;

  // Slash
  OverlayEntry? _slash;
  int _slashIdx = 0;
  List<_Opt> _slashOpts = [];

  // Animations
  late AnimationController _bgAc; // 오로라 배경
  late AnimationController _saveAc; // 저장 체크
  late AnimationController _sumAc; // 요약 펄스
  late AnimationController _panelAc; // 패널 슬라이드
  late Animation<double> _bgAnim, _saveAnim, _sumPulse, _panelSlide;

  // Slash commands
  static const _opts = [
    _Opt('h1', '제목 1', Icons.looks_one_rounded, '# '),
    _Opt('h2', '제목 2', Icons.looks_two_rounded, '## '),
    _Opt('h3', '제목 3', Icons.looks_3_rounded, '### '),
    _Opt('p', '텍스트', Icons.short_text_rounded, ''),
    _Opt('bullet', '글머리', Icons.format_list_bulleted_rounded, '- '),
    _Opt('todo', '할 일', Icons.check_box_outlined, '[] '),
    _Opt('code', '코드', Icons.code_rounded, '```'),
    _Opt('quote', '인용', Icons.format_quote_rounded, '> '),
    _Opt('div', '구분선', Icons.horizontal_rule_rounded, '---'),
  ];

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 5, vsync: this);

    _bgAc = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat(reverse: true);
    _saveAc = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _sumAc = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _panelAc = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );

    _bgAnim = CurvedAnimation(parent: _bgAc, curve: Curves.easeInOut);
    _saveAnim = CurvedAnimation(parent: _saveAc, curve: Curves.elasticOut);
    _sumPulse = Tween(
      begin: 0.6,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _sumAc, curve: Curves.easeInOut));
    _panelSlide = CurvedAnimation(parent: _panelAc, curve: Curves.easeOutCubic);
    _panelAc.value = 1;

    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  Future<void> _init() async {
    await ref.read(fileEditorProvider.notifier).loadFileDetail(widget.fileId);
    final st = ref.read(fileEditorProvider);
    // ✅ 로컬 DB에서 title/tags 직접 로드
    try {
      final file = await FilesDBHelper.getFile(widget.fileId);
      if (file != null && mounted) {
        setState(() {
          _tCtrl.text = (file.title == '제목 없음') ? '' : file.title;
          _gCtrl.text = file.tags;
          _pCtrl.text = file.prompt ?? st.filePrompt ?? '';
        });
      } else if (mounted) {
        setState(() {
          _pCtrl.text = st.filePrompt ?? '';
        });
      }
    } catch (_) {
      if (mounted)
        setState(() {
          _pCtrl.text = st.filePrompt ?? '';
        });
    }
  }

  @override
  void dispose() {
    _saveT?.cancel();
    _focT?.cancel();
    _sumT?.cancel();
    _tCtrl.dispose();
    _gCtrl.dispose();
    _pCtrl.dispose();
    _qaCtrl.dispose();
    _tab.dispose();
    _bgAc.dispose();
    _saveAc.dispose();
    _sumAc.dispose();
    _panelAc.dispose();
    _removeSlash();
    super.dispose();
  }

  // ── Save ──────────────────────────────────────────────
  void _chg({String? ft}) {
    if (ft != null)
      ref.read(fileEditorProvider.notifier).state = ref
          .read(fileEditorProvider)
          .copyWith(focusedText: ft);
    setState(() => _saving = true);
    _saveT?.cancel();
    _saveT = Timer(const Duration(milliseconds: 900), () async {
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
        setState(() => _saving = false);
        _saveAc.forward(from: 0);
      }
    });
    final mc = ref.read(fileEditorProvider).meaningfulCharCount;
    if ((mc - _lastSumLen).abs() > 120) {
      _sumT?.cancel();
      _sumT = Timer(const Duration(seconds: 9), _doSum);
    }
  }

  void _doSum() {
    if (_tab.index == 0 && !ref.read(fileEditorProvider).isSummaryLoading) {
      _lastSumLen = ref.read(fileEditorProvider).meaningfulCharCount;
      ref
          .read(fileEditorProvider.notifier)
          .requestSummary(title: _tCtrl.text, tags: _gCtrl.text);
    }
  }

  void _focusEvent(String text) {
    _focT?.cancel();
    _focT = Timer(const Duration(milliseconds: 1800), () {
      if (text.trim().length > 20) {
        ref
            .read(fileEditorProvider.notifier)
            .analyzeBlock(text: text, title: _tCtrl.text);
      }
    });
  }

  // ── Key handler ───────────────────────────────────────
  KeyEventResult _key(FocusNode n, KeyEvent e, int i) {
    if (e is! KeyDownEvent) return KeyEventResult.ignored;
    final meta = HardwareKeyboard.instance.isMetaPressed;
    final ctrl = HardwareKeyboard.instance.isControlPressed;
    final shift = HardwareKeyboard.instance.isShiftPressed;

    if ((meta || ctrl) && e.logicalKey == LogicalKeyboardKey.keyA) {
      final b = ref.read(fileEditorProvider).blocks[i];
      b.controller.selection = TextSelection(
        baseOffset: 0,
        extentOffset: b.controller.text.length,
      );
      return KeyEventResult.handled;
    }

    // slash nav
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
    final bc = blocks[i].controller, bt = blocks[i].type;

    if (e.logicalKey == LogicalKeyboardKey.tab) {
      shift
          ? ref.read(fileEditorProvider.notifier).dedent(i)
          : ref.read(fileEditorProvider.notifier).indent(i);
      return KeyEventResult.handled;
    }

    if (e.logicalKey == LogicalKeyboardKey.enter && !meta && !ctrl) {
      final txt = bc.text, pos = bc.selection.baseOffset.clamp(0, txt.length);
      if (txt.isEmpty && (bt == BlockType.bullet || bt == BlockType.checkbox)) {
        ref.read(fileEditorProvider.notifier).exitListMode(i);
        return KeyEventResult.handled;
      }
      bc.text = txt.substring(0, pos);
      ref.read(fileEditorProvider.notifier).insertBlocks(i + 1, [
        txt.substring(pos),
      ]);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final upd = ref.read(fileEditorProvider).blocks;
        if (i + 1 < upd.length) {
          if (bt == BlockType.bullet || bt == BlockType.checkbox)
            ref.read(fileEditorProvider.notifier).setType(i + 1, bt);
          upd[i + 1].focusNode.requestFocus();
          upd[i + 1].controller.selection = TextSelection.collapsed(offset: 0);
        }
      });
      _chg();
      return KeyEventResult.handled;
    }

    if (e.logicalKey == LogicalKeyboardKey.backspace) {
      if (bc.selection.isCollapsed && bc.selection.baseOffset == 0 && i > 0) {
        ref.read(fileEditorProvider.notifier).mergeWithPrev(i);
        return KeyEventResult.handled;
      }
      if (bc.text.isEmpty &&
          bt != BlockType.text &&
          bt != BlockType.h1 &&
          bt != BlockType.h2 &&
          bt != BlockType.h3) {
        ref.read(fileEditorProvider.notifier).setType(i, BlockType.text);
        return KeyEventResult.handled;
      }
    }

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

  // ── Text change ───────────────────────────────────────
  void _txt(String text, int i) {
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
        final c = ref.read(fileEditorProvider).blocks[i].controller;
        c.text = nc;
        ref.read(fileEditorProvider.notifier).setType(i, nt);
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => c.selection = TextSelection.collapsed(offset: nc.length),
        );
        _chg(ft: nc);
        return;
      }
    }
    final si = text.lastIndexOf('/');
    if (si != -1 && si == text.length - 1)
      _showSlash(context, i, '');
    else if (si != -1 && !text.substring(si + 1).contains(' '))
      _showSlash(context, i, text.substring(si + 1));
    else
      _removeSlash();
    _chg(ft: text);
  }

  // ── Slash menu ────────────────────────────────────────
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
    _slash = OverlayEntry(
      builder: (_) => Positioned(
        width: 270,
        child: CompositedTransformFollower(
          link: bl[i].layerLink,
          showWhenUnlinked: false,
          offset: const Offset(0, 40),
          child: _SlashMenu(
            opts: _slashOpts,
            sel: _slashIdx,
            onSel: (o) => _applyOpt(i, o),
          ),
        ),
      ),
    );
    Overlay.of(ctx).insert(_slash!);
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
      case 'todo':
        ref.read(fileEditorProvider.notifier).setType(i, BlockType.checkbox);
        break;
      case 'code':
        ref.read(fileEditorProvider.notifier).setType(i, BlockType.code);
        break;
      case 'div':
        c.text = '─────────────────────';
        ref.read(fileEditorProvider.notifier).setType(i, BlockType.code);
        break;
      default:
        ref.read(fileEditorProvider.notifier).setType(i, BlockType.text);
    }
    _foc(i);
  }

  void _removeSlash() {
    _slash?.remove();
    _slash = null;
  }

  void _snack(String msg) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(msg, style: const TextStyle(color: _txt0, fontSize: 13)),
      backgroundColor: _bg3,
      duration: const Duration(milliseconds: 1600),
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  );

  // ════════════════════ BUILD ════════════════════════════
  @override
  Widget build(BuildContext context) {
    final st = ref.watch(fileEditorProvider);
    return Scaffold(
      backgroundColor: _bg0,
      body: Stack(
        children: [
          // ── 오로라 배경 ──────────────────────────────
          _AuroraBG(anim: _bgAnim),

          // ── 메인 레이아웃 ────────────────────────────
          Column(
            children: [
              _AppBar(
                saving: _saving,
                savedAt: st.lastSavedAt,
                saveAnim: _saveAnim,
                charCount: st.charCount,
                view: _view,
                onBack: () => Navigator.pop(context),
                onCopy: () {
                  Clipboard.setData(
                    ClipboardData(
                      text: st.blocks.map((b) => b.controller.text).join('\n'),
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
                  _panelAc.reverse().then((_) {
                    setState(() => _view = _view == 0 ? 1 : 0);
                    _panelAc.forward();
                  });
                },
                onGraph: () {
                  setState(() => _view = _view == 2 ? 0 : 2);
                  if (_view == 2)
                    ref.read(fileEditorProvider.notifier).requestGraph();
                },
              ),
              Expanded(
                child: _view == 2
                    ? _GraphView(st: st, ref: ref)
                    : _view == 1
                    ? _buildEditor(st)
                    : _Split(left: _buildEditor(st), right: _buildPanel(st)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Editor ────────────────────────────────────────────
  Widget _buildEditor(FileEditorState st) {
    final blocks = st.blocks;
    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(88, 64, 88, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 이모지 아이콘
                _IconRow(
                  current: st.icon ?? '',
                  onChange: (e) {
                    ref.read(fileEditorProvider.notifier).setIcon(e);
                    _chg();
                  },
                ),
                const SizedBox(height: 22),
                // 타이틀
                _GlowTitle(ctrl: _tCtrl, onChange: () => _chg()),
                const SizedBox(height: 32),
                // 프로퍼티
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
                const SizedBox(height: 28),
                const _Divider(),
                const SizedBox(height: 14),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(88, 0, 88, 280),
          sliver: SliverReorderableList(
            itemCount: blocks.length,
            onReorder: (o, n) =>
                ref.read(fileEditorProvider.notifier).reorder(o, n),
            itemBuilder: (ctx, i) => _NBlock(
              key: ValueKey(blocks[i].id),
              idx: i,
              block: blocks[i],
              prevType: i > 0 ? blocks[i - 1].type : null,
              onKey: _key,
              onTxt: _txt,
              onDel: () => ref.read(fileEditorProvider.notifier).removeBlock(i),
              onDup: () => ref.read(fileEditorProvider.notifier).duplicate(i),
              onType: (t) =>
                  ref.read(fileEditorProvider.notifier).setType(i, t),
              onCheck: (v) =>
                  ref.read(fileEditorProvider.notifier).toggleCheck(i, v),
              onFocus: () {
                _chg(ft: blocks[i].controller.text);
                _focusEvent(blocks[i].controller.text);
              },
            ),
          ),
        ),
      ],
    );
  }

  // ── AI Panel ──────────────────────────────────────────
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
              // 탭 헤더
              Container(
                height: 54,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: _bdr)),
                ),
                child: _PremiumTabs(ctrl: _tab),
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
                    _AnaPanel(st: st),
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

// ══════════════════ AURORA BACKGROUND ══════════════════
class _AuroraBG extends StatelessWidget {
  final Animation<double> anim;
  const _AuroraBG({required this.anim});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: anim,
      builder: (_, __) {
        final t = anim.value;
        return SizedBox.expand(child: CustomPaint(painter: _AuroraPainter(t)));
      },
    );
  }
}

class _AuroraPainter extends CustomPainter {
  final double t;
  const _AuroraPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    void blob(double cx, double cy, double r, Color c, double a) {
      canvas.drawCircle(
        Offset(cx * size.width, cy * size.height),
        r,
        Paint()
          ..color = c.withOpacity(a)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 120),
      );
    }

    // 움직이는 오로라 오브들
    blob(
      0.15 + t * 0.08,
      0.2 + math.sin(t * math.pi) * 0.05,
      260,
      const Color(0xFF4F8EFF),
      0.045,
    );
    blob(
      0.85 - t * 0.06,
      0.15 + math.cos(t * math.pi) * 0.04,
      200,
      _acc,
      0.035,
    );
    blob(0.5 + math.sin(t * math.pi) * 0.1, 0.9, 300, _pur, 0.03);
    blob(0.9, 0.7 + t * 0.05, 180, _grn, 0.025);
  }

  @override
  bool shouldRepaint(_AuroraPainter o) => o.t != t;
}

// ══════════════════ APP BAR ════════════════════════════
class _AppBar extends StatelessWidget implements PreferredSizeWidget {
  final bool saving;
  final DateTime? savedAt;
  final Animation<double> saveAnim;
  final int charCount, view;
  final VoidCallback onBack, onCopy, onMdCopy, onView, onGraph;
  const _AppBar({
    required this.saving,
    this.savedAt,
    required this.saveAnim,
    required this.charCount,
    required this.view,
    required this.onBack,
    required this.onCopy,
    required this.onMdCopy,
    required this.onView,
    required this.onGraph,
  });

  @override
  Size get preferredSize => const Size.fromHeight(52);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      color: Colors.transparent,
      child: Row(
        children: [
          const SizedBox(width: 6),
          // 뒤로가기
          _CircleBtn(icon: Icons.arrow_back_rounded, onTap: onBack),
          const SizedBox(width: 12),
          // 저장 상태
          _SaveChip(saving: saving, savedAt: savedAt, anim: saveAnim),
          const Spacer(),
          // 글자 수
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _bg3,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '$charCount자',
              style: const TextStyle(color: _txt2, fontSize: 11),
            ),
          ),
          const SizedBox(width: 8),
          _TipBtn(Icons.copy_rounded, '복사', onCopy),
          _TipBtn(Icons.download_outlined, 'MD 복사', onMdCopy),
          _TipBtn(
            view == 0 ? Icons.crop_square_rounded : Icons.view_column_rounded,
            view == 0 ? '전체화면' : '분할 뷰',
            onView,
          ),
          _TipBtn(Icons.account_tree_outlined, '지식 그래프', onGraph),
          const SizedBox(width: 10),
        ],
      ),
    );
  }
}

class _CircleBtn extends StatefulWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _CircleBtn({required this.icon, required this.onTap});
  @override
  State<_CircleBtn> createState() => _CircleBtnState();
}

class _CircleBtnState extends State<_CircleBtn> {
  bool _hov = false;
  @override
  Widget build(BuildContext context) => MouseRegion(
    onEnter: (_) => setState(() => _hov = true),
    onExit: (_) => setState(() => _hov = false),
    child: GestureDetector(
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: _hov ? _bg4 : Colors.transparent,
          shape: BoxShape.circle,
          border: Border.all(color: _hov ? _bdr2 : Colors.transparent),
        ),
        child: Icon(widget.icon, size: 17, color: _hov ? _txt0 : _txt2),
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
            width: 11,
            height: 11,
            child: CircularProgressIndicator(
              strokeWidth: 1.2,
              color: _txt2.withOpacity(0.5),
            ),
          ),
          const SizedBox(width: 7),
          const Text('저장 중', style: TextStyle(color: _txt2, fontSize: 11)),
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
                size: 13,
                color: _grn.withOpacity(0.8),
              ),
              const SizedBox(width: 5),
              const Text('저장됨', style: TextStyle(color: _txt2, fontSize: 11)),
            ],
          ),
        ),
      );
    return const SizedBox.shrink();
  }
}

class _TipBtn extends StatelessWidget {
  final IconData icon;
  final String tip;
  final VoidCallback onTap;
  const _TipBtn(this.icon, this.tip, this.onTap);
  @override
  Widget build(BuildContext context) => Tooltip(
    message: tip,
    preferBelow: true,
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

// ══════════════════ GLOW TITLE ═════════════════════════
class _GlowTitle extends StatefulWidget {
  final TextEditingController ctrl;
  final VoidCallback onChange;
  const _GlowTitle({required this.ctrl, required this.onChange});
  @override
  State<_GlowTitle> createState() => _GlowTitleState();
}

class _GlowTitleState extends State<_GlowTitle> {
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
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      decoration: _foc && widget.ctrl.text.isNotEmpty
          ? BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: _acc.withOpacity(0.04),
                  blurRadius: 40,
                  spreadRadius: 10,
                ),
              ],
            )
          : null,
      child: TextField(
        controller: widget.ctrl,
        focusNode: _fn,
        style: const TextStyle(
          fontSize: 40,
          fontWeight: FontWeight.w800,
          color: _txt0,
          height: 1.18,
          letterSpacing: -1.2,
          shadows: [Shadow(color: Color(0x22CCFF66), blurRadius: 30)],
        ),
        decoration: const InputDecoration(
          border: InputBorder.none,
          filled: false,
          isDense: true,
          contentPadding: EdgeInsets.zero,
          hintText: '제목 없음',
          hintStyle: TextStyle(
            fontSize: 40,
            fontWeight: FontWeight.w800,
            color: _txt2,
            height: 1.18,
            letterSpacing: -1.2,
          ),
        ),
        onChanged: (_) => widget.onChange(),
      ),
    );
  }
}

// ══════════════════ ICON PICKER ════════════════════════
class _IconRow extends StatefulWidget {
  final String current;
  final void Function(String) onChange;
  const _IconRow({required this.current, required this.onChange});
  @override
  State<_IconRow> createState() => _IconRowState();
}

class _IconRowState extends State<_IconRow>
    with SingleTickerProviderStateMixin {
  bool _open = false;
  late AnimationController _ac;
  late Animation<double> _anim;
  static const _icons = [
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
      duration: const Duration(milliseconds: 200),
    );
    _anim = CurvedAnimation(parent: _ac, curve: Curves.easeOutCubic);
  }

  @override
  void dispose() {
    _ac.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() => _open = !_open);
    _open ? _ac.forward() : _ac.reverse();
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      GestureDetector(
        onTap: _toggle,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
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
                duration: const Duration(milliseconds: 200),
                child: const Icon(
                  Icons.expand_more_rounded,
                  size: 16,
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
            children: _icons
                .map(
                  (ic) => GestureDetector(
                    onTap: () {
                      widget.onChange(ic);
                      _toggle();
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 120),
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

// ══════════════════ PROP ROW ═══════════════════════════
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
  State<_PropRow> createState() => _PropRowState();
}

class _PropRowState extends State<_PropRow> {
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
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          child: Icon(widget.icon, size: 14, color: _foc ? _acc : _txt2),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 62,
          child: Text(
            widget.label,
            style: const TextStyle(color: _txt2, fontSize: 12),
          ),
        ),
        Expanded(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              color: _foc ? _bg4 : Colors.transparent,
              borderRadius: BorderRadius.circular(7),
              border: Border.all(color: _foc ? _bdr2 : Colors.transparent),
            ),
            child: TextField(
              controller: widget.ctrl,
              focusNode: _fn,
              style: const TextStyle(color: _txt1, fontSize: 13),
              decoration: InputDecoration(
                border: InputBorder.none,
                filled: false,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 7,
                ),
                hintText: widget.hint,
                hintStyle: const TextStyle(color: _txt2, fontSize: 13),
              ),
              onChanged: widget.onChange,
            ),
          ),
        ),
      ],
    ),
  );
}

class _Divider extends StatelessWidget {
  const _Divider();
  @override
  Widget build(BuildContext context) => Container(
    height: 1,
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [Colors.transparent, _bdr, Colors.transparent],
      ),
    ),
  );
}

// ══════════════════ NOTION BLOCK ═══════════════════════
class _NBlock extends StatefulWidget {
  final int idx;
  final Block block;
  final BlockType? prevType;
  final KeyEventResult Function(FocusNode, KeyEvent, int) onKey;
  final Function(String, int) onTxt;
  final VoidCallback onDel, onDup, onFocus;
  final Function(BlockType) onType;
  final Function(bool) onCheck;
  const _NBlock({
    Key? key,
    required this.idx,
    required this.block,
    this.prevType,
    required this.onKey,
    required this.onTxt,
    required this.onDel,
    required this.onDup,
    required this.onType,
    required this.onCheck,
    required this.onFocus,
  }) : super(key: key);
  @override
  State<_NBlock> createState() => _NBlockState();
}

class _NBlockState extends State<_NBlock> with SingleTickerProviderStateMixin {
  bool _hov = false, _foc = false;
  late AnimationController _ac;
  late Animation<double> _fade;
  late Animation<Offset> _slide;
  @override
  void initState() {
    super.initState();
    widget.block.focusNode.addListener(_onFoc);
    _ac = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _fade = CurvedAnimation(parent: _ac, curve: Curves.easeOut);
    _slide = Tween(
      begin: const Offset(0, -.03),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ac, curve: Curves.easeOutCubic));
    _ac.forward();
  }

  @override
  void dispose() {
    widget.block.focusNode.removeListener(_onFoc);
    _ac.dispose();
    super.dispose();
  }

  void _onFoc() {
    if (mounted) {
      setState(() => _foc = widget.block.focusNode.hasFocus);
      if (_foc) widget.onFocus();
    }
  }

  TextStyle _style() {
    switch (widget.block.type) {
      case BlockType.h1:
        return const TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.w800,
          color: _txt0,
          height: 1.3,
          letterSpacing: -0.7,
          shadows: [Shadow(color: Color(0x15FFFFFF), blurRadius: 20)],
        );
      case BlockType.h2:
        return const TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: _txt0,
          height: 1.35,
          letterSpacing: -0.3,
        );
      case BlockType.h3:
        return const TextStyle(
          fontSize: 19,
          fontWeight: FontWeight.w600,
          color: _txt0,
          height: 1.4,
        );
      case BlockType.code:
        return const TextStyle(
          fontSize: 14,
          fontFamily: 'Courier',
          color: Color(0xFFBBAFF8),
          height: 1.6,
          letterSpacing: 0.2,
        );
      default:
        return const TextStyle(
          fontSize: 16,
          color: _txt0,
          height: 1.8,
          letterSpacing: 0.15,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    widget.block.focusNode.onKeyEvent = (n, e) =>
        widget.onKey(n, e, widget.idx);
    final isBul = widget.block.type == BlockType.bullet;
    final isPrevBul = widget.prevType == BlockType.bullet;
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
              top: (isBul && isPrevBul) ? 1 : (isBul ? 3 : 2),
              bottom: isBul ? 1 : 2,
              left: 8,
              right: 8,
            ),
            decoration: BoxDecoration(
              color: _foc
                  ? Colors.white.withOpacity(0.018)
                  : widget.block.type == BlockType.code
                  ? const Color(0xFF0D1117)
                  : null,
              borderRadius: BorderRadius.circular(6),
              border: widget.block.type == BlockType.code
                  ? Border.all(color: _bdr)
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
                          _mi('d', Icons.delete_outline_rounded, '삭제', _red),
                          _mi('c', Icons.content_copy_rounded, '복제', _txt1),
                          const PopupMenuDivider(height: 6),
                          _mi('h1', Icons.looks_one_outlined, '제목 1', _txt1),
                          _mi('h2', Icons.looks_two_outlined, '제목 2', _txt1),
                          _mi('t', Icons.short_text_rounded, '텍스트', _txt1),
                          _mi(
                            'b',
                            Icons.format_list_bulleted_rounded,
                            '글머리',
                            _txt1,
                          ),
                          _mi('cd', Icons.code_rounded, '코드', _txt1),
                        ],
                      ),
                    ),
                  ),
                ),
                if (widget.block.type == BlockType.bullet)
                  Padding(
                    padding: const EdgeInsets.only(top: 12, right: 10),
                    child: Icon(Icons.circle, size: 4, color: _txt2),
                  ),
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
                if (widget.block.type == BlockType.code)
                  Padding(
                    padding: const EdgeInsets.only(top: 2, right: 6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: _bdr,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'CODE',
                        style: TextStyle(
                          color: _txt2,
                          fontSize: 8,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                  ),
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
                            ? _txt2
                            : null,
                      ),
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                        filled: false,
                        hintText: (_foc && widget.block.controller.text.isEmpty)
                            ? _hint(widget.block.type)
                            : '',
                        hintStyle: TextStyle(
                          color: _txt2.withOpacity(0.45),
                          fontSize: 16,
                        ),
                      ),
                      onChanged: (t) => widget.onTxt(t, widget.idx),
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

  String _hint(BlockType t) => switch (t) {
    BlockType.h1 => '제목 1',
    BlockType.h2 => '제목 2',
    BlockType.h3 => '제목 3',
    BlockType.bullet => '항목 입력',
    BlockType.checkbox => '할 일 추가',
    BlockType.code => '코드 입력',
    _ => "'/' 로 블록 삽입  ·  입력 시작",
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

// ══════════════════ SLASH MENU ═════════════════════════
class _Opt {
  final String id, label, hint;
  final IconData icon;
  const _Opt(this.id, this.label, this.icon, this.hint);
}

class _SlashMenu extends StatelessWidget {
  final List<_Opt> opts;
  final int sel;
  final void Function(_Opt) onSel;
  const _SlashMenu({
    required this.opts,
    required this.sel,
    required this.onSel,
  });
  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(14),
    child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
      child: Container(
        decoration: BoxDecoration(
          color: _bg3.withOpacity(0.92),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _bdr2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.4),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
              child: Row(
                children: [
                  Icon(Icons.add_circle_outline_rounded, size: 11, color: _acc),
                  const SizedBox(width: 6),
                  const Text(
                    '블록 삽입',
                    style: TextStyle(
                      color: _txt2,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
            ...opts.asMap().entries.map(
              (e) => _SlashItem(
                opt: e.value,
                sel: e.key == sel,
                onTap: () => onSel(e.value),
              ),
            ),
            const SizedBox(height: 6),
          ],
        ),
      ),
    ),
  );
}

class _SlashItem extends StatefulWidget {
  final _Opt opt;
  final bool sel;
  final VoidCallback onTap;
  const _SlashItem({required this.opt, required this.sel, required this.onTap});
  @override
  State<_SlashItem> createState() => _SlashItemState();
}

class _SlashItemState extends State<_SlashItem> {
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
          color: (widget.sel || _h) ? _bg4 : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(
            color: (widget.sel || _h) ? _bdr2 : Colors.transparent,
          ),
        ),
        child: Row(
          children: [
            Icon(
              widget.opt.icon,
              size: 15,
              color: (widget.sel || _h) ? _acc : _txt2,
            ),
            const SizedBox(width: 10),
            Text(
              widget.opt.label,
              style: TextStyle(
                color: (widget.sel || _h) ? _txt0 : _txt1,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
            const Spacer(),
            if (widget.opt.hint.isNotEmpty)
              Text(
                widget.opt.hint,
                style: const TextStyle(
                  color: _txt2,
                  fontSize: 10,
                  fontFamily: 'Courier',
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

// ══════════════════ PREMIUM TABS ═══════════════════════
class _PremiumTabs extends StatelessWidget {
  final TabController ctrl;
  const _PremiumTabs({required this.ctrl});
  @override
  Widget build(BuildContext context) => TabBar(
    controller: ctrl,
    isScrollable: true,
    tabAlignment: TabAlignment.start,
    dividerColor: Colors.transparent,
    indicator: BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0xFF1A2A0A), Color(0xFF1A2A0A)],
      ),
      borderRadius: BorderRadius.circular(9),
      border: Border.all(color: _acc.withOpacity(0.3)),
    ),
    labelColor: _acc,
    unselectedLabelColor: _txt2,
    labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
    unselectedLabelStyle: const TextStyle(fontSize: 12),
    labelPadding: const EdgeInsets.symmetric(horizontal: 14),
    tabs: [
      _T(Icons.auto_awesome_rounded, '요약'),
      _T(Icons.manage_search_rounded, '분석'),
      _T(Icons.psychology_rounded, '암기'),
      _T(Icons.quiz_rounded, '퀴즈'),
      _T(Icons.chat_bubble_outline, 'Ask'),
    ],
  );
  Tab _T(IconData icon, String txt) => Tab(
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [Icon(icon, size: 13), const SizedBox(width: 5), Text(txt)],
    ),
  );
}

// ══════════════════ SUMMARY PANEL ══════════════════════
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
  Widget build(BuildContext context) {
    return Stack(
      children: [
        if (st.summaryBlocks.isEmpty && !st.isSummaryLoading)
          const _EmptyState(
            icon: Icons.auto_awesome_rounded,
            title: '스마트 요약',
            desc: '80자 이상 작성하면\nAI가 자동으로 요약합니다.',
          ),
        if (st.isSummaryLoading && st.summaryBlocks.isEmpty)
          const _LoadingState(msg: '내용을 분석하는 중...'),
        ListView.builder(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 120),
          itemCount: st.summaryBlocks.length,
          itemBuilder: (_, i) => _SumCard(
            key: ValueKey('sc$i'),
            block: st.summaryBlocks[i],
            index: i,
            onPin: () =>
                ref.read(fileEditorProvider.notifier).toggleSummarySave(i),
            onDel: () =>
                ref.read(fileEditorProvider.notifier).removeSummaryBlock(i),
            onCopy: () {
              Clipboard.setData(
                ClipboardData(text: st.summaryBlocks[i].content),
              );
              snack('복사됨');
            },
          ),
        ),
        _GradFade(),
        Positioned(
          bottom: 16,
          left: 14,
          right: 14,
          child: _FloatAction(
            loading: st.isSummaryLoading,
            label: st.summaryBlocks.any((b) => b.isSaved) ? '추가 분석' : '요약 생성',
            icon: Icons.auto_fix_high_rounded,
            pulse: pulse,
            onTap: () => ref
                .read(fileEditorProvider.notifier)
                .requestSummary(title: tCtrl.text, tags: gCtrl.text),
          ),
        ),
      ],
    );
  }
}

// ── 요약 카드 — 글로우 효과 ───────────────────────────────
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
  late AnimationController _ac;
  late Animation<double> _fade, _scale, _slide;
  @override
  void initState() {
    super.initState();
    _ac = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 300 + widget.index * 70),
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
    return FadeTransition(
      opacity: _fade,
      child: ScaleTransition(
        scale: _scale,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: pinned ? const Color(0xFF0A1505) : _bg3,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: pinned ? _acc.withOpacity(0.4) : _bdr,
              width: pinned ? 1.5 : 1,
            ),
            boxShadow: pinned
                ? [
                    BoxShadow(
                      color: _acc.withOpacity(0.08),
                      blurRadius: 24,
                      spreadRadius: 0,
                    ),
                    BoxShadow(
                      color: _acc.withOpacity(0.04),
                      blurRadius: 60,
                      spreadRadius: 10,
                    ),
                  ]
                : [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      blurRadius: 8,
                    ),
                  ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 헤더
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 11, 10, 11),
                child: Row(
                  children: [
                    // 상태 도트
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: pinned ? _acc : _txt2.withOpacity(0.3),
                        shape: BoxShape.circle,
                        boxShadow: pinned
                            ? [
                                BoxShadow(
                                  color: _acc.withOpacity(0.7),
                                  blurRadius: 8,
                                  spreadRadius: 1,
                                ),
                              ]
                            : [],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      pinned ? 'PINNED' : 'LATEST',
                      style: TextStyle(
                        color: pinned ? _acc : _txt2,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const Spacer(),
                    _IBtn(
                      Icons.content_copy_rounded,
                      widget.onCopy,
                      color: _txt2,
                      sz: 13,
                    ),
                    const SizedBox(width: 2),
                    _IBtn(
                      pinned ? Icons.push_pin : Icons.push_pin_outlined,
                      widget.onPin,
                      color: pinned ? _acc : _txt2,
                      sz: 13,
                    ),
                    const SizedBox(width: 2),
                    _IBtn(
                      Icons.close_rounded,
                      widget.onDel,
                      color: _txt2,
                      sz: 13,
                    ),
                  ],
                ),
              ),
              // 구분선
              Container(
                height: 1,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.transparent,
                      pinned ? _acc.withOpacity(0.2) : _bdr,
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
              // 내용
              Padding(
                padding: const EdgeInsets.all(16),
                child: MarkdownBody(
                  data: widget.block.content,
                  styleSheet: _mdStyle(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ══════════════════ 분석 패널 ═══════════════════════════
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
          child: st.isAnalysisLoading
              ? const _LoadingState(msg: '문맥 의미 분석 중...')
              : st.currentAnalysis?.isNotEmpty == true
              ? SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(14, 16, 14, 40),
                  child: MarkdownBody(
                    data: st.currentAnalysis!,
                    styleSheet: _mdStyle(),
                  ),
                )
              : const _EmptyState(
                  icon: Icons.manage_search_rounded,
                  title: '문단 분석',
                  desc: '에디터 문단을 클릭하면\nAI가 즉시 심층 분석합니다.',
                ),
        ),
      ),
    ],
  );
}

// ══════════════════ 암기/퀴즈/ASK 패널 ═════════════════
class _MemoPanel extends StatelessWidget {
  final FileEditorState st;
  final WidgetRef ref;
  final TextEditingController tCtrl;
  const _MemoPanel({required this.st, required this.ref, required this.tCtrl});
  @override
  Widget build(BuildContext context) => Stack(
    children: [
      if (st.currentMemo == null && !st.isMemoLoading)
        const _EmptyState(
          icon: Icons.psychology_rounded,
          title: '핵심 암기',
          desc: '본문에서 핵심 개념을\n자동 추출합니다.',
        ),
      if (st.currentMemo?.isNotEmpty == true)
        SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 120),
          child: MarkdownBody(data: st.currentMemo!, styleSheet: _mdStyle()),
        ),
      _GradFade(),
      if (st.currentMemo == null || st.isMemoLoading)
        Positioned(
          bottom: 16,
          left: 14,
          right: 14,
          child: _FloatAction(
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

class _QuizPanel extends StatelessWidget {
  final FileEditorState st;
  final WidgetRef ref;
  const _QuizPanel({required this.st, required this.ref});
  @override
  Widget build(BuildContext context) => Stack(
    children: [
      if (st.quizData == null && !st.isQuizLoading)
        const _EmptyState(
          icon: Icons.quiz_rounded,
          title: '퀴즈',
          desc: '본문으로 인터랙티브\n객관식 퀴즈를 생성합니다.',
        ),
      if (st.quizData != null)
        ListView.builder(
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
      _GradFade(),
      if (st.quizData == null || st.isQuizLoading)
        Positioned(
          bottom: 16,
          left: 14,
          right: 14,
          child: _FloatAction(
            loading: st.isQuizLoading,
            label: '퀴즈 생성',
            icon: Icons.quiz_rounded,
            onTap: () => ref.read(fileEditorProvider.notifier).generateQuiz(),
          ),
        ),
    ],
  );
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
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Q${qi + 1}.  ${q['question']}',
            style: const TextStyle(
              color: _txt0,
              fontSize: 14,
              fontWeight: FontWeight.w600,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          ...List.generate((q['options'] as List).length, (oi) {
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
                    q['options'][oi],
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
            ? const _LoadingState(msg: '노트 + 웹 검색 중...')
            : st.qaAnswer != null
            ? SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(14, 16, 14, 20),
                child: MarkdownBody(data: st.qaAnswer!, styleSheet: _mdStyle()),
              )
            : const _EmptyState(
                icon: Icons.chat_bubble_outline_rounded,
                title: 'Quick Ask',
                desc: '내 노트 + 실시간 웹으로\n무엇이든 답합니다.',
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
                style: const TextStyle(color: _txt0, fontSize: 13),
                decoration: InputDecoration(
                  hintText: '질문 입력...',
                  hintStyle: const TextStyle(color: _txt2, fontSize: 13),
                  filled: true,
                  fillColor: _bg3,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: const BorderSide(color: _bdr),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: const BorderSide(color: _bdr),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: const BorderSide(color: _acc),
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

// ══════════════════ 지식 그래프 뷰 ═════════════════════
class _GraphView extends StatelessWidget {
  final FileEditorState st;
  final WidgetRef ref;
  const _GraphView({required this.st, required this.ref});
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
              child: const Icon(Icons.hub_rounded, color: _acc, size: 18),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'AI Semantic Graph',
                  style: TextStyle(
                    color: _txt0,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                ),
                const Text(
                  '개념 간 의미적 연결 시각화',
                  style: TextStyle(color: _txt2, fontSize: 12),
                ),
              ],
            ),
            const Spacer(),
            _TipBtn(
              Icons.refresh_rounded,
              '재생성',
              () => ref.read(fileEditorProvider.notifier).requestGraph(),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            _SC(Icons.article_outlined, '블록', '${st.blocks.length}개'),
            const SizedBox(width: 12),
            _SC(Icons.text_fields_rounded, '글자', '${st.charCount}자'),
            const SizedBox(width: 12),
            _SC(
              Icons.bookmark_rounded,
              '확정 요약',
              '${st.summaryBlocks.where((b) => b.isSaved).length}개',
              accent: true,
            ),
            const SizedBox(width: 12),
            _SC(Icons.timer_outlined, '읽기', '${(st.wordCount / 200).ceil()}분'),
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
                BoxShadow(color: _acc.withOpacity(0.04), blurRadius: 40),
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
                  : const _EmptyState(
                      icon: Icons.hub_outlined,
                      title: '지식 그래프',
                      desc: '충분한 내용 작성 시\n자동으로 그래프가 생성됩니다.',
                    ),
            ),
          ),
        ),
      ],
    ),
  );
}

class _SC extends StatelessWidget {
  final IconData icon;
  final String label, value;
  final bool accent;
  const _SC(this.icon, this.label, this.value, {this.accent = false});
  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: accent ? _accD : _bg3,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent ? _acc.withOpacity(0.3) : _bdr),
        boxShadow: accent
            ? [BoxShadow(color: _acc.withOpacity(0.06), blurRadius: 20)]
            : [],
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

// ══════════════════ 그래프 캔버스 ══════════════════════
class _GraphCanvas extends StatefulWidget {
  final Map<String, dynamic> data;
  const _GraphCanvas({required this.data});
  @override
  State<_GraphCanvas> createState() => _GCState();
}

class _GCState extends State<_GraphCanvas> with SingleTickerProviderStateMixin {
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
    final rn = widget.data['nodes'] as List ?? ([]);
    final re = widget.data['edges'] as List ?? ([]);
    for (int i = 0; i < rn.length; i++) {
      final ic = i == 0;
      ns.add(
        _GN(
          id: rn[i]['id'].toString(),
          label: rn[i]['label'].toString(),
          r: ic ? 14 : 7,
          color: ic ? _acc : _blu,
          br: ic ? 0 : 65 + math.Random().nextDouble() * 110,
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

// ══════════════════ SPLIT PANE ═════════════════════════
class _Split extends StatefulWidget {
  final Widget left, right;
  const _Split({required this.left, required this.right});
  @override
  State<_Split> createState() => _SplitState();
}

class _SplitState extends State<_Split> {
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

// ══════════════════ 공통 위젯 ══════════════════════════
class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title, desc;
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.desc,
  });
  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: RadialGradient(colors: [_bg4, _bg3]),
            shape: BoxShape.circle,
            border: Border.all(color: _bdr2),
          ),
          child: Icon(icon, size: 28, color: _txt2),
        ),
        const SizedBox(height: 18),
        Text(
          title,
          style: const TextStyle(
            color: _txt0,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          desc,
          textAlign: TextAlign.center,
          style: const TextStyle(color: _txt2, fontSize: 13, height: 1.6),
        ),
      ],
    ),
  );
}

class _LoadingState extends StatelessWidget {
  final String msg;
  const _LoadingState({required this.msg});
  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(
            color: _acc,
            strokeWidth: 2,
            strokeCap: StrokeCap.round,
          ),
        ),
        const SizedBox(height: 16),
        Text(msg, style: const TextStyle(color: _txt2, fontSize: 13)),
      ],
    ),
  );
}

class _GradFade extends StatelessWidget {
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
            colors: [Color(0xFF0F0F16), Colors.transparent],
          ),
        ),
      ),
    ),
  );
}

class _FloatAction extends StatefulWidget {
  final bool loading;
  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  final Animation<double>? pulse;
  const _FloatAction({
    required this.loading,
    required this.label,
    required this.icon,
    this.onTap,
    this.pulse,
  });
  @override
  State<_FloatAction> createState() => _FloatActionState();
}

class _FloatActionState extends State<_FloatAction>
    with SingleTickerProviderStateMixin {
  bool _hov = false;
  late AnimationController _ac;
  late Animation<double> _scale;
  @override
  void initState() {
    super.initState();
    _ac = AnimationController(vsync: this, duration: const Duration(seconds: 2))
      ..repeat(reverse: true);
    _scale = Tween(
      begin: 1.0,
      end: 1.02,
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
      scale: widget.loading ? _scale : const AlwaysStoppedAnimation(1.0),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hov = true),
        onExit: (_) => setState(() => _hov = false),
        child: GestureDetector(
          onTap: widget.loading ? null : widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 13),
            decoration: BoxDecoration(
              gradient: widget.loading
                  ? LinearGradient(colors: [_accD, const Color(0xFF1A2A0A)])
                  : null,
              color: widget.loading ? null : (_hov ? _bg4 : _bg3),
              borderRadius: BorderRadius.circular(32),
              border: Border.all(
                color: widget.loading
                    ? _acc.withOpacity(0.4)
                    : (_hov ? _bdr2 : _bdr),
                width: widget.loading ? 1.5 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.4),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
                if (widget.loading)
                  BoxShadow(
                    color: _acc.withOpacity(0.15),
                    blurRadius: 24,
                    spreadRadius: 2,
                  ),
                if (_hov && !widget.loading)
                  BoxShadow(color: _acc.withOpacity(0.06), blurRadius: 20),
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
                    color: widget.loading ? _acc : (_hov ? _txt0 : _txt1),
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

class _IBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color? color;
  final double sz;
  const _IBtn(this.icon, this.onTap, {this.color, this.sz = 14});
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

// ══════════════════ MARKDOWN STYLE ═════════════════════
MarkdownStyleSheet _mdStyle() => MarkdownStyleSheet(
  p: const TextStyle(
    color: _txt0,
    fontSize: 14,
    height: 1.82,
    letterSpacing: 0.1,
  ),
  strong: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
  em: const TextStyle(color: _txt0, fontStyle: FontStyle.italic),
  code: const TextStyle(
    backgroundColor: Color(0xFF1A1A2E),
    fontFamily: 'Courier',
    color: Color(0xFFBBAFF8),
    fontSize: 13,
  ),
  codeblockDecoration: BoxDecoration(
    color: const Color(0xFF0D1117),
    borderRadius: BorderRadius.circular(10),
    border: Border.all(color: _bdr),
  ),
  tableBorder: TableBorder(
    horizontalInside: const BorderSide(color: _bdr),
    bottom: const BorderSide(color: _bdr),
  ),
  tableHead: const TextStyle(
    fontWeight: FontWeight.w700,
    color: _txt1,
    fontSize: 13,
  ),
  tableBody: const TextStyle(color: _txt0, fontSize: 13),
  tableCellsPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
  blockquoteDecoration: BoxDecoration(
    border: Border(left: BorderSide(color: _acc, width: 3)),
    color: _accD.withOpacity(0.4),
  ),
  blockquotePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
  listBullet: const TextStyle(color: _txt2, fontSize: 14),
  h1: const TextStyle(
    fontSize: 19,
    color: Colors.white,
    fontWeight: FontWeight.w800,
    height: 1.5,
    letterSpacing: -0.3,
  ),
  h2: const TextStyle(
    fontSize: 16,
    color: Colors.white,
    fontWeight: FontWeight.w700,
    height: 1.5,
  ),
  h3: const TextStyle(
    fontSize: 14,
    color: Colors.white,
    fontWeight: FontWeight.w700,
    height: 1.5,
  ),
  horizontalRuleDecoration: BoxDecoration(
    border: Border(top: BorderSide(color: _bdr)),
  ),
);
