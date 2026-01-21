import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../models/block_model.dart';
import 'file_provider.dart';
import '../../core/theme.dart'; // 테마 임포트

class FileScreen extends ConsumerStatefulWidget {
  final String fileId;
  const FileScreen({Key? key, required this.fileId}) : super(key: key);

  @override
  ConsumerState<FileScreen> createState() => _FileScreenState();
}

class _FileScreenState extends ConsumerState<FileScreen> {
  final TextEditingController _titleController = TextEditingController(
    text: "제목 없음",
  );
  final TextEditingController _tagsController = TextEditingController();
  final TextEditingController _aiPromptController = TextEditingController();
  String _createdDate = DateFormat('yyyy. MM. dd').format(DateTime.now());

  OverlayEntry? _overlayEntry;
  int _activeBlockIndex = -1;
  int _menuSelectedIndex = 0;
  List<Map<String, dynamic>> _currentFilteredOptions = [];

  final List<Map<String, dynamic>> _allMenuOptions = [
    {
      'type': BlockType.h1,
      'label': '제목 1',
      'sub': '대제목',
      'icon': Icons.looks_one,
    },
    {
      'type': BlockType.h2,
      'label': '제목 2',
      'sub': '중제목',
      'icon': Icons.looks_two,
    },
    {
      'type': BlockType.h3,
      'label': '제목 3',
      'sub': '소제목',
      'icon': Icons.looks_3,
    },
    {
      'type': BlockType.text,
      'label': '텍스트',
      'sub': '기본',
      'icon': Icons.short_text,
    },
    {
      'type': BlockType.bullet,
      'label': '글머리 기호',
      'sub': '리스트',
      'icon': Icons.format_list_bulleted,
    },
    {
      'type': BlockType.checkbox,
      'label': '할 일',
      'sub': '체크박스',
      'icon': Icons.check_box_outlined,
    },
    {'type': BlockType.code, 'label': '코드', 'sub': 'Code', 'icon': Icons.code},
  ];

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      final fileModel = await ref
          .read(fileProvider.notifier)
          .loadFile(widget.fileId);
      if (fileModel != null) {
        setState(() {
          _titleController.text = fileModel.title;
          _tagsController.text = fileModel.tags;
          _createdDate = DateFormat('yyyy. MM. dd').format(fileModel.createdAt);
        });
      }
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _tagsController.dispose();
    _aiPromptController.dispose();
    _removeOverlay();
    super.dispose();
  }

  Future<bool> _onWillPop() async {
    await ref
        .read(fileProvider.notifier)
        .saveFile(
          fileId: widget.fileId,
          title: _titleController.text,
          tags: _tagsController.text,
        );
    return true;
  }

  // --- Helpers ---
  void _addNewBlock(int index) {
    ref.read(fileProvider.notifier).addBlock(index);
    _moveFocus(index);
  }

  void _deleteBlock(int index) {
    ref.read(fileProvider.notifier).removeBlock(index);
    if (index > 0) {
      _removeOverlay();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final blocks = ref.read(fileProvider).blocks;
        final prevBlock = blocks[index - 1];
        prevBlock.focusNode.requestFocus();
        prevBlock.controller.selection = TextSelection.fromPosition(
          TextPosition(offset: prevBlock.controller.text.length),
        );
      });
    }
  }

  void _applyTypeChange({required int index, required BlockType newType}) {
    _removeOverlay();
    ref.read(fileProvider.notifier).updateBlockType(index, newType);
    _moveFocus(index);
  }

  void _moveFocus(int index) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final blocks = ref.read(fileProvider).blocks;
      if (index < blocks.length) {
        blocks[index].focusNode.requestFocus();
      }
    });
  }

  Future<void> _handleAIRequest() async {
    final success = await ref
        .read(fileProvider.notifier)
        .requestAISummary(
          fileId: widget.fileId,
          tags: _tagsController.text,
          prompt: _aiPromptController.text,
        );
    if (success && mounted) {
      await ref
          .read(fileProvider.notifier)
          .saveFile(
            fileId: widget.fileId,
            title: _titleController.text,
            tags: _tagsController.text,
          );
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("✨ 요약 완료 및 저장됨!")));
    }
  }

  // --- Icon Logic ---
  void _addRandomIcon() {
    final emojis = [
      "📝",
      "🚀",
      "💡",
      "🔥",
      "✅",
      "🎨",
      "💻",
      "📚",
      "🪐",
      "🍎",
      "☘️",
    ];
    final randomEmoji = emojis[Random().nextInt(emojis.length)];
    ref.read(fileProvider.notifier).updateIcon(randomEmoji);
  }

  void _removeIcon() {
    ref.read(fileProvider.notifier).updateIcon(null);
  }

  @override
  Widget build(BuildContext context) {
    final fileState = ref.watch(fileProvider);
    final blocks = fileState.blocks;
    final isLoading = fileState.isLoading;
    final pageIcon = fileState.icon;
    final bool isWideScreen = MediaQuery.of(context).size.width > 800;

    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        // 배경색은 테마에서 자동 적용됨
        appBar: AppBar(
          leading: BackButton(
            onPressed: () async {
              await _onWillPop();
              Navigator.pop(context);
            },
          ),
          title: Text(
            _titleController.text.isEmpty ? "제목 없음" : _titleController.text,
            style: TextStyle(
              fontSize: 16,
              color: AppTheme.textPrimary.withOpacity(0.8),
              fontWeight: FontWeight.w500,
            ),
          ),
          actions: [
            IconButton(icon: const Icon(Icons.more_horiz), onPressed: () {}),
            if (isWideScreen) const SizedBox(width: 20),
          ],
        ),
        floatingActionButton: isWideScreen
            ? null
            : FloatingActionButton.extended(
                onPressed: isLoading ? null : _handleAIRequest,
                backgroundColor: AppTheme.bgSecondary,
                label: Text(
                  isLoading ? "분석 중" : "AI 요약",
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                icon: Icon(Icons.auto_awesome, color: AppTheme.aiAccentColor),
              ),
        body: GestureDetector(
          onTap: _removeOverlay,
          child: Row(
            children: [
              // [LEFT] Editor Area
              Expanded(
                flex: 3,
                child: CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 60,
                        ), // 여백 조정
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 1. Page Icon Header
                            const SizedBox(height: 40),
                            if (pageIcon != null) ...[
                              GestureDetector(
                                onTap: _addRandomIcon,
                                child: Text(
                                  pageIcon,
                                  style: const TextStyle(fontSize: 72),
                                ),
                              ),
                              const SizedBox(height: 20),
                            ] else
                              GestureDetector(
                                onTap: _addRandomIcon,
                                child: Container(
                                  margin: const EdgeInsets.only(bottom: 24),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.add_reaction_outlined,
                                        color: AppTheme.textSecondary,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        "아이콘 추가",
                                        style: AppTheme.caption.copyWith(
                                          fontSize: 15,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                            // 2. Title Input
                            TextField(
                              controller: _titleController,
                              style: AppTheme.titleHuge, // 테마 스타일 적용
                              decoration: const InputDecoration(
                                border: InputBorder.none,
                                filled: false, // 배경색 제거
                                hintText: '제목 없음',
                                hintStyle: TextStyle(color: AppTheme.textHint),
                                contentPadding: EdgeInsets.zero,
                              ),
                              onChanged: (val) {},
                            ),

                            // 3. Properties
                            const SizedBox(height: 24),
                            _buildPropertyRow(
                              Icons.calendar_today_outlined,
                              "작성일",
                              _createdDate,
                            ),
                            _buildPropertyRow(
                              Icons.person_outline,
                              "작성자",
                              "이승희",
                            ), // 실제 사용자 정보로 대체 필요
                            if (pageIcon != null)
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8.0,
                                ),
                                child: GestureDetector(
                                  onTap: _removeIcon,
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.remove_circle_outline,
                                        size: 18,
                                        color: AppTheme.textSecondary,
                                      ),
                                      const SizedBox(width: 12),
                                      Text(
                                        "아이콘 삭제",
                                        style: AppTheme.caption.copyWith(
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                            const SizedBox(height: 24),
                            const Divider(), // 테마 디바이더 적용
                            const SizedBox(height: 24),
                          ],
                        ),
                      ),
                    ),

                    // 4. Block List
                    SliverPadding(
                      padding: const EdgeInsets.only(
                        left: 60,
                        right: 60,
                        bottom: 120,
                      ),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate((context, index) {
                          return HoverBlockItem(
                            key: ValueKey(blocks[index].id),
                            index: index,
                            block: blocks[index],
                            onEnter: _handleKeyEvent,
                            onChanged: _handleTextChanged,
                            onDelete: () => _deleteBlock(index),
                            onOptions: () => _showBlockOptionMenu(index),
                            onToggleCheckbox: (val) {
                              ref
                                  .read(fileProvider.notifier)
                                  .toggleCheckbox(index, val);
                            },
                            getStyle: _getStyleForBlock,
                            getHint: _getHintText,
                          );
                        }, childCount: blocks.length),
                      ),
                    ),
                  ],
                ),
              ),

              // [RIGHT] Sidebar (Desktop Only)
              if (isWideScreen)
                Container(
                  width: 320,
                  decoration: BoxDecoration(
                    color: AppTheme.bgSecondary, // 사이드바 배경색 적용
                    border: Border(
                      left: BorderSide(color: AppTheme.borderColor),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(-2, 0),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("AI Assistant", style: AppTheme.titleSmall),
                      const SizedBox(height: 32),
                      _buildSidebarField("태그", _tagsController, "예: 중요, 회의록"),
                      const SizedBox(height: 24),
                      _buildSidebarField(
                        "프롬프트",
                        _aiPromptController,
                        "AI에게 요청할 내용을 입력하세요...",
                        maxLines: 5,
                      ),
                      const SizedBox(height: 32),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: isLoading ? null : _handleAIRequest,
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                AppTheme.aiAccentColor, // AI 강조색 적용
                            foregroundColor: Colors.black, // 텍스트 색상
                            padding: const EdgeInsets.symmetric(vertical: 20),
                          ),
                          icon: isLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: Colors.black,
                                  ),
                                )
                              : const Icon(
                                  Icons.auto_awesome,
                                  size: 20,
                                  color: Colors.black,
                                ),
                          label: Text(
                            isLoading ? " 분석 중..." : " AI 요약 실행",
                            style: const TextStyle(fontSize: 18),
                          ),
                        ),
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

  // --- Widgets ---

  Widget _buildSidebarField(
    String label,
    TextEditingController ctrl,
    String hint, {
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTheme.caption.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: ctrl,
          maxLines: maxLines,
          style: AppTheme.bodyText.copyWith(fontSize: 14),
          decoration: InputDecoration(hintText: hint),
        ),
      ],
    );
  }

  Widget _buildPropertyRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppTheme.textSecondary),
          const SizedBox(width: 12),
          SizedBox(
            width: 120,
            child: Text(label, style: AppTheme.caption.copyWith(fontSize: 15)),
          ),
          Expanded(
            child: Text(
              value,
              style: AppTheme.bodyText.copyWith(
                fontSize: 15,
                color: AppTheme.textPrimary.withOpacity(0.9),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showBlockOptionMenu(int index) {
    showModalBottomSheet(
      context: context,
      // 배경색은 테마에서 자동 적용됨
      builder: (context) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(
                  Icons.delete_outline,
                  color: Colors.redAccent,
                ),
                title: const Text(
                  "블록 삭제",
                  style: TextStyle(color: Colors.redAccent),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _deleteBlock(index);
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.content_copy,
                  color: AppTheme.textPrimary,
                ),
                title: const Text(
                  "복제",
                  style: TextStyle(color: AppTheme.textPrimary),
                ),
                onTap: () {
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  // --- 기존 Helper Methods (Overlay, KeyEvent, Hints) ---
  String? _getHintText(Block block, int index) {
    final blocksLength = ref.read(fileProvider).blocks.length;
    if (block.type == BlockType.h1) return "제목 1";
    if (block.type == BlockType.h2) return "제목 2";
    if (block.type == BlockType.h3) return "제목 3";
    if (block.type == BlockType.code) return "코드 작성...";
    if (block.controller.text.isEmpty && index == blocksLength - 1)
      return "'/'를 입력하여 명령어 사용";
    return null;
  }

  void _handleTextChanged(String text, int index) {
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
  }

  TextStyle _getStyleForBlock(BlockType type) {
    // 테마 스타일 적용
    switch (type) {
      case BlockType.h1:
        return AppTheme.titleLarge;
      case BlockType.h2:
        return AppTheme.titleMedium;
      case BlockType.h3:
        return AppTheme.titleSmall;
      case BlockType.code:
        return AppTheme.codeText;
      case BlockType.text:
      default:
        return AppTheme.bodyText;
    }
  }

  void _handleKeyEvent(RawKeyEvent event, int index) {
    if (event is! RawKeyDownEvent) return;
    if (_overlayEntry != null) {
      if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
        if (_menuSelectedIndex > 0) {
          _menuSelectedIndex--;
          _overlayEntry!.markNeedsBuild();
        }
        return;
      } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
        if (_menuSelectedIndex < _currentFilteredOptions.length - 1) {
          _menuSelectedIndex++;
          _overlayEntry!.markNeedsBuild();
        }
        return;
      } else if (event.logicalKey == LogicalKeyboardKey.enter) {
        _applyTypeChange(
          index: index,
          newType: _currentFilteredOptions[_menuSelectedIndex]['type'],
        );
        return;
      } else if (event.logicalKey == LogicalKeyboardKey.escape) {
        _removeOverlay();
        return;
      }
    }
    if (event.logicalKey == LogicalKeyboardKey.enter) {
      if (!event.isShiftPressed && _overlayEntry == null) {
        _addNewBlock(index + 1);
      }
    } else if (event.logicalKey == LogicalKeyboardKey.backspace) {
      if (ref.read(fileProvider).blocks[index].controller.text.isEmpty &&
          index > 0) {
        _deleteBlock(index);
      }
    }
  }

  void _showOverlay(BuildContext context, int index, String query) {
    _activeBlockIndex = index;
    final blocks = ref.read(fileProvider).blocks;
    final block = blocks[index];
    _currentFilteredOptions = _allMenuOptions.where((option) {
      final label = (option['label'] as String).toLowerCase();
      final sub = (option['sub'] as String).toLowerCase();
      final q = query.toLowerCase();
      return label.contains(q) || sub.contains(q);
    }).toList();

    if (_currentFilteredOptions.isEmpty) {
      _removeOverlay();
      return;
    }
    if (_overlayEntry == null) _menuSelectedIndex = 0;
    _overlayEntry?.remove();
    _overlayEntry = _createOverlayEntry(block);
    Overlay.of(context).insert(_overlayEntry!);
  }

  OverlayEntry _createOverlayEntry(Block block) {
    return OverlayEntry(
      builder: (context) => Positioned(
        width: 320,
        child: CompositedTransformFollower(
          link: block.layerLink,
          showWhenUnlinked: false,
          offset: const Offset(0, 40),
          child: Material(
            elevation: 12,
            borderRadius: BorderRadius.circular(8),
            color: AppTheme.bgSecondary, // 테마 적용
            child: Container(
              constraints: const BoxConstraints(maxHeight: 320),
              decoration: BoxDecoration(
                border: Border.all(color: AppTheme.borderColor), // 테마 적용
                borderRadius: BorderRadius.circular(8),
              ),
              child: ListView.builder(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(vertical: 6),
                itemCount: _currentFilteredOptions.length,
                itemBuilder: (context, i) {
                  final option = _currentFilteredOptions[i];
                  final isSelected = i == _menuSelectedIndex;
                  return Container(
                    color: isSelected ? AppTheme.bgHover : null, // 테마 적용
                    child: ListTile(
                      dense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 2,
                      ),
                      leading: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppTheme.bgPrimary,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: AppTheme.borderColor.withOpacity(0.5),
                          ),
                        ),
                        child: Icon(
                          option['icon'],
                          size: 18,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                      title: Text(
                        option['label'],
                        style: AppTheme.bodyText.copyWith(fontSize: 15),
                      ),
                      subtitle: Text(
                        option['sub'],
                        style: AppTheme.caption.copyWith(fontSize: 12),
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
}

// -----------------------------------------------------------------------------
// Improved HoverBlockItem (Handle Visibility Fix)
// -----------------------------------------------------------------------------
class HoverBlockItem extends StatefulWidget {
  final int index;
  final Block block;
  final Function(RawKeyEvent, int) onEnter;
  final Function(String, int) onChanged;
  final VoidCallback onDelete;
  final VoidCallback onOptions;
  final Function(bool) onToggleCheckbox;
  final TextStyle Function(BlockType) getStyle;
  final String? Function(Block, int) getHint;

  const HoverBlockItem({
    Key? key,
    required this.index,
    required this.block,
    required this.onEnter,
    required this.onChanged,
    required this.onDelete,
    required this.onOptions,
    required this.onToggleCheckbox,
    required this.getStyle,
    required this.getHint,
  }) : super(key: key);

  @override
  State<HoverBlockItem> createState() => _HoverBlockItemState();
}

class _HoverBlockItemState extends State<HoverBlockItem> {
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    bool isCode = widget.block.type == BlockType.code;
    bool isMobile = Platform.isAndroid || Platform.isIOS;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // 1. Content
          Container(
            margin: EdgeInsets.only(top: 4, bottom: isCode ? 12 : 4),
            padding: isCode ? const EdgeInsets.all(16) : null,
            decoration: isCode
                ? BoxDecoration(
                    color: AppTheme.bgSecondary,
                    borderRadius: BorderRadius.circular(6),
                  ) // 코드 블록 스타일 개선
                : null,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.block.type == BlockType.bullet)
                  Padding(
                    padding: const EdgeInsets.only(top: 10, right: 12, left: 4),
                    child: Icon(
                      Icons.circle,
                      size: 6,
                      color: AppTheme.textPrimary.withOpacity(0.6),
                    ),
                  ),

                if (widget.block.type == BlockType.checkbox)
                  Padding(
                    padding: const EdgeInsets.only(top: 4, right: 10),
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: Checkbox(
                        value: widget.block.isChecked,
                        activeColor: AppTheme.accentColor,
                        checkColor: Colors.white,
                        side: BorderSide(
                          color: AppTheme.textSecondary,
                          width: 1.5,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                        onChanged: (val) => widget.onToggleCheckbox(val!),
                      ),
                    ),
                  ),

                Expanded(
                  child: CompositedTransformTarget(
                    link: widget.block.layerLink,
                    child: RawKeyboardListener(
                      focusNode: FocusNode(),
                      onKey: (event) => widget.onEnter(event, widget.index),
                      child: GestureDetector(
                        onLongPress: isMobile ? widget.onOptions : null,
                        child: TextField(
                          controller: widget.block.controller,
                          focusNode: widget.block.focusNode,
                          maxLines: null,
                          style: widget
                              .getStyle(widget.block.type)
                              .copyWith(
                                decoration:
                                    (widget.block.type == BlockType.checkbox &&
                                        widget.block.isChecked)
                                    ? TextDecoration.lineThrough
                                    : TextDecoration.none,
                                color:
                                    (widget.block.type == BlockType.checkbox &&
                                        widget.block.isChecked)
                                    ? AppTheme.textSecondary
                                    : AppTheme.textPrimary,
                              ),
                          decoration: InputDecoration(
                            border: InputBorder.none,
                            filled: false, // 배경색 제거
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 3,
                            ),
                            hintText: widget.getHint(
                              widget.block,
                              widget.index,
                            ),
                            hintStyle: TextStyle(
                              color: AppTheme.textHint.withOpacity(0.5),
                            ),
                          ),
                          onChanged: (text) =>
                              widget.onChanged(text, widget.index),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 2. The Handle (::) - Desktop Hover
          if (!isMobile)
            Positioned(
              left: -44,
              top: 0,
              bottom: 0,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 150),
                opacity: _isHovering ? 1.0 : 0.0,
                child: Center(
                  child: IconButton(
                    icon: Icon(
                      Icons.drag_indicator,
                      color: AppTheme.textSecondary.withOpacity(0.5),
                      size: 22,
                    ),
                    onPressed: widget.onOptions,
                    tooltip: "블록 옵션",
                    splashRadius: 20,
                    hoverColor: AppTheme.bgHover,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
