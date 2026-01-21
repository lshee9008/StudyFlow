import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:study_flow/features/file/file_model.dart';
import 'dart:convert';
import 'dart:io';

import '../../models/block_model.dart';

import '../../core/local_db_helper.dart';

class FileState {
  final List<Block> blocks;
  final bool isLoading;
  final String? icon;

  FileState({required this.blocks, this.isLoading = false, this.icon});

  FileState copyWith({List<Block>? blocks, bool? isLoading, String? icon}) {
    return FileState(
      blocks: blocks ?? this.blocks,
      isLoading: isLoading ?? this.isLoading,
      icon: icon ?? this.icon,
    );
  }
}

final fileProvider = StateNotifierProvider.autoDispose<FileNotifier, FileState>(
  (ref) => FileNotifier(),
);

class FileNotifier extends StateNotifier<FileState> {
  FileNotifier() : super(FileState(blocks: []));

  Future<FileModel?> loadFile(String fileId) async {
    state = state.copyWith(isLoading: true);
    final fileModel = await LocalDatabase.instance.getFile(fileId);

    if (fileModel != null) {
      if (fileModel.content.isNotEmpty) {
        try {
          final List<dynamic> jsonList = jsonDecode(fileModel.content);
          final loadedBlocks = jsonList.map((e) => Block.fromJson(e)).toList();
          state = state.copyWith(
            blocks: loadedBlocks,
            isLoading: false,
            icon: fileModel.icon,
          );
        } catch (e) {
          _initEmptyBlock();
        }
      } else {
        _initEmptyBlock();
      }
      return fileModel;
    } else {
      _initEmptyBlock();
      return null;
    }
  }

  void _initEmptyBlock() {
    addBlock(0);
    state = state.copyWith(isLoading: false);
  }

  void updateIcon(String? newIcon) {
    state = state.copyWith(icon: newIcon);
  }

  Future<void> saveFile({
    required String fileId,
    required String title,
    required String tags,
  }) async {
    final List<Map<String, dynamic>> jsonList = state.blocks
        .map((b) => b.toJson())
        .toList();
    final String contentJson = jsonEncode(jsonList);

    await LocalDatabase.instance.updateFile(
      id: fileId,
      title: title,
      tags: tags,
      content: contentJson,
      icon: state.icon,
    );
  }

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
    newBlocks[index].dispose();
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

  // [수정] 체크박스 상태 변경 로직
  void toggleCheckbox(int index, bool value) {
    // 불변성을 지키기 위해 깊은 복사 혹은 새로운 리스트 생성 필요
    final blocks = [...state.blocks];
    final targetBlock = blocks[index];

    // 블록 내부 상태 변경 (Block 클래스에 isChecked 필드가 있어야 함)
    targetBlock.isChecked = value;

    state = state.copyWith(blocks: blocks);
  }

  Future<bool> requestAISummary({
    required String fileId,
    required String tags,
    required String prompt,
  }) async {
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
        int lastIndex = state.blocks.length;
        addBlock(lastIndex, type: BlockType.h2, initialContent: "✨ AI 요약 결과");
        addBlock(lastIndex + 1, type: BlockType.text, initialContent: summary);
        return true;
      } else {
        return false;
      }
    } catch (e) {
      return false;
    } finally {
      state = state.copyWith(isLoading: false);
    }
  }
}
