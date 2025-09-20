import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import 'package:image_to_pdf_scanner/services/library_repository.dart';
import 'package:image_to_pdf_scanner/services/receipt_intel.dart';

class _FakePathProvider extends PathProviderPlatform {
  _FakePathProvider(this.documentsPath);

  final String documentsPath;

  @override
  Future<String?> getApplicationDocumentsPath() async => documentsPath;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late Directory docsDir;
  final repo = LibraryRepository.instance;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('library_repo_test');
    docsDir = Directory(p.join(tempDir.path, 'docs'));
    await docsDir.create(recursive: true);
    PathProviderPlatform.instance = _FakePathProvider(docsDir.path);
    final scansDir = Directory(p.join(docsDir.path, 'scans'));
    if (await scansDir.exists()) {
      await scansDir.delete(recursive: true);
    }
    await scansDir.create(recursive: true);
    await repo.refresh();
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('registerFile publishes new entry', () async {
    final scansDir = Directory(p.join(docsDir.path, 'scans'));
    final file = File(p.join(scansDir.path, 'test.pdf'));
    await file.writeAsBytes([1, 2, 3]);

    final entriesFuture = repo.watch().firstWhere(
        (entries) => entries.any((entry) => entry.name == 'test.pdf'));

    await repo.registerFile(file);
    final entries = await entriesFuture;

    expect(entries.first.name, 'test.pdf');
    expect(entries.first.isPdf, isTrue);
  });

  test('rename prevents duplicate names', () async {
    final scansDir = Directory(p.join(docsDir.path, 'scans'));
    final original = File(p.join(scansDir.path, 'one.pdf'));
    final conflict = File(p.join(scansDir.path, 'two.pdf'));
    await original.writeAsBytes([0]);
    await conflict.writeAsBytes([1]);

    await repo.refresh();

    final renamed = await repo.rename(original.path, 'two.pdf');
    expect(renamed, isNull);

    final success = await repo.rename(original.path, 'three.pdf');
    expect(success, isNotNull);
    expect(p.basename(success!.path), 'three.pdf');
  });

  test('saveMetadata writes companion file', () async {
    final scansDir = Directory(p.join(docsDir.path, 'scans'));
    final pdf = File(p.join(scansDir.path, 'receipt.pdf'));
    await pdf.writeAsBytes([0]);

    final result = ReceiptIntelResult(
      vendor: 'Store',
      purchaseDate: DateTime(2024, 9, 18),
      total: const ReceiptAmount(15.99, 0.8),
      confidence: 0.6,
    );

    final future = repo.watch().firstWhere((e) => e.isNotEmpty);
    await repo.saveMetadata(pdf.path, result);
    final entries = await future;
    final entry = entries.first;
    expect(entry.receipt?.vendor, 'Store');
    expect(entry.receipt?.total?.value, 15.99);
  });
}
