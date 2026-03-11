import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import '../../core/db_helper/files_db_helper.dart';
import '../../models/block_model.dart';
import 'file_provider.dart';

// 💎 프리미엄 다크 테마 팔레트 (Linear & Vercel 스타일)
const Color _kBgPrimary = Color(0xFF0E0E11);
const Color _kBgSecondary = Color(0xFF161618);
const Color _kCardColor = Color(0xFF1C1C1F);
const Color _kHoverColor = Color(0xFF27272A);
const Color _kTextColor = Color(0xFFF4F4F5);
const Color _kTextSecondary = Color(0xFFA1A1AA);
const Color _kTextHint = Color(0xFF52525B);
const Color _kBorderColor = Color(0xFF27272A);
const Color _kAccentColor = Color(0xFFCCFF66);
const Color _kAccentMuted = Color(0xFF2A331E);

const Color _kCorrectColor = Color(0xFF34D399);
const Color _kWrongColor = Color(0xFFF87171);

// -----------------------------------------------------------------------------
// [WIDGET] Resizable Split View
// -----------------------------------------------------------------------------
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
        final leftWidth = width * _ratio;
        return Row(
          children: [
            SizedBox(width: leftWidth, child: widget.left),
            MouseRegion(
              cursor: SystemMouseCursors.resizeColumn,
              onEnter: (_) => setState(() => _isDragging = true),
              onExit: (_) => setState(() => _isDragging = false),
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onPanUpdate: (details) => setState(() {
                  _ratio += details.delta.dx / width;
                  if (_ratio < 0.3) _ratio = 0.3;
                  if (_ratio > 0.7) _ratio = 0.7;
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

class FileScreen extends ConsumerStatefulWidget {
  final String fileId;
  final String projectId;
  const FileScreen({Key? key, required this.fileId, this.projectId = "default"})
    : super(key: key);
  @override
  ConsumerState<FileScreen> createState() => _FileScreenState();
}

class _FileScreenState extends ConsumerState<FileScreen>
    with TickerProviderStateMixin {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _tagsController = TextEditingController();
  final TextEditingController _aiPromptController = TextEditingController();
  final TextEditingController _qaController = TextEditingController();
  late TabController _tabController;

  Timer? _saveDebounceTimer;
  Timer? _focusDebounceTimer;
  Timer? _autoSummaryTimer;

  int _lastSummarizedLength = 0;

  void _triggerAutoSummary() {
    final currentFullContent = ref
        .read(fileEditorProvider)
        .blocks
        .map((b) => b.controller.text)
        .join("\n");

    if ((currentFullContent.length - _lastSummarizedLength).abs() >= 50) {
      if (_autoSummaryTimer?.isActive ?? false) _autoSummaryTimer!.cancel();

      if (_tabController.index == 0 &&
          !ref.read(fileEditorProvider).isSummaryLoading) {
        _lastSummarizedLength = currentFullContent.length;

        ref
            .read(fileEditorProvider.notifier)
            .requestAutoAISummary(
              title: _titleController.text,
              tags: _tagsController.text,
            );
      }
    }
  }

  OverlayEntry? _overlayEntry;
  int _activeBlockIndex = -1;
  int _menuSelectedIndex = 0;
  List<Map<String, dynamic>> _currentFilteredOptions = [];
  int _viewMode = 0;
  String _lastFocusedText = "";
  bool _isSaving = false;

  String _lastFullContent = "";

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
    WidgetsBinding.instance.addPostFrameCallback((_) => _initializeScreen());
  }

  Future<void> _initializeScreen() async {
    await ref.read(fileEditorProvider.notifier).loadFileDetail(widget.fileId);
    try {
      final fileModel = await FilesDBHelper.getFile(widget.fileId);
      if (fileModel != null && mounted) {
        setState(() {
          _titleController.text = fileModel.title;
          _tagsController.text = fileModel.tags;
          _aiPromptController.text = fileModel.prompt ?? "";
        });
      }
    } catch (e) {}
  }

  @override
  void dispose() {
    _saveDebounceTimer?.cancel();
    _focusDebounceTimer?.cancel();
    _autoSummaryTimer?.cancel();
    _titleController.dispose();
    _tagsController.dispose();
    _aiPromptController.dispose();
    _qaController.dispose();
    _tabController.dispose();
    _removeOverlay();
    super.dispose();
  }

  void _onContentChanged({String? activeBlockText}) {
    if (activeBlockText != null) {
      _lastFocusedText = activeBlockText;
      ref.read(fileEditorProvider.notifier).state = ref
          .read(fileEditorProvider)
          .copyWith(focusedText: activeBlockText);
    }
    setState(() => _isSaving = true);

    if (_saveDebounceTimer?.isActive ?? false) _saveDebounceTimer!.cancel();
    _saveDebounceTimer = Timer(const Duration(milliseconds: 600), () async {
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

    final currentFullContent = ref
        .read(fileEditorProvider)
        .blocks
        .map((b) => b.controller.text)
        .join("\n");

    if ((currentFullContent.length - _lastSummarizedLength).abs() >= 50) {
      if (_autoSummaryTimer?.isActive ?? false) _autoSummaryTimer!.cancel();
      _autoSummaryTimer = Timer(const Duration(seconds: 5), () {
        _triggerAutoSummary();
      });
    }
  }

  void _onBlockFocus(String text) {
    _triggerAutoSummary();

    if (_focusDebounceTimer?.isActive ?? false) _focusDebounceTimer!.cancel();
    _focusDebounceTimer = Timer(const Duration(milliseconds: 1000), () {
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

  void _handleTextChanged(String text, int index) {
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
      _triggerAutoSummary();
      return;
    }

    if (text.endsWith(' ')) {
      BlockType? newType;
      String newText = text;
      if (text == '/h1 ' || text == '# ') {
        newType = BlockType.h1;
        newText = '';
      } else if (text == '/h2 ' || text == '## ') {
        newType = BlockType.h2;
        newText = '';
      } else if (text == '/h3 ' || text == '### ') {
        newType = BlockType.h3;
        newText = '';
      } else if (text == '- ' || text == '* ') {
        newType = BlockType.bullet;
        newText = '';
      } else if (text == '[] ' || text == '/todo ') {
        newType = BlockType.checkbox;
        newText = '';
      } else if (text == '/table ') {
        newType = BlockType.code;
        newText = "| 헤더 1 | 헤더 2 |\n|---|---|\n| 내용 1 | 내용 2 |";
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

    int slashIndex = text.lastIndexOf('/');
    if (slashIndex != -1 && slashIndex == text.length - 1) {
      _showOverlay(context, index, "");
    } else if (slashIndex != -1 &&
        !text.substring(slashIndex + 1).contains(' ')) {
      _showOverlay(context, index, text.substring(slashIndex + 1));
    } else {
      _removeOverlay();
    }
    _onContentChanged(activeBlockText: text);
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event, int index) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (HardwareKeyboard.instance.isMetaPressed ||
        HardwareKeyboard.instance.isControlPressed)
      return KeyEventResult.ignored;

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
      return KeyEventResult.ignored;
    }

    final blocks = ref.read(fileEditorProvider).blocks;
    final ctrl = blocks[index].controller;

    if (event.logicalKey == LogicalKeyboardKey.backspace &&
        ctrl.selection.baseOffset == 0 &&
        index > 0) {
      final prevBlock = blocks[index - 1];
      final currentText = ctrl.text;
      final prevTextLength = prevBlock.controller.text.length;
      prevBlock.controller.text += currentText;
      ref.read(fileEditorProvider.notifier).removeBlock(index);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        prevBlock.focusNode.requestFocus();
        prevBlock.controller.selection = TextSelection.collapsed(
          offset: prevTextLength,
        );
      });
      return KeyEventResult.handled;
    }

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

  void _applyMenuOption(int index, Map<String, dynamic> option) {
    _removeOverlay();
    final ctrl = ref.read(fileEditorProvider).blocks[index].controller;
    String currentText = ctrl.text;
    int slashIndex = currentText.lastIndexOf('/');
    if (slashIndex != -1) ctrl.text = currentText.substring(0, slashIndex);

    if (option['type'] == 'table') {
      ctrl.text += "| 열 1 | 열 2 |\n|---|---|\n| 내용 | 내용 |";
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

  void _moveFocus(int index) {
    final blocks = ref.read(fileEditorProvider).blocks;
    if (index < blocks.length) {
      blocks[index].focusNode.requestFocus();
      final ctrl = blocks[index].controller;
      ctrl.selection = TextSelection.collapsed(offset: ctrl.text.length);
    }
  }

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
      builder: (context) => Positioned(
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
                border: Border.all(color: _kBorderColor, width: 1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _currentFilteredOptions.length,
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                itemBuilder: (context, i) => Container(
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
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
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
        content: Text("복사되었습니다."),
        duration: Duration(seconds: 1),
        backgroundColor: _kCardColor,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fileState = ref.watch(fileEditorProvider);
    final blocks = fileState.blocks;

    // 🖋️ 좌측 메인 에디터
    Widget editorView = CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 80),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 80),
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
                Column(
                  children: [
                    _buildPropertyRow(
                      Icons.tag_rounded,
                      "Tags",
                      _tagsController,
                      "비어 있음",
                    ),
                    _buildPropertyRow(
                      Icons.auto_awesome_rounded,
                      "Prompt",
                      _aiPromptController,
                      "AI 분석 지시사항...",
                    ),
                  ],
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
            onReorder: (oldIndex, newIndex) => ref
                .read(fileEditorProvider.notifier)
                .reorderBlock(oldIndex, newIndex),
            itemBuilder: (context, index) {
              final block = blocks[index];
              final prevBlockType = index > 0 ? blocks[index - 1].type : null;
              return HoverBlockItem(
                key: ValueKey(block.id),
                index: index,
                block: block,
                isLastBlock: index == blocks.length - 1,
                prevBlockType: prevBlockType,
                onKey: _handleKeyEvent,
                onChanged: (text, idx) => _handleTextChanged(text, idx),
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
                  _lastFocusedText = block.controller.text;
                  _onContentChanged(activeBlockText: block.controller.text);
                  _onBlockFocus(block.controller.text);
                },
              );
            },
          ),
        ),
      ],
    );

    // 🌟 우측 모던 AI 스튜디오 패널
    Widget rightPanel = Container(
      decoration: const BoxDecoration(
        color: _kBgSecondary,
        border: Border(left: BorderSide(color: _kBorderColor, width: 1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
                unselectedLabelStyle: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
                labelPadding: const EdgeInsets.symmetric(horizontal: 16),
                tabs: const [
                  Tab(
                    child: Row(
                      children: [
                        Icon(Icons.subject_rounded, size: 16),
                        SizedBox(width: 6),
                        Text("요약"),
                      ],
                    ),
                  ),
                  Tab(
                    child: Row(
                      children: [
                        Icon(Icons.manage_search_rounded, size: 16),
                        SizedBox(width: 6),
                        Text("분석"),
                      ],
                    ),
                  ),
                  Tab(
                    child: Row(
                      children: [
                        Icon(Icons.lightbulb_outline_rounded, size: 16),
                        SizedBox(width: 6),
                        Text("암기"),
                      ],
                    ),
                  ),
                  Tab(
                    child: Row(
                      children: [
                        Icon(Icons.rule_rounded, size: 16),
                        SizedBox(width: 6),
                        Text("퀴즈"),
                      ],
                    ),
                  ),
                  Tab(
                    child: Row(
                      children: [
                        Icon(Icons.forum_outlined, size: 16),
                        SizedBox(width: 6),
                        Text("Ask"),
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

    return Scaffold(
      backgroundColor: _kBgPrimary,
      appBar: AppBar(
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
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: _kTextSecondary,
                      ),
                    ),
                    SizedBox(width: 8),
                    Text(
                      "저장 중...",
                      style: TextStyle(
                        color: _kTextSecondary,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                )
              : fileState.lastSavedAt != null
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(
                      Icons.cloud_done_rounded,
                      size: 16,
                      color: _kTextSecondary,
                    ),
                    SizedBox(width: 6),
                    Text(
                      "저장됨",
                      style: TextStyle(
                        color: _kTextSecondary,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                )
              : const SizedBox.shrink(),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.copy_rounded, size: 18),
            onPressed: _copyAllContent,
            color: _kTextSecondary,
            tooltip: '복사',
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
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: _viewMode == 0
          ? ResizableSplitView(left: editorView, right: rightPanel)
          : _buildDashboardView(fileState),
    );
  }

  Widget _buildStudioFloatingButton({
    required String label,
    required IconData icon,
    required VoidCallback onPressed,
    bool isLoading = false,
  }) {
    return Positioned(
      bottom: 32,
      left: 0,
      right: 0,
      child: Center(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: _kCardColor.withOpacity(0.9),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: _kBorderColor, width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.5),
                blurRadius: 16,
                offset: const Offset(0, 8),
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
                  horizontal: 24,
                  vertical: 14,
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
                      Icon(icon, color: _kAccentColor, size: 18),
                    const SizedBox(width: 10),
                    Text(
                      isLoading ? "생성 중..." : label,
                      style: const TextStyle(
                        color: _kTextColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
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

  Widget _buildSummaryTab(FileEditorState state) {
    return Stack(
      children: [
        if (state.summaryBlocks.isEmpty && !state.isSummaryLoading)
          _buildEmptyStudioState(
            Icons.auto_awesome_rounded,
            "AI가 문서를 분석하여\n구조화된 요약 노트를 생성합니다.",
          ),

        ListView.builder(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 120),
          itemCount: state.summaryBlocks.length,
          itemBuilder: (context, index) {
            final block = state.summaryBlocks[index];
            final bool isSaved = block.isSaved;

            return AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(
                color: isSaved ? _kBgSecondary : _kCardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isSaved
                      ? _kAccentColor.withOpacity(0.5)
                      : _kBorderColor,
                  width: isSaved ? 1.5 : 1,
                ),
                boxShadow: isSaved
                    ? [
                        BoxShadow(
                          color: _kAccentColor.withOpacity(0.05),
                          blurRadius: 10,
                        ),
                      ]
                    : [],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: isSaved
                          ? _kAccentColor.withOpacity(0.1)
                          : Colors.transparent,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(15),
                      ),
                      border: const Border(
                        bottom: BorderSide(color: _kBorderColor, width: 0.5),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              isSaved
                                  ? Icons.check_circle_rounded
                                  : Icons.radio_button_unchecked_rounded,
                              size: 16,
                              color: isSaved ? _kAccentColor : _kTextSecondary,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              isSaved ? "확정된 요약 (유지됨)" : "최신 분석 결과 (임시)",
                              style: TextStyle(
                                color: isSaved
                                    ? _kAccentColor
                                    : _kTextSecondary,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(20),
                            onTap: () => ref
                                .read(fileEditorProvider.notifier)
                                .toggleSummarySave(index),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    isSaved
                                        ? Icons.lock_rounded
                                        : Icons.push_pin_outlined,
                                    size: 14,
                                    color: isSaved ? _kAccentColor : _kTextHint,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    isSaved ? "잠금 해제" : "확정하기",
                                    style: TextStyle(
                                      color: isSaved
                                          ? _kAccentColor
                                          : _kTextHint,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
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
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: MarkdownBody(
                      data: block.content,
                      styleSheet: _getMarkdownStyle(),
                    ),
                  ),
                ],
              ),
            );
          },
        ),

        _buildBottomGradientFade(),

        _buildStudioFloatingButton(
          label: state.summaryBlocks.any((b) => b.isSaved)
              ? "변경된 내용만 업데이트"
              : "요약 생성",
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

  Widget _buildAnalysisTab(FileEditorState state) {
    return Column(
      children: [
        AnimatedSize(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          child: state.focusedText.trim().isNotEmpty
              ? Container(
                  width: double.infinity,
                  margin: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: _kCardColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: _kBorderColor),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: const [
                          Icon(
                            Icons.my_location_rounded,
                            size: 14,
                            color: _kAccentColor,
                          ),
                          SizedBox(width: 6),
                          Text(
                            "현재 포커스",
                            style: TextStyle(
                              fontSize: 12,
                              color: _kAccentColor,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        state.focusedText,
                        style: const TextStyle(
                          color: _kTextSecondary,
                          fontSize: 14,
                          height: 1.6,
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
                ? _buildStudioLoader("문맥의 핵심을 파악 중...")
                : state.currentBlockAnalysis == null ||
                      state.focusedText.trim().isEmpty
                ? _buildEmptyStudioState(
                    Icons.manage_search_rounded,
                    "에디터에서 문단을 클릭하면\nAI가 실시간으로 분석합니다.",
                  )
                : SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(32, 32, 32, 100),
                    physics: const BouncingScrollPhysics(),
                    child: MarkdownBody(
                      data: state.currentBlockAnalysis!,
                      styleSheet: _getMarkdownStyle(),
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildMemoTab(FileEditorState state) {
    return Stack(
      children: [
        if (state.currentMemo == null && !state.isStudioLoading)
          _buildEmptyStudioState(
            Icons.psychology_rounded,
            "본문에서 가장 중요한\n핵심 개념만 스마트하게 추출합니다.",
          ),
        if (state.currentMemo != null)
          SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(32, 24, 32, 120),
            child: MarkdownBody(
              data: state.currentMemo!,
              styleSheet: _getMarkdownStyle(),
            ),
          ),
        _buildBottomGradientFade(),
        if (state.currentMemo == null || state.isStudioLoading)
          _buildStudioFloatingButton(
            label: "암기 노트 생성",
            icon: Icons.lightbulb_rounded,
            isLoading: state.isStudioLoading,
            onPressed: () => ref
                .read(fileEditorProvider.notifier)
                .generateStudioContent('memo'),
          ),
      ],
    );
  }

  Widget _buildQuizTab(FileEditorState state) {
    return Stack(
      children: [
        if (state.quizData == null && !state.isStudioLoading)
          _buildEmptyStudioState(
            Icons.rule_rounded,
            "학습 내용을 바탕으로\n객관식 퀴즈를 풀어보세요.",
          ),
        if (state.quizData != null)
          ListView.builder(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 120),
            itemCount: state.quizData!.length,
            itemBuilder: (context, qIndex) {
              final q = state.quizData![qIndex];
              final isAnswered = state.quizAnswers.containsKey(qIndex);
              final selectedOpt = state.quizAnswers[qIndex];
              final correctOpt = q['answer'] ?? 0;

              return Container(
                margin: const EdgeInsets.only(bottom: 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Q${qIndex + 1}. ${q['question']}",
                      style: const TextStyle(
                        color: _kTextColor,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 20),
                    ...List.generate((q['options'] as List).length, (optIndex) {
                      Color btnBgColor = _kCardColor,
                          btnBorderColor = _kBorderColor,
                          btnTextColor = _kTextColor;
                      if (isAnswered) {
                        if (optIndex == correctOpt) {
                          btnBgColor = _kCorrectColor.withOpacity(0.1);
                          btnBorderColor = _kCorrectColor.withOpacity(0.5);
                          btnTextColor = _kCorrectColor;
                        } else if (optIndex == selectedOpt) {
                          btnBgColor = _kWrongColor.withOpacity(0.1);
                          btnBorderColor = _kWrongColor.withOpacity(0.5);
                          btnTextColor = _kWrongColor;
                        }
                      }
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: InkWell(
                          onTap: () => ref
                              .read(fileEditorProvider.notifier)
                              .answerQuiz(qIndex, optIndex),
                          borderRadius: BorderRadius.circular(12),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              vertical: 16,
                              horizontal: 20,
                            ),
                            decoration: BoxDecoration(
                              color: btnBgColor,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: btnBorderColor,
                                width: 1,
                              ),
                            ),
                            child: Text(
                              q['options'][optIndex],
                              style: TextStyle(
                                color: btnTextColor,
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                    AnimatedSize(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOutCubic,
                      child: isAnswered
                          ? Container(
                              margin: const EdgeInsets.only(top: 8),
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: _kBgPrimary,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: _kBorderColor,
                                  width: 1,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        selectedOpt == correctOpt
                                            ? Icons.check_circle_rounded
                                            : Icons.cancel_rounded,
                                        size: 18,
                                        color: selectedOpt == correctOpt
                                            ? _kCorrectColor
                                            : _kWrongColor,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        selectedOpt == correctOpt
                                            ? "정답입니다"
                                            : "오답입니다",
                                        style: TextStyle(
                                          color: selectedOpt == correctOpt
                                              ? _kCorrectColor
                                              : _kWrongColor,
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    q['explanation'] ?? '',
                                    style: const TextStyle(
                                      color: _kTextSecondary,
                                      height: 1.6,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : const SizedBox.shrink(),
                    ),
                  ],
                ),
              );
            },
          ),
        _buildBottomGradientFade(),
        if (state.quizData == null || state.isStudioLoading)
          _buildStudioFloatingButton(
            label: "퀴즈 출제하기",
            icon: Icons.quiz_rounded,
            isLoading: state.isStudioLoading,
            onPressed: () => ref
                .read(fileEditorProvider.notifier)
                .generateStudioContent('quiz'),
          ),
      ],
    );
  }

  Widget _buildQATab(FileEditorState state) {
    return Column(
      children: [
        Expanded(
          child: state.isQALoading
              ? _buildStudioLoader("노트와 웹을 스캔하여 답변을 작성 중...")
              : state.qaAnswer == null
              ? _buildEmptyStudioState(
                  Icons.forum_rounded,
                  "궁금한 점을 자유롭게 물어보세요.\n이전 기록과 실시간 웹을 동시 검색합니다.",
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(32, 32, 32, 100),
                  child: MarkdownBody(
                    data: state.qaAnswer!,
                    styleSheet: _getMarkdownStyle(),
                  ),
                ),
        ),
        Container(
          padding: const EdgeInsets.all(16),
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
                    hintText: "무엇이든 물어보세요...",
                    hintStyle: const TextStyle(color: _kTextHint),
                    filled: true,
                    fillColor: _kCardColor,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 16,
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
              const SizedBox(width: 12),
              InkWell(
                onTap: () {
                  ref
                      .read(fileEditorProvider.notifier)
                      .askAI(_qaController.text, widget.projectId);
                  _qaController.clear();
                },
                borderRadius: BorderRadius.circular(30),
                child: Container(
                  padding: const EdgeInsets.all(14),
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
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPropertyRow(
    IconData icon,
    String label,
    TextEditingController ctrl,
    String hint,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: _kTextHint),
          const SizedBox(width: 12),
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: const TextStyle(
                color: _kTextHint,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: TextField(
              controller: ctrl,
              style: const TextStyle(
                color: _kTextColor,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
              decoration: InputDecoration(
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  vertical: 8,
                  horizontal: 12,
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

  Widget _buildBottomGradientFade() {
    return Positioned(
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
              colors: [_kBgSecondary, _kBgSecondary.withOpacity(0.0)],
            ),
          ),
        ),
      ),
    );
  }

  MarkdownStyleSheet _getMarkdownStyle() {
    return MarkdownStyleSheet(
      p: const TextStyle(
        color: _kTextColor,
        fontSize: 15,
        height: 1.7,
        letterSpacing: 0.3,
      ),
      strong: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
      code: const TextStyle(
        backgroundColor: _kCardColor,
        fontFamily: 'monospace',
        color: _kAccentColor,
        fontSize: 14,
      ),
      codeblockDecoration: BoxDecoration(
        color: _kCardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kBorderColor),
      ),
      tableBorder: TableBorder(
        horizontalInside: const BorderSide(color: _kBorderColor, width: 1),
        bottom: const BorderSide(color: _kBorderColor, width: 1),
      ),
      tableHead: const TextStyle(
        fontWeight: FontWeight.w700,
        color: _kTextSecondary,
        fontSize: 14,
      ),
      tableBody: const TextStyle(color: _kTextColor, fontSize: 14),
      tableCellsPadding: const EdgeInsets.symmetric(
        vertical: 14,
        horizontal: 16,
      ),
      blockquoteDecoration: const BoxDecoration(
        border: Border(left: BorderSide(color: _kAccentColor, width: 4)),
        color: _kCardColor,
      ),
      blockquotePadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 12,
      ),
      listBullet: const TextStyle(color: _kTextSecondary, fontSize: 16),
      h1: const TextStyle(
        fontSize: 22,
        color: Colors.white,
        fontWeight: FontWeight.w800,
        height: 1.5,
      ),
      h2: const TextStyle(
        fontSize: 18,
        color: Colors.white,
        fontWeight: FontWeight.w700,
        height: 1.5,
      ),
      h3: const TextStyle(
        fontSize: 16,
        color: Colors.white,
        fontWeight: FontWeight.w700,
        height: 1.5,
      ),
    );
  }

  Widget _buildEmptyStudioState(IconData icon, String text) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: _kCardColor,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 32, color: _kTextHint),
          ),
          const SizedBox(height: 24),
          Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: _kTextSecondary,
              height: 1.6,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStudioLoader(String text) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 32,
            height: 32,
            child: CircularProgressIndicator(
              color: _kAccentColor,
              strokeWidth: 3,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            text,
            style: const TextStyle(
              color: _kTextSecondary,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // -----------------------------------------------------------------------------
  // 🌟 [추가] 프리미엄 AI 대시보드 뷰
  // -----------------------------------------------------------------------------
  Widget _buildDashboardView(FileEditorState state) {
    // 💡 화면이 렌더링될 때 그래프 데이터가 없으면 AI에게 요청
    if (state.aiGraphData == null && !state.isGraphLoading) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(fileEditorProvider.notifier).requestAIGraph();
      });
    }

    int totalChars = state.blocks.fold(
      0,
      (sum, b) => sum + b.controller.text.length,
    );
    int totalWords = state.blocks
        .map((b) => b.controller.text)
        .join(' ')
        .split(RegExp(r'\s+'))
        .length;

    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Document Analytics",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
              // 새로고침 버튼 (AI에게 다시 키워드 뽑으라고 지시)
              IconButton(
                icon: const Icon(Icons.refresh_rounded, color: _kTextSecondary),
                onPressed: () =>
                    ref.read(fileEditorProvider.notifier).requestAIGraph(),
              ),
            ],
          ),
          const SizedBox(height: 24),
          // 📊 상단 통계 카드
          Row(
            children: [
              _buildStatCard(
                Icons.article_rounded,
                "총 블록 수",
                "${state.blocks.length}개",
              ),
              const SizedBox(width: 16),
              _buildStatCard(Icons.text_fields_rounded, "글자 수", "$totalChars자"),
              const SizedBox(width: 16),
              _buildStatCard(
                Icons.auto_awesome_rounded,
                "AI 요약본",
                "${state.summaryBlocks.where((b) => b.isSaved).length}개 확정됨",
                color: _kAccentColor,
              ),
              const SizedBox(width: 16),
              _buildStatCard(
                Icons.timer_rounded,
                "예상 읽기 시간",
                "${(totalWords / 200).ceil()}분",
              ),
            ],
          ),
          const SizedBox(height: 32),
          // 🌌 하단 지식 그래프
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: _kCardColor,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: _kBorderColor),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Stack(
                  children: [
                    // 💡 로딩 중일 때와 로딩 완료되었을 때 분기
                    if (state.isGraphLoading)
                      const Center(
                        child: CircularProgressIndicator(color: _kAccentColor),
                      )
                    else if (state.aiGraphData != null)
                      KnowledgeGraphWidget(
                        aiGraphData: state.aiGraphData!,
                      ), // AI 데이터 전달!

                    Positioned(
                      top: 32,
                      left: 32,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: const [
                              Icon(
                                Icons.hub_rounded,
                                color: _kAccentColor,
                                size: 20,
                              ),
                              SizedBox(width: 8),
                              Text(
                                "AI Semantic Graph",
                                style: TextStyle(
                                  color: _kAccentColor,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            "Gemma3 모델이 문맥을 분석하여 핵심 키워드와 관계를 도출합니다.",
                            style: TextStyle(
                              color: _kTextSecondary,
                              fontSize: 13,
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

  Widget _buildStatCard(
    IconData icon,
    String title,
    String value, {
    Color color = Colors.white,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: _kCardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _kBorderColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: _kTextHint, size: 24),
            const SizedBox(height: 16),
            Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: const TextStyle(
                color: _kTextSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// 🌌 [위젯] AI 기반 지식 그래프 (AI Semantic Graph)
// -----------------------------------------------------------------------------
class KnowledgeGraphWidget extends StatefulWidget {
  final Map<String, dynamic> aiGraphData; // 서버에서 받은 JSON 데이터
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
              _updateNodesPhysics();
            });
          })
          ..forward();
    WidgetsBinding.instance.addPostFrameCallback((_) => _buildAIGraph());
  }

  @override
  void didUpdateWidget(covariant KnowledgeGraphWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.aiGraphData != widget.aiGraphData) _buildAIGraph();
  }

  void _buildAIGraph() {
    final size = context.size ?? const Size(800, 600);
    final center = Offset(size.width / 2, size.height / 2);
    _nodes.clear();
    _edges.clear();

    List<dynamic> rawNodes = widget.aiGraphData['nodes'] ?? [];
    List<dynamic> rawEdges = widget.aiGraphData['edges'] ?? [];

    if (rawNodes.isEmpty) return;

    // 첫 번째 노드를 코어(중앙) 노드로 설정
    for (int i = 0; i < rawNodes.length; i++) {
      String id = rawNodes[i]['id'].toString();
      String label = rawNodes[i]['label'].toString();

      bool isCore = i == 0;
      double radius = isCore ? 16.0 : 8.0;
      Color color = isCore ? const Color(0xFFCCFF66) : const Color(0xFF60A5FA);

      _nodes.add(
        GraphNode(
          id: id,
          label: label,
          radius: radius,
          color: color,
          baseRadius: isCore
              ? 0
              : 80 + (math.Random().nextDouble() * 150), // 코어를 중심으로 궤도 형성
          baseAngle: (2 * math.pi / (rawNodes.length - 1)) * i,
          x: center.dx,
          y: center.dy,
          isCore: isCore,
        ),
      );
    }

    // 엣지 연결
    for (var e in rawEdges) {
      _edges.add(GraphEdge(e['source'].toString(), e['target'].toString()));
    }
  }

  void _updateNodesPhysics() {
    final size = context.size ?? const Size(800, 600);
    final center = Offset(size.width / 2, size.height / 2);

    for (var node in _nodes) {
      if (node.isCore) {
        node.x = center.dx;
        node.y = center.dy;
        continue;
      }
      // 행성처럼 공전하는 애니메이션
      double targetX =
          center.dx +
          math.cos(node.baseAngle + (_time * 0.5)) * node.baseRadius;
      double targetY =
          center.dy +
          math.sin(node.baseAngle + (_time * 0.5)) * node.baseRadius +
          math.sin(_time * 2 + node.baseAngle) * 20;

      node.x += (targetX - node.x) * 0.05;
      node.y += (targetY - node.y) * 0.05;
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
      painter: SemanticGraphPainter(nodes: _nodes, edges: _edges),
      size: Size.infinite,
    );
  }
}

class GraphNode {
  String id;
  String? label;
  double radius;
  Color color;
  double x, y;

  double baseRadius;
  double baseAngle;
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
  String sourceId;
  String targetId;
  GraphEdge(this.sourceId, this.targetId);
}

class SemanticGraphPainter extends CustomPainter {
  final List<GraphNode> nodes;
  final List<GraphEdge> edges;

  SemanticGraphPainter({required this.nodes, required this.edges});

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke
      ..color = const Color(0xFF27272A);
    final highlightLinePaint = Paint()
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke
      ..color = const Color(0xFFCCFF66).withOpacity(0.3);

    for (var edge in edges) {
      final source = nodes.where((n) => n.id == edge.sourceId).firstOrNull;
      final target = nodes.where((n) => n.id == edge.targetId).firstOrNull;
      if (source != null && target != null) {
        canvas.drawLine(
          Offset(source.x, source.y),
          Offset(target.x, target.y),
          source.isCore ? highlightLinePaint : linePaint,
        );
      }
    }

    for (var node in nodes) {
      final nodePaint = Paint()
        ..color = node.color
        ..style = PaintingStyle.fill
        ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 4);
      canvas.drawCircle(Offset(node.x, node.y), node.radius, nodePaint);

      if (node.label != null) {
        String displayLabel = node.label!.length > 10
            ? "${node.label!.substring(0, 10)}..."
            : node.label!;
        final textPainter = TextPainter(
          text: TextSpan(
            text: displayLabel,
            style: TextStyle(
              color: node.isCore ? Colors.white : const Color(0xFFA1A1AA),
              fontSize: node.isCore ? 14 : 11,
              fontWeight: node.isCore ? FontWeight.w800 : FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
          textDirection: TextDirection.ltr,
        );
        textPainter.layout();
        textPainter.paint(
          canvas,
          Offset(node.x - (textPainter.width / 2), node.y + node.radius + 6),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// -----------------------------------------------------------------------------
// [WIDGET] HoverBlockItem
// -----------------------------------------------------------------------------
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

  PopupMenuItem<String> _menuItem(String val, IconData icon, String txt) {
    return PopupMenuItem(
      value: val,
      height: 36,
      child: Row(
        children: [
          Icon(icon, size: 18, color: _kTextSecondary),
          const SizedBox(width: 12),
          Text(
            txt,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    widget.block.focusNode.onKeyEvent = (node, event) =>
        widget.onKey(node, event, widget.index);
    final bool isList = widget.block.type == BlockType.bullet;
    final bool isPrevList = widget.prevBlockType == BlockType.bullet;
    final double topPadding = (isList && isPrevList)
        ? 0.0
        : (isList ? 6.0 : 8.0);
    final double bottomPadding = isList ? 0.0 : 8.0;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.only(
          top: topPadding,
          bottom: bottomPadding,
          left: 16,
          right: 16,
        ),
        margin: const EdgeInsets.only(bottom: 2),
        decoration: BoxDecoration(
          color: _isFocused ? _kCardColor.withOpacity(0.3) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 24,
              height: 24,
              alignment: Alignment.center,
              margin: const EdgeInsets.only(top: 4, right: 12),
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
                      borderRadius: BorderRadius.circular(12),
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
                    },
                    itemBuilder: (ctx) => [
                      _menuItem('del', Icons.delete_outline, '삭제'),
                      _menuItem('dup', Icons.content_copy, '복제'),
                      const PopupMenuDivider(height: 10),
                      _menuItem('h1', Icons.looks_one_rounded, '제목 1'),
                      _menuItem('h2', Icons.looks_two_rounded, '제목 2'),
                      _menuItem('text', Icons.short_text_rounded, '텍스트'),
                    ],
                    child: const Icon(
                      Icons.drag_indicator_rounded,
                      size: 20,
                      color: _kTextHint,
                    ),
                  ),
                ),
              ),
            ),
            if (widget.block.type == BlockType.bullet)
              const Padding(
                padding: EdgeInsets.only(top: 12, right: 16),
                child: Icon(Icons.circle, size: 6, color: _kTextColor),
              ),
            if (widget.block.type == BlockType.checkbox)
              Padding(
                padding: const EdgeInsets.only(top: 6, right: 16),
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
                        : "",
                    hintStyle: TextStyle(
                      color: _kTextHint.withOpacity(0.6),
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
}
