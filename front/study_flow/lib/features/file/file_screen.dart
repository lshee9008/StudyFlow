import 'dart:io';
import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import '../../core/db_helper/files_db_helper.dart';
import '../../models/block_model.dart';
import 'file_provider.dart';

// 🎨 [Notion Style] 색상 팔레트 (누락 없이 완벽 정의)
const Color _kBgPrimary = Color(0xFF191919);
const Color _kBgSecondary = Color(0xFF202020);
const Color _kCardColor = Color(0xFF2D2D2D);
const Color _kTextColor = Color(0xFFE3E3E3);
const Color _kTextHint = Color(0xFF6B6B6B);
const Color _kTextSecondary = Color(0xFF9B9B9B); // 속성 라벨용 색상
const Color _kBorderColor = Color(0xFF2F2F2F);
const Color _kAccentColor = Color(0xFF00BFFF);

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
    this.initialRatio = 0.65,
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
                  if (_ratio > 0.8) _ratio = 0.8;
                }),
                child: Container(
                  width: 6,
                  color: Colors.transparent,
                  alignment: Alignment.center,
                  child: Container(
                    width: 1,
                    height: double.infinity,
                    color: _isDragging ? _kAccentColor : Colors.transparent,
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
  const FileScreen({Key? key, required this.fileId}) : super(key: key);
  @override
  ConsumerState<FileScreen> createState() => _FileScreenState();
}

class _FileScreenState extends ConsumerState<FileScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _tagsController = TextEditingController();
  final TextEditingController _aiPromptController = TextEditingController();
  late TabController _tabController;

  Timer? _debounceTimer;
  OverlayEntry? _overlayEntry;
  int _activeBlockIndex = -1;
  int _menuSelectedIndex = 0;
  List<Map<String, dynamic>> _currentFilteredOptions = [];
  int _viewMode = 0;

  final List<Map<String, dynamic>> _allMenuOptions = [
    {'type': BlockType.h1, 'label': '제목 1', 'icon': Icons.looks_one},
    {'type': BlockType.h2, 'label': '제목 2', 'icon': Icons.looks_two},
    {'type': BlockType.h3, 'label': '제목 3', 'icon': Icons.looks_3},
    {'type': BlockType.text, 'label': '텍스트', 'icon': Icons.short_text},
    {
      'type': BlockType.bullet,
      'label': '글머리 기호',
      'icon': Icons.format_list_bulleted,
    },
    {
      'type': BlockType.checkbox,
      'label': '할 일',
      'icon': Icons.check_box_outlined,
    },
    {'type': BlockType.code, 'label': '코드', 'icon': Icons.code},
    {'type': 'table', 'label': '표 (Table)', 'icon': Icons.table_chart},
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
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
    _debounceTimer?.cancel();
    _titleController.dispose();
    _tagsController.dispose();
    _aiPromptController.dispose();
    _tabController.dispose();
    _removeOverlay();
    super.dispose();
  }

  void _onContentChanged({String? activeBlockText}) {
    if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 800), () async {
      await ref
          .read(fileEditorProvider.notifier)
          .saveFile(
            fileId: widget.fileId,
            title: _titleController.text,
            tags: _tagsController.text,
            prompt: _aiPromptController.text,
            updateAt: DateTime.now(),
          );

      ref
          .read(fileEditorProvider.notifier)
          .requestAutoAISummary(
            title: _titleController.text,
            tags: _tagsController.text,
            prompt: "",
          );

      if (_tabController.index == 1 && activeBlockText != null) {
        ref
            .read(fileEditorProvider.notifier)
            .requestBlockAnalysis(
              text: activeBlockText,
              tags: _tagsController.text,
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
      return;
    }

    if (text.endsWith(' ')) {
      String command = text.trim();
      BlockType? newType;
      String newText = text;

      if (command == '/h1' || command == '#') {
        newType = BlockType.h1;
        newText = '';
      } else if (command == '/h2' || command == '##') {
        newType = BlockType.h2;
        newText = '';
      } else if (command == '- ' || command == '*') {
        newType = BlockType.bullet;
        newText = '';
      } else if (command == '[]') {
        newType = BlockType.checkbox;
        newText = '';
      } else if (command == '/table') {
        newType = BlockType.code;
        newText = "| 제목 | 내용 |\n|---|---|\n| 예시 | 값 |";
      }

      if (newType != null || newText != text) {
        ref.read(fileEditorProvider).blocks[index].controller.text = newText;
        if (newType != null)
          ref.read(fileEditorProvider.notifier).updateBlockType(index, newType);

        WidgetsBinding.instance.addPostFrameCallback((_) {
          final ctrl = ref.read(fileEditorProvider).blocks[index].controller;
          ctrl.selection = TextSelection.collapsed(offset: ctrl.text.length);
        });

        _onContentChanged(activeBlockText: newText);
        return;
      }
    }

    int slashIndex = text.lastIndexOf('/');
    if (slashIndex != -1) {
      String query = text.substring(slashIndex + 1);
      if (!query.contains(' '))
        _showOverlay(context, index, query);
      else
        _removeOverlay();
    } else {
      _removeOverlay();
    }

    _onContentChanged(activeBlockText: text);
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event, int index) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
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
    if (option['type'] == 'table') {
      ref.read(fileEditorProvider).blocks[index].controller.text =
          "| 제목 | 내용 |\n|---|---|\n| 예시 | 값 |";
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
        width: 200,
        child: CompositedTransformFollower(
          link: blocks[index].layerLink,
          showWhenUnlinked: false,
          offset: const Offset(0, 32),
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(8),
            color: _kCardColor,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _currentFilteredOptions.length,
              padding: EdgeInsets.zero,
              itemBuilder: (context, i) => ListTile(
                dense: true,
                selected: i == _menuSelectedIndex,
                selectedTileColor: Colors.white10,
                leading: Icon(
                  _currentFilteredOptions[i]['icon'],
                  size: 16,
                  color: Colors.white70,
                ),
                title: Text(
                  _currentFilteredOptions[i]['label'],
                  style: const TextStyle(color: Colors.white),
                ),
                onTap: () =>
                    _applyMenuOption(index, _currentFilteredOptions[i]),
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

  // 랜덤 아이콘 (Notion 감성)
  void _changeRandomIcon() {
    final icons = ['📄', '📝', '💡', '🚀', '🎨', '📚', '💻', '🔥', '✨', '🎯'];
    final newIcon = icons[Random().nextInt(icons.length)];
    ref.read(fileEditorProvider.notifier).updateIcon(newIcon);
    _onContentChanged();
  }

  void _copyAllContent() {
    final blocks = ref.read(fileEditorProvider).blocks;
    final fullText = blocks.map((b) => b.controller.text).join('\n');
    Clipboard.setData(ClipboardData(text: fullText));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("전체 복사 완료!"),
        duration: Duration(milliseconds: 1000),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fileState = ref.watch(fileEditorProvider);
    final blocks = fileState.blocks;

    Widget editorView = CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 80),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 60),

                // 1. [아이콘]
                GestureDetector(
                  onTap: _changeRandomIcon,
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: Text(
                      fileState.icon ?? '📄',
                      style: const TextStyle(fontSize: 60),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // 2. [제목]
                TextField(
                  controller: _titleController,
                  style: const TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    height: 1.2,
                  ),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    hintText: '제목 없음',
                    hintStyle: TextStyle(color: Colors.white24),
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                  onChanged: (_) => _onContentChanged(),
                ),
                const SizedBox(height: 24),

                // 3. [복구됨!] 속성 패널 (태그 & 프롬프트)
                _buildNotionPropertyRow(
                  Icons.local_offer_outlined,
                  "태그",
                  _tagsController,
                  "비어 있음",
                ),
                _buildNotionPropertyRow(
                  Icons.auto_awesome_outlined,
                  "명령어",
                  _aiPromptController,
                  "AI에게 지시할 내용...",
                ),

                const SizedBox(height: 24),
                const Divider(color: _kBorderColor, thickness: 1),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),

        // 4. [본문]
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(80, 0, 80, 200),
          sliver: SliverReorderableList(
            itemCount: blocks.length,
            onReorder: (oldIndex, newIndex) => ref
                .read(fileEditorProvider.notifier)
                .reorderBlock(oldIndex, newIndex),
            itemBuilder: (context, index) {
              final block = blocks[index];
              return HoverBlockItem(
                key: ValueKey(block.id),
                index: index,
                block: block,
                isLastBlock: index == blocks.length - 1,
                onKey: _handleKeyEvent,
                onChanged: (text, idx) => _handleTextChanged(text, idx),
                onDelete: () =>
                    ref.read(fileEditorProvider.notifier).removeBlock(index),
                onDuplicate: () =>
                    ref.read(fileEditorProvider.notifier).duplicateBlock(index),
                onTypeChange: (type) => ref
                    .read(fileEditorProvider.notifier)
                    .updateBlockType(index, type),
                onOptions: () {},
                onToggleCheckbox: (val) => ref
                    .read(fileEditorProvider.notifier)
                    .toggleCheckbox(index, val),
              );
            },
          ),
        ),
      ],
    );

    Widget rightPanel = Container(
      color: _kBgSecondary,
      child: Column(
        children: [
          TabBar(
            controller: _tabController,
            labelColor: _kAccentColor,
            unselectedLabelColor: _kTextSecondary,
            indicatorColor: _kAccentColor,
            indicatorWeight: 3,
            tabs: const [
              Tab(text: "✨ 전체 요약"),
              Tab(text: "🔍 상세 분석"),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildSummaryList(fileState.summaryBlocks),
                fileState.currentBlockAnalysis == null
                    ? Center(
                        child: Text(
                          "블록을 선택하고 내용을 입력하면\nAI가 상세하게 분석합니다.",
                          textAlign: TextAlign.center,
                          style: TextStyle(color: _kTextSecondary),
                        ),
                      )
                    : SingleChildScrollView(
                        padding: const EdgeInsets.all(20),
                        child: MarkdownBody(
                          data: fileState.currentBlockAnalysis!,
                          styleSheet: MarkdownStyleSheet(
                            p: const TextStyle(
                              color: _kTextColor,
                              fontSize: 14,
                              height: 1.6,
                            ),
                            strong: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                            code: const TextStyle(
                              backgroundColor: Color(0xFF1E1E1E),
                              fontFamily: 'monospace',
                              color: _kAccentColor,
                            ),
                            tableBorder: TableBorder.all(color: _kBorderColor),
                            tableHead: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                            tableBody: const TextStyle(color: _kTextColor),
                          ),
                        ),
                      ),
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
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => Navigator.pop(context),
          color: _kTextSecondary,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.copy_all_rounded, size: 20),
            onPressed: _copyAllContent,
            color: _kTextSecondary,
            tooltip: '전체 복사',
          ),
          IconButton(
            icon: Icon(
              _viewMode == 0
                  ? Icons.bubble_chart_rounded
                  : Icons.edit_note_rounded,
            ),
            onPressed: () => setState(() => _viewMode = _viewMode == 0 ? 1 : 0),
            color: _kTextSecondary,
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: _viewMode == 0
          ? ResizableSplitView(left: editorView, right: rightPanel)
          : const Center(
              child: Text("지식 그래프 뷰", style: TextStyle(color: Colors.white)),
            ),
    );
  }

  // 💡 [Notion Style] 속성 패널 디자인
  Widget _buildNotionPropertyRow(
    IconData icon,
    String label,
    TextEditingController ctrl,
    String hint,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: _kTextSecondary),
          const SizedBox(width: 10),
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(color: _kTextSecondary, fontSize: 14),
            ),
          ),
          Expanded(
            child: TextField(
              controller: ctrl,
              style: const TextStyle(color: _kTextColor, fontSize: 14),
              decoration: InputDecoration(
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
                hintText: hint,
                hintStyle: TextStyle(color: _kTextSecondary.withOpacity(0.5)),
              ),
              onChanged: (_) => _onContentChanged(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryList(List<SummaryBlock> summaries) {
    if (summaries.isEmpty)
      return Center(
        child: Text(
          "작성을 시작하면 AI가 요약해줍니다.",
          style: TextStyle(color: _kTextSecondary),
        ),
      );
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: summaries.length,
      itemBuilder: (context, index) {
        final item = summaries[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _kCardColor,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _kBorderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              MarkdownBody(
                data: item.content,
                styleSheet: MarkdownStyleSheet(
                  p: const TextStyle(color: _kTextColor, height: 1.5),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class HoverBlockItem extends StatefulWidget {
  final int index;
  final Block block;
  final bool isLastBlock;
  final KeyEventResult Function(FocusNode, KeyEvent, int) onKey;
  final Function(String, int) onChanged;
  final VoidCallback onDelete;
  final VoidCallback onDuplicate;
  final VoidCallback onOptions;
  final Function(bool) onToggleCheckbox;
  final Function(BlockType) onTypeChange;

  const HoverBlockItem({
    Key? key,
    required this.index,
    required this.block,
    required this.isLastBlock,
    required this.onKey,
    required this.onChanged,
    required this.onDelete,
    required this.onDuplicate,
    required this.onOptions,
    required this.onToggleCheckbox,
    required this.onTypeChange,
  }) : super(key: key);

  @override
  State<HoverBlockItem> createState() => _HoverBlockItemState();
}

class _HoverBlockItemState extends State<HoverBlockItem> {
  bool _isHovering = false;

  TextStyle _getStyle(BlockType type) {
    switch (type) {
      case BlockType.h1:
        return const TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: Colors.white,
          height: 1.2,
        );
      case BlockType.h2:
        return const TextStyle(
          fontSize: 26,
          fontWeight: FontWeight.bold,
          color: Colors.white,
          height: 1.2,
        );
      case BlockType.h3:
        return const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Colors.white,
          height: 1.2,
        );
      case BlockType.bullet:
        return const TextStyle(fontSize: 16, color: _kTextColor, height: 1.5);
      case BlockType.code:
        return const TextStyle(
          fontSize: 14,
          fontFamily: 'monospace',
          color: _kAccentColor,
        );
      default:
        return const TextStyle(fontSize: 16, color: _kTextColor, height: 1.6);
    }
  }

  PopupMenuItem<String> _menuItem(String val, IconData icon, String txt) {
    return PopupMenuItem(
      value: val,
      height: 32,
      child: Row(
        children: [
          Icon(icon, size: 16, color: _kTextSecondary),
          const SizedBox(width: 8),
          Text(txt, style: const TextStyle(color: Colors.white, fontSize: 13)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    widget.block.focusNode.onKeyEvent = (node, event) =>
        widget.onKey(node, event, widget.index);
    final bool isList =
        widget.block.type == BlockType.bullet ||
        widget.block.type == BlockType.checkbox;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: isList ? 1.0 : 4.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 24,
              height: 24,
              alignment: Alignment.center,
              margin: const EdgeInsets.only(top: 2),
              child: Opacity(
                opacity: _isHovering ? 1.0 : 0.0,
                child: ReorderableDragStartListener(
                  index: widget.index,
                  child: PopupMenuButton<String>(
                    padding: EdgeInsets.zero,
                    color: _kCardColor,
                    tooltip: '',
                    offset: const Offset(0, 30),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: const BorderSide(color: _kBorderColor),
                    ),
                    onSelected: (val) {
                      if (val == 'del') widget.onDelete();
                      if (val == 'dup') widget.onDuplicate();
                      if (val == 'h1') widget.onTypeChange(BlockType.h1);
                      if (val == 'text') widget.onTypeChange(BlockType.text);
                    },
                    itemBuilder: (ctx) => [
                      _menuItem('del', Icons.delete_outline, '삭제'),
                      _menuItem('dup', Icons.content_copy, '복제'),
                      const PopupMenuDivider(height: 10),
                      _menuItem('h1', Icons.title, '제목 1'),
                      _menuItem('text', Icons.short_text, '텍스트'),
                    ],
                    child: const Icon(
                      Icons.drag_indicator,
                      size: 18,
                      color: _kTextHint,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 6),
            if (widget.block.type == BlockType.bullet)
              Padding(
                padding: const EdgeInsets.only(top: 10, right: 8),
                child: Icon(Icons.circle, size: 6, color: _kTextColor),
              ),

            Expanded(
              child: CompositedTransformTarget(
                link: widget.block.layerLink,
                child: TextField(
                  controller: widget.block.controller,
                  focusNode: widget.block.focusNode,
                  maxLines: null,
                  style: _getStyle(widget.block.type),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                    hintText: "명령어 '/' 입력",
                    hintStyle: TextStyle(color: Colors.white10),
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
