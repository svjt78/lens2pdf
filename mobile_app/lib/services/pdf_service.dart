import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

enum ColorMode { color, grayscale, bw }

class PdfService {
  static Future<File> buildPdf({
    required List<String> imagePaths,
    int quality = 90,
    ColorMode mode = ColorMode.color,
  }) async {
    final title = _docTitle(imagePaths.length);
    final doc = pw.Document(
      title: title,
      creator: 'Image to PDF Scanner',
      author: 'Image to PDF Scanner',
      subject: 'Scanned document',
    );

    for (final path in imagePaths) {
      final bytes = await File(path).readAsBytes();
      final img = pw.MemoryImage(bytes);
      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (ctx) {
            pw.Widget imageWidget = pw.Image(img, fit: pw.BoxFit.contain);
            // Mode adjustments can be done during pre-processing via OpenCV.
            // Here we embed the processed image as-is.
            return pw.Center(child: imageWidget);
          },
        ),
      );
    }

    final dir = await getApplicationDocumentsDirectory();
    final outDir = Directory('${dir.path}/scans');
    if (!await outDir.exists()) await outDir.create(recursive: true);
    final name = _filename(imagePaths.length);
    final file = File('${outDir.path}/$name');
    final data = await doc.save();
    await file.writeAsBytes(Uint8List.fromList(data), flush: true);
    return file;
  }

  static String _filename(int pages) {
    final now = DateTime.now();
    final y = now.year.toString().padLeft(4, '0');
    final m = now.month.toString().padLeft(2, '0');
    final d = now.day.toString().padLeft(2, '0');
    final hh = now.hour.toString().padLeft(2, '0');
    final mm = now.minute.toString().padLeft(2, '0');
    return 'Scan_${y}${m}${d}_${hh}${mm}_${pages}p.pdf';
  }

  static String _docTitle(int pages, {DateTime? now}) {
    now ??= DateTime.now();
    final y = now.year.toString().padLeft(4, '0');
    final m = now.month.toString().padLeft(2, '0');
    final d = now.day.toString().padLeft(2, '0');
    final hh = now.hour.toString().padLeft(2, '0');
    final mm = now.minute.toString().padLeft(2, '0');
    return 'Scan ${y}-${m}-${d} ${hh}:${mm} (${pages} pages)';
  }

  // Test helpers
  @visibleForTesting
  static String debugFilenameForPages(int pages) => _filename(pages);

  @visibleForTesting
  static String debugDocTitleForPages(int pages, DateTime now) => _docTitle(pages, now: now);
}
