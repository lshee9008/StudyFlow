import 'dart:io';
import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:intl/intl.dart';
// 이모지 피커 패키지
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:study_flow/core/db_helper/files_db_helper.dart';

// 모델 및 프로바이더, DB 헬퍼 임포트
import '../../models/block_model.dart';
import 'file_provider.dart';
import '../../core/theme.dart';
import '../../core/local_db_helper.dart'; // initState에서 초기 데이터 로드용

// -----------------------------------------------------------------------------
// [WIDGET] Resizable Split View (화면 분할 위젯)
// -----------------------------------------------------------------------------
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
          children: [
            SizedBox(width: leftWidth, child: widget.left),

            // Resizer (드래그 핸들)
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

// -----------------------------------------------------------------------------
// [SCREEN] File Screen (파일 상세/편집 화면)
// -----------------------------------------------------------------------------
class FileScreen extends ConsumerStatefulWidget {
  final String fileId;
  const FileScreen({Key? key, required this.fileId}) : super(key: key);

  @override
  ConsumerState<FileScreen> createState() => _FileScreenState();
}

class _FileScreenState extends ConsumerState<FileScreen> {
  // 텍스트 컨트롤러
  final TextEditingController _titleController = TextEditingController(
    text: "제목 없음",
  );
  final TextEditingController _tagsController = TextEditingController();
  final TextEditingController _aiPromptController = TextEditingController();
  final TextEditingController _summaryController = TextEditingController();

  String _createdDate = DateFormat('yyyy. MM. dd').format(DateTime.now());
  Timer? _debounceTimer;
  bool _isEditingSummary = false;

  // 슬래시 메뉴(/) 관련 변수
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

    // 초기 데이터 로드
    Future.microtask(() async {
      // 1. Provider에 데이터 로드 요청 (블록 상태 초기화)
      await ref.read(fileEditorProvider.notifier).loadFileDetail(widget.fileId);

      // 2. TextField 초기값을 위해 DB에서 직접 데이터 한번 조회
      // (Provider 상태를 바로 읽어도 되지만, 컨트롤러 초기화 시점을 명확히 하기 위함)
      final fileModel = await FilesDBHelper.getFile(widget.fileId);

      if (fileModel != null && mounted) {
        setState(() {
          _titleController.text = fileModel.title;
          _tagsController.text = fileModel.tags;
          _createdDate = DateFormat('yyyy. MM. dd').format(fileModel.create_at);
          _summaryController.text = fileModel.summary ?? "";
          _aiPromptController.text = fileModel.prompt ?? "";
        });
      }
    });
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _titleController.dispose();
    _tagsController.dispose();
    _aiPromptController.dispose();
    _summaryController.dispose();
    _removeOverlay();
    super.dispose();
  }

  // 내용 변경 감지 및 자동 저장
  void _onContentChanged() {
    if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();
    _debounceTimer = Timer(const Duration(seconds: 2), () async {
      // 1. 현재 에디터 상태 저장 (DB 업데이트)
      await ref
          .read(fileEditorProvider.notifier)
          .saveFile(
            fileId: widget.fileId,
            title: _titleController.text,
            tags: _tagsController.text,
            prompt: _aiPromptController.text,
            updateAt: DateTime.now(),
          );

      // 2. 파일 목록 화면의 제목 동기화 (뒤로가기 시 반영)
      ref
          .read(filesProvider.notifier)
          .updateFileTitle(widget.fileId, _titleController.text);

      // 3. AI 요약 자동 요청
      await ref
          .read(fileEditorProvider.notifier)
          .requestAutoAISummary(
            title: _titleController.text,
            tags: _tagsController.text,
            prompt: _aiPromptController.text.isEmpty
                ? "내용을 분석하고 요약해줘"
                : _aiPromptController.text,
          );
    });
  }

  // 뒤로가기 시 저장 처리
  Future<bool> _onWillPop() async {
    await ref
        .read(fileEditorProvider.notifier)
        .saveFile(
          fileId: widget.fileId,
          title: _titleController.text,
          tags: _tagsController.text,
          prompt: _aiPromptController.text,
          updateAt: DateTime.now(),
        );

    // 목록 제목 동기화
    ref
        .read(filesProvider.notifier)
        .updateFileTitle(widget.fileId, _titleController.text);

    return true;
  }

  // --- 블록 조작 메서드 (EditorProvider 사용) ---

  void _addNewBlock(int index) {
    ref.read(fileEditorProvider.notifier).addBlock(index);
    _moveFocus(index);
  }

  void _deleteBlock(int index) {
    ref.read(fileEditorProvider.notifier).removeBlock(index);
    if (index > 0) {
      _removeOverlay();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // 현재 블록 리스트 가져오기
        final blocks = ref.read(fileEditorProvider).blocks;
        // 이전 블록으로 포커스 이동
        if (index - 1 < blocks.length) {
          final prevBlock = blocks[index - 1];
          prevBlock.focusNode.requestFocus();
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final blocks = ref.read(fileEditorProvider).blocks;
      if (index < blocks.length) {
        blocks[index].focusNode.requestFocus();
      }
    });
  }

  // --- 이모지 피커 (Notion 스타일) ---
  void _showEmojiPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          height: 450,
          decoration: BoxDecoration(
            color: AppTheme.bgSecondary,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 20,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Column(
            children: [
              // 드래그 핸들
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Expanded(
                child: EmojiPicker(
                  onEmojiSelected: (category, emoji) {
                    // 아이콘 업데이트
                    ref
                        .read(fileEditorProvider.notifier)
                        .updateIcon(emoji.emoji);
                    _onContentChanged();
                    Navigator.pop(context);
                  },
                  config: Config(
                    height: 256,
                    checkPlatformCompatibility: true,
                    emojiViewConfig: EmojiViewConfig(
                      backgroundColor: AppTheme.bgSecondary,
                      columns: 7,
                      emojiSizeMax: 28,
                    ),
                    skinToneConfig: const SkinToneConfig(),
                    categoryViewConfig: CategoryViewConfig(
                      backgroundColor: AppTheme.bgSecondary,
                      dividerColor: AppTheme.borderColor,
                      indicatorColor: AppTheme.aiAccentColor,
                      iconColorSelected: AppTheme.aiAccentColor,
                      iconColor: AppTheme.textSecondary,
                    ),
                    bottomActionBarConfig: const BottomActionBarConfig(
                      enabled: false,
                    ),
                    searchViewConfig: SearchViewConfig(
                      backgroundColor: AppTheme.bgSecondary,
                      buttonIconColor: AppTheme.textSecondary,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _removeIcon() {
    ref.read(fileEditorProvider.notifier).updateIcon(null);
    _onContentChanged();
  }

  // --- UI Build ---
  @override
  Widget build(BuildContext context) {
    // 에디터 상태 감시 (Blocks, Icon, Summary)
    final fileState = ref.watch(fileEditorProvider);
    final blocks = fileState.blocks;
    final isLoading = fileState.isLoading;
    final pageIcon = fileState.icon;
    final summaryContent = fileState.summaryContent;

    // AI 요약 내용이 변경되면 컨트롤러에 반영
    if (_summaryController.text != summaryContent &&
        !isLoading &&
        !_isEditingSummary) {
      _summaryController.text = summaryContent;
    }

    final bool isWideScreen = MediaQuery.of(context).size.width > 800;

    // 1. [LEFT] 에디터 영역
    Widget leftEditor = CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 50),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 60),

                // 아이콘 표시 영역
                if (pageIcon != null) ...[
                  GestureDetector(
                    onTap: _showEmojiPicker,
                    child: Text(pageIcon, style: const TextStyle(fontSize: 72)),
                  ),
                  const SizedBox(height: 20),
                ] else
                  // 아이콘 추가 버튼
                  GestureDetector(
                    onTap: _showEmojiPicker,
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
                            style: AppTheme.caption.copyWith(fontSize: 15),
                          ),
                        ],
                      ),
                    ),
                  ),

                // 제목 입력 필드
                TextField(
                  controller: _titleController,
                  style: AppTheme.titleHuge,
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    filled: false,
                    hintText: '제목 없음',
                    hintStyle: TextStyle(color: AppTheme.textHint),
                    contentPadding: EdgeInsets.zero,
                  ),
                  onChanged: (_) => _onContentChanged(),
                ),

                const SizedBox(height: 24),

                // 속성 행들 (작성일, 태그, 프롬프트)
                _buildPropertyRow(
                  Icons.calendar_today_outlined,
                  "작성일",
                  _createdDate,
                ),
                _buildInputPropertyRow(
                  icon: Icons.tag,
                  label: "태그",
                  controller: _tagsController,
                  hint: "예: 중요, 회의록",
                  onChanged: (_) => _onContentChanged(),
                ),
                _buildInputPropertyRow(
                  icon: Icons.smart_toy_outlined,
                  label: "프롬프트",
                  controller: _aiPromptController,
                  hint: "AI 요약 지시사항...",
                  onChanged: (_) => _onContentChanged(),
                ),

                if (pageIcon != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                    child: GestureDetector(
                      onTap: _removeIcon,
                      child: Row(
                        children: [
                          Icon(
                            Icons.remove_circle_outline,
                            size: 20,
                            color: AppTheme.textSecondary,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            "아이콘 삭제",
                            style: AppTheme.caption.copyWith(fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  ),

                const SizedBox(height: 24),
                const Divider(),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),

        // 블록 리스트
        SliverPadding(
          padding: const EdgeInsets.only(left: 50, right: 50, bottom: 120),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate((context, index) {
              return HoverBlockItem(
                key: ValueKey(blocks[index].id),
                index: index,
                block: blocks[index],
                onEnter: _handleKeyEvent,
                onChanged: (text, idx) {
                  _handleTextChanged(text, idx);
                  _onContentChanged();
                },
                onDelete: () {
                  _deleteBlock(index);
                  _onContentChanged();
                },
                onOptions: () => _showBlockOptionMenu(index),
                onToggleCheckbox: (val) {
                  ref
                      .read(fileEditorProvider.notifier)
                      .toggleCheckbox(index, val);
                  _onContentChanged();
                },
                getStyle: _getStyleForBlock,
                getHint: _getHintText,
              );
            }, childCount: blocks.length),
          ),
        ),
      ],
    );

    // 2. [RIGHT] 요약(Summary) 영역
    Widget rightSummary = Container(
      color: AppTheme.bgSecondary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 10, 20),
            child: Row(
              children: [
                Icon(
                  Icons.auto_awesome,
                  size: 18,
                  color: AppTheme.aiAccentColor,
                ),
                const SizedBox(width: 8),
                Text(
                  "AI Insight",
                  style: AppTheme.titleSmall.copyWith(fontSize: 16),
                ),
                const Spacer(),
                if (isLoading)
                  Padding(
                    padding: const EdgeInsets.only(right: 14),
                    child: SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppTheme.aiAccentColor,
                      ),
                    ),
                  )
                else
                  IconButton(
                    icon: Icon(
                      _isEditingSummary ? Icons.check : Icons.edit_outlined,
                      size: 18,
                      color: AppTheme.textSecondary,
                    ),
                    tooltip: _isEditingSummary ? "완료" : "직접 수정",
                    onPressed: () {
                      setState(() {
                        _isEditingSummary = !_isEditingSummary;
                      });
                    },
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _isEditingSummary
                ? TextField(
                    controller: _summaryController,
                    maxLines: null,
                    expands: true,
                    style: AppTheme.bodyText.copyWith(
                      fontSize: 14,
                      height: 1.6,
                    ),
                    textAlignVertical: TextAlignVertical.top,
                    decoration: InputDecoration(
                      hintText: "요약 내용을 직접 수정할 수 있습니다.",
                      hintStyle: TextStyle(
                        color: AppTheme.textHint.withOpacity(0.6),
                      ),
                      border: InputBorder.none,
                      filled: false,
                      contentPadding: const EdgeInsets.all(24),
                    ),
                    onChanged: (val) {
                      ref
                          .read(fileEditorProvider.notifier)
                          .updateSummaryContent(val);
                    },
                  )
                : Markdown(
                    data: summaryContent.isEmpty
                        ? "왼쪽에 내용을 작성하시면,\nAI가 실시간으로 분석하여 이곳에 **요약**을 남깁니다."
                        : summaryContent,
                    padding: const EdgeInsets.all(24),
                    selectable: true,
                    styleSheet: MarkdownStyleSheet(
                      p: AppTheme.bodyText.copyWith(fontSize: 14, height: 1.6),
                      h1: AppTheme.titleLarge.copyWith(
                        fontSize: 22,
                        height: 1.4,
                      ),
                      h2: AppTheme.titleMedium.copyWith(
                        fontSize: 18,
                        height: 1.4,
                      ),
                      h3: AppTheme.titleSmall.copyWith(
                        fontSize: 16,
                        height: 1.4,
                      ),
                      strong: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      code: const TextStyle(
                        backgroundColor: Color(0xFF333333),
                        fontFamily: 'Courier',
                        fontSize: 13,
                      ),
                      listBullet: const TextStyle(
                        color: AppTheme.aiAccentColor,
                      ),
                      blockquote: const TextStyle(color: Colors.grey),
                      blockquoteDecoration: BoxDecoration(
                        color: const Color(0xFF303030),
                        borderRadius: BorderRadius.circular(4),
                        border: const Border(
                          left: BorderSide(color: Colors.grey, width: 4),
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );

    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        appBar: AppBar(
          leading: BackButton(
            onPressed: () async {
              await _onWillPop();
              Navigator.pop(context);
            },
          ),
          title: Text(
            _titleController.text.isEmpty ? "제목 없음" : _titleController.text,
            style: const TextStyle(fontSize: 14),
          ),
          centerTitle: true,
          actions: [
            IconButton(icon: const Icon(Icons.more_horiz), onPressed: () {}),
            const SizedBox(width: 16),
          ],
        ),
        body: GestureDetector(
          onTap: _removeOverlay,
          child: isWideScreen
              ? ResizableSplitView(
                  left: leftEditor,
                  right: rightSummary,
                  initialRatio: 0.65,
                )
              : leftEditor,
        ),
      ),
    );
  }

  // --- Helper Widgets ---

  Widget _buildPropertyRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppTheme.textSecondary),
          const SizedBox(width: 12),
          SizedBox(
            width: 100,
            child: Text(label, style: AppTheme.caption.copyWith(fontSize: 14)),
          ),
          Expanded(
            child: Text(
              value,
              style: AppTheme.bodyText.copyWith(
                fontSize: 14,
                color: AppTheme.textPrimary.withOpacity(0.9),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputPropertyRow({
    required IconData icon,
    required String label,
    required TextEditingController controller,
    required String hint,
    Function(String)? onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Icon(icon, size: 20, color: AppTheme.textSecondary),
          ),
          const SizedBox(width: 12),
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: SizedBox(
              width: 100,
              child: Text(
                label,
                style: AppTheme.caption.copyWith(fontSize: 14),
              ),
            ),
          ),
          Expanded(
            child: TextField(
              controller: controller,
              style: AppTheme.bodyText.copyWith(
                fontSize: 14,
                color: AppTheme.textPrimary.withOpacity(0.9),
              ),
              maxLines: null,
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: TextStyle(color: AppTheme.textHint.withOpacity(0.5)),
                border: InputBorder.none,
                filled: false,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }

  void _showBlockOptionMenu(int index) {
    showModalBottomSheet(
      context: context,
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
                  _onContentChanged();
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

  // --- 슬래시 커맨드 및 힌트 처리 ---

  String? _getHintText(Block block, int index) {
    final blocksLength = ref.read(fileEditorProvider).blocks.length;
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
      if (ref.read(fileEditorProvider).blocks[index].controller.text.isEmpty &&
          index > 0) {
        _deleteBlock(index);
      }
    }
  }

  void _showOverlay(BuildContext context, int index, String query) {
    _activeBlockIndex = index;
    final blocks = ref.read(fileEditorProvider).blocks;
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
            color: AppTheme.bgSecondary,
            child: Container(
              constraints: const BoxConstraints(maxHeight: 320),
              decoration: BoxDecoration(
                border: Border.all(color: AppTheme.borderColor),
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
                    color: isSelected ? AppTheme.bgHover : null,
                    child: ListTile(
                      dense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 2,
                      ),
                      leading: Icon(
                        option['icon'],
                        size: 18,
                        color: AppTheme.textSecondary,
                      ),
                      title: Text(
                        option['label'],
                        style: AppTheme.bodyText.copyWith(fontSize: 15),
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
// [WIDGET] HoverBlockItem (블록 아이템 위젯)
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
    double handleTopPadding = 4.0;
    if (widget.block.type == BlockType.h1) handleTopPadding = 12.0;
    if (widget.block.type == BlockType.h2) handleTopPadding = 8.0;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 드래그 핸들 / 옵션 버튼
          Container(
            width: 24,
            height: 24,
            margin: EdgeInsets.only(top: handleTopPadding),
            child: Opacity(
              opacity: _isHovering ? 1.0 : 0.0,
              child: IconButton(
                padding: EdgeInsets.zero,
                icon: Icon(
                  Icons.drag_indicator,
                  color: AppTheme.textSecondary.withOpacity(0.4),
                  size: 18,
                ),
                onPressed: widget.onOptions,
                splashRadius: 12,
                tooltip: "옵션",
              ),
            ),
          ),
          const SizedBox(width: 6),
          // 본문 입력 영역
          Expanded(
            child: Container(
              margin: EdgeInsets.only(bottom: isCode ? 12 : 0),
              padding: isCode ? const EdgeInsets.all(16) : null,
              decoration: isCode
                  ? BoxDecoration(
                      color: AppTheme.bgSecondary,
                      borderRadius: BorderRadius.circular(6),
                    )
                  : null,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (widget.block.type == BlockType.bullet)
                    Padding(
                      padding: const EdgeInsets.only(top: 10, right: 12),
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
                        width: 20,
                        height: 20,
                        child: Checkbox(
                          value: widget.block.isChecked,
                          activeColor: AppTheme.accentColor,
                          side: BorderSide(
                            color: AppTheme.textSecondary,
                            width: 1.5,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(3),
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
                        child: TextField(
                          controller: widget.block.controller,
                          focusNode: widget.block.focusNode,
                          maxLines: null,
                          strutStyle: const StrutStyle(
                            height: 1.5,
                            forceStrutHeight: true,
                          ),
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
                            filled: false,
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 2,
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
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
