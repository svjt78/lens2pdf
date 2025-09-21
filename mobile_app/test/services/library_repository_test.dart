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

  test('rename moves metadata sidecar', () async {
    final scansDir = Directory(p.join(docsDir.path, 'scans'));
    final original = File(p.join(scansDir.path, 'original.pdf'));
    await original.writeAsBytes([0]);

    await repo.saveMetadata(
      original.path,
      const ReceiptIntelResult(vendor: 'Storefront', confidence: 0.5),
    );

    final renamed = await repo.rename(original.path, 'renamed.pdf');
    expect(renamed, isNotNull);

    final oldMeta = File(p.join(scansDir.path, 'original.receipt.json'));
    final newMeta = File(p.join(scansDir.path, 'renamed.receipt.json'));
    expect(await oldMeta.exists(), isFalse);
    expect(await newMeta.exists(), isTrue);

    final raw = await repo.loadMetadataMap(renamed!.path);
    expect(raw, isNotNull);
    expect(raw!['vendor'], 'Storefront');
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

  test('saveMetadataMap normalizes values', () async {
    final scansDir = Directory(p.join(docsDir.path, 'scans'));
    final pdf = File(p.join(scansDir.path, 'meta.pdf'));
    await pdf.writeAsBytes([0]);

    final future = repo.watch().firstWhere((e) =>
        e.any((entry) => entry.path == pdf.path && entry.tags.isNotEmpty));

    await repo.saveMetadataMap(pdf.path, {
      'vendor': ' Fresh Mart  ',
      'purchaseDate': DateTime(2024, 2, 1),
      'total': 21.5,
      'tags': 'groceries, weekly , groceries',
      'notes': '  keep for taxes ',
    });

    final entries = await future;
    final entry = entries.firstWhere((element) => element.path == pdf.path);
    expect(entry.tags, containsAll(<String>['groceries', 'weekly']));

    final raw = await repo.loadMetadataMap(pdf.path);
    expect(raw, isNotNull);
    expect(raw!['vendor'], 'Fresh Mart');
    expect(raw['purchaseDate'], startsWith('2024-02-01'));
    expect(raw['tags'], ['groceries', 'weekly']);
    expect(raw['notes'], 'keep for taxes');
  });

  test('metadata is exposed for search and document typing', () async {
    final scansDir = Directory(p.join(docsDir.path, 'scans'));
    final pdf = File(p.join(scansDir.path, 'typed.pdf'));
    await pdf.writeAsBytes([0]);

    await repo.registerFile(pdf);

    final result = ReceiptIntelResult(
      vendor: 'Acme Hardware',
      purchaseDate: DateTime(2024, 1, 10),
      total: const ReceiptAmount(42.75, 0.9),
      paymentMethod: 'Visa',
      last4: '1234',
      confidence: 0.8,
    );

    final entriesFuture = repo.watch().firstWhere((value) => value.any(
          (entry) =>
              entry.path == pdf.path &&
              entry.metadata != null &&
              entry.receipt != null,
        ));
    await repo.saveMetadata(pdf.path, result);
    final entries = await entriesFuture;

    final entry = entries.firstWhere((element) => element.path == pdf.path);

    expect(entry.metadata, isNotNull);
    expect(entry.metadata!['vendor'], 'Acme Hardware');
    expect(entry.documentType, 'receipt');
    expect(entry.matchesQuery('hardware'), isTrue);
    expect(entry.matchesQuery('42.75'), isTrue);
    expect(entry.matchesQuery('visa'), isTrue);
    expect(entry.matchesQuery('nope'), isFalse);

    final raw = await repo.loadMetadataMap(pdf.path);
    expect(raw, isNotNull);
    expect(raw!['vendor'], 'Acme Hardware');
  });
}
