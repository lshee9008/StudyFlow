import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../models/block_model.dart';
import 'file_provider.dart'; // FileNotifier가 있는 파일 import

class FileScreen extends ConsumerStatefulWidget {
  // [중요] 파일을 저장하고 불러오려면 ID가 꼭 필요합니다.
  final String fileId;

  const FileScreen({Key? key, required this.fileId}) : super(key: key);

  @override
  ConsumerState<FileScreen> createState() => _FileScreenState();
}

class _FileScreenState extends ConsumerState<FileScreen> {
  // UI 컨트롤러
  final TextEditingController _titleController = TextEditingController(
    text: "새 페이지",
  );
  final TextEditingController _tagsController = TextEditingController();
  final TextEditingController _aiPromptController = TextEditingController();

  String _createdDate = DateFormat('yyyy년 MM월 dd일').format(DateTime.now());

  // 메뉴(Overlay) 관련 변수
  OverlayEntry? _overlayEntry;
  int _activeBlockIndex = -1;
  int _menuSelectedIndex = 0;
  List<Map<String, dynamic>> _currentFilteredOptions = [];

  // 메뉴 옵션
  final List<Map<String, dynamic>> _allMenuOptions = [
    {
      'type': BlockType.h1,
      'label': '제목 1',
      'sub': 'H1',
      'icon': Icons.looks_one,
    },
    {
      'type': BlockType.h2,
      'label': '제목 2',
      'sub': 'H2',
      'icon': Icons.looks_two,
    },
    {'type': BlockType.h3, 'label': '제목 3', 'sub': 'H3', 'icon': Icons.looks_3},
    {
      'type': BlockType.text,
      'label': '텍스트',
      'sub': '기본',
      'icon': Icons.text_fields,
    },
    {
      'type': BlockType.bullet,
      'label': '글머리 기호',
      'sub': '목록',
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
    // [핵심] 화면 진입 시 DB에서 파일 내용 불러오기
    Future.microtask(() {
      ref.read(fileProvider.notifier).loadFile(widget.fileId);
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

  // [핵심] 뒤로가기 시 자동 저장
  Future<bool> _onWillPop() async {
    await ref.read(fileProvider.notifier).saveFile(widget.fileId);
    return true;
  }

  // --- Helper Methods ---

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

  // AI 요약 실행
  Future<void> _handleAIRequest() async {
    final success = await ref
        .read(fileProvider.notifier)
        .requestAISummary(
          fileId: widget.fileId, // 저장할 파일 ID 전달
          tags: _tagsController.text,
          prompt: _aiPromptController.text,
        );

    if (success && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("✨ 요약 완료 및 저장됨!")));
    }
  }

  // --- Overlay Logic (기존 유지) ---
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
        width: 280,
        child: CompositedTransformFollower(
          link: block.layerLink,
          showWhenUnlinked: false,
          offset: const Offset(0, 30),
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(6),
            color: const Color(0xFF252525),
            child: Container(
              constraints: const BoxConstraints(maxHeight: 300),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.withOpacity(0.2)),
                borderRadius: BorderRadius.circular(6),
              ),
              child: ListView.builder(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                itemCount: _currentFilteredOptions.length,
                itemBuilder: (context, i) {
                  final option = _currentFilteredOptions[i];
                  final isSelected = i == _menuSelectedIndex;
                  return Container(
                    color: isSelected ? Colors.white.withOpacity(0.1) : null,
                    child: ListTile(
                      dense: true,
                      visualDensity: VisualDensity.compact,
                      leading: Icon(
                        option['icon'],
                        size: 18,
                        color: Colors.grey[400],
                      ),
                      title: Text(
                        option['label'],
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                        ),
                      ),
                      trailing: Text(
                        option['sub'],
                        style: TextStyle(color: Colors.grey[600], fontSize: 11),
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

  void _handleKeyEvent(RawKeyEvent event, int index) {
    if (event is! RawKeyDownEvent) return;
    final blocks = ref.read(fileProvider).blocks;

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
      if (blocks[index].controller.text.isEmpty && index > 0) {
        _deleteBlock(index);
      }
    }
  }

  // --- UI Build ---

  @override
  Widget build(BuildContext context) {
    final fileState = ref.watch(fileProvider);
    final blocks = fileState.blocks;
    final isLoading = fileState.isLoading; // [수정됨] isLoadingAI -> isLoading

    final bool isWideScreen = MediaQuery.of(context).size.width > 800;

    // [핵심] WillPopScope로 감싸서 뒤로가기 시 자동 저장
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        backgroundColor: const Color(0xFF191919),

        // 상단 앱바 (저장 버튼 추가)
        appBar: AppBar(
          backgroundColor: const Color(0xFF191919),
          elevation: 0,
          leading: BackButton(
            onPressed: () async {
              await _onWillPop(); // 저장 후 닫기
              Navigator.pop(context);
            },
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.save),
              onPressed: () async {
                await ref.read(fileProvider.notifier).saveFile(widget.fileId);
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text("저장되었습니다.")));
              },
            ),
          ],
        ),

        floatingActionButton: isWideScreen
            ? null
            : FloatingActionButton.extended(
                onPressed: isLoading ? null : _handleAIRequest,
                backgroundColor: const Color(0xFFCCFF66),
                icon: isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.black,
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.auto_awesome, color: Colors.black),
                label: Text(isLoading ? "분석 중" : "AI 요약"),
              ),

        body: GestureDetector(
          onTap: _removeOverlay,
          child: isLoading && blocks.isEmpty
              ? const Center(child: CircularProgressIndicator()) // 로딩 중일 때
              : Row(
                  children: [
                    // [LEFT] 에디터 영역
                    Expanded(
                      flex: 3,
                      child: CustomScrollView(
                        slivers: [
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(
                                50,
                                20,
                                50,
                                10,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  TextField(
                                    controller: _titleController,
                                    style: const TextStyle(
                                      fontSize: 40,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.grey,
                                    ),
                                    decoration: const InputDecoration(
                                      border: InputBorder.none,
                                      hintText: '제목 없음',
                                      hintStyle: TextStyle(color: Colors.grey),
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                  _buildPropertyRow(
                                    Icons.calendar_today,
                                    "작성일",
                                    _createdDate,
                                  ),
                                  _buildPropertyRow(
                                    Icons.people,
                                    "작성한 사람",
                                    "사용자",
                                  ),
                                  const SizedBox(height: 10),
                                  const Divider(
                                    color: Colors.grey,
                                    thickness: 0.5,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          SliverPadding(
                            padding: const EdgeInsets.symmetric(horizontal: 50),
                            sliver: SliverList(
                              delegate: SliverChildBuilderDelegate(
                                (context, index) =>
                                    _buildBlockItem(index, blocks[index]),
                                childCount: blocks.length,
                              ),
                            ),
                          ),
                          const SliverToBoxAdapter(
                            child: SizedBox(height: 100),
                          ),
                        ],
                      ),
                    ),

                    if (isWideScreen)
                      Container(width: 1, color: Colors.grey.withOpacity(0.2)),

                    // [RIGHT] AI 사이드바
                    if (isWideScreen)
                      Expanded(
                        flex: 1,
                        child: Container(
                          color: const Color(0xFF1E1E1E),
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "AI Assistant",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 24),

                              const Text(
                                "TAGS",
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextField(
                                controller: _tagsController,
                                style: const TextStyle(color: Colors.white),
                                decoration: InputDecoration(
                                  filled: true,
                                  fillColor: Colors.black,
                                  hintText: "태그 입력",
                                  hintStyle: TextStyle(color: Colors.grey[700]),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide.none,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 24),

                              const Text(
                                "PROMPT",
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextField(
                                controller: _aiPromptController,
                                maxLines: 4,
                                style: const TextStyle(color: Colors.white),
                                decoration: InputDecoration(
                                  filled: true,
                                  fillColor: Colors.black,
                                  hintText: "요청사항 입력",
                                  hintStyle: TextStyle(color: Colors.grey[700]),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide.none,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 24),

                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: isLoading
                                      ? null
                                      : _handleAIRequest,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFCCFF66),
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 16,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  icon: isLoading
                                      ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            color: Colors.black,
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Icon(
                                          Icons.auto_awesome,
                                          color: Colors.black,
                                        ),
                                  label: Text(
                                    isLoading ? "분석 중..." : "AI 요약 실행",
                                    style: const TextStyle(
                                      color: Colors.black,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
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
        ),
      ),
    );
  }

  Widget _buildPropertyRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey[500]),
          const SizedBox(width: 10),
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(color: Colors.grey[500], fontSize: 14),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBlockItem(int index, Block block) {
    bool isCode = block.type == BlockType.code;
    return RawKeyboardListener(
      focusNode: FocusNode(),
      onKey: (event) => _handleKeyEvent(event, index),
      child: Container(
        margin: EdgeInsets.only(top: 4, bottom: isCode ? 10 : 4),
        padding: isCode ? const EdgeInsets.all(12) : null,
        decoration: isCode
            ? BoxDecoration(
                color: const Color(0xFF2C2C2C),
                borderRadius: BorderRadius.circular(4),
              )
            : null,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (block.type == BlockType.bullet)
              const Padding(
                padding: EdgeInsets.only(top: 8, right: 10, left: 4),
                child: Icon(Icons.circle, size: 6, color: Colors.white70),
              ),
            if (block.type == BlockType.checkbox)
              Padding(
                padding: const EdgeInsets.only(top: 2, right: 8),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: Checkbox(
                    value: block.isChecked,
                    activeColor: Colors.blueAccent,
                    side: const BorderSide(color: Colors.grey),
                    onChanged: (val) => ref
                        .read(fileProvider.notifier)
                        .toggleCheckbox(index, val!),
                  ),
                ),
              ),
            Expanded(
              child: CompositedTransformTarget(
                link: block.layerLink,
                child: TextField(
                  controller: block.controller,
                  focusNode: block.focusNode,
                  maxLines: null,
                  style: _getStyleForBlock(block.type),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                    hintText: _getHintText(block, index),
                    hintStyle: TextStyle(color: Colors.grey.withOpacity(0.5)),
                  ),
                  onChanged: (text) => _handleTextChanged(text, index),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String? _getHintText(Block block, int index) {
    final blocksLength = ref.read(fileProvider).blocks.length;
    if (block.type == BlockType.h1) return "제목 1";
    if (block.type == BlockType.h2) return "제목 2";
    if (block.type == BlockType.h3) return "제목 3";
    if (block.type == BlockType.code) return "코드 입력...";
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
        return const TextStyle(
          fontSize: 30,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        );
      case BlockType.h2:
        return const TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        );
      case BlockType.h3:
        return const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        );
      case BlockType.code:
        return const TextStyle(
          fontSize: 14,
          fontFamily: 'Courier',
          color: Color(0xFFFF5252),
        );
      case BlockType.text:
      default:
        return const TextStyle(fontSize: 16, color: Colors.white, height: 1.5);
    }
  }
}
