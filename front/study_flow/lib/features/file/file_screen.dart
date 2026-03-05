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

// 🖋️ 미니멀하고 깨끗한 NotebookLM 스타일 다크 테마
const Color _kBgPrimary = Color(0xFF141414);
const Color _kBgSecondary = Color(0xFF1A1A1A);
const Color _kCardColor = Color(0xFF222222);
const Color _kTextColor = Color(0xFFE5E7EB);
const Color _kTextHint = Color(0xFF6B7280);
const Color _kTextSecondary = Color(0xFF9CA3AF);
const Color _kBorderColor = Color(0xFF333333);
const Color _kAccentColor = Color(0xFF60A5FA);

// 퀴즈용 컬러
const Color _kCorrectColor = Color(0xFF10B981);
const Color _kWrongColor = Color(0xFFEF4444);

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
                  width: 8,
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

  Timer? _saveDebounceTimer;
  Timer? _aiDebounceTimer;

  OverlayEntry? _overlayEntry;
  int _activeBlockIndex = -1;
  int _menuSelectedIndex = 0;
  List<Map<String, dynamic>> _currentFilteredOptions = [];
  int _viewMode = 0;
  String _lastFocusedText = "";
  bool _isSaving = false;

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
    _tabController = TabController(length: 4, vsync: this);
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
    _titleController.dispose();
    _tagsController.dispose();
    _aiPromptController.dispose();
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

    if (_aiDebounceTimer?.isActive ?? false) _aiDebounceTimer!.cancel();
    _aiDebounceTimer = Timer(const Duration(milliseconds: 1200), () {
      if (_tabController.index == 1 && _lastFocusedText.trim().isNotEmpty)
        _triggerAIAnalysis(_lastFocusedText);
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
        width: 220,
        child: CompositedTransformFollower(
          link: blocks[index].layerLink,
          showWhenUnlinked: false,
          offset: const Offset(0, 36),
          child: TweenAnimationBuilder<double>(
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOutCubic,
            tween: Tween(begin: 0.95, end: 1.0),
            builder: (context, val, child) => Transform.scale(
              scale: val,
              alignment: Alignment.topLeft,
              child: Opacity(opacity: val.clamp(0.0, 1.0), child: child),
            ),
            child: Material(
              elevation: 16,
              borderRadius: BorderRadius.circular(8),
              color: _kCardColor,
              shadowColor: Colors.black.withOpacity(0.5),
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: _kBorderColor),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _currentFilteredOptions.length,
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  itemBuilder: (context, i) => Container(
                    color: i == _menuSelectedIndex
                        ? _kAccentColor.withOpacity(0.15)
                        : Colors.transparent,
                    child: ListTile(
                      dense: true,
                      minLeadingWidth: 20,
                      leading: Icon(
                        _currentFilteredOptions[i]['icon'],
                        size: 16,
                        color: i == _menuSelectedIndex
                            ? _kAccentColor
                            : _kTextSecondary,
                      ),
                      title: Text(
                        _currentFilteredOptions[i]['label'],
                        style: TextStyle(
                          color: i == _menuSelectedIndex
                              ? Colors.white
                              : _kTextSecondary,
                          fontSize: 13,
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
        content: Text("전체 복사 완료!"),
        duration: Duration(seconds: 1),
        backgroundColor: _kAccentColor,
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
                const SizedBox(height: 80),
                const SizedBox(height: 20),
                TextField(
                  controller: _titleController,
                  style: const TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    height: 1.2,
                    letterSpacing: -0.5,
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
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: const BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: _kBorderColor, width: 1),
                    ),
                  ),
                  child: Column(
                    children: [
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
                        "명령어 입력...",
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 30),
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

    // 🌟 AI 스튜디오 패널
    Widget rightPanel = Container(
      color: _kBgSecondary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 💡 아이콘 위, 텍스트 아래의 깔끔한 탭바 구성
          Container(
            padding: const EdgeInsets.only(top: 16),
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: _kBorderColor, width: 1),
              ),
            ),
            child: TabBar(
              controller: _tabController,
              labelColor: _kAccentColor,
              unselectedLabelColor: _kTextSecondary,
              indicatorColor: _kAccentColor,
              indicatorWeight: 3,
              labelPadding: const EdgeInsets.symmetric(horizontal: 12),
              tabs: const [
                Tab(
                  icon: Icon(Icons.dashboard_customize_outlined),
                  text: "전체 요약",
                ),
                Tab(icon: Icon(Icons.manage_search_rounded), text: "상세 분석"),
                Tab(icon: Icon(Icons.lightbulb_outline_rounded), text: "핵심 암기"),
                Tab(icon: Icon(Icons.fact_check_outlined), text: "AI 퀴즈"),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // 1. 전체 요약
                Stack(
                  children: [
                    _buildSummaryList(fileState.summaryBlocks),
                    if (fileState.isSummaryLoading)
                      Positioned.fill(
                        child: _buildStudioLoader("문서를 스캔하고 있습니다..."),
                      ),
                    Positioned(
                      bottom: 24,
                      right: 24,
                      child: FloatingActionButton.extended(
                        onPressed: () => ref
                            .read(fileEditorProvider.notifier)
                            .requestAutoAISummary(
                              title: _titleController.text,
                              tags: _tagsController.text,
                              prompt: "",
                            ),
                        backgroundColor: _kCardColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: const BorderSide(color: _kBorderColor),
                        ),
                        icon: const Icon(
                          Icons.auto_fix_high,
                          color: Colors.white,
                          size: 18,
                        ),
                        label: const Text(
                          "요약 생성",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        elevation: 0,
                      ),
                    ),
                  ],
                ),

                // 2. 상세 분석
                Column(
                  children: [
                    AnimatedSize(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOut,
                      child: fileState.focusedText.trim().isNotEmpty
                          ? Container(
                              margin: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: _kBgPrimary,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: _kBorderColor),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.location_searching_rounded,
                                        size: 14,
                                        color: _kTextSecondary,
                                      ),
                                      const SizedBox(width: 6),
                                      const Text(
                                        "분석 중인 문맥",
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: _kTextSecondary,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    '"${fileState.focusedText}"',
                                    style: const TextStyle(
                                      color: _kTextColor,
                                      fontSize: 13,
                                      height: 1.5,
                                      fontStyle: FontStyle.italic,
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
                        child: fileState.isAnalysisLoading
                            ? _buildStudioLoader("문맥 분석 중...")
                            : fileState.currentBlockAnalysis == null ||
                                  fileState.focusedText.trim().isEmpty
                            ? _buildEmptyStudioState(
                                Icons.article_outlined,
                                "문단을 클릭하면\nAI가 실시간으로 분석합니다.",
                              )
                            : SingleChildScrollView(
                                padding: const EdgeInsets.all(24),
                                physics: const BouncingScrollPhysics(),
                                child: MarkdownBody(
                                  data: fileState.currentBlockAnalysis!,
                                  styleSheet: _getMarkdownStyle(),
                                ),
                              ),
                      ),
                    ),
                  ],
                ),

                // 3. 핵심 암기
                Stack(
                  children: [
                    fileState.isStudioLoading
                        ? _buildStudioLoader("핵심 개념을 추출 중입니다...")
                        : fileState.currentMemo == null
                        ? _buildEmptyStudioState(
                            Icons.psychology_rounded,
                            "시험에 나올 핵심만\nAI가 추출해 드립니다.",
                          )
                        : SingleChildScrollView(
                            padding: const EdgeInsets.all(24),
                            child: MarkdownBody(
                              data: fileState.currentMemo!,
                              styleSheet: _getMarkdownStyle(),
                            ),
                          ),
                    if (fileState.currentMemo == null &&
                        !fileState.isStudioLoading)
                      Positioned(
                        bottom: 24,
                        right: 24,
                        child: FloatingActionButton.extended(
                          onPressed: () => ref
                              .read(fileEditorProvider.notifier)
                              .generateStudioContent('memo'),
                          backgroundColor: _kCardColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                            side: const BorderSide(color: _kBorderColor),
                          ),
                          label: const Text(
                            "암기 노트 생성",
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          elevation: 0,
                        ),
                      ),
                  ],
                ),

                // 4. 🎯 인터랙티브 AI 퀴즈 뷰
                Stack(
                  children: [
                    fileState.isStudioLoading
                        ? _buildStudioLoader("퀴즈를 생성 중입니다...")
                        : fileState.quizData == null
                        ? _buildEmptyStudioState(
                            Icons.quiz_outlined,
                            "본문 내용을 바탕으로\nAI가 객관식 문제를 출제합니다.",
                          )
                        : _buildInteractiveQuiz(fileState),
                    if (fileState.quizData == null &&
                        !fileState.isStudioLoading)
                      Positioned(
                        bottom: 24,
                        right: 24,
                        child: FloatingActionButton.extended(
                          onPressed: () => ref
                              .read(fileEditorProvider.notifier)
                              .generateStudioContent('quiz'),
                          backgroundColor: _kCardColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                            side: const BorderSide(color: _kBorderColor),
                          ),
                          label: const Text(
                            "퀴즈 출제하기",
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          elevation: 0,
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
        title: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: _isSaving
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: _kTextSecondary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      "저장 중...",
                      style: TextStyle(color: _kTextSecondary, fontSize: 12),
                    ),
                  ],
                )
              : fileState.lastSavedAt != null
              ? const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.cloud_done_outlined,
                      size: 14,
                      color: _kTextSecondary,
                    ),
                    SizedBox(width: 6),
                    Text(
                      "클라우드 저장됨",
                      style: TextStyle(color: _kTextSecondary, fontSize: 12),
                    ),
                  ],
                )
              : const SizedBox.shrink(),
        ),
        centerTitle: true,
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
                  ? Icons.space_dashboard_rounded
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
              child: Text("대시보드 뷰", style: TextStyle(color: Colors.white)),
            ),
    );
  }

  // 💡 버튼으로 풀 수 있는 인터랙티브 퀴즈 UI
  Widget _buildInteractiveQuiz(FileEditorState fileState) {
    final quizList = fileState.quizData!;
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
      itemCount: quizList.length,
      itemBuilder: (context, qIndex) {
        final q = quizList[qIndex];
        final bool isAnswered = fileState.quizAnswers.containsKey(qIndex);
        final int? selectedOpt = fileState.quizAnswers[qIndex];
        final int correctOpt = q['answer'] ?? 0;

        return Container(
          margin: const EdgeInsets.only(bottom: 20),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: _kCardColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _kBorderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Q${qIndex + 1}. ${q['question']}",
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 16),
              ...List.generate((q['options'] as List).length, (optIndex) {
                final optionText = q['options'][optIndex];

                // 버튼 색상 로직 (정답 체크 후 색상 변화)
                Color btnBgColor = _kBgPrimary;
                Color btnBorderColor = _kBorderColor;
                if (isAnswered) {
                  if (optIndex == correctOpt) {
                    btnBgColor = _kCorrectColor.withOpacity(0.15);
                    btnBorderColor = _kCorrectColor;
                  } else if (optIndex == selectedOpt) {
                    btnBgColor = _kWrongColor.withOpacity(0.15);
                    btnBorderColor = _kWrongColor;
                  }
                }

                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: InkWell(
                    onTap: () => ref
                        .read(fileEditorProvider.notifier)
                        .answerQuiz(qIndex, optIndex),
                    borderRadius: BorderRadius.circular(8),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        vertical: 14,
                        horizontal: 16,
                      ),
                      decoration: BoxDecoration(
                        color: btnBgColor,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: btnBorderColor),
                      ),
                      child: Text(
                        optionText,
                        style: const TextStyle(
                          color: _kTextColor,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                );
              }),

              // 정답 선택 후 해설 표시
              AnimatedSize(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOut,
                child: isAnswered
                    ? Container(
                        margin: const EdgeInsets.only(top: 16),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: _kBgPrimary.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: _kBorderColor),
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
                                      ? "정답입니다!"
                                      : "오답입니다.",
                                  style: TextStyle(
                                    color: selectedOpt == correctOpt
                                        ? _kCorrectColor
                                        : _kWrongColor,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              "해설: ${q['explanation']}",
                              style: const TextStyle(
                                color: _kTextSecondary,
                                height: 1.5,
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
    );
  }

  // AI 스튜디오 공통 마크다운 스타일 (깔끔한 텍스트/표/리스트 최적화)
  MarkdownStyleSheet _getMarkdownStyle() {
    return MarkdownStyleSheet(
      p: const TextStyle(color: _kTextColor, fontSize: 14, height: 1.6),
      strong: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      code: const TextStyle(
        backgroundColor: _kBgPrimary,
        fontFamily: 'monospace',
        color: _kAccentColor,
        fontSize: 13,
      ),
      codeblockDecoration: BoxDecoration(
        color: _kBgPrimary,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _kBorderColor),
      ),
      tableBorder: TableBorder.all(color: _kBorderColor),
      tableHead: const TextStyle(
        fontWeight: FontWeight.bold,
        color: Colors.white,
        backgroundColor: _kBgPrimary,
      ),
      tableCellsPadding: const EdgeInsets.symmetric(
        vertical: 12,
        horizontal: 16,
      ),
      blockquoteDecoration: BoxDecoration(
        border: const Border(left: BorderSide(color: _kBorderColor, width: 4)),
        color: _kBgPrimary,
        borderRadius: BorderRadius.circular(4),
      ),
      listBullet: const TextStyle(color: _kTextSecondary, fontSize: 18),
      h1: const TextStyle(
        fontSize: 20,
        color: Colors.white,
        fontWeight: FontWeight.bold,
      ),
      h2: const TextStyle(
        fontSize: 18,
        color: Colors.white,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildEmptyStudioState(IconData icon, String text) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48, color: _kBorderColor),
          const SizedBox(height: 16),
          Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: _kTextSecondary,
              height: 1.5,
              fontSize: 14,
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
          const CircularProgressIndicator(color: _kAccentColor, strokeWidth: 2),
          const SizedBox(height: 20),
          Text(
            text,
            style: const TextStyle(color: _kTextSecondary, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildNotionPropertyRow(
    IconData icon,
    String label,
    TextEditingController ctrl,
    String hint,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: _kTextHint),
          const SizedBox(width: 8),
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(color: _kTextHint, fontSize: 14),
            ),
          ),
          Expanded(
            child: TextField(
              controller: ctrl,
              style: const TextStyle(color: _kTextColor, fontSize: 14),
              decoration: InputDecoration(
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  vertical: 4,
                  horizontal: 8,
                ),
                hintText: hint,
                hintStyle: TextStyle(color: _kTextHint.withOpacity(0.5)),
                filled: true,
                fillColor: Colors.transparent,
                hoverColor: _kCardColor.withOpacity(0.5),
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
      return _buildEmptyStudioState(
        Icons.auto_awesome_mosaic_outlined,
        "문서를 기반으로 요약을 생성해 보세요.",
      );
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
      itemCount: summaries.length,
      itemBuilder: (context, index) {
        final item = summaries[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: _kCardColor,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _kBorderColor),
          ),
          child: MarkdownBody(
            data: item.content,
            styleSheet: _getMarkdownStyle(),
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
          fontSize: 32,
          fontWeight: FontWeight.w700,
          color: Colors.white,
          height: 1.4,
        );
      case BlockType.h2:
        return const TextStyle(
          fontSize: 26,
          fontWeight: FontWeight.w600,
          color: Colors.white,
          height: 1.4,
        );
      case BlockType.h3:
        return const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: Colors.white,
          height: 1.4,
        );
      case BlockType.code:
        return const TextStyle(
          fontSize: 14,
          fontFamily: 'monospace',
          color: _kAccentColor,
          backgroundColor: _kCardColor,
        );
      case BlockType.bullet:
        return const TextStyle(fontSize: 16, color: _kTextColor, height: 1.6);
      default:
        return const TextStyle(fontSize: 16, color: _kTextColor, height: 1.6);
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
        : (isList ? 4.0 : 8.0);
    final double bottomPadding = isList ? 0.0 : 8.0;

    return Material(
      color: Colors.transparent,
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovering = true),
        onExit: (_) => setState(() => _isHovering = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: EdgeInsets.only(
            top: topPadding,
            bottom: bottomPadding,
            left: 4,
          ),
          decoration: BoxDecoration(
            color: _isFocused
                ? Colors.white.withOpacity(0.01)
                : Colors.transparent,
            border: Border(
              left: BorderSide(
                color: _isFocused ? _kAccentColor : Colors.transparent,
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
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 100),
                  opacity: _isHovering ? 1.0 : 0.0,
                  child: ReorderableDragStartListener(
                    index: widget.index,
                    child: PopupMenuButton<String>(
                      padding: EdgeInsets.zero,
                      color: _kCardColor,
                      offset: const Offset(0, 30),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
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
                        size: 20,
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
                      activeColor: _kAccentColor,
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
                      hintStyle: TextStyle(color: _kTextHint.withOpacity(0.4)),
                    ),
                    onChanged: (text) => widget.onChanged(text, widget.index),
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
