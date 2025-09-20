import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'receipt_intel.dart';

class ScanEntry {
  final String path;
  final DateTime modified;
  final int? sizeBytes;
  final ReceiptIntelResult? receipt;

  const ScanEntry({
    required this.path,
    required this.modified,
    required this.sizeBytes,
    this.receipt,
  });

  String get name => p.basename(path);
  bool get isPdf => name.toLowerCase().endsWith('.pdf');
}

class LibraryRepository {
  LibraryRepository._();

  static final LibraryRepository instance = LibraryRepository._();

  final StreamController<List<ScanEntry>> _controller =
      StreamController<List<ScanEntry>>.broadcast();

  bool _initialized = false;
  bool _refreshing = false;

  Stream<List<ScanEntry>> watch() {
    if (!_initialized) {
      _initialized = true;
      unawaited(refresh());
    }
    return _controller.stream;
  }

  Future<Directory> _ensureScansDir() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, 'scans'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<void> refresh() async {
    if (_refreshing) return;
    _refreshing = true;
    try {
      final dir = await _ensureScansDir();
      final entries = <ScanEntry>[];
      if (await dir.exists()) {
        final list = await dir.list().toList();
        list.sort(
            (a, b) => b.statSync().modified.compareTo(a.statSync().modified));
        for (final item in list) {
          final stat = await item.stat();
          if (item is File && item.path.toLowerCase().endsWith('.receipt.json')) {
            continue;
          }
          ReceiptIntelResult? meta;
          if (item is File && item.path.toLowerCase().endsWith('.pdf')) {
            meta = await _readMetadata(item.path);
          }
          entries.add(
            ScanEntry(
              path: item.path,
              modified: stat.modified,
              sizeBytes:
                  stat.type == FileSystemEntityType.file ? stat.size : null,
              receipt: meta,
            ),
          );
        }
      }
      _controller.add(entries);
    } finally {
      _refreshing = false;
    }
  }

  Future<void> registerFile(File file) async {
    final scansDir = await _ensureScansDir();
    final normalizedScans = p.normalize(scansDir.path);
    final normalizedParent = p.normalize(file.parent.path);
    if (normalizedScans != normalizedParent) {
      await importPdf(file.path);
      return;
    }
    await refresh();
  }

  Future<File> importPdf(String sourcePath) async {
    final scansDir = await _ensureScansDir();
    final name = p.basename(sourcePath);
    var target = File(p.join(scansDir.path, name));
    if (await target.exists()) {
      final ts = DateTime.now().millisecondsSinceEpoch;
      final base = p.basenameWithoutExtension(name);
      final ext = p.extension(name);
      target = File(p.join(scansDir.path, '${base}_$ts$ext'));
    }
    final copied = await File(sourcePath).copy(target.path);
    await refresh();
    return copied;
  }

  Future<File?> rename(String sourcePath, String newName) async {
    final file = File(sourcePath);
    if (!await file.exists()) return null;
    final scansDir = await _ensureScansDir();
    final target = File(p.join(scansDir.path, newName));
    if (await target.exists()) {
      return null;
    }
    final renamed = await file.rename(target.path);
    await refresh();
    return renamed;
  }

  Future<void> delete(String path) async {
    final file = File(path);
    if (await file.exists()) {
      await file.delete();
    }
    final metadataFile = File(_metadataPathFor(path));
    if (await metadataFile.exists()) {
      await metadataFile.delete();
    }
    await refresh();
  }

  Future<void> saveMetadata(String pdfPath, ReceiptIntelResult data) async {
    final file = File(_metadataPathFor(pdfPath));
    await file.writeAsString(jsonEncode(data.toJson()), flush: true);
    await refresh();
  }

  Future<ReceiptIntelResult?> loadMetadata(String pdfPath) => _readMetadata(pdfPath);

  Future<ReceiptIntelResult?> _readMetadata(String pdfPath) async {
    final file = File(_metadataPathFor(pdfPath));
    if (!await file.exists()) return null;
    try {
      final json = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      ReceiptAmount? amountFrom(String key, String confKey) {
        final value = json[key];
        if (value == null) return null;
        final conf = json[confKey];
        return ReceiptAmount((value as num).toDouble(),
            conf is num ? conf.toDouble() : 0.0);
      }

      return ReceiptIntelResult(
        vendor: json['vendor'] as String?,
        purchaseDate: (json['purchaseDate'] as String?) != null
            ? DateTime.tryParse(json['purchaseDate'] as String)
            : null,
        subtotal: amountFrom('subtotal', 'subtotalConfidence'),
        tax: amountFrom('tax', 'taxConfidence'),
        total: amountFrom('total', 'totalConfidence'),
        paymentMethod: json['paymentMethod'] as String?,
        last4: json['last4'] as String?,
        confidence:
            (json['confidence'] is num) ? (json['confidence'] as num).toDouble() : 0,
      );
    } catch (_) {
      return null;
    }
  }

  String _metadataPathFor(String pdfPath) {
    final base = p.basenameWithoutExtension(pdfPath);
    return p.join(File(pdfPath).parent.path, '$base.receipt.json');
  }
}
