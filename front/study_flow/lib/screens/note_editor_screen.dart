import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import 'package:flutter/material.dart';

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
}

class NotionEditorScreen extends StatefulWidget {
  const NotionEditorScreen({super.key});

  @override
  State<NotionEditorScreen> createState() => _NotionEditorScreenState();
}

class _NotionEditorScreenState extends State<NotionEditorScreen> {
  // 페이지 속성 (헤더) 데이터
  final TextEditingController _titleController = TextEditingController(
    text: "새 페이지",
  );
  String _createdDate = DateFormat('yyyy년 MM월 dd일').format(DateTime.now());
  String _author = "비어 있음";
  String _tags = "비어 있음";

  // 본문 블록 데이터
  List<Block> blocks = [];

  // 메뉴 관련 상태
  OverlayEntry? _overlayEntry;
  int _activeBlockIndex = -1;
  int _menuSelectedIndex = 0; // 키보드 탐색용 인덱스
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
  void initState() {
    super.initState();
    // 초기 블록 생성
    _addBlock(0, type: BlockType.text);
  }

  @override
  void dispose() {
    _removeOverlay();
    _titleController.dispose();
    for (var block in blocks) {
      block.controller.dispose();
      block.focusNode.dispose();
    }
    super.dispose();
  }

  // --- 블록 관리 로직 ---
  void _addBlock(
    int index, {
    BlockType type = BlockType.text,
    String initialContent = "",
  }) {
    setState(() {
      Block newBlock = Block(
        id: DateTime.now().toIso8601String() + index.toString(),
        type: type,
        content: initialContent,
      );
      blocks.insert(index, newBlock);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      blocks[index].focusNode.requestFocus();
    });
  }

  void _removeBlock(int index) {
    if (blocks.length <= 1) return;
    _removeOverlay();
    setState(() {
      blocks.removeAt(index);
    });
    if (index > 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        blocks[index - 1].focusNode.requestFocus();
        blocks[index - 1].controller.selection = TextSelection.fromPosition(
          TextPosition(offset: blocks[index - 1].controller.text.length),
        );
      });
    }
  }

  // --- 오버레이(메뉴) 로직 ---
  void _showOverlay(BuildContext context, int index, String query) {
    _activeBlockIndex = index;
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
                      onTap: () => _applyCommand(
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

  void _applyCommand({required int index, required BlockType newType}) {
    _removeOverlay();
    setState(() {
      blocks[index].type = newType;
      blocks[index].controller.text = "";
      if (newType == BlockType.checkbox) blocks[index].isChecked = false;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      blocks[index].focusNode.requestFocus();
    });
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
        _applyCommand(
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
        _addBlock(index + 1);
      }
    } else if (event.logicalKey == LogicalKeyboardKey.backspace) {
      if (blocks[index].controller.text.isEmpty && index > 0) {
        _removeBlock(index);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF191919),
      body: GestureDetector(
        onTap: _removeOverlay,
        child: CustomScrollView(
          slivers: [
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
                    _buildPropertyRow(Icons.people, "작성한 사람", _author),
                    _buildPropertyRow(Icons.tag, "태그", _tags),
                    const SizedBox(height: 10),
                    TextButton.icon(
                      onPressed: () {},
                      icon: const Icon(Icons.add, size: 16, color: Colors.grey),
                      label: const Text(
                        "속성 추가",
                        style: TextStyle(color: Colors.grey),
                      ),
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        alignment: Alignment.centerLeft,
                      ),
                    ),
                    const Divider(color: Colors.grey, thickness: 0.5),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 50),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) => _buildBlockItem(index),
                  childCount: blocks.length,
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 300)),
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

  Widget _buildBlockItem(int index) {
    Block block = blocks[index];
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
                    onChanged: (val) {
                      setState(() => block.isChecked = val!);
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
                    hintText: block.type == BlockType.h1
                        ? "제목 1"
                        : block.type == BlockType.h2
                        ? "제목 2"
                        : block.type == BlockType.h3
                        ? "제목 3"
                        : block.type == BlockType.code
                        ? "코드 입력..."
                        : (block.controller.text.isEmpty &&
                              index == blocks.length - 1)
                        ? "'/'를 입력하여 명령어 사용"
                        : null,
                    hintStyle: TextStyle(color: Colors.grey.withOpacity(0.5)),
                  ),
                  onChanged: (text) {
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
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
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
