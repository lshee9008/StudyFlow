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

// --- 앱 전체 다크 모드 색상 팔레트 (Notion Style) ---
const Color _kBgPrimary = Color(0xFF191919);
const Color _kBgSecondary = Color(0xFF202020);
const Color _kCardColor = Color(0xFF2C2C2C);
const Color _kTextColor = Color(0xFFEBEBEB);
const Color _kTextHint = Color(0xFF707070);
const Color _kBorderColor = Color(0xFF333333);

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
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(width: leftWidth, child: widget.left),
            MouseRegion(
              cursor: SystemMouseCursors.resizeColumn,
              onEnter: (_) => setState(() => _isDragging = true),
              onExit: (_) => setState(() => _isDragging = false),
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onPanUpdate: (details) {
                  setState(() {
                    _ratio += details.delta.dx / width;
                    if (_ratio < 0.3) _ratio = 0.3;
                    if (_ratio > 0.8) _ratio = 0.8;
                  });
                },
                child: Container(
                  width: 6,
                  color: Colors.transparent,
                  alignment: Alignment.center,
                  child: Container(
                    width: 1,
                    height: double.infinity,
                    color: _isDragging ? Colors.blueAccent : _kBorderColor,
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

// -----------------------------------------------------------------------------
// [SCREEN] File Screen
// -----------------------------------------------------------------------------
class FileScreen extends ConsumerStatefulWidget {
  final String fileId;
  const FileScreen({Key? key, required this.fileId}) : super(key: key);

  @override
  ConsumerState<FileScreen> createState() => _FileScreenState();
}

class _FileScreenState extends ConsumerState<FileScreen> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _tagsController = TextEditingController();
  final TextEditingController _aiPromptController = TextEditingController();

  Timer? _debounceTimer;
  OverlayEntry? _overlayEntry;
  int _activeBlockIndex = -1;
  String? _lastActiveBlockId;
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
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeScreen();
    });
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
    _removeOverlay();
    super.dispose();
  }

  void _onContentChanged({String? activeBlockId}) {
    if (activeBlockId != null) {
      _lastActiveBlockId = activeBlockId;
    }

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
          .read(filesProvider.notifier)
          .updateFileTitle(widget.fileId, _titleController.text);

      await ref
          .read(fileEditorProvider.notifier)
          .requestAutoAISummary(
            title: _titleController.text,
            tags: _tagsController.text,
            prompt: _aiPromptController.text.isEmpty
                ? "내용을 분석하고 요약해줘"
                : _aiPromptController.text,
            activeBlockId: _lastActiveBlockId,
          );
    });
  }

  Future<bool> _onWillPop() async {
    _onContentChanged();
    return true;
  }

  void _handleTextChanged(String text, int index) {
    final currentBlockId = ref.read(fileEditorProvider).blocks[index].id;

    if (text.contains('\n')) {
      final split = text.split('\n');
      final currentContent = split[0];
      final nextContent = split.length > 1 ? split[1] : "";

      ref.read(fileEditorProvider).blocks[index].controller.text =
          currentContent;
      ref
          .read(fileEditorProvider.notifier)
          .addBlock(index + 1, initialContent: nextContent);

      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _moveFocus(index + 1),
      );
      _onContentChanged(activeBlockId: currentBlockId);
      return;
    }

    int slashIndex = text.lastIndexOf('/');
    if (slashIndex != -1) {
      String query = text.substring(slashIndex + 1);
      if (!query.contains(' ')) {
        _showOverlay(context, index, query);
      } else {
        _removeOverlay();
      }
    } else {
      _removeOverlay();
    }

    _onContentChanged(activeBlockId: currentBlockId);
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
        _applyTypeChange(
          index: index,
          newType: _currentFilteredOptions[_menuSelectedIndex]['type'],
        );
        return KeyEventResult.handled;
      } else if (event.logicalKey == LogicalKeyboardKey.escape) {
        _removeOverlay();
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }

    final blocks = ref.read(fileEditorProvider).blocks;
    final ctrl = blocks[index].controller;

    if (event.logicalKey == LogicalKeyboardKey.backspace) {
      if (ctrl.selection.baseOffset == 0) {
        if (index > 0) {
          final prevBlock = blocks[index - 1];
          final currentText = ctrl.text;
          final prevTextLength = prevBlock.controller.text.length;

          prevBlock.controller.text += currentText;
          _deleteBlock(index);

          WidgetsBinding.instance.addPostFrameCallback((_) {
            prevBlock.focusNode.requestFocus();
            prevBlock.controller.selection = TextSelection.collapsed(
              offset: prevTextLength,
            );
          });
          return KeyEventResult.handled;
        }
      }
    } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      if (index > 0) {
        _moveFocus(index - 1);
        return KeyEventResult.handled;
      }
    } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      if (index < blocks.length - 1) {
        _moveFocus(index + 1);
        return KeyEventResult.handled;
      }
    }

    return KeyEventResult.ignored;
  }

  void _deleteBlock(int index) {
    ref.read(fileEditorProvider.notifier).removeBlock(index);
    _onContentChanged();
  }

  void _applyTypeChange({required int index, required BlockType newType}) {
    _removeOverlay();
    ref.read(fileEditorProvider.notifier).updateBlockType(index, newType);
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
    _currentFilteredOptions = _allMenuOptions.where((option) {
      final label = (option['label'] as String).toLowerCase();
      return label.contains(query.toLowerCase());
    }).toList();

    if (_currentFilteredOptions.isEmpty) {
      _removeOverlay();
      return;
    }

    if (_overlayEntry == null) _menuSelectedIndex = 0;
    _overlayEntry?.remove();

    final blocks = ref.read(fileEditorProvider).blocks;
    _overlayEntry = _createOverlayEntry(blocks[index]);
    Overlay.of(context).insert(_overlayEntry!);
  }

  OverlayEntry _createOverlayEntry(Block block) {
    return OverlayEntry(
      builder: (context) => Positioned(
        width: 220,
        child: CompositedTransformFollower(
          link: block.layerLink,
          showWhenUnlinked: false,
          offset: const Offset(0, 32),
          child: Material(
            elevation: 12,
            borderRadius: BorderRadius.circular(8),
            color: _kCardColor,
            clipBehavior: Clip.antiAlias,
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: _kBorderColor),
                borderRadius: BorderRadius.circular(8),
              ),
              child: ListView.builder(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(vertical: 4),
                itemCount: _currentFilteredOptions.length,
                itemBuilder: (context, i) {
                  final option = _currentFilteredOptions[i];
                  final isSelected = i == _menuSelectedIndex;
                  return Container(
                    color: isSelected
                        ? Colors.white.withOpacity(0.1)
                        : Colors.transparent,
                    child: ListTile(
                      dense: true,
                      minLeadingWidth: 20,
                      leading: Icon(
                        option['icon'],
                        size: 18,
                        color: isSelected ? Colors.white : Colors.grey[400],
                      ),
                      title: Text(
                        option['label'],
                        style: TextStyle(
                          fontSize: 14,
                          color: isSelected ? Colors.white : Colors.grey[300],
                        ),
                      ),
                      onTap: () => _applyTypeChange(
                        index: _activeBlockIndex,
                        newType: option['type'],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    _activeBlockIndex = -1;
  }

  Color _getBlockColor(String? blockId) {
    if (blockId == null) return Colors.transparent;
    final int hash = blockId.hashCode;
    final List<Color> colors = [
      const Color(0xFF60A5FA),
      const Color(0xFF34D399),
      const Color(0xFFFBBF24),
      const Color(0xFFA78BFA),
      const Color(0xFFF472B6),
      const Color(0xFF38BDF8),
    ];
    return colors[hash.abs() % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    final fileState = ref.watch(fileEditorProvider);
    final blocks = fileState.blocks;
    final isLoading = fileState.isLoading;
    final summaryBlocks = fileState.summaryBlocks;

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
                    fontSize: 42,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: -1.0,
                    height: 1.2,
                  ),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    filled: false,
                    hintText: '제목 없음',
                    hintStyle: TextStyle(color: _kTextHint),
                    contentPadding: EdgeInsets.zero,
                  ),
                  onChanged: (_) => _onContentChanged(),
                ),
                const SizedBox(height: 24),
                _buildCleanPropertyRow(
                  Icons.local_offer_outlined,
                  "태그",
                  _tagsController,
                  "비어 있음",
                ),
                _buildCleanPropertyRow(
                  Icons.auto_awesome_outlined,
                  "명령어",
                  _aiPromptController,
                  "AI 지시사항",
                ),
                const SizedBox(height: 32),
                const Divider(color: _kBorderColor, height: 1),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(80, 0, 80, 200),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate((context, index) {
              final block = blocks[index];
              return HoverBlockItem(
                key: ValueKey(block.id),
                index: index,
                block: block,
                isLastBlock: index == blocks.length - 1,
                onKey: _handleKeyEvent,
                onChanged: (text, idx) {
                  _handleTextChanged(text, idx);
                },
                onDelete: () {
                  _deleteBlock(index);
                },
                onOptions: () {},
                onToggleCheckbox: (val) {
                  ref
                      .read(fileEditorProvider.notifier)
                      .toggleCheckbox(index, val);
                  _onContentChanged();
                },
              );
            }, childCount: blocks.length),
          ),
        ),
      ],
    );

    // --- ✨ AI Insight 우측 패널 (Overflow 버그 해결판) ---
    Widget rightSummary = Container(
      color: _kBgSecondary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
            child: Row(
              children: [
                const Icon(
                  Icons.auto_awesome,
                  color: Color(0xFFA78BFA),
                  size: 20,
                ),
                const SizedBox(width: 10),
                const Text(
                  "AI Insight",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const Spacer(),
                if (isLoading)
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.0,
                      color: Color(0xFFA78BFA),
                    ),
                  ),
              ],
            ),
          ),
          const Divider(height: 1, color: _kBorderColor),
          Expanded(
            child: summaryBlocks.isEmpty
                ? const Center(
                    child: Text(
                      "작성을 시작하면 AI가 요약해줍니다.",
                      style: TextStyle(color: _kTextHint, fontSize: 14),
                    ),
                  )
                : ListView.builder(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.all(20),
                    itemCount: summaryBlocks.length,
                    itemBuilder: (context, index) {
                      final item = summaryBlocks[index];
                      final Color cardColor = _getBlockColor(
                        item.relatedBlockId,
                      );

                      if (item.content.trim().isEmpty)
                        return const SizedBox.shrink();

                      // 🚨 [핵심 해결] IntrinsicHeight 제거 및 Stack 구조 적용
                      // 표(Table)나 긴 텍스트가 들어가도 안전하게 레이아웃을 렌더링합니다.
                      return Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: _kCardColor,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        clipBehavior: Clip.hardEdge,
                        child: Stack(
                          children: [
                            // 왼쪽 색상 띠 (Stack의 높이에 맞춰 자동 확장됨)
                            Positioned(
                              left: 0,
                              top: 0,
                              bottom: 0,
                              width: 4,
                              child: Container(
                                color: item.isSaved
                                    ? cardColor
                                    : cardColor.withOpacity(0.4),
                              ),
                            ),

                            // 메인 콘텐츠 영역 (이 높이에 따라 Stack의 전체 높이가 결정됨)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(
                                20,
                                16,
                                16,
                                16,
                              ), // 왼쪽 여백 20 (띠 4px 고려)
                              child: Column(
                                mainAxisSize: MainAxisSize.min, // 내용물만큼만 차지
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      GestureDetector(
                                        onTap: () {
                                          ref
                                              .read(fileEditorProvider.notifier)
                                              .toggleSummaryBlockSaved(index);
                                          _onContentChanged();
                                        },
                                        child: Icon(
                                          item.isSaved
                                              ? Icons.bookmark
                                              : Icons.bookmark_border,
                                          color: item.isSaved
                                              ? cardColor
                                              : Colors.grey[600],
                                          size: 18,
                                        ),
                                      ),
                                      const Spacer(),
                                      if (!item.isSaved)
                                        GestureDetector(
                                          onTap: () {
                                            ref
                                                .read(
                                                  fileEditorProvider.notifier,
                                                )
                                                .deleteSummaryBlock(index);
                                            _onContentChanged();
                                          },
                                          child: Icon(
                                            Icons.close,
                                            size: 16,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),

                                  // 마크다운 렌더링 (다크 테마 최적화)
                                  MarkdownBody(
                                    data: item.content,
                                    selectable: true,
                                    styleSheet: MarkdownStyleSheet(
                                      p: const TextStyle(
                                        fontSize: 14,
                                        height: 1.6,
                                        color: _kTextColor,
                                      ),
                                      strong: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                      code: const TextStyle(
                                        backgroundColor: Color(0xFF1E1E1E),
                                        color: Color(0xFFF472B6),
                                        fontFamily: 'monospace',
                                        fontSize: 13,
                                      ),
                                      codeblockDecoration: BoxDecoration(
                                        color: const Color(0xFF1E1E1E),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      tableBorder: TableBorder.all(
                                        color: _kBorderColor,
                                      ),
                                      tableCellsPadding: const EdgeInsets.all(
                                        8,
                                      ),
                                      tableHead: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
                                      ),
                                      tableBody: const TextStyle(
                                        color: _kTextColor,
                                      ),
                                      listBullet: TextStyle(
                                        color: cardColor,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );

    Widget graphView = _KnowledgeGraphView(
      title: _titleController.text,
      tags: _tagsController.text,
    );

    return Scaffold(
      backgroundColor: _kBgPrimary,
      appBar: AppBar(
        backgroundColor: _kBgPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        leadingWidth: 70,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          color: Colors.grey[400],
          onPressed: () async {
            await _onWillPop();
            Navigator.pop(context);
          },
        ),
        title: Text(
          _titleController.text.isEmpty ? "Untitled" : _titleController.text,
          style: const TextStyle(fontSize: 14, color: _kTextHint),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: const Color(0xFF252525),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [_buildToggleBtn(0, "문서"), _buildToggleBtn(1, "그래프")],
            ),
          ),
        ],
      ),
      body: _viewMode == 0
          ? (MediaQuery.of(context).size.width > 800
                ? ResizableSplitView(
                    left: editorView,
                    right: rightSummary,
                    initialRatio: 0.65,
                  )
                : editorView)
          : graphView,
    );
  }

  Widget _buildToggleBtn(int mode, String label) {
    final isSelected = _viewMode == mode;
    return GestureDetector(
      onTap: () => setState(() => _viewMode = mode),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF404040) : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
            color: isSelected ? Colors.white : Colors.grey[500],
          ),
        ),
      ),
    );
  }

  Widget _buildCleanPropertyRow(
    IconData icon,
    String label,
    TextEditingController ctrl,
    String hint,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, size: 18, color: Colors.grey[600]),
          const SizedBox(width: 8),
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: TextStyle(color: Colors.grey[500], fontSize: 14),
            ),
          ),
          Expanded(
            child: TextField(
              controller: ctrl,
              style: const TextStyle(fontSize: 14, color: _kTextColor),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: const TextStyle(color: _kTextHint),
                border: InputBorder.none,
                filled: false,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
              onChanged: (_) => _onContentChanged(),
            ),
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// [WIDGET] HoverBlockItem
// -----------------------------------------------------------------------------
class HoverBlockItem extends StatefulWidget {
  final int index;
  final Block block;
  final bool isLastBlock;
  final KeyEventResult Function(FocusNode, KeyEvent, int) onKey;
  final Function(String, int) onChanged;
  final VoidCallback onDelete;
  final VoidCallback onOptions;
  final Function(bool) onToggleCheckbox;

  const HoverBlockItem({
    Key? key,
    required this.index,
    required this.block,
    required this.isLastBlock,
    required this.onKey,
    required this.onChanged,
    required this.onDelete,
    required this.onOptions,
    required this.onToggleCheckbox,
  }) : super(key: key);

  @override
  State<HoverBlockItem> createState() => _HoverBlockItemState();
}

class _HoverBlockItemState extends State<HoverBlockItem> {
  bool _isHovering = false;
  bool _hasFocus = false;

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
      setState(() {
        _hasFocus = widget.block.focusNode.hasFocus;
      });
    }
  }

  TextStyle _getStyle(BlockType type) {
    switch (type) {
      case BlockType.h1:
        return const TextStyle(
          fontSize: 30,
          fontWeight: FontWeight.w700,
          color: Colors.white,
          height: 1.3,
          letterSpacing: -0.5,
        );
      case BlockType.h2:
        return const TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: Colors.white,
          height: 1.3,
          letterSpacing: -0.5,
        );
      case BlockType.h3:
        return const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: Colors.white,
          height: 1.3,
          letterSpacing: -0.3,
        );
      case BlockType.code:
        return const TextStyle(
          fontSize: 14,
          fontFamily: 'monospace',
          color: Color(0xFF34D399),
          backgroundColor: Color(0xFF222222),
        );
      default:
        return const TextStyle(
          fontSize: 16,
          color: _kTextColor,
          height: 1.5,
          letterSpacing: -0.2,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    widget.block.focusNode.onKeyEvent = (node, event) {
      return widget.onKey(node, event, widget.index);
    };

    bool showHint =
        (widget.block.type == BlockType.text &&
            widget.block.controller.text.isEmpty) &&
        (_hasFocus || widget.isLastBlock);

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 3.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 2),
              width: 24,
              alignment: Alignment.centerLeft,
              child: Opacity(
                opacity: _isHovering ? 1.0 : 0.0,
                child: IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  icon: const Icon(
                    Icons.drag_indicator_rounded,
                    size: 18,
                    color: _kTextHint,
                  ),
                  onPressed: widget.onOptions,
                  hoverColor: Colors.transparent,
                  splashColor: Colors.transparent,
                ),
              ),
            ),
            const SizedBox(width: 8),

            if (widget.block.type == BlockType.checkbox)
              Padding(
                padding: const EdgeInsets.only(top: 4, right: 12),
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: Checkbox(
                    value: widget.block.isChecked,
                    onChanged: (val) => widget.onToggleCheckbox(val!),
                    activeColor: Colors.blueAccent,
                    checkColor: Colors.white,
                    side: const BorderSide(color: Colors.grey, width: 1.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ),
            if (widget.block.type == BlockType.bullet)
              const Padding(
                padding: EdgeInsets.only(top: 10, right: 12, left: 4),
                child: Icon(Icons.circle, size: 6, color: _kTextColor),
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
                        ? Colors.grey[600]
                        : null,
                  ),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    filled: false,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                    hintText: showHint ? "명령어를 사용하려면 '/'를 입력하세요" : "",
                    hintStyle: const TextStyle(color: _kTextHint, fontSize: 16),
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

// -----------------------------------------------------------------------------
// [WIDGET] 🕸️ Knowledge Graph View
// -----------------------------------------------------------------------------
class _KnowledgeGraphView extends StatelessWidget {
  final String title;
  final String tags;

  const _KnowledgeGraphView({required this.title, required this.tags});

  @override
  Widget build(BuildContext context) {
    List<String> tagList = tags
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    return Container(
      color: _kBgPrimary,
      child: InteractiveViewer(
        boundaryMargin: const EdgeInsets.all(double.infinity),
        minScale: 0.1,
        maxScale: 4.0,
        child: CustomPaint(
          painter: _GraphPainter(
            title: title.isEmpty ? "Current Note" : title,
            tags: tagList,
          ),
          size: Size.infinite,
        ),
      ),
    );
  }
}

class _GraphPainter extends CustomPainter {
  final String title;
  final List<String> tags;

  _GraphPainter({required this.title, required this.tags});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paintLine = Paint()
      ..color = _kBorderColor
      ..strokeWidth = 1.5;

    _drawNode(canvas, center, title, isMain: true);

    if (tags.isNotEmpty) {
      final double radius = 180.0;
      final double angleStep = (2 * pi) / tags.length;

      for (int i = 0; i < tags.length; i++) {
        final double angle = i * angleStep;
        final Offset tagCenter = Offset(
          center.dx + radius * cos(angle),
          center.dy + radius * sin(angle),
        );

        canvas.drawLine(center, tagCenter, paintLine);
        _drawNode(canvas, tagCenter, tags[i], isMain: false);
      }
    }
  }

  void _drawNode(
    Canvas canvas,
    Offset position,
    String text, {
    required bool isMain,
  }) {
    final nodePaint = Paint()
      ..color = isMain ? const Color(0xFF60A5FA) : const Color(0xFF34D399);

    canvas.drawCircle(position, isMain ? 20 : 12, nodePaint);

    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: Colors.white,
          fontSize: isMain ? 14 : 12,
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();

    final textOffset = Offset(
      position.dx - textPainter.width / 2,
      position.dy + (isMain ? 28 : 20),
    );
    textPainter.paint(canvas, textOffset);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
