import 'dart:io';
import 'dart:async';
import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import '../../core/db_helper/files_db_helper.dart';
import '../../models/block_model.dart';
import 'file_provider.dart';

// 💎 Apple Intelligence & Notion 감성을 섞은 프리미엄 네온 다크 테마
const Color _kBgPrimary = Color(0xFF09090B); // 칠흑 같은 블랙
const Color _kBgSecondary = Color(0xFF121214); // 패널 배경
const Color _kCardColor = Color(0xFF1C1C1F);
const Color _kTextColor = Color(0xFFFAFAFA);
const Color _kTextHint = Color(0xFF52525B);
const Color _kTextSecondary = Color(0xFFA1A1AA);
const Color _kBorderColor = Color(0xFF27272A);
// ✨ 신비로운 오로라 네온 컬러
const Color _kAccentNeonBlue = Color(0xFF00F2FE);
const Color _kAccentNeonPurple = Color(0xFF8B5CF6);

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
                  if (_ratio > 0.7) _ratio = 0.7;
                }),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 8,
                  color: Colors.transparent,
                  alignment: Alignment.center,
                  child: Container(
                    width: _isDragging ? 2 : 1,
                    height: double.infinity,
                    decoration: BoxDecoration(
                      color: _isDragging
                          ? _kAccentNeonBlue
                          : _kBorderColor.withOpacity(0.5),
                      boxShadow: _isDragging
                          ? [
                              BoxShadow(
                                color: _kAccentNeonBlue.withOpacity(0.6),
                                blurRadius: 10,
                              ),
                            ]
                          : [],
                    ),
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
    with TickerProviderStateMixin {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _tagsController = TextEditingController();
  final TextEditingController _aiPromptController = TextEditingController();
  late TabController _tabController;
  late AnimationController _pulseController; // AI 로딩 효과 애니메이션

  Timer? _saveDebounceTimer;
  Timer? _aiDebounceTimer;

  OverlayEntry? _overlayEntry;
  int _activeBlockIndex = -1;
  int _menuSelectedIndex = 0;
  List<Map<String, dynamic>> _currentFilteredOptions = [];
  int _viewMode = 0;
  String _lastFocusedText = "";

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
    _tabController = TabController(length: 2, vsync: this);

    // 신비로운 AI 숨쉬기(Pulse) 애니메이션
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _tabController.addListener(() {
      if (_tabController.index == 1 && _lastFocusedText.trim().isNotEmpty) {
        _triggerAIAnalysis(_lastFocusedText);
      }
    });

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
    _aiDebounceTimer?.cancel();
    _pulseController.dispose();
    _titleController.dispose();
    _tagsController.dispose();
    _aiPromptController.dispose();
    _tabController.dispose();
    _removeOverlay();
    super.dispose();
  }

  // ⚡ [스마트 디바운싱] 서버가 죽지 않도록 저장과 AI 요청을 분리
  void _onContentChanged({String? activeBlockText}) {
    if (activeBlockText != null) {
      _lastFocusedText = activeBlockText;
      ref.read(fileEditorProvider.notifier).state = ref
          .read(fileEditorProvider)
          .copyWith(focusedText: activeBlockText);
    }

    if (_saveDebounceTimer?.isActive ?? false) _saveDebounceTimer!.cancel();
    _saveDebounceTimer = Timer(const Duration(milliseconds: 500), () async {
      await ref
          .read(fileEditorProvider.notifier)
          .saveFile(
            fileId: widget.fileId,
            title: _titleController.text,
            tags: _tagsController.text,
            prompt: _aiPromptController.text,
            updateAt: DateTime.now(),
          );
    });

    // 🚀 클라우드 모델로 변경되어 속도가 빨라졌으므로, 디바운스 시간을 1초로 단축하여 더 즉각적으로 반응하게 함
    if (_aiDebounceTimer?.isActive ?? false) _aiDebounceTimer!.cancel();
    _aiDebounceTimer = Timer(const Duration(milliseconds: 1000), () {
      if (_tabController.index == 1 && _lastFocusedText.trim().isNotEmpty) {
        _triggerAIAnalysis(_lastFocusedText);
      }
    });
  }

  void _triggerAIAnalysis(String text) {
    ref
        .read(fileEditorProvider.notifier)
        .requestBlockAnalysis(
          text: text,
          tags: _tagsController.text,
          documentContext: _titleController.text,
        );
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
    if (slashIndex != -1) {
      ctrl.text = currentText.substring(0, slashIndex);
    }

    if (option['type'] == 'table') {
      ctrl.text += "| 컬럼 1 | 컬럼 2 |\n|---|---|\n| 데이터 | 데이터 |";
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
            borderRadius: BorderRadius.circular(16),
            color: _kCardColor.withOpacity(0.85),
            shadowColor: Colors.black.withOpacity(0.6),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: _kBorderColor.withOpacity(0.8)),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _currentFilteredOptions.length,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemBuilder: (context, i) => Container(
                      color: i == _menuSelectedIndex
                          ? _kAccentNeonBlue.withOpacity(0.15)
                          : Colors.transparent,
                      child: ListTile(
                        dense: true,
                        minLeadingWidth: 20,
                        leading: Icon(
                          _currentFilteredOptions[i]['icon'],
                          size: 18,
                          color: i == _menuSelectedIndex
                              ? _kAccentNeonBlue
                              : _kTextSecondary,
                        ),
                        title: Text(
                          _currentFilteredOptions[i]['label'],
                          style: TextStyle(
                            color: i == _menuSelectedIndex
                                ? Colors.white
                                : _kTextSecondary,
                            fontWeight: i == _menuSelectedIndex
                                ? FontWeight.bold
                                : FontWeight.normal,
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
        ),
      ),
    );
    Overlay.of(context).insert(_overlayEntry!);
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  void _changeRandomIcon() {
    final icons = [
      '📄',
      '📝',
      '💡',
      '🚀',
      '🎨',
      '📚',
      '💻',
      '🔥',
      '✨',
      '🎯',
      '🪐',
      '🧠',
      '⚡️',
      '🔮',
    ];
    ref
        .read(fileEditorProvider.notifier)
        .updateIcon(icons[Random().nextInt(icons.length)]);
    _onContentChanged();
  }

  void _copyAllContent() {
    final blocks = ref.read(fileEditorProvider).blocks;
    Clipboard.setData(
      ClipboardData(text: blocks.map((b) => b.controller.text).join('\n')),
    );
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("전체 복사 완료!"),
        duration: Duration(seconds: 1),
        backgroundColor: _kAccentNeonBlue,
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
                GestureDetector(
                  onTap: _changeRandomIcon,
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: Text(
                      fileState.icon ?? '📄',
                      style: const TextStyle(fontSize: 72),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _titleController,
                  style: const TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
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
                const SizedBox(height: 30),
                _buildPropertyRow(
                  Icons.local_offer_rounded,
                  "태그",
                  _tagsController,
                  "비어 있음",
                ),
                _buildPropertyRow(
                  Icons.auto_awesome,
                  "명령어",
                  _aiPromptController,
                  "AI에게 지시할 내용...",
                ),
                const SizedBox(height: 30),
                const Divider(color: _kBorderColor, thickness: 1),
                const SizedBox(height: 20),
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
                onFocus: () {
                  _lastFocusedText = block.controller.text;
                  _onContentChanged(activeBlockText: block.controller.text);
                },
                onToggleCheckbox: (val) => ref
                    .read(fileEditorProvider.notifier)
                    .toggleCheckbox(index, val),
              );
            },
          ),
        ),
      ],
    );

    // 🤖 AI 인사이트 우측 패널 (홀로그램 매칭 UX 적용)
    Widget rightPanel = Container(
      decoration: const BoxDecoration(
        color: _kBgSecondary,
        border: Border(left: BorderSide(color: _kBorderColor, width: 1)),
      ),
      child: Column(
        children: [
          TabBar(
            controller: _tabController,
            labelColor: _kAccentNeonBlue,
            unselectedLabelColor: _kTextSecondary,
            indicatorColor: _kAccentNeonBlue,
            indicatorWeight: 2,
            dividerColor: Colors.transparent, // 탭바 하단 선 제거로 더 깔끔하게
            tabs: const [
              Tab(icon: Icon(Icons.auto_awesome, size: 18), text: "전체 요약"),
              Tab(icon: Icon(Icons.hub_rounded, size: 18), text: "상세 분석"),
            ],
          ),
          const Divider(height: 1, color: _kBorderColor),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // 1. 전체 요약 탭
                Stack(
                  children: [
                    _buildSummaryList(fileState.summaryBlocks),
                    if (fileState.isSummaryLoading)
                      Positioned.fill(
                        child: _buildMagicLoader("문서 전체를 스캔하고 있습니다..."),
                      ),

                    // 💡 shadowColor 에러 해결 (속성 제거)
                    Positioned(
                      bottom: 30,
                      right: 30,
                      child: Container(
                        decoration: BoxDecoration(
                          boxShadow: [
                            BoxShadow(
                              color: _kAccentNeonPurple.withOpacity(0.5),
                              blurRadius: 10,
                              spreadRadius: 1,
                              offset: const Offset(0, 4),
                            ),
                          ],
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: FloatingActionButton.extended(
                          onPressed: () => ref
                              .read(fileEditorProvider.notifier)
                              .requestAutoAISummary(
                                title: _titleController.text,
                                tags: _tagsController.text,
                                prompt: "",
                              ),
                          backgroundColor: _kAccentNeonPurple.withOpacity(0.9),
                          icon: const Icon(
                            Icons.auto_fix_high,
                            color: Colors.white,
                          ),
                          label: const Text(
                            "요약 생성",
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          elevation:
                              0, // Container 그림자를 쓰기 위해 기본 elevation은 0으로
                        ),
                      ),
                    ),
                  ],
                ),

                // 2. 상세 분석 탭 (✨ 실시간 1:1 매칭 뷰)
                Column(
                  children: [
                    if (fileState.focusedText.trim().isNotEmpty)
                      Container(
                        margin: const EdgeInsets.fromLTRB(20, 20, 20, 10),
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.03),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: _kAccentNeonBlue.withOpacity(0.3),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: _kAccentNeonBlue.withOpacity(0.05),
                              blurRadius: 20,
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.track_changes_rounded,
                                  size: 14,
                                  color: _kAccentNeonBlue,
                                ),
                                const SizedBox(width: 8),
                                const Text(
                                  "현재 포커스된 문맥",
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: _kAccentNeonBlue,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text(
                              '"${fileState.focusedText}"',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontStyle: FontStyle.italic,
                                height: 1.5,
                              ),
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),

                    Expanded(
                      child: fileState.isAnalysisLoading
                          ? _buildMagicLoader("Cloud AI가 숨은 의미를 찾는 중...")
                          : fileState.currentBlockAnalysis == null ||
                                fileState.focusedText.trim().isEmpty
                          ? Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.bubble_chart_rounded,
                                    size: 64,
                                    color: _kBorderColor.withOpacity(0.5),
                                  ),
                                  const SizedBox(height: 20),
                                  Text(
                                    "문단을 클릭하고 내용을 작성하세요.\nCloud AI가 즉시 반응합니다.",
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: _kTextSecondary.withOpacity(0.7),
                                      height: 1.5,
                                      fontSize: 15,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : SingleChildScrollView(
                              padding: const EdgeInsets.fromLTRB(
                                20,
                                10,
                                20,
                                40,
                              ),
                              physics: const BouncingScrollPhysics(),
                              child: Container(
                                padding: const EdgeInsets.all(24),
                                decoration: BoxDecoration(
                                  color: _kCardColor,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: _kBorderColor),
                                ),
                                child: MarkdownBody(
                                  data: fileState.currentBlockAnalysis!,
                                  styleSheet: MarkdownStyleSheet(
                                    p: const TextStyle(
                                      color: _kTextColor,
                                      fontSize: 15,
                                      height: 1.8,
                                    ),
                                    strong: const TextStyle(
                                      color: _kAccentNeonBlue,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    code: const TextStyle(
                                      backgroundColor: Color(0xFF111111),
                                      fontFamily: 'monospace',
                                      color: _kAccentNeonPurple,
                                      fontSize: 14,
                                    ),
                                    codeblockDecoration: BoxDecoration(
                                      color: const Color(0xFF111111),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: _kBorderColor),
                                    ),
                                    tableBorder: TableBorder.all(
                                      color: _kBorderColor,
                                    ),
                                    tableHead: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                      backgroundColor: Color(0xFF1A1A1A),
                                    ),
                                    blockquoteDecoration: BoxDecoration(
                                      border: const Border(
                                        left: BorderSide(
                                          color: _kAccentNeonPurple,
                                          width: 4,
                                        ),
                                      ),
                                      color: Colors.white.withOpacity(0.02),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                    ),
                  ],
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
                  ? Icons.auto_graph_rounded
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

  // ✨ 신비로운 글래스모피즘 로딩 애니메이션
  Widget _buildMagicLoader(String text) {
    return Center(
      child: FadeTransition(
        opacity: Tween<double>(begin: 0.5, end: 1.0).animate(_pulseController),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 28),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white.withOpacity(0.1)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(
                    color: _kAccentNeonBlue,
                    strokeWidth: 3,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    text,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
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

  Widget _buildPropertyRow(
    IconData icon,
    String label,
    TextEditingController ctrl,
    String hint,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: _kTextHint),
          const SizedBox(width: 12),
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(
                color: _kTextHint,
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: TextField(
              controller: ctrl,
              style: const TextStyle(color: _kTextColor, fontSize: 15),
              decoration: InputDecoration(
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
                hintText: hint,
                hintStyle: TextStyle(color: _kTextHint.withOpacity(0.5)),
                filled: false,
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
      return const Center(
        child: Text(
          "하단의 요약 버튼을 눌러주세요.",
          style: TextStyle(color: _kTextSecondary),
        ),
      );
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 100),
      itemCount: summaries.length,
      itemBuilder: (context, index) {
        final item = summaries[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: _kCardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _kBorderColor),
          ),
          child: MarkdownBody(
            data: item.content,
            styleSheet: MarkdownStyleSheet(
              p: const TextStyle(color: _kTextColor, height: 1.7, fontSize: 15),
              listBullet: const TextStyle(color: _kAccentNeonBlue),
            ),
          ),
        );
      },
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
          fontWeight: FontWeight.bold,
          color: Colors.white,
          height: 1.3,
        );
      case BlockType.h2:
        return const TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.bold,
          color: Colors.white,
          height: 1.3,
        );
      case BlockType.h3:
        return const TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.bold,
          color: Colors.white,
          height: 1.3,
        );
      case BlockType.code:
        return const TextStyle(
          fontSize: 15,
          fontFamily: 'monospace',
          color: _kAccentNeonBlue,
        );
      case BlockType.bullet:
        return const TextStyle(fontSize: 16, color: _kTextColor, height: 1.5);
      default:
        return const TextStyle(fontSize: 16, color: _kTextColor, height: 1.7);
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
          Text(txt, style: const TextStyle(color: Colors.white, fontSize: 14)),
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
        : (isList ? 4.0 : 6.0);
    final double bottomPadding = isList ? 0.0 : 6.0;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.only(
          top: topPadding,
          bottom: bottomPadding,
          left: 4,
        ),
        decoration: BoxDecoration(
          border: Border(
            left: BorderSide(
              color: _isFocused
                  ? _kAccentNeonBlue.withOpacity(0.8)
                  : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 24,
              height: 24,
              alignment: Alignment.center,
              margin: const EdgeInsets.only(top: 2, right: 8),
              child: Opacity(
                opacity: _isHovering ? 1.0 : 0.0,
                child: ReorderableDragStartListener(
                  index: widget.index,
                  child: PopupMenuButton<String>(
                    padding: EdgeInsets.zero,
                    color: _kCardColor,
                    offset: const Offset(0, 30),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: const BorderSide(color: _kBorderColor),
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
                      _menuItem('text', Icons.short_text_rounded, '일반 텍스트'),
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

            if (widget.block.type == BlockType.bullet)
              const Padding(
                padding: EdgeInsets.only(top: 10, right: 12),
                child: Icon(Icons.circle, size: 6, color: _kTextColor),
              ),

            if (widget.block.type == BlockType.checkbox)
              Padding(
                padding: const EdgeInsets.only(top: 4, right: 12),
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: Checkbox(
                    value: widget.block.isChecked,
                    onChanged: (val) => widget.onToggleCheckbox(val!),
                    activeColor: _kAccentNeonBlue,
                    checkColor: _kBgPrimary,
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
                        ? "명령어 '/' 입력"
                        : "",
                    hintStyle: TextStyle(color: Colors.white.withOpacity(0.15)),
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
