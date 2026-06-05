import 'package:flutter/material.dart';

enum BlockType {
  text,      // 일반 텍스트
  h1, h2, h3, // 제목
  bullet,    // 불릿 리스트
  number,    // 번호 리스트
  checkbox,  // 체크박스
  code,      // 코드 블록
  quote,     // 블록쿼트
  image,     // 이미지
  table,     // 테이블
  hr,        // 수평선
  pdf,       // PDF 문서
  math,      // LaTeX 수식
}

class Block {
  String id;
  BlockType type;
  TextEditingController controller;
  UndoHistoryController undoController;
  FocusNode focusNode;
  bool isChecked;
  Map<String, dynamic>? metadata;
  final LayerLink layerLink = LayerLink();

  Block({
    required this.id,
    this.type = BlockType.text,
    String content = '',
    this.isChecked = false,
    this.metadata,
  }) : controller = TextEditingController(text: content),
       undoController = UndoHistoryController(),
       focusNode = FocusNode();

  // 1. DB에 저장하기 위해 JSON으로 변환 (Serialization)
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.index, // Enum을 숫자로 저장 (0, 1, 2...)
      'content': controller.text,
      'isChecked': isChecked,
      'metadata': metadata,
    };
  }

  // 2. DB에서 불러온 JSON을 객체로 변환 (Deserialization)
  factory Block.fromJson(Map<String, dynamic> json) {
    return Block(
      id: json['id'],
      type: BlockType.values[json['type']], // 숫자를 다시 Enum으로
      content: json['content'] ?? '',
      isChecked: json['isChecked'] ?? false,
      metadata: json['metadata'] != null ? Map<String, dynamic>.from(json['metadata']) : null,
    );
  }

  void dispose() {
    controller.dispose();
    undoController.dispose();
    focusNode.dispose();
  }
}
