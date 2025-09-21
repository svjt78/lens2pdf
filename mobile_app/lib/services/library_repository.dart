import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'receipt_intel.dart';

class ScanEntry {
  final String path;
  final DateTime modified;
  final int? sizeBytes;
  final ReceiptIntelResult? receipt;
  final Map<String, dynamic>? metadata;
  final String? documentType;
  final List<String> tags;

  const ScanEntry({
    required this.path,
    required this.modified,
    required this.sizeBytes,
    this.receipt,
    this.metadata,
    this.documentType,
    this.tags = const [],
  });

  String get name => p.basename(path);
  bool get isPdf => name.toLowerCase().endsWith('.pdf');

  List<String> get _searchTokens {
    final tokens = <String>[];
    tokens.add(name);
    if (documentType != null) {
      tokens.add(documentType!);
    }
    if (tags.isNotEmpty) {
      tokens.addAll(tags);
    }

    final receiptMeta = receipt;
    if (receiptMeta != null) {
      if (receiptMeta.vendor != null) {
        tokens.add(receiptMeta.vendor!);
      }
      if (receiptMeta.purchaseDate != null) {
        final date = receiptMeta.purchaseDate!;
        tokens.add(DateFormat.yMMMd().format(date));
        tokens.add(DateFormat('yyyy-MM-dd').format(date));
      }
      if (receiptMeta.total?.value != null) {
        final total = receiptMeta.total!.value;
        tokens.add(NumberFormat.simpleCurrency().format(total));
        tokens.add(total.toStringAsFixed(2));
        tokens.add(total.toStringAsFixed(2).replaceAll('.', ''));
      }
      if (receiptMeta.paymentMethod != null) {
        tokens.add(receiptMeta.paymentMethod!);
      }
      if (receiptMeta.last4 != null) {
        tokens.add(receiptMeta.last4!);
      }
    }

    final meta = metadata;
    if (meta != null) {
      for (final entry in meta.entries) {
        final value = entry.value;
        if (value == null) continue;
        if (value is String) {
          tokens.add(value);
        } else if (value is num) {
          tokens.add(value.toString());
        } else if (value is bool) {
          tokens.add('${entry.key}:${value ? 'yes' : 'no'}');
        }
      }
    }

    return tokens
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .map((value) => value.toLowerCase())
        .toList();
  }

  bool matchesQuery(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return true;
    return _searchTokens.any((token) => token.contains(q));
  }
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
          if (item is File &&
              item.path.toLowerCase().endsWith('.receipt.json')) {
            continue;
          }
          ReceiptIntelResult? receiptMeta;
          Map<String, dynamic>? rawMeta;
          String? docType;
          if (item is File && item.path.toLowerCase().endsWith('.pdf')) {
            rawMeta = await _readMetadataMap(item.path);
            if (rawMeta != null) {
              receiptMeta = _parseReceiptMetadata(rawMeta);
              docType = _documentType(rawMeta, receiptMeta);
            }
          }
          final tags = _extractTags(rawMeta, receiptMeta);
          entries.add(
            ScanEntry(
              path: item.path,
              modified: stat.modified,
              sizeBytes:
                  stat.type == FileSystemEntityType.file ? stat.size : null,
              receipt: receiptMeta,
              metadata: rawMeta,
              documentType: docType,
              tags: tags,
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
    final metadataFile = File(_metadataPathFor(sourcePath));
    final renamed = await file.rename(target.path);
    if (await metadataFile.exists()) {
      final newMetadataPath = _metadataPathFor(renamed.path);
      await metadataFile.rename(newMetadataPath);
    }
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
    await saveMetadataMap(pdfPath, data.toJson());
  }

  Future<void> saveMetadataMap(
      String pdfPath, Map<String, dynamic> metadata) async {
    final file = File(_metadataPathFor(pdfPath));
    final cleaned = _cleanMetadataMap(metadata);
    if (cleaned.isEmpty) {
      if (await file.exists()) {
        await file.delete();
      }
    } else {
      await file.writeAsString(jsonEncode(cleaned), flush: true);
    }
    await refresh();
  }

  Future<ReceiptIntelResult?> loadMetadata(String pdfPath) =>
      _readMetadata(pdfPath);

  Future<Map<String, dynamic>?> loadMetadataMap(String pdfPath) async {
    return _readMetadataMap(pdfPath);
  }

  Future<ReceiptIntelResult?> _readMetadata(String pdfPath) async {
    final map = await _readMetadataMap(pdfPath);
    if (map == null) return null;
    return _parseReceiptMetadata(map);
  }

  Future<Map<String, dynamic>?> _readMetadataMap(String pdfPath) async {
    final file = File(_metadataPathFor(pdfPath));
    if (!await file.exists()) return null;
    try {
      final json =
          jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      return json;
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic> _cleanMetadataMap(Map<String, dynamic> metadata) {
    final result = <String, dynamic>{};
    metadata.forEach((key, value) {
      if (value == null) return;
      if (key == 'tags') {
        final normalizedTags = _normalizeTags(value);
        if (normalizedTags.isNotEmpty) {
          result[key] = normalizedTags;
        }
        return;
      }
      if (value is DateTime) {
        result[key] = value.toIso8601String();
      } else if (value is Map<String, dynamic>) {
        final cleaned = _cleanMetadataMap(value);
        if (cleaned.isNotEmpty) {
          result[key] = cleaned;
        }
      } else if (value is Iterable) {
        final items = value
            .map((item) => item is DateTime ? item.toIso8601String() : item)
            .where((item) => item != null)
            .map((item) => item is String ? item.trim() : item)
            .where((item) {
          if (item is String) {
            return item.isNotEmpty;
          }
          return true;
        }).toList();
        if (items.isNotEmpty) {
          result[key] = items;
        }
      } else if (value is String) {
        final trimmed = value.trim();
        if (trimmed.isNotEmpty) {
          result[key] = trimmed;
        }
      } else if (value is num || value is bool) {
        result[key] = value;
      } else {
        result[key] = value;
      }
    });
    return result;
  }

  String _metadataPathFor(String pdfPath) {
    final base = p.basenameWithoutExtension(pdfPath);
    return p.join(File(pdfPath).parent.path, '$base.receipt.json');
  }

  List<String> _extractTags(
    Map<String, dynamic>? json,
    ReceiptIntelResult? receipt,
  ) {
    final seen = <String>{};
    final result = <String>[];

    void addTag(String value) {
      final trimmed = value.trim();
      if (trimmed.isEmpty) return;
      final lower = trimmed.toLowerCase();
      if (seen.add(lower)) {
        result.add(trimmed);
      }
    }

    if (receipt != null && receipt.tags.isNotEmpty) {
      for (final tag in receipt.tags) {
        addTag(tag);
      }
    }

    if (json != null && json.containsKey('tags')) {
      final normalized = _normalizeTags(json['tags']);
      for (final value in normalized) {
        addTag(value);
      }
    }

    return result;
  }

  List<String> _normalizeTags(dynamic raw) {
    if (raw == null) return const [];
    final seen = <String>{};
    final result = <String>[];

    void add(String value) {
      final trimmed = value.trim();
      if (trimmed.isEmpty) return;
      final lower = trimmed.toLowerCase();
      if (seen.add(lower)) {
        result.add(trimmed);
      }
    }

    if (raw is List) {
      for (final value in raw) {
        if (value is String) {
          add(value);
        }
      }
    } else if (raw is String) {
      for (final value in raw.split(',')) {
        add(value);
      }
    }

    return result;
  }

  ReceiptIntelResult? _parseReceiptMetadata(Map<String, dynamic> json) {
    ReceiptAmount? amountFrom(String key, String confKey) {
      final value = json[key];
      if (value == null) return null;
      final conf = json[confKey];
      return ReceiptAmount(
        (value as num).toDouble(),
        conf is num ? conf.toDouble() : 0.0,
      );
    }

    final parsedTags = _extractTags(json, null);
    final notes = json['notes'] as String?;

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
      confidence: (json['confidence'] is num)
          ? (json['confidence'] as num).toDouble()
          : 0,
      tags: parsedTags,
      notes: notes,
    );
  }

  String? _documentType(
    Map<String, dynamic>? json,
    ReceiptIntelResult? receipt,
  ) {
    if (json == null) return receipt != null ? 'receipt' : null;
    final raw = json['documentType'];
    if (raw is String && raw.isNotEmpty) {
      return raw.toLowerCase();
    }
    if (receipt != null) return 'receipt';
    if (json.containsKey('redactions') ||
        json.containsKey('redactionMasks') ||
        json.containsKey('idFields') ||
        json.containsKey('watermark')) {
      return 'id';
    }
    return null;
  }
}
