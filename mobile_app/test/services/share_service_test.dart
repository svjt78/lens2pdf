import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import 'package:image_to_pdf_scanner/services/receipt_intel.dart';
import 'package:image_to_pdf_scanner/services/share_profile.dart';
import 'package:image_to_pdf_scanner/services/share_service.dart';

class _FakePathProvider extends PathProviderPlatform {
  _FakePathProvider(this.tempPath);

  final String tempPath;

  @override
  Future<String?> getTemporaryPath() async => tempPath;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late PathProviderPlatform originalPlatform;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('share_service_test');
    originalPlatform = PathProviderPlatform.instance;
    PathProviderPlatform.instance = _FakePathProvider(tempDir.path);
  });

  tearDown(() async {
    PathProviderPlatform.instance = originalPlatform;
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('payload embeds metadata and summary for receipts', () async {
    final pdf = File(p.join(tempDir.path, 'test.pdf'));
    await pdf.writeAsBytes([1, 2, 3]);

    final receipt = ReceiptIntelResult(
      vendor: 'Test Store',
      purchaseDate: DateTime(2024, 5, 5),
      total: const ReceiptAmount(12.3, 0.9),
      paymentMethod: 'Visa',
      last4: '7890',
      confidence: 0.75,
    );

    final payload = await ShareService.debugBuildPayload(
      pdf,
      receipt: receipt,
      metadata: receipt.toJson(),
      documentType: 'receipt',
    );

    expect(payload.summary, contains('Test Store'));
    expect(payload.summary, contains('Visa ending 7890'));
    expect(payload.metadataFile, isNotNull);

    final metadataFile = payload.metadataFile!;
    final json =
        jsonDecode(await metadataFile.readAsString()) as Map<String, dynamic>;
    expect(json['documentType'], 'receipt');
    expect(json['fileName'], 'test.pdf');
    final data = json['data'] as Map<String, dynamic>;
    expect(data['vendor'], 'Test Store');
    expect(data['total'], 12.3);

    payload.dispose();
    await metadataFile.delete();
  });

  test('compact profile omits metadata sidecar', () async {
    final pdf = File(p.join(tempDir.path, 'compact.pdf'));
    await pdf.writeAsBytes([1, 2, 3]);

    final receipt = ReceiptIntelResult(
      vendor: 'Quick Market',
      purchaseDate: DateTime(2024, 4, 1),
      total: const ReceiptAmount(9.99, 0.5),
      confidence: 0.4,
    );

    final payload = await ShareService.debugBuildPayload(
      pdf,
      receipt: receipt,
      metadata: receipt.toJson(),
      documentType: 'receipt',
      subject: 'Receipt',
      profile: ShareProfile.compact,
    );

    expect(payload.metadataFile, isNull);
    expect(payload.subject, 'Receipt (Compact)');
    expect(payload.summary, contains('Quick Market'));

    payload.dispose();
  });
}
