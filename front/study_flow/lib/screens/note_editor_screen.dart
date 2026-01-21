import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

// -----------------------------------------------------------------------------
// 1. Models & Enums
// -----------------------------------------------------------------------------
enum BlockType { text, h1, h2, h3, bullet, checkbox, code }

class Block {
  String id;
  BlockType type;
  TextEditingController controller;
  FocusNode focusNode;
  bool isChecked;
  final LayerLink layerLink = LayerLink();

  Block({
    required this.id,
    this.type = BlockType.text,
    String content = '',
    this.isChecked = false,
  }) : controller = TextEditingController(text: content),
       focusNode = FocusNode();

  // 상태 불변성을 위해 dispose는 위젯 트리에서 관리하거나,
  // 리스트에서 제거될 때 명시적으로 호출해야 합니다.
  void dispose() {
    controller.dispose();
    focusNode.dispose();
  }
}

// -----------------------------------------------------------------------------
// 2. Riverpod Provider & Notifier
// -----------------------------------------------------------------------------

// 블록 리스트를 관리하는 Provider
final blockListProvider =
    StateNotifierProvider.autoDispose<BlockListNotifier, List<Block>>((ref) {
      return BlockListNotifier();
    });

class BlockListNotifier extends StateNotifier<List<Block>> {
  BlockListNotifier() : super([]) {
    // 초기화 시 첫 번째 블록 추가
    addBlock(0, type: BlockType.text);
  }

  // 블록 추가
  void addBlock(
    int index, {
    BlockType type = BlockType.text,
    String initialContent = "",
  }) {
    final newBlock = Block(
      id: DateTime.now().toIso8601String() + index.toString(),
      type: type,
      content: initialContent,
    );

    // 리스트 불변성 유지하며 삽입
    state = [...state]..insert(index, newBlock);
  }

  // 블록 삭제
  void removeBlock(int index) {
    if (state.length <= 1) return; // 최소 1개 유지

    final targetBlock = state[index];
    targetBlock.dispose(); // 리소스 해제

    state = [...state]..removeAt(index);
  }

  // 블록 타입 변경 (명령어 실행 시)
  void updateBlockType(int index, BlockType newType) {
    final block = state[index];
    block.type = newType;
    block.controller.text = ""; // 명령어 텍스트 초기화
    if (newType == BlockType.checkbox) block.isChecked = false;

    // 객체 내부 속성만 바뀌었으므로 state를 새로 할당해 리빌드 트리거
    state = [...state];
  }

  // 체크박스 토글
  void toggleCheckbox(int index, bool value) {
    state[index].isChecked = value;
    state = [...state];
  }

  // 전체 dispose (Provider가 autoDispose될 때 호출됨)
  @override
  void dispose() {
    for (var block in state) {
      block.dispose();
    }
    super.dispose();
  }
}

// -----------------------------------------------------------------------------
// 3. UI Screen (ConsumerStatefulWidget)
// -----------------------------------------------------------------------------

class NotionEditorScreen extends ConsumerStatefulWidget {
  const NotionEditorScreen({super.key});

  @override
  ConsumerState<NotionEditorScreen> createState() => _NotionEditorScreenState();
}

class _NotionEditorScreenState extends ConsumerState<NotionEditorScreen> {
  // 헤더 데이터 (로컬 상태 유지)
  final TextEditingController _titleController = TextEditingController(
    text: "새 페이지",
  );

  // [NEW] 태그와 커스텀 프롬프트 입력 컨트롤러 추가
  final TextEditingController _tagsController = TextEditingController();
  final TextEditingController _aiPromptController = TextEditingController();

  String _createdDate = DateFormat('yyyy년 MM월 dd일').format(DateTime.now());
  bool _isLoadingAI = false; // 로딩 상태

  // 메뉴(Overlay) 관련 상태는 UI 인터랙션이 강하므로 여기 둡니다.
  OverlayEntry? _overlayEntry;
  int _activeBlockIndex = -1;
  int _menuSelectedIndex = 0;
  List<Map<String, dynamic>> _currentFilteredOptions = [];

  // 메뉴 옵션 정의
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
  void dispose() {
    _tagsController.dispose();
    _aiPromptController.dispose(); // 해제
    _removeOverlay();
    _titleController.dispose();
    super.dispose();
  }

  // --- Helper Methods using Riverpod ---

  void _addNewBlock(int index) {
    // 1. 상태 업데이트 (Provider)
    ref.read(blockListProvider.notifier).addBlock(index);

    // 2. 포커스 이동 (UI Logic)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // state가 갱신된 후 리스트를 다시 가져옴
      final blocks = ref.read(blockListProvider);
      if (index < blocks.length) {
        blocks[index].focusNode.requestFocus();
      }
    });
  }

  void _deleteBlock(int index) {
    // 1. 상태 업데이트
    ref.read(blockListProvider.notifier).removeBlock(index);

    // 2. 포커스 이동 (이전 블록으로)
    if (index > 0) {
      _removeOverlay();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final blocks = ref.read(blockListProvider);
        final prevBlock = blocks[index - 1];
        prevBlock.focusNode.requestFocus();
        // 커서를 맨 끝으로
        prevBlock.controller.selection = TextSelection.fromPosition(
          TextPosition(offset: prevBlock.controller.text.length),
        );
      });
    }
  }

  void _applyTypeChange({required int index, required BlockType newType}) {
    _removeOverlay();

    // 1. 상태 업데이트
    ref.read(blockListProvider.notifier).updateBlockType(index, newType);

    // 2. 포커스 유지
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final blocks = ref.read(blockListProvider);
      blocks[index].focusNode.requestFocus();
    });
  }

  // --- Overlay Logic (UI State) ---
  // 오버레이는 BuildContext와 RenderBox 위치 등 UI 고유값이 필요하므로 위젯 내부에 둡니다.

  void _showOverlay(BuildContext context, int index, String query) {
    _activeBlockIndex = index;
    final blocks = ref.read(blockListProvider); // 현재 블록 리스트 접근
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
    if (_menuSelectedIndex >= _currentFilteredOptions.length)
      _menuSelectedIndex = 0;

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
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.withOpacity(0.2)),
                borderRadius: BorderRadius.circular(6),
              ),
              constraints: const BoxConstraints(maxHeight: 300),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
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

  // --- Keyboard Handling ---

  void _handleKeyEvent(RawKeyEvent event, int index) {
    if (event is! RawKeyDownEvent) return;

    final blocks = ref.read(blockListProvider); // 블록 상태 읽기

    // 1. 메뉴가 열려있을 때
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

    // 2. 일반 에디터 동작
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

  // [NEW] AI 요약 요청 함수
  Future<void> _requestAISummary() async {
    final blocks = ref.read(blockListProvider);

    // 1. 본문 내용 합치기
    String content = blocks.map((b) => b.controller.text).join("\n");
    if (content.trim().isEmpty) return;

    setState(() => _isLoadingAI = true);

    try {
      // 2. 백엔드로 요청 (Android 에뮬레이터 기준 10.0.2.2, iOS는 localhost)
      final response = await http.post(
        Uri.parse('http://localhost:8000/api/ai/summarize'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "content": content,
          "tags": _tagsController.text, // 입력한 태그 전달
          "custom_prompt": _aiPromptController.text, // 입력한 프롬프트 전달
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        String summary = data['summary'];

        // 3. 요약 결과를 새로운 블록으로 추가 (맨 아래에)
        int lastIndex = ref.read(blockListProvider).length;

        // "AI 요약" 헤더 추가
        ref
            .read(blockListProvider.notifier)
            .addBlock(
              lastIndex,
              type: BlockType.h2,
              initialContent: "✨ AI 요약 결과",
            );

        // 요약 내용 추가
        ref
            .read(blockListProvider.notifier)
            .addBlock(
              lastIndex + 1,
              type: BlockType.text,
              initialContent: summary,
            );

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("요약이 완료되었습니다!")));
      } else {
        throw Exception("Server Error: ${response.statusCode}");
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("AI 요청 실패: $e")));
    } finally {
      setState(() => _isLoadingAI = false);
    }
  }

  @override
  @override
  Widget build(BuildContext context) {
    // [Riverpod] 블록 리스트 구독
    final blocks = ref.watch(blockListProvider);

    // 화면 너비가 좁으면(모바일) 분할하지 않음 (반응형)
    final bool isWideScreen = MediaQuery.of(context).size.width > 800;

    return Scaffold(
      backgroundColor: const Color(0xFF191919),
      // 분할 화면일 때는 FAB 대신 사이드바에 버튼을 둡니다.
      floatingActionButton: isWideScreen
          ? null
          : FloatingActionButton.extended(
              onPressed: _isLoadingAI ? null : _requestAISummary,
              backgroundColor: const Color(0xFFCCFF66),
              label: Text(_isLoadingAI ? "생성 중..." : "AI 요약"),
              icon: const Icon(Icons.auto_awesome),
            ),

      body: GestureDetector(
        onTap: _removeOverlay, // 화면 어디든 누르면 메뉴 닫기
        child: Row(
          children: [
            // ---------------------------------------------------------
            // [LEFT] 에디터 영역 (Flex: 2 or 3)
            // ---------------------------------------------------------
            Expanded(
              flex: 3,
              child: CustomScrollView(
                slivers: [
                  // 1. 헤더 (제목, 속성)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(50, 60, 50, 10),
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
                          _buildPropertyRow(Icons.people, "작성한 사람", "이승희"),
                          const SizedBox(height: 10),
                          const Divider(color: Colors.grey, thickness: 0.5),
                        ],
                      ),
                    ),
                  ),

                  // 2. 블록 리스트
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

                  // 하단 여백
                  const SliverToBoxAdapter(child: SizedBox(height: 100)),
                ],
              ),
            ),

            // ---------------------------------------------------------
            // [Divider] 구분선
            // ---------------------------------------------------------
            if (isWideScreen)
              Container(width: 1, color: Colors.grey.withOpacity(0.2)),

            // ---------------------------------------------------------
            // [RIGHT] AI 사이드바 (Flex: 1) - 넓은 화면일 때만 표시
            // ---------------------------------------------------------
            if (isWideScreen)
              Expanded(
                flex: 1,
                child: Container(
                  color: const Color(0xFF1E1E1E), // 사이드바 배경색 (약간 다르게)
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 40),
                      const Text(
                        "AI Assistant",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 24),

                      // 태그 입력
                      const Text(
                        "TAGS",
                        style: TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _tagsController,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: Colors.black,
                          hintText: "태그 입력 (예: 회의, 중요)",
                          hintStyle: TextStyle(color: Colors.grey[700]),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // 프롬프트 입력
                      const Text(
                        "PROMPT",
                        style: TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _aiPromptController,
                        maxLines: 3,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: Colors.black,
                          hintText: "AI에게 요청할 내용을 적으세요.\n(예: 3줄로 요약해줘)",
                          hintStyle: TextStyle(color: Colors.grey[700]),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // 실행 버튼
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _isLoadingAI ? null : _requestAISummary,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFCCFF66),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          icon: _isLoadingAI
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
                            _isLoadingAI ? "분석 중..." : "AI 요약 실행",
                            style: const TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),

                      const Spacer(),

                      // 하단 안내
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.black,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.grey.withOpacity(0.3),
                          ),
                        ),
                        child: const Text(
                          "💡 Tip: 왼쪽 에디터에 내용을 작성하고 우측 버튼을 누르면, AI가 내용을 분석하여 맨 아래에 요약을 추가합니다.",
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: 13,
                            height: 1.4,
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

  // [NEW] 편집 가능한 속성 행 위젯
  Widget _buildEditablePropertyRow({
    required IconData icon,
    required String label,
    required TextEditingController controller,
    String hint = "",
  }) {
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
            child: TextField(
              controller: controller,
              style: const TextStyle(color: Colors.white70, fontSize: 14),
              decoration: InputDecoration(
                isDense: true,
                contentPadding: EdgeInsets.zero,
                border: InputBorder.none,
                hintText: hint,
                hintStyle: TextStyle(color: Colors.grey.withOpacity(0.5)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBlockItem(int index, Block block) {
    bool isCode = block.type == BlockType.code;

    return RawKeyboardListener(
      focusNode: FocusNode(), // 이벤트를 잡기 위한 가상 노드
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
                    onChanged: (val) {
                      ref
                          .read(blockListProvider.notifier)
                          .toggleCheckbox(index, val!);
                    },
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
    final blocksLength = ref.read(blockListProvider).length;
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
