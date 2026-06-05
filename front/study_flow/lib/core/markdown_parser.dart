import '../models/block_model.dart';

class MarkdownParser {
  /// 마크다운 문자열을 분석하여 Block 리스트로 변환합니다.
  ///
  /// 지원하는 마크다운:
  /// - 제목: # ~ ### (h1 ~ h3)
  /// - 리스트: - * (bullet), 1. (number), - [ ] (checkbox)
  /// - 코드: ``` (멀티라인 코드 블록)
  /// - 이미지: ![alt](url)
  /// - 테이블: |col|col| 형식
  /// - 인라인: **bold**, *italic*, `code`, [text](url)
  static List<Map<String, dynamic>> parse(String text) {
    final List<String> lines = text.split('\n');
    final List<Map<String, dynamic>> parsedBlocks = [];

    int i = 0;
    while (i < lines.length) {
      final line = lines[i];

      // 빈 줄 스킵
      if (line.trim().isEmpty) {
        i++;
        continue;
      }

      // ══════════════ 코드 블록 (```...```) ══════════════
      if (line.trim().startsWith('```')) {
        final codeLines = <String>[];
        // 언어 지정 파싱 (예: ```javascript)
        final langMatch = RegExp(r'^```(\w+)?').firstMatch(line);
        final language = langMatch?.group(1) ?? '';

        i++;
        // 종료 ``` 찾기
        while (i < lines.length && !lines[i].trim().startsWith('```')) {
          codeLines.add(lines[i]);
          i++;
        }
        i++; // 종료 ``` 스킵

        final code = codeLines.join('\n').trim();
        if (code.isNotEmpty) {
          parsedBlocks.add({
            'type': BlockType.code,
            'content': code,
            'language': language,
          });
        }
        continue;
      }

      // ══════════════ 테이블 (|...|...|) ══════════════
      if (line.trim().startsWith('|') && line.trim().endsWith('|')) {
        final tableLines = <String>[];
        while (i < lines.length &&
               lines[i].trim().startsWith('|') &&
               lines[i].trim().endsWith('|')) {
          tableLines.add(lines[i]);
          i++;
        }

        if (tableLines.length >= 2) {
          final rows = tableLines.map((l) {
            return l.split('|')
                .map((c) => c.trim())
                .where((c) => c.isNotEmpty)
                .toList();
          }).toList();

          parsedBlocks.add({
            'type': BlockType.table,
            'rows': rows,
          });
        }
        continue;
      }

      // ══════════════ 이미지 (![alt](url)) ══════════════
      final imgRegex = RegExp(r'!\[([^\]]*)\]\(([^)]+)\)');
      if (imgRegex.hasMatch(line)) {
        final match = imgRegex.firstMatch(line);
        if (match != null) {
          parsedBlocks.add({
            'type': BlockType.image,
            'alt': match.group(1) ?? 'image',
            'url': match.group(2) ?? '',
          });
          i++;
          continue;
        }
      }

      // ══════════════ 제목 (# ## ###) ══════════════
      if (line.startsWith('# ')) {
        parsedBlocks.add({
          'type': BlockType.h1,
          'content': line.substring(2).trim(),
        });
        i++;
        continue;
      }
      if (line.startsWith('## ')) {
        parsedBlocks.add({
          'type': BlockType.h2,
          'content': line.substring(3).trim(),
        });
        i++;
        continue;
      }
      if (line.startsWith('### ')) {
        parsedBlocks.add({
          'type': BlockType.h3,
          'content': line.substring(4).trim(),
        });
        i++;
        continue;
      }

      // ══════════════ 체크박스 (- [ ] ...) ══════════════
      final checkRegex = RegExp(r'^-\s*\[([x ])\]\s*(.+)$', caseSensitive: false);
      final checkMatch = checkRegex.firstMatch(line);
      if (checkMatch != null) {
        parsedBlocks.add({
          'type': BlockType.checkbox,
          'content': checkMatch.group(2)?.trim() ?? '',
          'isChecked': checkMatch.group(1)?.toLowerCase() == 'x',
        });
        i++;
        continue;
      }

      // ══════════════ 번호 리스트 (1. 2. ...) ══════════════
      final numRegex = RegExp(r'^(\d+)\.\s+(.+)$');
      final numMatch = numRegex.firstMatch(line);
      if (numMatch != null) {
        parsedBlocks.add({
          'type': BlockType.number,
          'content': numMatch.group(2)?.trim() ?? '',
          'number': int.tryParse(numMatch.group(1) ?? '1') ?? 1,
        });
        i++;
        continue;
      }

      // ══════════════ 불릿 리스트 (- * ) ══════════════
      if ((line.startsWith('- ') || line.startsWith('* '))) {
        parsedBlocks.add({
          'type': BlockType.bullet,
          'content': line.substring(2).trim(),
        });
        i++;
        continue;
      }

      // ══════════════ 블록쿼트 (> ...) ══════════════
      if (line.startsWith('> ')) {
        parsedBlocks.add({
          'type': BlockType.quote,
          'content': line.substring(2).trim(),
        });
        i++;
        continue;
      }

      // ══════════════ 수평선 (---, ***, ___) ══════════════
      if (RegExp(r'^(-{3,}|\*{3,}|_{3,})$').hasMatch(line.trim())) {
        parsedBlocks.add({
          'type': BlockType.hr,
          'content': '',
        });
        i++;
        continue;
      }

      // ══════════════ 일반 텍스트 ══════════════
      final content = _processInlineFormatting(line.trim());
      parsedBlocks.add({
        'type': BlockType.text,
        'content': content,
      });
      i++;
    }

    return parsedBlocks;
  }

  /// 인라인 포매팅 처리 (**bold**, *italic*, `code`, [text](url))
  ///
  /// NOTE: 실제 렌더링은 UI 레이어에서 수행합니다.
  /// 여기서는 마크다운 마크를 보존하거나 간단한 정보만 추출합니다.
  static String _processInlineFormatting(String text) {
    // 마크다운 마크는 유지하고, UI에서 flutter_markdown을 사용해 렌더링하면 됩니다.
    // 또는 직접 파싱할 수도 있습니다.
    // 현재는 단순히 텍스트를 반환합니다.
    return text;
  }

  /// 마크다운을 HTML로 변환 (선택사항, 필요시)
  static String toHtml(String markdown) {
    final blocks = parse(markdown);
    final html = StringBuffer();

    for (final block in blocks) {
      final type = block['type'] as BlockType;
      final content = block['content'] as String? ?? '';

      switch (type) {
        case BlockType.h1:
          html.writeln('<h1>$content</h1>');
        case BlockType.h2:
          html.writeln('<h2>$content</h2>');
        case BlockType.h3:
          html.writeln('<h3>$content</h3>');
        case BlockType.bullet:
          html.writeln('<li>$content</li>');
        case BlockType.number:
          html.writeln('<li>$content</li>');
        case BlockType.code:
          final lang = block['language'] as String? ?? '';
          html.writeln('<pre><code class="language-$lang">$content</code></pre>');
        case BlockType.quote:
          html.writeln('<blockquote>$content</blockquote>');
        case BlockType.image:
          final url = block['url'] as String? ?? '';
          final alt = block['alt'] as String? ?? '';
          html.writeln('<img src="$url" alt="$alt" />');
        case BlockType.table:
          final rows = block['rows'] as List? ?? [];
          html.writeln('<table>');
          for (final row in rows) {
            html.write('<tr>');
            for (final cell in (row as List)) {
              html.write('<td>$cell</td>');
            }
            html.writeln('</tr>');
          }
          html.writeln('</table>');
        case BlockType.hr:
          html.writeln('<hr />');
        case BlockType.pdf:
          final url = block['url'] as String? ?? content;
          html.writeln('<a href="$url">$url</a>');
        case BlockType.checkbox:
          final isChecked = block['isChecked'] as bool? ?? false;
          final checked = isChecked ? 'checked' : '';
          html.writeln('<input type="checkbox" $checked /> $content');
        case BlockType.text:
          html.writeln('<p>$content</p>');
        case BlockType.math:
          html.writeln('<p>\\($content\\)</p>');
      }
    }

    return html.toString();
  }
}
