import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

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
