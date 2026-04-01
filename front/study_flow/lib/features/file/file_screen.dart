// ============================================================
// file_screen.dart  (v2 - Bug Fixes + Notion UX)
// ============================================================
// ✅ 수정된 버그:
//   1. 백스페이스로 블록 병합 (위 블록으로 올라가기)
//   2. 리스트 작성 중 엔터 → 다음 리스트 자동 이어짐
//   3. 빈 리스트에서 엔터 → 일반 텍스트로 탈출
//   4. 탭 키 → 들여쓰기 (4스페이스)
//   5. Ctrl+A / Cmd+A → 전체 선택
// ✅ 추가 기능:
//   - 요약 복사/삭제 버튼
//   - 제목과 요약 동기화 표시
//   - 더 부드러운 애니메이션
// ============================================================

import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import '../../core/db_helper/files_db_helper.dart';
import '../../models/block_model.dart';
import 'file_provider.dart';

// ─── 프리미엄 다크 팔레트 ─────────────────────────────────
const Color _kBgPrimary = Color(0xFF0E0E11);
const Color _kBgSecondary = Color(0xFF161618);
const Color _kCardColor = Color(0xFF1C1C1F);
const Color _kHoverColor = Color(0xFF27272A);
const Color _kTextColor = Color(0xFFF4F4F5);
const Color _kTextSecondary = Color(0xFFA1A1AA);
const Color _kTextHint = Color(0xFF52525B);
const Color _kBorderColor = Color(0xFF27272A);
const Color _kAccentColor = Color(0xFFCCFF66);
const Color _kCorrectColor = Color(0xFF34D399);
const Color _kWrongColor = Color(0xFFF87171);

// ─────────────────────────────────────────────────────────
// ResizableSplitView
// ─────────────────────────────────────────────────────────
class ResizableSplitView extends StatefulWidget {
  final Widget left;
  final Widget right;
  final double initialRatio;
  const ResizableSplitView({
    Key? key,
    required this.left,
    required this.right,
    this.initialRatio = 0.55,
  }) : super(key: key);

  @override
  State<ResizableSplitView> createState() => _ResizableSplitViewState();
}

class _ResizableSplitViewState extends State<ResizableSplitView> {
  late double _ratio;
  bool _isDragging = false;

  @override
  void initState() {
    super.initState();
    _ratio = widget.initialRatio;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        return Row(
          children: [
            SizedBox(width: width * _ratio, child: widget.left),
            MouseRegion(
              cursor: SystemMouseCursors.resizeColumn,
              onEnter: (_) => setState(() => _isDragging = true),
              onExit: (_) => setState(() => _isDragging = false),
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onPanUpdate: (details) => setState(() {
                  _ratio += details.delta.dx / width;
                  _ratio = _ratio.clamp(0.3, 0.75);
                }),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 6,
                  color: Colors.transparent,
                  alignment: Alignment.center,
                  child: Container(
                    width: _isDragging ? 2 : 1,
                    height: double.infinity,
                    color: _isDragging ? _kAccentColor : _kBorderColor,
                  ),
                ),
              ),
            ),
            Expanded(child: widget.right),
          ],
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────
// FileScreen
// ─────────────────────────────────────────────────────────
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
  final _titleController = TextEditingController();
  final _tagsController = TextEditingController();
  final _aiPromptController = TextEditingController();
  final _qaController = TextEditingController();
  late TabController _tabController;

  Timer? _saveTimer;
  Timer? _focusTimer;
  Timer? _autoSummaryTimer;

  int _lastSummarizedLength = 0;
  bool _isSaving = false;
  int _viewMode = 0; // 0: split, 1: dashboard

  OverlayEntry? _overlayEntry;
  int _activeBlockIndex = -1;
  int _menuSelectedIndex = 0;
  List<Map<String, dynamic>> _currentFilteredOptions = [];

  final List<Map<String, dynamic>> _allMenuOptions = [
    {'type': BlockType.h1, 'label': '제목 1', 'icon': Icons.looks_one_rounded},
    {'type': BlockType.h2, 'label': '제목 2', 'icon': Icons.looks_two_rounded},
    {'type': BlockType.h3, 'label': '제목 3', 'icon': Icons.looks_3_rounded},
    {'type': BlockType.text, 'label': '텍스트', 'icon': Icons.short_text_rounded},
    {
      'type': BlockType.bullet,
      'label': '글머리 기호',
      'icon': Icons.format_list_bulleted_rounded,
    },
    {
      'type': BlockType.checkbox,
      'label': '할 일',
      'icon': Icons.check_box_outlined,
    },
    {'type': BlockType.code, 'label': '코드 블록', 'icon': Icons.code_rounded},
    {'type': 'table', 'label': '표 (Table)', 'icon': Icons.table_chart_rounded},
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  Future<void> _init() async {
    await ref.read(fileEditorProvider.notifier).loadFileDetail(widget.fileId);
    final file = await FilesDBHelper.getFile(widget.fileId);
    if (file != null && mounted) {
      setState(() {
        _titleController.text = file.title;
        _tagsController.text = file.tags;
        _aiPromptController.text = file.prompt ?? '';
      });
    }
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    _focusTimer?.cancel();
    _autoSummaryTimer?.cancel();
    _titleController.dispose();
    _tagsController.dispose();
    _aiPromptController.dispose();
    _qaController.dispose();
    _tabController.dispose();
    _removeOverlay();
    super.dispose();
  }

  // ─── 자동 저장 (Debounce) ─────────────────────
  void _onContentChanged({String? activeBlockText}) {
    if (activeBlockText != null) {
      ref.read(fileEditorProvider.notifier).state = ref
          .read(fileEditorProvider)
          .copyWith(focusedText: activeBlockText);
    }
    setState(() => _isSaving = true);
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 800), () async {
      await ref
          .read(fileEditorProvider.notifier)
          .saveFile(
            fileId: widget.fileId,
            title: _titleController.text,
            tags: _tagsController.text,
            prompt: _aiPromptController.text,
            updateAt: DateTime.now(),
          );
      if (mounted) setState(() => _isSaving = false);
    });

    // 50자 이상 변경 시 자동 요약 예약
    final len = ref.read(fileEditorProvider).charCount;
    if ((len - _lastSummarizedLength).abs() >= 50) {
      _autoSummaryTimer?.cancel();
      _autoSummaryTimer = Timer(const Duration(seconds: 6), () {
        _triggerAutoSummary();
      });
    }
  }

  void _triggerAutoSummary() {
    if (_tabController.index == 0 &&
        !ref.read(fileEditorProvider).isSummaryLoading) {
      _lastSummarizedLength = ref.read(fileEditorProvider).charCount;
      ref
          .read(fileEditorProvider.notifier)
          .requestAutoAISummary(
            title: _titleController.text,
            tags: _tagsController.text,
          );
    }
  }

  void _onBlockFocus(String text) {
    _focusTimer?.cancel();
    _focusTimer = Timer(const Duration(milliseconds: 1200), () {
      if (text.trim().isNotEmpty) {
        ref
            .read(fileEditorProvider.notifier)
            .requestBlockAnalysis(
              text: text,
              contextTitle: _titleController.text,
            );
      }
    });
  }

  // ─────────────────────────────────────────────
  // ✅ 핵심 키 이벤트 처리 (버그 수정)
  // ─────────────────────────────────────────────
  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event, int index) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    final isMeta = HardwareKeyboard.instance.isMetaPressed;
    final isCtrl = HardwareKeyboard.instance.isControlPressed;

    // ── Ctrl+A / Cmd+A: 전체 텍스트 선택 ──────
    if ((isMeta || isCtrl) && event.logicalKey == LogicalKeyboardKey.keyA) {
      final blocks = ref.read(fileEditorProvider).blocks;
      // 현재 블록 전체 선택 (단순 구현; 멀티블록 선택은 TODO)
      final ctrl = blocks[index].controller;
      ctrl.selection = TextSelection(
        baseOffset: 0,
        extentOffset: ctrl.text.length,
      );
      return KeyEventResult.handled;
    }

    // ── 슬래시 메뉴 열려있을 때 ──────────────
    if (_overlayEntry != null) {
      if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
        if (_menuSelectedIndex > 0) {
          _menuSelectedIndex--;
          _overlayEntry!.markNeedsBuild();
        }
        return KeyEventResult.handled;
      } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
        if (_menuSelectedIndex < _currentFilteredOptions.length - 1) {
          _menuSelectedIndex++;
          _overlayEntry!.markNeedsBuild();
        }
        return KeyEventResult.handled;
      } else if (event.logicalKey == LogicalKeyboardKey.enter) {
        _applyMenuOption(index, _currentFilteredOptions[_menuSelectedIndex]);
        return KeyEventResult.handled;
      } else if (event.logicalKey == LogicalKeyboardKey.escape) {
        _removeOverlay();
        return KeyEventResult.handled;
      }
    }

    final blocks = ref.read(fileEditorProvider).blocks;
    final ctrl = blocks[index].controller;

    // ── Tab: 들여쓰기 ────────────────────────
    if (event.logicalKey == LogicalKeyboardKey.tab) {
      ref.read(fileEditorProvider.notifier).indentBlock(index);
      return KeyEventResult.handled;
    }

    // ── Backspace: 블록 시작에서 → 위 블록과 병합 ──
    if (event.logicalKey == LogicalKeyboardKey.backspace) {
      final sel = ctrl.selection;
      if (sel.isCollapsed && sel.baseOffset == 0 && index > 0) {
        // ✅ 수정: mergeWithPreviousBlock 사용
        ref.read(fileEditorProvider.notifier).mergeWithPreviousBlock(index);
        return KeyEventResult.handled;
      }
      // bullet/checkbox 타입이고 내용이 없으면 타입만 text로 변경
      if (ctrl.text.isEmpty &&
          (blocks[index].type == BlockType.bullet ||
              blocks[index].type == BlockType.checkbox)) {
        ref
            .read(fileEditorProvider.notifier)
            .updateBlockType(index, BlockType.text);
        return KeyEventResult.handled;
      }
    }

    // ── Enter: 새 블록 생성 ──────────────────
    if (event.logicalKey == LogicalKeyboardKey.enter && !isMeta && !isCtrl) {
      final currentType = blocks[index].type;
      final currentText = ctrl.text;

      // ✅ bullet/checkbox가 비어있으면 → 일반 텍스트로 탈출
      if (currentText.trim().isEmpty &&
          (currentType == BlockType.bullet ||
              currentType == BlockType.checkbox)) {
        ref.read(fileEditorProvider.notifier).exitListMode(index);
        return KeyEventResult.handled;
      }

      // ✅ bullet/checkbox이면 다음 블록도 같은 타입으로 생성
      final nextType =
          (currentType == BlockType.bullet || currentType == BlockType.checkbox)
          ? currentType
          : BlockType.text;

      // 커서 위치에서 텍스트 분리
      final cursorPos = ctrl.selection.baseOffset.clamp(0, currentText.length);
      final before = currentText.substring(0, cursorPos);
      final after = currentText.substring(cursorPos);

      ctrl.text = before;
      ref.read(fileEditorProvider.notifier).insertBlocks(index + 1, [after]);

      // 다음 블록 타입 설정
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final updatedBlocks = ref.read(fileEditorProvider).blocks;
        if (index + 1 < updatedBlocks.length) {
          if (nextType != BlockType.text) {
            ref
                .read(fileEditorProvider.notifier)
                .updateBlockType(index + 1, nextType);
          }
          updatedBlocks[index + 1].focusNode.requestFocus();
          updatedBlocks[index + 1].controller.selection =
              TextSelection.collapsed(offset: 0);
        }
      });
      _onContentChanged();
      return KeyEventResult.handled;
    }

    // ── 방향키로 블록 이동 ───────────────────
    if (event.logicalKey == LogicalKeyboardKey.arrowUp && index > 0) {
      _moveFocus(index - 1);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowDown &&
        index < blocks.length - 1) {
      _moveFocus(index + 1);
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  // ─── 텍스트 변경 처리 ─────────────────────────
  void _handleTextChanged(String text, int index) {
    // 붙여넣기로 여러 줄 입력 시
    if (text.contains('\n')) {
      final lines = text.split('\n');
      ref.read(fileEditorProvider).blocks[index].controller.text = lines[0];
      if (lines.length > 1) {
        ref
            .read(fileEditorProvider.notifier)
            .insertBlocks(index + 1, lines.sublist(1));
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => _moveFocus(index + lines.length - 1),
        );
      }
      _onContentChanged(activeBlockText: lines[0]);
      return;
    }

    // 단축키 마크다운 변환 (스페이스로 트리거)
    if (text.endsWith(' ')) {
      BlockType? newType;
      String newText = text;

      if (text == '# ') {
        newType = BlockType.h1;
        newText = '';
      } else if (text == '## ') {
        newType = BlockType.h2;
        newText = '';
      } else if (text == '### ') {
        newType = BlockType.h3;
        newText = '';
      } else if (text == '- ' || text == '* ') {
        newType = BlockType.bullet;
        newText = '';
      } else if (text == '[] ' || text == '/todo ') {
        newType = BlockType.checkbox;
        newText = '';
      }

      if (newType != null) {
        final ctrl = ref.read(fileEditorProvider).blocks[index].controller;
        ctrl.text = newText;
        ref.read(fileEditorProvider.notifier).updateBlockType(index, newType);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          ctrl.selection = TextSelection.collapsed(offset: newText.length);
        });
        _onContentChanged(activeBlockText: newText);
        return;
      }
    }

    // 슬래시 메뉴 표시
    final slashIndex = text.lastIndexOf('/');
    if (slashIndex != -1 && slashIndex == text.length - 1) {
      _showOverlay(context, index, '');
    } else if (slashIndex != -1 &&
        !text.substring(slashIndex + 1).contains(' ')) {
      _showOverlay(context, index, text.substring(slashIndex + 1));
    } else {
      _removeOverlay();
    }

    _onContentChanged(activeBlockText: text);
  }

  void _moveFocus(int index) {
    final blocks = ref.read(fileEditorProvider).blocks;
    if (index >= 0 && index < blocks.length) {
      blocks[index].focusNode.requestFocus();
      final ctrl = blocks[index].controller;
      ctrl.selection = TextSelection.collapsed(offset: ctrl.text.length);
    }
  }

  // ─── 슬래시 메뉴 ─────────────────────────────
  void _showOverlay(BuildContext context, int index, String query) {
    _activeBlockIndex = index;
    _currentFilteredOptions = _allMenuOptions
        .where(
          (o) => (o['label'] as String).toLowerCase().contains(
            query.toLowerCase(),
          ),
        )
        .toList();

    if (_currentFilteredOptions.isEmpty) {
      _removeOverlay();
      return;
    }
    if (_overlayEntry == null) _menuSelectedIndex = 0;

    _overlayEntry?.remove();
    final blocks = ref.read(fileEditorProvider).blocks;

    _overlayEntry = OverlayEntry(
      builder: (ctx) => Positioned(
        width: 240,
        child: CompositedTransformFollower(
          link: blocks[index].layerLink,
          showWhenUnlinked: false,
          offset: const Offset(0, 36),
          child: Material(
            elevation: 24,
            borderRadius: BorderRadius.circular(12),
            color: _kCardColor,
            shadowColor: Colors.black.withOpacity(0.5),
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: _kBorderColor),
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListView.builder(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                itemCount: _currentFilteredOptions.length,
                itemBuilder: (_, i) => Container(
                  margin: const EdgeInsets.only(bottom: 2),
                  decoration: BoxDecoration(
                    color: i == _menuSelectedIndex
                        ? _kHoverColor
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ListTile(
                    dense: true,
                    minLeadingWidth: 24,
                    leading: Icon(
                      _currentFilteredOptions[i]['icon'],
                      size: 18,
                      color: i == _menuSelectedIndex
                          ? _kTextColor
                          : _kTextSecondary,
                    ),
                    title: Text(
                      _currentFilteredOptions[i]['label'],
                      style: TextStyle(
                        color: i == _menuSelectedIndex
                            ? _kTextColor
                            : _kTextSecondary,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    onTap: () =>
                        _applyMenuOption(index, _currentFilteredOptions[i]),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    Overlay.of(context).insert(_overlayEntry!);
  }

  void _applyMenuOption(int index, Map<String, dynamic> option) {
    _removeOverlay();
    final ctrl = ref.read(fileEditorProvider).blocks[index].controller;
    final slashIndex = ctrl.text.lastIndexOf('/');
    if (slashIndex != -1) ctrl.text = ctrl.text.substring(0, slashIndex);

    if (option['type'] == 'table') {
      ctrl.text += '| 열 1 | 열 2 |\n|---|---|\n| 내용 | 내용 |';
      ref
          .read(fileEditorProvider.notifier)
          .updateBlockType(index, BlockType.code);
    } else {
      ref
          .read(fileEditorProvider.notifier)
          .updateBlockType(index, option['type']);
    }
    _moveFocus(index);
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  void _copyAllContent() {
    final blocks = ref.read(fileEditorProvider).blocks;
    Clipboard.setData(
      ClipboardData(text: blocks.map((b) => b.controller.text).join('\n')),
    );
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('복사되었습니다.'),
        duration: Duration(seconds: 1),
        backgroundColor: _kCardColor,
      ),
    );
  }

  // ─────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final fileState = ref.watch(fileEditorProvider);
    final blocks = fileState.blocks;

    final editorView = CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 80),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 80),
                // 제목
                TextField(
                  controller: _titleController,
                  style: const TextStyle(
                    fontSize: 44,
                    fontWeight: FontWeight.w800,
                    color: _kTextColor,
                    height: 1.2,
                    letterSpacing: -1.0,
                  ),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    hintText: '제목 없음',
                    hintStyle: TextStyle(color: _kTextHint),
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                    filled: false,
                  ),
                  onChanged: (_) => _onContentChanged(),
                ),
                const SizedBox(height: 32),
                // 프로퍼티 행
                _buildPropertyRow(
                  Icons.tag_rounded,
                  'Tags',
                  _tagsController,
                  '비어 있음',
                ),
                _buildPropertyRow(
                  Icons.auto_awesome_rounded,
                  'Prompt',
                  _aiPromptController,
                  'AI 분석 지시사항...',
                ),
                const SizedBox(height: 32),
                const Divider(color: _kBorderColor, thickness: 1),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(80, 0, 80, 200),
          sliver: SliverReorderableList(
            itemCount: blocks.length,
            onReorder: (o, n) =>
                ref.read(fileEditorProvider.notifier).reorderBlock(o, n),
            itemBuilder: (context, index) {
              final block = blocks[index];
              final prevType = index > 0 ? blocks[index - 1].type : null;
              return HoverBlockItem(
                key: ValueKey(block.id),
                index: index,
                block: block,
                isLastBlock: index == blocks.length - 1,
                prevBlockType: prevType,
                onKey: _handleKeyEvent,
                onChanged: _handleTextChanged,
                onDelete: () =>
                    ref.read(fileEditorProvider.notifier).removeBlock(index),
                onDuplicate: () =>
                    ref.read(fileEditorProvider.notifier).duplicateBlock(index),
                onTypeChange: (type) => ref
                    .read(fileEditorProvider.notifier)
                    .updateBlockType(index, type),
                onToggleCheckbox: (val) => ref
                    .read(fileEditorProvider.notifier)
                    .toggleCheckbox(index, val),
                onFocus: () {
                  _onContentChanged(activeBlockText: block.controller.text);
                  _onBlockFocus(block.controller.text);
                },
              );
            },
          ),
        ),
      ],
    );

    final rightPanel = _buildRightPanel(fileState);

    return Scaffold(
      backgroundColor: _kBgPrimary,
      appBar: _buildAppBar(fileState),
      body: _viewMode == 0
          ? ResizableSplitView(left: editorView, right: rightPanel)
          : _buildDashboardView(fileState),
    );
  }

  AppBar _buildAppBar(FileEditorState fileState) {
    return AppBar(
      backgroundColor: _kBgPrimary,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
        onPressed: () => Navigator.pop(context),
        color: _kTextSecondary,
      ),
      title: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: _isSaving
            ? _saveIndicator(
                '저장 중...',
                child: const CircularProgressIndicator(
                  strokeWidth: 2,
                  color: _kTextSecondary,
                ),
              )
            : fileState.lastSavedAt != null
            ? _saveIndicator(
                '저장됨',
                child: const Icon(
                  Icons.cloud_done_rounded,
                  size: 16,
                  color: _kTextSecondary,
                ),
              )
            : const SizedBox.shrink(),
      ),
      centerTitle: true,
      actions: [
        IconButton(
          icon: const Icon(Icons.copy_rounded, size: 18),
          onPressed: _copyAllContent,
          color: _kTextSecondary,
          tooltip: '전체 복사',
        ),
        IconButton(
          icon: Icon(
            _viewMode == 0
                ? Icons.space_dashboard_rounded
                : Icons.edit_note_rounded,
            size: 18,
          ),
          onPressed: () => setState(() => _viewMode = _viewMode == 0 ? 1 : 0),
          color: _kTextSecondary,
          tooltip: _viewMode == 0 ? '대시보드 보기' : '에디터 보기',
        ),
        const SizedBox(width: 16),
      ],
    );
  }

  Widget _saveIndicator(String label, {required Widget child}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(width: 16, height: 16, child: child),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(
            color: _kTextSecondary,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  // ─── 우측 AI 스튜디오 패널 ────────────────────
  Widget _buildRightPanel(FileEditorState fileState) {
    return Container(
      decoration: const BoxDecoration(
        color: _kBgSecondary,
        border: Border(left: BorderSide(color: _kBorderColor, width: 1)),
      ),
      child: Column(
        children: [
          // 탭 바
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: _kBorderColor, width: 1),
              ),
            ),
            child: Theme(
              data: ThemeData(
                highlightColor: Colors.transparent,
                splashColor: Colors.transparent,
              ),
              child: TabBar(
                controller: _tabController,
                isScrollable: true,
                dividerColor: Colors.transparent,
                indicator: BoxDecoration(
                  color: _kCardColor,
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: _kBorderColor, width: 1),
                ),
                labelColor: _kTextColor,
                unselectedLabelColor: _kTextSecondary,
                labelStyle: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
                labelPadding: const EdgeInsets.symmetric(horizontal: 12),
                tabs: const [
                  Tab(
                    child: Row(
                      children: [
                        Icon(Icons.subject_rounded, size: 14),
                        SizedBox(width: 5),
                        Text('요약'),
                      ],
                    ),
                  ),
                  Tab(
                    child: Row(
                      children: [
                        Icon(Icons.manage_search_rounded, size: 14),
                        SizedBox(width: 5),
                        Text('분석'),
                      ],
                    ),
                  ),
                  Tab(
                    child: Row(
                      children: [
                        Icon(Icons.lightbulb_outline_rounded, size: 14),
                        SizedBox(width: 5),
                        Text('암기'),
                      ],
                    ),
                  ),
                  Tab(
                    child: Row(
                      children: [
                        Icon(Icons.rule_rounded, size: 14),
                        SizedBox(width: 5),
                        Text('퀴즈'),
                      ],
                    ),
                  ),
                  Tab(
                    child: Row(
                      children: [
                        Icon(Icons.forum_outlined, size: 14),
                        SizedBox(width: 5),
                        Text('Ask'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildSummaryTab(fileState),
                _buildAnalysisTab(fileState),
                _buildMemoTab(fileState),
                _buildQuizTab(fileState),
                _buildQATab(fileState),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  // 탭 1: 요약
  // ─────────────────────────────────────────────
  Widget _buildSummaryTab(FileEditorState state) {
    return Stack(
      children: [
        if (state.summaryBlocks.isEmpty && !state.isSummaryLoading)
          _emptyState(
            Icons.auto_awesome_rounded,
            'AI가 문서를 분석하여\n구조화된 요약 노트를 생성합니다.',
          ),

        ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
          itemCount: state.summaryBlocks.length,
          itemBuilder: (_, index) {
            final block = state.summaryBlocks[index];
            return _buildSummaryCard(block, index);
          },
        ),

        _bottomFade(),

        _floatingActionButton(
          label: state.summaryBlocks.any((b) => b.isSaved)
              ? '변경 내용 업데이트'
              : '요약 생성',
          icon: Icons.auto_fix_high_rounded,
          isLoading: state.isSummaryLoading,
          onPressed: () => ref
              .read(fileEditorProvider.notifier)
              .requestAutoAISummary(
                title: _titleController.text,
                tags: _tagsController.text,
              ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard(SummaryBlock block, int index) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: block.isSaved ? _kBgSecondary : _kCardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: block.isSaved ? _kAccentColor.withOpacity(0.5) : _kBorderColor,
          width: block.isSaved ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 카드 헤더
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      block.isSaved
                          ? Icons.check_circle_rounded
                          : Icons.radio_button_unchecked_rounded,
                      size: 14,
                      color: block.isSaved ? _kAccentColor : _kTextSecondary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      block.isSaved ? '확정된 요약' : '최신 분석 (임시)',
                      style: TextStyle(
                        color: block.isSaved ? _kAccentColor : _kTextSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                // ✅ 추가: 복사 / 확정 / 삭제 버튼
                Row(
                  children: [
                    // 복사 버튼
                    _miniIconButton(Icons.copy_rounded, '복사', () {
                      Clipboard.setData(ClipboardData(text: block.content));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('복사됨'),
                          duration: Duration(seconds: 1),
                          backgroundColor: _kCardColor,
                        ),
                      );
                    }),
                    // 확정/해제 버튼
                    _miniIconButton(
                      block.isSaved
                          ? Icons.lock_rounded
                          : Icons.push_pin_outlined,
                      block.isSaved ? '잠금 해제' : '확정',
                      () => ref
                          .read(fileEditorProvider.notifier)
                          .toggleSummarySave(index),
                      color: block.isSaved ? _kAccentColor : _kTextHint,
                    ),
                    // 삭제 버튼
                    _miniIconButton(Icons.close_rounded, '삭제', () {
                      ref
                          .read(fileEditorProvider.notifier)
                          .removeSummaryBlock(index);
                    }),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: _kBorderColor),
          // 본문
          Padding(
            padding: const EdgeInsets.all(16),
            child: MarkdownBody(data: block.content, styleSheet: _mdStyle()),
          ),
        ],
      ),
    );
  }

  Widget _miniIconButton(
    IconData icon,
    String tooltip,
    VoidCallback onTap, {
    Color? color,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(5),
          child: Icon(icon, size: 14, color: color ?? _kTextHint),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // 탭 2: 분석
  // ─────────────────────────────────────────────
  Widget _buildAnalysisTab(FileEditorState state) {
    return Column(
      children: [
        AnimatedSize(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          child: state.focusedText.trim().isNotEmpty
              ? Container(
                  margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _kCardColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _kBorderColor),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(
                            Icons.my_location_rounded,
                            size: 12,
                            color: _kAccentColor,
                          ),
                          SizedBox(width: 5),
                          Text(
                            '현재 포커스',
                            style: TextStyle(
                              fontSize: 11,
                              color: _kAccentColor,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        state.focusedText,
                        style: const TextStyle(
                          color: _kTextSecondary,
                          fontSize: 13,
                          height: 1.5,
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                )
              : const SizedBox.shrink(),
        ),
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: state.isAnalysisLoading
                ? _loader('문맥을 파악하는 중...')
                : state.currentBlockAnalysis == null ||
                      state.focusedText.trim().isEmpty
                ? _emptyState(
                    Icons.manage_search_rounded,
                    '에디터에서 문단을 클릭하면\nAI가 실시간으로 분석합니다.',
                  )
                : SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 100),
                    child: MarkdownBody(
                      data: state.currentBlockAnalysis!,
                      styleSheet: _mdStyle(),
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────
  // 탭 3: 암기
  // ─────────────────────────────────────────────
  Widget _buildMemoTab(FileEditorState state) {
    return Stack(
      children: [
        if (state.currentMemo == null && !state.isStudioLoading)
          _emptyState(
            Icons.psychology_rounded,
            '본문에서 가장 중요한\n핵심 개념만 스마트하게 추출합니다.',
          ),
        if (state.currentMemo != null)
          SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 120),
            child: MarkdownBody(
              data: state.currentMemo!,
              styleSheet: _mdStyle(),
            ),
          ),
        _bottomFade(),
        if (state.currentMemo == null || state.isStudioLoading)
          _floatingActionButton(
            label: '암기 노트 생성',
            icon: Icons.lightbulb_rounded,
            isLoading: state.isStudioLoading,
            onPressed: () => ref
                .read(fileEditorProvider.notifier)
                .generateStudioContent('memo'),
          ),
      ],
    );
  }

  // ─────────────────────────────────────────────
  // 탭 4: 퀴즈
  // ─────────────────────────────────────────────
  Widget _buildQuizTab(FileEditorState state) {
    return Stack(
      children: [
        if (state.quizData == null && !state.isStudioLoading)
          _emptyState(Icons.rule_rounded, '학습 내용을 바탕으로\n객관식 퀴즈를 풀어보세요.'),
        if (state.quizData != null)
          ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
            itemCount: state.quizData!.length,
            itemBuilder: (_, qIndex) => _buildQuizItem(state, qIndex),
          ),
        _bottomFade(),
        if (state.quizData == null || state.isStudioLoading)
          _floatingActionButton(
            label: '퀴즈 출제',
            icon: Icons.quiz_rounded,
            isLoading: state.isStudioLoading,
            onPressed: () => ref
                .read(fileEditorProvider.notifier)
                .generateStudioContent('quiz'),
          ),
      ],
    );
  }

  Widget _buildQuizItem(FileEditorState state, int qIndex) {
    final q = state.quizData![qIndex];
    final isAnswered = state.quizAnswers.containsKey(qIndex);
    final selected = state.quizAnswers[qIndex];
    final correct = q['answer'] ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Q${qIndex + 1}. ${q['question']}',
            style: const TextStyle(
              color: _kTextColor,
              fontSize: 15,
              fontWeight: FontWeight.w700,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          ...List.generate((q['options'] as List).length, (optIndex) {
            Color bg = _kCardColor, border = _kBorderColor, text = _kTextColor;
            if (isAnswered) {
              if (optIndex == correct) {
                bg = _kCorrectColor.withOpacity(0.1);
                border = _kCorrectColor.withOpacity(0.5);
                text = _kCorrectColor;
              } else if (optIndex == selected) {
                bg = _kWrongColor.withOpacity(0.1);
                border = _kWrongColor.withOpacity(0.5);
                text = _kWrongColor;
              }
            }
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: InkWell(
                onTap: () => ref
                    .read(fileEditorProvider.notifier)
                    .answerQuiz(qIndex, optIndex),
                borderRadius: BorderRadius.circular(10),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                    vertical: 14,
                    horizontal: 18,
                  ),
                  decoration: BoxDecoration(
                    color: bg,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: border),
                  ),
                  child: Text(
                    q['options'][optIndex],
                    style: TextStyle(
                      color: text,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            );
          }),
          if (isAnswered)
            Container(
              margin: const EdgeInsets.only(top: 6),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _kBgPrimary,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _kBorderColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        selected == correct
                            ? Icons.check_circle_rounded
                            : Icons.cancel_rounded,
                        size: 16,
                        color: selected == correct
                            ? _kCorrectColor
                            : _kWrongColor,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        selected == correct ? '정답!' : '오답',
                        style: TextStyle(
                          color: selected == correct
                              ? _kCorrectColor
                              : _kWrongColor,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    q['explanation'] ?? '',
                    style: const TextStyle(
                      color: _kTextSecondary,
                      height: 1.5,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  // 탭 5: Ask (RAG)
  // ─────────────────────────────────────────────
  Widget _buildQATab(FileEditorState state) {
    return Column(
      children: [
        Expanded(
          child: state.isQALoading
              ? _loader('노트와 웹을 동시 검색 중...')
              : state.qaAnswer == null
              ? _emptyState(
                  Icons.forum_rounded,
                  '궁금한 점을 자유롭게 물어보세요.\n이전 기록과 실시간 웹을 동시 검색합니다.',
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 100),
                  child: MarkdownBody(
                    data: state.qaAnswer!,
                    styleSheet: _mdStyle(),
                  ),
                ),
        ),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: const BoxDecoration(
            color: _kBgSecondary,
            border: Border(top: BorderSide(color: _kBorderColor)),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _qaController,
                  style: const TextStyle(color: _kTextColor, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: '무엇이든 물어보세요...',
                    hintStyle: const TextStyle(color: _kTextHint),
                    filled: true,
                    fillColor: _kCardColor,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 14,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30),
                      borderSide: BorderSide(color: _kBorderColor),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30),
                      borderSide: BorderSide(color: _kBorderColor),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30),
                      borderSide: const BorderSide(color: _kAccentColor),
                    ),
                  ),
                  onSubmitted: (val) {
                    ref
                        .read(fileEditorProvider.notifier)
                        .askAI(val, widget.projectId);
                    _qaController.clear();
                  },
                ),
              ),
              const SizedBox(width: 10),
              InkWell(
                onTap: () {
                  ref
                      .read(fileEditorProvider.notifier)
                      .askAI(_qaController.text, widget.projectId);
                  _qaController.clear();
                },
                borderRadius: BorderRadius.circular(30),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _kAccentColor,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: _kAccentColor.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.arrow_upward_rounded,
                    color: Colors.black,
                    size: 18,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────
  // 대시보드 뷰 (Dashboard)
  // ─────────────────────────────────────────────
  Widget _buildDashboardView(FileEditorState state) {
    if (state.aiGraphData == null && !state.isGraphLoading) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(fileEditorProvider.notifier).requestAIGraph();
      });
    }

    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Document Analytics',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.refresh_rounded, color: _kTextSecondary),
                onPressed: () =>
                    ref.read(fileEditorProvider.notifier).requestAIGraph(),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              _statCard(
                Icons.article_rounded,
                '총 블록',
                '${state.blocks.length}개',
              ),
              const SizedBox(width: 12),
              _statCard(
                Icons.text_fields_rounded,
                '글자 수',
                '${state.charCount}자',
              ),
              const SizedBox(width: 12),
              _statCard(
                Icons.auto_awesome_rounded,
                '확정 요약',
                '${state.summaryBlocks.where((b) => b.isSaved).length}개',
                color: _kAccentColor,
              ),
              const SizedBox(width: 12),
              _statCard(
                Icons.timer_rounded,
                '예상 읽기',
                '${(state.wordCount / 200).ceil()}분',
              ),
            ],
          ),
          const SizedBox(height: 24),
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: _kCardColor,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _kBorderColor),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Stack(
                  children: [
                    if (state.isGraphLoading)
                      const Center(
                        child: CircularProgressIndicator(color: _kAccentColor),
                      )
                    else if (state.aiGraphData != null)
                      KnowledgeGraphWidget(aiGraphData: state.aiGraphData!),

                    Positioned(
                      top: 24,
                      left: 24,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Row(
                            children: [
                              Icon(
                                Icons.hub_rounded,
                                color: _kAccentColor,
                                size: 18,
                              ),
                              SizedBox(width: 6),
                              Text(
                                'AI Semantic Graph',
                                style: TextStyle(
                                  color: _kAccentColor,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 6),
                          Text(
                            'Gemma3 모델이 핵심 키워드와 관계를 도출합니다.',
                            style: TextStyle(
                              color: _kTextSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── 유틸 위젯들 ─────────────────────────────

  Widget _buildPropertyRow(
    IconData icon,
    String label,
    TextEditingController ctrl,
    String hint,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Icon(icon, size: 16, color: _kTextHint),
          const SizedBox(width: 10),
          SizedBox(
            width: 70,
            child: Text(
              label,
              style: const TextStyle(
                color: _kTextHint,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: TextField(
              controller: ctrl,
              style: const TextStyle(
                color: _kTextColor,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
              decoration: InputDecoration(
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  vertical: 6,
                  horizontal: 10,
                ),
                hintText: hint,
                hintStyle: TextStyle(color: _kTextHint.withOpacity(0.5)),
                filled: true,
                fillColor: Colors.transparent,
                hoverColor: _kCardColor,
              ),
              onChanged: (_) => _onContentChanged(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statCard(
    IconData icon,
    String title,
    String value, {
    Color color = Colors.white,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: _kCardColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _kBorderColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: _kTextHint, size: 22),
            const SizedBox(height: 14),
            Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: const TextStyle(
                color: _kTextSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyState(IconData icon, String text) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: const BoxDecoration(
              color: _kCardColor,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 28, color: _kTextHint),
          ),
          const SizedBox(height: 20),
          Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: _kTextSecondary,
              height: 1.6,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _loader(String text) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(
              color: _kAccentColor,
              strokeWidth: 2.5,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            text,
            style: const TextStyle(
              color: _kTextSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _bottomFade() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      height: 80,
      child: IgnorePointer(
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: [_kBgSecondary, _kBgSecondary.withOpacity(0)],
            ),
          ),
        ),
      ),
    );
  }

  Widget _floatingActionButton({
    required String label,
    required IconData icon,
    required VoidCallback onPressed,
    bool isLoading = false,
  }) {
    return Positioned(
      bottom: 24,
      left: 0,
      right: 0,
      child: Center(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: _kCardColor.withOpacity(0.95),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: _kBorderColor),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.5),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(30),
              onTap: isLoading ? null : onPressed,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 22,
                  vertical: 12,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isLoading)
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: _kAccentColor,
                        ),
                      )
                    else
                      Icon(icon, color: _kAccentColor, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      isLoading ? '생성 중...' : label,
                      style: const TextStyle(
                        color: _kTextColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  MarkdownStyleSheet _mdStyle() {
    return MarkdownStyleSheet(
      p: const TextStyle(
        color: _kTextColor,
        fontSize: 14,
        height: 1.7,
        letterSpacing: 0.2,
      ),
      strong: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
      code: const TextStyle(
        backgroundColor: _kCardColor,
        fontFamily: 'monospace',
        color: _kAccentColor,
        fontSize: 13,
      ),
      codeblockDecoration: BoxDecoration(
        color: _kCardColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _kBorderColor),
      ),
      tableBorder: TableBorder(
        horizontalInside: const BorderSide(color: _kBorderColor, width: 1),
        bottom: const BorderSide(color: _kBorderColor, width: 1),
      ),
      tableHead: const TextStyle(
        fontWeight: FontWeight.w700,
        color: _kTextSecondary,
        fontSize: 13,
      ),
      tableBody: const TextStyle(color: _kTextColor, fontSize: 13),
      tableCellsPadding: const EdgeInsets.symmetric(
        vertical: 12,
        horizontal: 14,
      ),
      listBullet: const TextStyle(color: _kTextSecondary, fontSize: 15),
      h1: const TextStyle(
        fontSize: 20,
        color: Colors.white,
        fontWeight: FontWeight.w800,
        height: 1.5,
      ),
      h2: const TextStyle(
        fontSize: 17,
        color: Colors.white,
        fontWeight: FontWeight.w700,
        height: 1.5,
      ),
      h3: const TextStyle(
        fontSize: 15,
        color: Colors.white,
        fontWeight: FontWeight.w700,
        height: 1.5,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
// HoverBlockItem (블록 단위 위젯)
// ─────────────────────────────────────────────────────────
class HoverBlockItem extends StatefulWidget {
  final int index;
  final Block block;
  final bool isLastBlock;
  final BlockType? prevBlockType;
  final KeyEventResult Function(FocusNode, KeyEvent, int) onKey;
  final Function(String, int) onChanged;
  final VoidCallback onDelete;
  final VoidCallback onDuplicate;
  final Function(bool) onToggleCheckbox;
  final Function(BlockType) onTypeChange;
  final VoidCallback onFocus;

  const HoverBlockItem({
    Key? key,
    required this.index,
    required this.block,
    required this.isLastBlock,
    this.prevBlockType,
    required this.onKey,
    required this.onChanged,
    required this.onDelete,
    required this.onDuplicate,
    required this.onToggleCheckbox,
    required this.onTypeChange,
    required this.onFocus,
  }) : super(key: key);

  @override
  State<HoverBlockItem> createState() => _HoverBlockItemState();
}

class _HoverBlockItemState extends State<HoverBlockItem> {
  bool _isHovering = false;
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    widget.block.focusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    widget.block.focusNode.removeListener(_onFocusChange);
    super.dispose();
  }

  void _onFocusChange() {
    if (mounted) {
      setState(() => _isFocused = widget.block.focusNode.hasFocus);
      if (_isFocused) widget.onFocus();
    }
  }

  TextStyle _getStyle(BlockType type) {
    switch (type) {
      case BlockType.h1:
        return const TextStyle(
          fontSize: 36,
          fontWeight: FontWeight.w800,
          color: Colors.white,
          height: 1.4,
          letterSpacing: -0.5,
        );
      case BlockType.h2:
        return const TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w700,
          color: Colors.white,
          height: 1.4,
          letterSpacing: -0.3,
        );
      case BlockType.h3:
        return const TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w600,
          color: Colors.white,
          height: 1.4,
        );
      case BlockType.code:
        return const TextStyle(
          fontSize: 15,
          fontFamily: 'monospace',
          color: _kTextColor,
          backgroundColor: _kCardColor,
          height: 1.6,
        );
      case BlockType.bullet:
        return const TextStyle(fontSize: 16, color: _kTextColor, height: 1.7);
      default:
        return const TextStyle(
          fontSize: 16,
          color: _kTextColor,
          height: 1.7,
          letterSpacing: 0.2,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    widget.block.focusNode.onKeyEvent = (node, event) =>
        widget.onKey(node, event, widget.index);

    final isBullet = widget.block.type == BlockType.bullet;
    final isPrevBullet = widget.prevBlockType == BlockType.bullet;
    final topPad = (isBullet && isPrevBullet) ? 0.0 : (isBullet ? 4.0 : 6.0);
    final bottomPad = isBullet ? 0.0 : 6.0;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: EdgeInsets.only(
          top: topPad,
          bottom: bottomPad,
          left: 12,
          right: 12,
        ),
        margin: const EdgeInsets.only(bottom: 1),
        decoration: BoxDecoration(
          color: _isFocused
              ? _kCardColor.withOpacity(0.35)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 드래그 핸들 + 메뉴
            SizedBox(
              width: 28,
              height: 28,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 150),
                opacity: _isHovering ? 1.0 : 0.0,
                child: ReorderableDragStartListener(
                  index: widget.index,
                  child: PopupMenuButton<String>(
                    padding: EdgeInsets.zero,
                    color: _kCardColor,
                    offset: const Offset(0, 28),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: const BorderSide(color: _kBorderColor, width: 1),
                    ),
                    onSelected: (val) {
                      if (val == 'del')
                        widget.onDelete();
                      else if (val == 'dup')
                        widget.onDuplicate();
                      else if (val == 'h1')
                        widget.onTypeChange(BlockType.h1);
                      else if (val == 'h2')
                        widget.onTypeChange(BlockType.h2);
                      else if (val == 'text')
                        widget.onTypeChange(BlockType.text);
                      else if (val == 'bullet')
                        widget.onTypeChange(BlockType.bullet);
                    },
                    itemBuilder: (_) => [
                      _mi('del', Icons.delete_outline, '삭제'),
                      _mi('dup', Icons.content_copy, '복제'),
                      const PopupMenuDivider(height: 8),
                      _mi('h1', Icons.looks_one_rounded, '제목 1'),
                      _mi('h2', Icons.looks_two_rounded, '제목 2'),
                      _mi('text', Icons.short_text_rounded, '텍스트'),
                      _mi('bullet', Icons.format_list_bulleted_rounded, '글머리'),
                    ],
                    child: const Icon(
                      Icons.drag_indicator_rounded,
                      size: 18,
                      color: _kTextHint,
                    ),
                  ),
                ),
              ),
            ),

            // bullet 점
            if (widget.block.type == BlockType.bullet)
              const Padding(
                padding: EdgeInsets.only(top: 11, right: 14),
                child: Icon(Icons.circle, size: 5, color: _kTextColor),
              ),

            // checkbox
            if (widget.block.type == BlockType.checkbox)
              Padding(
                padding: const EdgeInsets.only(top: 5, right: 14),
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: Checkbox(
                    value: widget.block.isChecked,
                    onChanged: (val) => widget.onToggleCheckbox(val!),
                    activeColor: _kAccentColor,
                    checkColor: Colors.black,
                    side: const BorderSide(color: _kTextHint, width: 1.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ),

            // 텍스트 입력
            Expanded(
              child: CompositedTransformTarget(
                link: widget.block.layerLink,
                child: TextField(
                  controller: widget.block.controller,
                  focusNode: widget.block.focusNode,
                  maxLines: null,
                  style: _getStyle(widget.block.type).copyWith(
                    decoration:
                        (widget.block.type == BlockType.checkbox &&
                            widget.block.isChecked)
                        ? TextDecoration.lineThrough
                        : TextDecoration.none,
                    color:
                        (widget.block.type == BlockType.checkbox &&
                            widget.block.isChecked)
                        ? _kTextHint
                        : null,
                  ),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                    filled: false,
                    hintText:
                        (_isFocused && widget.block.controller.text.isEmpty)
                        ? "'/' 명령어로 블록 추가"
                        : '',
                    hintStyle: TextStyle(
                      color: _kTextHint.withOpacity(0.5),
                      fontSize: 16,
                    ),
                  ),
                  onChanged: (text) => widget.onChanged(text, widget.index),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  PopupMenuItem<String> _mi(String val, IconData icon, String txt) {
    return PopupMenuItem(
      value: val,
      height: 34,
      child: Row(
        children: [
          Icon(icon, size: 16, color: _kTextSecondary),
          const SizedBox(width: 10),
          Text(
            txt,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
// KnowledgeGraphWidget (AI 지식 그래프)
// ─────────────────────────────────────────────────────────
class KnowledgeGraphWidget extends StatefulWidget {
  final Map<String, dynamic> aiGraphData;
  const KnowledgeGraphWidget({Key? key, required this.aiGraphData})
    : super(key: key);

  @override
  State<KnowledgeGraphWidget> createState() => _KnowledgeGraphWidgetState();
}

class _KnowledgeGraphWidgetState extends State<KnowledgeGraphWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  List<GraphNode> _nodes = [];
  List<GraphEdge> _edges = [];
  double _time = 0;

  @override
  void initState() {
    super.initState();
    _controller =
        AnimationController(vsync: this, duration: const Duration(days: 365))
          ..addListener(() {
            setState(() {
              _time += 0.01;
              _updatePhysics();
            });
          })
          ..forward();
    WidgetsBinding.instance.addPostFrameCallback((_) => _buildGraph());
  }

  @override
  void didUpdateWidget(covariant KnowledgeGraphWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.aiGraphData != widget.aiGraphData) _buildGraph();
  }

  void _buildGraph() {
    final size = context.size ?? const Size(800, 600);
    final center = Offset(size.width / 2, size.height / 2);
    _nodes.clear();
    _edges.clear();

    final rawNodes = widget.aiGraphData['nodes'] as List? ?? [];
    final rawEdges = widget.aiGraphData['edges'] as List? ?? [];
    if (rawNodes.isEmpty) return;

    for (int i = 0; i < rawNodes.length; i++) {
      final isCore = i == 0;
      _nodes.add(
        GraphNode(
          id: rawNodes[i]['id'].toString(),
          label: rawNodes[i]['label'].toString(),
          radius: isCore ? 16.0 : 8.0,
          color: isCore ? const Color(0xFFCCFF66) : const Color(0xFF60A5FA),
          baseRadius: isCore ? 0 : 80 + (math.Random().nextDouble() * 150),
          baseAngle: (2 * math.pi / (rawNodes.length - 1)) * i,
          x: center.dx,
          y: center.dy,
          isCore: isCore,
        ),
      );
    }
    for (var e in rawEdges) {
      _edges.add(GraphEdge(e['source'].toString(), e['target'].toString()));
    }
  }

  void _updatePhysics() {
    final size = context.size ?? const Size(800, 600);
    final center = Offset(size.width / 2, size.height / 2);
    for (var node in _nodes) {
      if (node.isCore) {
        node.x = center.dx;
        node.y = center.dy;
        continue;
      }
      final tx =
          center.dx + math.cos(node.baseAngle + _time * 0.5) * node.baseRadius;
      final ty =
          center.dy +
          math.sin(node.baseAngle + _time * 0.5) * node.baseRadius +
          math.sin(_time * 2 + node.baseAngle) * 20;
      node.x += (tx - node.x) * 0.05;
      node.y += (ty - node.y) * 0.05;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _GraphPainter(nodes: _nodes, edges: _edges),
      size: Size.infinite,
    );
  }
}

class GraphNode {
  String id;
  String? label;
  double radius;
  Color color;
  double x, y, baseRadius, baseAngle;
  bool isCore;
  GraphNode({
    required this.id,
    this.label,
    required this.radius,
    required this.color,
    required this.baseRadius,
    required this.baseAngle,
    required this.x,
    required this.y,
    this.isCore = false,
  });
}

class GraphEdge {
  String sourceId, targetId;
  GraphEdge(this.sourceId, this.targetId);
}

class _GraphPainter extends CustomPainter {
  final List<GraphNode> nodes;
  final List<GraphEdge> edges;
  _GraphPainter({required this.nodes, required this.edges});

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke
      ..color = const Color(0xFF27272A);
    final hlPaint = Paint()
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke
      ..color = const Color(0xFFCCFF66).withOpacity(0.3);

    for (var e in edges) {
      final src = nodes.where((n) => n.id == e.sourceId).firstOrNull;
      final tgt = nodes.where((n) => n.id == e.targetId).firstOrNull;
      if (src != null && tgt != null) {
        canvas.drawLine(
          Offset(src.x, src.y),
          Offset(tgt.x, tgt.y),
          src.isCore ? hlPaint : linePaint,
        );
      }
    }

    for (var n in nodes) {
      canvas.drawCircle(
        Offset(n.x, n.y),
        n.radius,
        Paint()
          ..color = n.color
          ..style = PaintingStyle.fill
          ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 4),
      );

      if (n.label != null) {
        final lbl = n.label!.length > 10
            ? '${n.label!.substring(0, 10)}...'
            : n.label!;
        final tp = TextPainter(
          text: TextSpan(
            text: lbl,
            style: TextStyle(
              color: n.isCore ? Colors.white : const Color(0xFFA1A1AA),
              fontSize: n.isCore ? 13 : 11,
              fontWeight: n.isCore ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(n.x - tp.width / 2, n.y + n.radius + 5));
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter _) => true;
}
