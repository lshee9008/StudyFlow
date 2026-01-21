import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:study_flow/core/local_db_helper.dart';
import 'dart:convert';
import 'dart:io'; // Platform 감지용
import '../../models/block_model.dart';

// 상태 클래스 (데이터)
class FileState {
  final List<Block> blocks;
  final bool isLoading; // 로딩 상태 추가

  FileState({required this.blocks, this.isLoading = false});

  FileState copyWith({List<Block>? blocks, bool? isLoading}) {
    return FileState(
      blocks: blocks ?? this.blocks,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

// 프로바이더 정의
final fileProvider = StateNotifierProvider.autoDispose<FileNotifier, FileState>(
  (ref) {
    return FileNotifier();
  },
);

// 노티파이어 (로직)
class FileNotifier extends StateNotifier<FileState> {
  FileNotifier() : super(FileState(blocks: []));

  // --- [NEW] DB 불러오기 (Load) ---
  Future<void> loadFile(String fileId) async {
    state = state.copyWith(isLoading: true); // 로딩 시작

    final fileModel = await LocalDatabase.instance.getFile(fileId);

    if (fileModel != null && fileModel.content.isNotEmpty) {
      try {
        // 1. JSON 문자열 파싱
        final List<dynamic> jsonList = jsonDecode(fileModel.content);
        // 2. Block 객체 리스트로 변환
        final loadedBlocks = jsonList.map((e) => Block.fromJson(e)).toList();

        state = state.copyWith(blocks: loadedBlocks, isLoading: false);
      } catch (e) {
        print("JSON 파싱 에러: $e");
        // 파싱 실패 시 기본 블록 하나 생성
        _initEmptyBlock();
      }
    } else {
      // 내용이 없으면 기본 블록 생성
      _initEmptyBlock();
    }
  }

  void _initEmptyBlock() {
    addBlock(0);
    state = state.copyWith(isLoading: false);
  }

  // --- [NEW] DB 저장하기 (Save) ---
  Future<void> saveFile(String fileId) async {
    // 1. 현재 블록들을 JSON 리스트로 변환
    final List<Map<String, dynamic>> jsonList = state.blocks
        .map((b) => b.toJson())
        .toList();

    // 2. 문자열로 인코딩
    final String contentJson = jsonEncode(jsonList);

    // 3. DB 업데이트
    await LocalDatabase.instance.updateFileContent(fileId, contentJson);
    print("저장 완료: $fileId");
  }

  // --- 기존 블록 관리 로직 (addBlock 등) ---
  // (내용이 변경될 때마다 자동 저장을 원하면 여기서 saveFile을 호출할 수도 있음)

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
    final newBlocks = [...state.blocks];
    newBlocks.insert(index, newBlock);
    state = state.copyWith(blocks: newBlocks);
  }

  void removeBlock(int index) {
    if (state.blocks.length <= 1) return;

    final newBlocks = [...state.blocks];
    final target = newBlocks[index];
    target.dispose(); // 리소스 해제
    newBlocks.removeAt(index);

    state = state.copyWith(blocks: newBlocks);
  }

  void updateBlockType(int index, BlockType newType) {
    final blocks = [...state.blocks];
    final block = blocks[index];

    block.type = newType;
    block.controller.text = "";
    if (newType == BlockType.checkbox) block.isChecked = false;

    state = state.copyWith(blocks: blocks);
  }

  void toggleCheckbox(int index, bool value) {
    final blocks = [...state.blocks];
    blocks[index].isChecked = value;
    state = state.copyWith(blocks: blocks);
  }

  // --- AI 기능 로직 ---

  // --- AI 기능 ---
  Future<bool> requestAISummary({
    required String fileId,
    required String tags,
    required String prompt,
  }) async {
    // 1. 본문 내용 합치기
    String content = state.blocks.map((b) => b.controller.text).join("\n");
    if (content.trim().isEmpty) return false;

    // [수정] isLoadingAI -> isLoading 으로 변경
    state = state.copyWith(isLoading: true);

    try {
      final String baseUrl = Platform.isAndroid
          ? 'http://10.0.2.2:8000'
          : 'http://localhost:8000';

      final response = await http.post(
        Uri.parse('$baseUrl/api/ai/summarize'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "content": content,
          "tags": tags,
          "custom_prompt": prompt,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        String summary = data['summary'];

        int lastIndex = state.blocks.length;
        addBlock(lastIndex, type: BlockType.h2, initialContent: "✨ AI 요약 결과");
        addBlock(lastIndex + 1, type: BlockType.text, initialContent: summary);

        // AI 결과 저장
        await saveFile(fileId);
        return true;
      } else {
        print("Server Error: ${response.statusCode}");
        return false;
      }
    } catch (e) {
      print("AI Request Failed: $e");
      return false;
    } finally {
      // [수정] isLoadingAI -> isLoading 으로 변경
      state = state.copyWith(isLoading: false);
    }
  }

  @override
  void dispose() {
    for (var block in state.blocks) {
      block.dispose();
    }
    super.dispose();
  }
}
