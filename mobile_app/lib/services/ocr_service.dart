import 'dart:io';
import 'dart:ui' show Rect;

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

/// Represents a single recognized line of text on a receipt page.
class OcrLine {
  final String text;
  final Rect boundingBox;

  const OcrLine({required this.text, required this.boundingBox});
}

/// Holds the OCR output for a single page.
class OcrPage {
  final String path;
  final List<OcrLine> lines;

  const OcrPage({required this.path, required this.lines});

  String get fullText => lines.map((l) => l.text).join('\n');
}

/// Thin wrapper around Google ML Kit text recognition.
class OcrService {
  static final TextRecognizer _recognizer = TextRecognizer();

  static Future<List<OcrPage>> recognizeBatch(List<String> imagePaths) async {
    final pages = <OcrPage>[];
    for (final path in imagePaths) {
      if (!File(path).existsSync()) continue;
      final input = InputImage.fromFilePath(path);
      final result = await _recognizer.processImage(input);
      final lines = <OcrLine>[];
      for (final block in result.blocks) {
        for (final line in block.lines) {
          lines.add(OcrLine(text: line.text, boundingBox: line.boundingBox));
        }
      }
      pages.add(OcrPage(path: path, lines: lines));
    }
    return pages;
  }

  static Future<void> dispose() async {
    await _recognizer.close();
  }
}
