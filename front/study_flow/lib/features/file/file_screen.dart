import 'dart:io';
import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db_helper/files_db_helper.dart';
import '../../models/block_model.dart';
import 'file_provider.dart';
import '../../core/theme.dart';

class ResizableSplitView extends StatefulWidget {
  final Widget left;
  final Widget right;
  final double initialRatio;

  const ResizableSplitView({
    Key? key,
    required this.left,
    required this.right,
    this.initialRatio = 0.6,
  }) : super(key: key);

  @override
  State<ResizableSplitView> createState() => _ResizableSplitViewState();
}

class _ResizableSplitViewState extends State<ResizableSplitView> {
  late double _ratio;

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
            GestureDetector(
              behavior: HitTestBehavior.translucent,
              onPanUpdate: (details) {
                setState(() {
                  _ratio += details.delta.dx / width;
                  if (_ratio < 0.3) _ratio = 0.3;
                  if (_ratio > 0.8) _ratio = 0.8;
                });
              },
              child: Container(
                width: 9,
                color: Colors.transparent,
                alignment: Alignment.center,
                child: Container(
                  width: 1,
                  height: double.infinity,
                  color: AppTheme.borderColor,
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

  final List<Map<String, dynamic>> _allMenuOptions = [
    {'type': BlockType.h1, 'label': '제목 1', 'icon': Icons.looks_one},
    {'type': BlockType.h2, 'label': '제목 2', 'icon': Icons.looks_two},
    {'type': BlockType.h3, 'label': '제목 3', 'icon': Icons.looks_3},
    {'type': BlockType.text, 'label': '텍스트', 'icon': Icons.short_text},
    {
      'type': BlockType.bullet,
      'label': '목록',
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
    } catch (e) {
      print("초기화 에러: $e");
    }
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

    if (event.logicalKey == LogicalKeyboardKey.backspace) {
      if (ref.read(fileEditorProvider).blocks[index].controller.text.isEmpty &&
          index > 0) {
        _deleteBlock(index);
        return KeyEventResult.handled;
      }
    } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      if (index > 0) {
        _moveFocus(index - 1);
        return KeyEventResult.handled;
      }
    } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      final len = ref.read(fileEditorProvider).blocks.length;
      if (index < len - 1) {
        _moveFocus(index + 1);
        return KeyEventResult.handled;
      }
    } else if (event.logicalKey == LogicalKeyboardKey.enter) {
      return KeyEventResult.ignored; // 엔터는 무시 -> TextField가 줄바꿈 처리
    }

    return KeyEventResult.ignored;
  }

  void _deleteBlock(int index) {
    ref.read(fileEditorProvider.notifier).removeBlock(index);
    if (index > 0) {
      _removeOverlay();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final blocks = ref.read(fileEditorProvider).blocks;
        if (index - 1 < blocks.length) {
          blocks[index - 1].focusNode.requestFocus();
        }
      });
    }
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
      ctrl.selection = TextSelection.fromPosition(
        TextPosition(offset: ctrl.text.length),
      );
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
        width: 250,
        child: CompositedTransformFollower(
          link: block.layerLink,
          showWhenUnlinked: false,
          offset: const Offset(0, 40),
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(8),
            color: AppTheme.bgSecondary,
            child: ListView.builder(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              itemCount: _currentFilteredOptions.length,
              itemBuilder: (context, i) {
                final option = _currentFilteredOptions[i];
                final isSelected = i == _menuSelectedIndex;
                return Container(
                  color: isSelected ? AppTheme.bgHover : null,
                  child: ListTile(
                    dense: true,
                    leading: Icon(
                      option['icon'],
                      size: 18,
                      color: AppTheme.textSecondary,
                    ),
                    title: Text(option['label'], style: AppTheme.bodyText),
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
      Colors.red[200]!,
      Colors.green[200]!,
      Colors.blue[200]!,
      Colors.orange[200]!,
      Colors.purple[200]!,
      Colors.teal[200]!,
      Colors.pink[200]!,
      Colors.amber[200]!,
    ];
    return colors[hash.abs() % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    final fileState = ref.watch(fileEditorProvider);
    final blocks = fileState.blocks;
    final isLoading = fileState.isLoading;
    final summaryBlocks = fileState.summaryBlocks;

    Widget leftEditor = CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 50),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 40),
                TextField(
                  controller: _titleController,
                  style: AppTheme.titleHuge,
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    hintText: '제목 없음',
                  ),
                  onChanged: (_) => _onContentChanged(),
                ),
                const SizedBox(height: 20),
                _buildInputRow(Icons.tag, "태그", _tagsController, "예: 중요, 회의"),
                _buildInputRow(
                  Icons.smart_toy_outlined,
                  "프롬프트",
                  _aiPromptController,
                  "AI 요약 지시사항...",
                ),
                const Divider(height: 30),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(50, 0, 50, 100),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate((context, index) {
              final block = blocks[index];
              final bool hasSummary = summaryBlocks.any(
                (s) => s.relatedBlockId == block.id,
              );
              final Color indicatorColor = hasSummary
                  ? _getBlockColor(block.id)
                  : Colors.transparent;

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 3,
                    height: 24,
                    margin: const EdgeInsets.only(top: 4, right: 8),
                    color: indicatorColor,
                  ),
                  Expanded(
                    child: HoverBlockItem(
                      key: ValueKey(block.id),
                      index: index,
                      block: block,
                      onKey: _handleKeyEvent,
                      onChanged: (text, idx) {
                        _handleTextChanged(text, idx);
                      },
                      onDelete: () {
                        _deleteBlock(index);
                        _onContentChanged();
                      },
                      onOptions: () {},
                      onToggleCheckbox: (val) {
                        ref
                            .read(fileEditorProvider.notifier)
                            .toggleCheckbox(index, val);
                        _onContentChanged();
                      },
                    ),
                  ),
                ],
              );
            }, childCount: blocks.length),
          ),
        ),
      ],
    );

    Widget rightSummary = Container(
      color: AppTheme.bgSecondary,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Icon(
                  Icons.auto_awesome,
                  color: AppTheme.aiAccentColor,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text("AI Insight", style: AppTheme.titleSmall),
                const Spacer(),
                if (isLoading)
                  const SizedBox(
                    width: 15,
                    height: 15,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: summaryBlocks.isEmpty
                ? Center(
                    child: Text("내용을 입력하면 AI가 요약합니다.", style: AppTheme.caption),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: summaryBlocks.length,
                    itemBuilder: (context, index) {
                      final item = summaryBlocks[index];
                      final Color cardColor = _getBlockColor(
                        item.relatedBlockId,
                      );

                      if (item.content.trim().isEmpty) {
                        return const SizedBox.shrink();
                      }

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        clipBehavior: Clip.hardEdge,
                        decoration: BoxDecoration(
                          color: AppTheme.bgPrimary,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppTheme.borderColor),
                        ),
                        child: IntrinsicHeight(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Container(width: 4, color: cardColor),
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          GestureDetector(
                                            onTap: () {
                                              ref
                                                  .read(
                                                    fileEditorProvider.notifier,
                                                  )
                                                  .toggleSummaryBlockSaved(
                                                    index,
                                                  );
                                              _onContentChanged();
                                            },
                                            child: Icon(
                                              item.isSaved
                                                  ? Icons.bookmark
                                                  : Icons.bookmark_border,
                                              color: item.isSaved
                                                  ? cardColor
                                                  : AppTheme.textSecondary,
                                              size: 20,
                                            ),
                                          ),
                                          const Spacer(),
                                          if (!item.isSaved)
                                            GestureDetector(
                                              onTap: () {
                                                ref
                                                    .read(
                                                      fileEditorProvider
                                                          .notifier,
                                                    )
                                                    .deleteSummaryBlock(index);
                                                _onContentChanged();
                                              },
                                              child: Icon(
                                                Icons.close,
                                                size: 16,
                                                color: AppTheme.textHint,
                                              ),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      SelectableText(
                                        item.content,
                                        style: AppTheme.bodyText.copyWith(
                                          fontSize: 14,
                                          height: 1.5,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );

    return Scaffold(
      appBar: AppBar(
        leading: BackButton(
          onPressed: () async {
            await _onWillPop();
            Navigator.pop(context);
          },
        ),
        title: Text(
          _titleController.text.isEmpty ? "제목 없음" : _titleController.text,
        ),
      ),
      body: MediaQuery.of(context).size.width > 800
          ? ResizableSplitView(left: leftEditor, right: rightSummary)
          : leftEditor,
    );
  }

  Widget _buildInputRow(
    IconData icon,
    String label,
    TextEditingController ctrl,
    String hint,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppTheme.textSecondary),
          const SizedBox(width: 12),
          SizedBox(width: 80, child: Text(label, style: AppTheme.caption)),
          Expanded(
            child: TextField(
              controller: ctrl,
              style: AppTheme.bodyText,
              decoration: InputDecoration(
                hintText: hint,
                border: InputBorder.none,
                filled: false,
                isDense: true,
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
  final KeyEventResult Function(FocusNode, KeyEvent, int) onKey;
  final Function(String, int) onChanged;
  final VoidCallback onDelete;
  final VoidCallback onOptions;
  final Function(bool) onToggleCheckbox;

  const HoverBlockItem({
    Key? key,
    required this.index,
    required this.block,
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

  TextStyle _getStyle(BlockType type) {
    switch (type) {
      case BlockType.h1:
        return AppTheme.titleLarge;
      case BlockType.h2:
        return AppTheme.titleMedium;
      case BlockType.h3:
        return AppTheme.titleSmall;
      case BlockType.code:
        return AppTheme.codeText;
      default:
        return AppTheme.bodyText;
    }
  }

  @override
  Widget build(BuildContext context) {
    // 🔴 [최종 해결] 빌드 시점에 focusNode에 이벤트 핸들러 부착
    // 위젯 트리 간섭 없이 가장 깔끔하게 키를 가로챔
    widget.block.focusNode.onKeyEvent = (node, event) {
      return widget.onKey(node, event, widget.index);
    };

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Opacity(
            opacity: _isHovering ? 1.0 : 0.0,
            child: IconButton(
              icon: const Icon(Icons.drag_indicator, size: 18),
              onPressed: widget.onOptions,
            ),
          ),
          if (widget.block.type == BlockType.checkbox)
            Checkbox(
              value: widget.block.isChecked,
              onChanged: (val) => widget.onToggleCheckbox(val!),
              activeColor: AppTheme.aiAccentColor,
            ),
          if (widget.block.type == BlockType.bullet)
            const Padding(
              padding: EdgeInsets.only(top: 10, right: 8),
              child: Icon(Icons.circle, size: 6),
            ),

          Expanded(
            child: CompositedTransformTarget(
              link: widget.block.layerLink,
              // KeyboardListener 삭제 -> 깔끔한 TextField
              child: TextField(
                controller: widget.block.controller,
                focusNode: widget.block.focusNode,
                maxLines: null,
                style: _getStyle(widget.block.type),
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  filled: false,
                  isDense: true,
                ),
                onChanged: (text) => widget.onChanged(text, widget.index),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
