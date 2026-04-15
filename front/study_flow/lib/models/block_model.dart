import 'package:flutter/material.dart';

enum BlockType { text, h1, h2, h3, bullet, checkbox, code, number, quote }

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

  // 1. DB에 저장하기 위해 JSON으로 변환 (Serialization)
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.index, // Enum을 숫자로 저장 (0, 1, 2...)
      'content': controller.text,
      'isChecked': isChecked,
    };
  }

  // 2. DB에서 불러온 JSON을 객체로 변환 (Deserialization)
  factory Block.fromJson(Map<String, dynamic> json) {
    return Block(
      id: json['id'],
      type: BlockType.values[json['type']], // 숫자를 다시 Enum으로
      content: json['content'] ?? '',
      isChecked: json['isChecked'] ?? false,
    );
  }

  void dispose() {
    controller.dispose();
    focusNode.dispose();
  }
}
