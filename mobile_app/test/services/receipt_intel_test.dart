import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';

import 'package:image_to_pdf_scanner/services/receipt_intel.dart';
import 'package:image_to_pdf_scanner/services/ocr_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ReceiptIntelService', () {
    test('extracts vendor, totals, and date', () async {
      final page = OcrPage(path: 'page1', lines: [
        OcrLine(text: 'TARGET', boundingBox: Rect.zero),
        OcrLine(text: '123 Main Street', boundingBox: Rect.zero),
        OcrLine(text: 'Date: 09/18/2024 12:03', boundingBox: Rect.zero),
        OcrLine(text: 'Subtotal 12.34', boundingBox: Rect.zero),
        OcrLine(text: 'Tax 0.99', boundingBox: Rect.zero),
        OcrLine(text: 'Grand Total 13.33', boundingBox: Rect.zero),
        OcrLine(text: 'VISA ****1234', boundingBox: Rect.zero),
      ]);

      final result = await ReceiptIntelService.analyze([page]);

      expect(result.vendor, 'TARGET');
      expect(result.purchaseDate, isNotNull);
      expect(result.total?.value, 13.33);
      expect(result.paymentMethod, 'Visa');
      expect(result.last4, '1234');
      expect(result.confidence, greaterThan(0));
    });

    test('handles missing values gracefully', () async {
      final page = OcrPage(path: 'page2', lines: [
        OcrLine(text: 'Local Cafe', boundingBox: Rect.zero),
        OcrLine(text: 'Thank you!', boundingBox: Rect.zero),
      ]);

      final result = await ReceiptIntelService.analyze([page]);
      expect(result.vendor, 'Local Cafe');
      expect(result.total, isNull);
    });
  });
}
