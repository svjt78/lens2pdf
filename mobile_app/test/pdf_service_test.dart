import 'package:flutter_test/flutter_test.dart';
import 'package:image_to_pdf_scanner/services/pdf_service.dart';

void main() {
  group('PdfService helpers', () {
    test('filename format includes pages and timestamp', () {
      final name = PdfService.debugFilenameForPages(3);
      final re = RegExp(r'^Scan_\d{8}_\d{4}_3p\.pdf$');
      expect(re.hasMatch(name), isTrue, reason: 'got: $name');
    });

    test('doc title uses provided datetime and page count', () {
      final title = PdfService.debugDocTitleForPages(3, DateTime(2024, 1, 2, 9, 5));
      expect(title, 'Scan 2024-01-02 09:05 (3 pages)');
    });
  });
}

