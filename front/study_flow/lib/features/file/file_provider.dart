import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:study_flow/features/file/file_model.dart';
import 'dart:convert';
import 'dart:io'; // Platform 감지용

import '../../models/block_model.dart';

import '../../core/local_db_helper.dart';

// -----------------------------------------------------------------------------
// 상태 클래스 (데이터)
// -----------------------------------------------------------------------------
class FileState {
  final List<Block> blocks;
  final bool isLoading; // 로딩 상태 (DB 로딩 + AI 요청 공용)

  FileState({required this.blocks, this.isLoading = false});

  FileState copyWith({List<Block>? blocks, bool? isLoading}) {
    return FileState(
      blocks: blocks ?? this.blocks,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

// -----------------------------------------------------------------------------
// 프로바이더 정의
// -----------------------------------------------------------------------------
final fileProvider = StateNotifierProvider.autoDispose<FileNotifier, FileState>(
  (ref) {
    return FileNotifier();
  },
);

// -----------------------------------------------------------------------------
// 노티파이어 (비즈니스 로직)
// -----------------------------------------------------------------------------
class FileNotifier extends StateNotifier<FileState> {
  FileNotifier() : super(FileState(blocks: []));

  // --- [DB Load] 파일 불러오기 ---
  // UI에 제목과 태그를 전달하기 위해 FileModel?을 반환하도록 수정함
  Future<FileModel?> loadFile(String fileId) async {
    state = state.copyWith(isLoading: true); // 로딩 시작

    final fileModel = await LocalDatabase.instance.getFile(fileId);

    if (fileModel != null) {
      // 1. 블록 내용(Content)이 있으면 파싱해서 상태 업데이트
      if (fileModel.content.isNotEmpty) {
        try {
          final List<dynamic> jsonList = jsonDecode(fileModel.content);
          final loadedBlocks = jsonList.map((e) => Block.fromJson(e)).toList();

          state = state.copyWith(blocks: loadedBlocks, isLoading: false);
        } catch (e) {
          print("JSON 파싱 에러: $e");
          _initEmptyBlock(); // 파싱 실패 시 기본 블록
        }
      } else {
        _initEmptyBlock(); // 내용 없으면 기본 블록
      }
      return fileModel; // [중요] UI에서 제목/태그를 쓰기 위해 모델 반환
    } else {
      _initEmptyBlock();
      return null; // 파일이 없으면 null 반환
    }
  }

  void _initEmptyBlock() {
    addBlock(0);
    state = state.copyWith(isLoading: false);
  }

  // --- [DB Save] 파일 저장하기 ---
  // 제목(title)과 태그(tags)도 함께 저장하도록 수정함
  Future<void> saveFile({
    required String fileId,
    required String title,
    required String tags,
  }) async {
    // 1. 현재 블록들을 JSON 리스트로 변환
    final List<Map<String, dynamic>> jsonList = state.blocks
        .map((b) => b.toJson())
        .toList();

    // 2. 문자열로 인코딩
    final String contentJson = jsonEncode(jsonList);

    // 3. DB 업데이트 (제목, 태그, 내용 모두 업데이트)
    await LocalDatabase.instance.updateFile(
      id: fileId,
      title: title,
      tags: tags,
      content: contentJson,
    );
    print("저장 완료: $title");
  }

  // --- 블록 관리 로직 ---

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

  // --- AI 기능 ---
  Future<bool> requestAISummary({
    required String fileId,
    required String tags,
    required String prompt,
  }) async {
    // 1. 본문 내용 합치기
    String content = state.blocks.map((b) => b.controller.text).join("\n");
    if (content.trim().isEmpty) return false;

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

        // 결과 블록 추가
        int lastIndex = state.blocks.length;
        addBlock(lastIndex, type: BlockType.h2, initialContent: "✨ AI 요약 결과");
        addBlock(lastIndex + 1, type: BlockType.text, initialContent: summary);

        // [중요] 여기서는 저장하지 않고 true만 리턴합니다.
        // 저장은 UI(Screen)에서 제목/태그 정보와 함께 saveFile을 호출하여 처리합니다.
        return true;
      } else {
        print("Server Error: ${response.statusCode}");
        return false;
      }
    } catch (e) {
      print("AI Request Failed: $e");
      return false;
    } finally {
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
