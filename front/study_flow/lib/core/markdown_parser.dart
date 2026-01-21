import '../models/block_model.dart';

class MarkdownParser {
  /// 마크다운 문자열을 분석하여 Block 리스트로 변환합니다.
  static List<Map<String, dynamic>> parse(String text) {
    final List<String> lines = text.split('\n');
    final List<Map<String, dynamic>> parsedBlocks = [];

    for (String line in lines) {
      String content = line;
      BlockType type = BlockType.text;

      // 마크다운 문법 파싱
      if (line.startsWith('# ')) {
        type = BlockType.h1;
        content = line.substring(2);
      } else if (line.startsWith('## ')) {
        type = BlockType.h2;
        content = line.substring(3);
      } else if (line.startsWith('### ')) {
        type = BlockType.h3;
        content = line.substring(4);
      } else if (line.startsWith('- ') || line.startsWith('* ')) {
        type = BlockType.bullet;
        content = line.substring(2);
      } else if (line.startsWith('[] ') || line.startsWith('- [ ] ')) {
        type = BlockType.checkbox;
        content = line.replaceFirst(RegExp(r'^(\[\] |-\s\[\s\]\s)'), '');
      } else if (line.startsWith('```')) {
        type = BlockType.code;
        content = line.replaceAll('```', '');
      }

      // 빈 줄은 무시하거나 빈 텍스트 블록으로 처리
      if (content.trim().isEmpty && type != BlockType.text) continue;

      parsedBlocks.add({'type': type, 'content': content.trim()});
    }

    return parsedBlocks;
  }
}
