import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

/// assets에 번들된 NotoSansKR 폰트를 로드한다 (한국어 완전 지원).
/// 로드 실패 시 PdfGoogleFonts fallback.
Future<pw.Font> _loadKrFont(String asset) async {
  try {
    final data = await rootBundle.load(asset);
    return pw.Font.ttf(data);
  } catch (_) {
    // fallback: 네트워크에서 NotoSansKR 다운로드
    return PdfGoogleFonts.notoSansKRRegular();
  }
}

/// 캡처한 PNG(마인드맵 화면)를 한 페이지 PDF로 만들어 다운로드/공유한다.
/// 웹에서는 브라우저 다운로드, 네이티브에서는 공유 시트로 동작한다.
Future<void> exportPngAsPdf(
  Uint8List pngBytes, {
  String filename = 'mindmap.pdf',
  bool landscape = true,
}) async {
  final doc = pw.Document();
  final image = pw.MemoryImage(pngBytes);
  final format = landscape
      ? PdfPageFormat.a4.landscape
      : PdfPageFormat.a4;

  doc.addPage(
    pw.Page(
      pageFormat: format,
      margin: const pw.EdgeInsets.all(16),
      build: (context) => pw.Center(
        child: pw.Image(image, fit: pw.BoxFit.contain),
      ),
    ),
  );

  await Printing.sharePdf(bytes: await doc.save(), filename: filename);
}

// ─────────────────────────────────────────────────────────
// 마크다운 텍스트 → PDF 위젯 변환 헬퍼
// (bold/italic/header/bullet 지원, 마크다운 기호 없이 렌더링)
// ─────────────────────────────────────────────────────────

/// 마크다운 문자열에서 인라인 기호(**/*/`) 를 제거하고 pw.TextSpan 목록으로 변환.
List<pw.InlineSpan> _parseInline(String raw, pw.Font baseFont,
    pw.Font boldFont, pw.Font italicFont, double fontSize) {
  final spans = <pw.InlineSpan>[];
  // bold(**text**), italic(*text*), code(`text`) 순으로 처리
  final re = RegExp(r'\*\*(.+?)\*\*|\*(.+?)\*|`(.+?)`');
  int cursor = 0;
  for (final m in re.allMatches(raw)) {
    if (m.start > cursor) {
      spans.add(pw.TextSpan(
        text: raw.substring(cursor, m.start),
        style: pw.TextStyle(font: baseFont, fontSize: fontSize),
      ));
    }
    if (m.group(1) != null) {
      // bold
      spans.add(pw.TextSpan(
        text: m.group(1),
        style: pw.TextStyle(font: boldFont, fontSize: fontSize),
      ));
    } else if (m.group(2) != null) {
      // italic
      spans.add(pw.TextSpan(
        text: m.group(2),
        style: pw.TextStyle(font: italicFont, fontSize: fontSize),
      ));
    } else if (m.group(3) != null) {
      // inline code
      spans.add(pw.TextSpan(
        text: ' ${m.group(3)} ',
        style: pw.TextStyle(
          font: baseFont,
          fontSize: fontSize,
          color: PdfColors.blueGrey600,
        ),
      ));
    }
    cursor = m.end;
  }
  if (cursor < raw.length) {
    spans.add(pw.TextSpan(
      text: raw.substring(cursor),
      style: pw.TextStyle(font: baseFont, fontSize: fontSize),
    ));
  }
  return spans;
}

/// 마크다운 텍스트 한 블록을 pw.Widget으로 변환.
pw.Widget _mdLine(String line, pw.Font base, pw.Font bold, pw.Font italic) {
  final trimmed = line.trimRight();

  // 제목 (####, ###, ##, # 모두 처리)
  if (trimmed.startsWith('#### ')) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(top: 6, bottom: 2),
      child: pw.Text(trimmed.substring(5),
          style: pw.TextStyle(font: bold, fontSize: 12)),
    );
  }
  if (trimmed.startsWith('### ')) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(top: 8, bottom: 2),
      child: pw.Text(trimmed.substring(4),
          style: pw.TextStyle(font: bold, fontSize: 13)),
    );
  }
  if (trimmed.startsWith('## ')) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(top: 10, bottom: 2),
      child: pw.Text(trimmed.substring(3),
          style: pw.TextStyle(font: bold, fontSize: 15)),
    );
  }
  if (trimmed.startsWith('# ')) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(top: 12, bottom: 4),
      child: pw.Text(trimmed.substring(2),
          style: pw.TextStyle(font: bold, fontSize: 18)),
    );
  }

  // 불릿
  if (trimmed.startsWith('- ') || trimmed.startsWith('• ')) {
    final content = trimmed.startsWith('- ')
        ? trimmed.substring(2)
        : trimmed.substring(2);
    return pw.Padding(
      padding: const pw.EdgeInsets.only(left: 12, bottom: 2),
      child: pw.RichText(
        text: pw.TextSpan(children: [
          pw.TextSpan(
            text: '• ',
            style: pw.TextStyle(font: bold, fontSize: 11),
          ),
          ..._parseInline(content, base, bold, italic, 11),
        ]),
      ),
    );
  }

  // 번호 리스트 (1. ...)
  final numRe = RegExp(r'^\d+\. (.+)$');
  final numMatch = numRe.firstMatch(trimmed);
  if (numMatch != null) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(left: 12, bottom: 2),
      child: pw.RichText(
        text: pw.TextSpan(children: [
          pw.TextSpan(
            text: '${trimmed.split('.').first}. ',
            style: pw.TextStyle(font: bold, fontSize: 11),
          ),
          ..._parseInline(numMatch.group(1)!, base, bold, italic, 11),
        ]),
      ),
    );
  }

  // 인용구 (> text)
  if (trimmed.startsWith('> ')) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(left: 10, bottom: 2),
      child: pw.Container(
        decoration: const pw.BoxDecoration(
          border: pw.Border(
            left: pw.BorderSide(color: PdfColors.grey400, width: 2),
          ),
        ),
        padding: const pw.EdgeInsets.only(left: 8),
        child: pw.RichText(
          text: pw.TextSpan(
            children: _parseInline(trimmed.substring(2), base, bold, italic, 11),
          ),
        ),
      ),
    );
  }

  // 구분선
  if (trimmed == '---' || trimmed == '***') {
    return pw.Divider(color: PdfColors.grey400, thickness: 0.5);
  }

  // 빈 줄
  if (trimmed.isEmpty) {
    return pw.SizedBox(height: 6);
  }

  // 일반 텍스트 (인라인 마크다운 적용)
  return pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 2),
    child: pw.RichText(
      text: pw.TextSpan(
        children: _parseInline(trimmed, base, bold, italic, 11),
      ),
    ),
  );
}

/// 마크다운 문자열을 렌더링된 PDF로 내보낸다.
/// [title]  : PDF 상단 제목 (선택)
/// [filename]: 저장 파일명
Future<void> exportMarkdownAsPdf(
  String markdownText, {
  String title = '',
  String filename = 'export.pdf',
}) async {
  final doc = pw.Document();

  // 번들된 NotoSansKR 폰트 로드 (한글·영문·숫자 완전 지원)
  final base   = await _loadKrFont('assets/fonts/NotoSansKR-Regular.ttf');
  final bold   = await _loadKrFont('assets/fonts/NotoSansKR-Bold.ttf');
  final italic = base; // KR italic 없으므로 Regular 사용

  final lines = markdownText.split('\n');

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.symmetric(horizontal: 48, vertical: 52),
      build: (ctx) => [
        if (title.isNotEmpty) ...[
          pw.Text(
            title,
            style: pw.TextStyle(font: bold, fontSize: 20),
          ),
          pw.SizedBox(height: 4),
          pw.Divider(color: PdfColors.grey300, thickness: 0.8),
          pw.SizedBox(height: 12),
        ],
        ...lines.map((l) => _mdLine(l, base, bold, italic)),
      ],
    ),
  );

  await Printing.sharePdf(bytes: await doc.save(), filename: filename);
}

/// 에디터 블록 목록을 PDF로 내보낸다.
/// [blockLines]: 각 블록의 (type명, content) 쌍
Future<void> exportNotesAsPdf(
  List<Map<String, String>> blockLines, {
  String title = '노트',
  String filename = 'notes.pdf',
}) async {
  // 블록들을 마크다운 문자열로 합친다
  final buffer = StringBuffer();
  for (final b in blockLines) {
    final type = b['type'] ?? 'text';
    final content = b['content'] ?? '';
    switch (type) {
      case 'h1':
        buffer.writeln('# $content');
      case 'h2':
        buffer.writeln('## $content');
      case 'h3':
        buffer.writeln('### $content');
      case 'bullet':
        buffer.writeln('- $content');
      case 'number':
        buffer.writeln('1. $content');
      case 'quote':
        buffer.writeln('> $content');
      case 'hr':
        buffer.writeln('---');
      case 'code':
        buffer.writeln(content);
      default:
        buffer.writeln(content);
    }
    buffer.writeln();
  }
  await exportMarkdownAsPdf(buffer.toString(), title: title, filename: filename);
}
