import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';

import '../services/library_repository.dart';
import '../services/receipt_intel.dart';
import '../services/share_service.dart';
import '../services/settings_service.dart';
import 'edit_metadata_sheet.dart';

class PdfViewArgs {
  final String path;
  final DateTime? createdAt;
  final ReceiptIntelResult? receipt;

  const PdfViewArgs({
    required this.path,
    this.createdAt,
    this.receipt,
  });
}

class PdfViewScreen extends StatefulWidget {
  static const route = '/pdf';
  const PdfViewScreen({super.key});

  @override
  State<PdfViewScreen> createState() => _PdfViewScreenState();
}

class _PdfViewScreenState extends State<PdfViewScreen> {
  String? _path;
  DateTime? _createdAt;
  ReceiptIntelResult? _receipt;
  Map<String, dynamic>? _metadata;
  bool _loading = false;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is PdfViewArgs) {
      _path = args.path;
      _createdAt = args.createdAt;
      _receipt = args.receipt;
    } else if (args is String) {
      _path = args;
    }
    if (_path != null) {
      _loadDefaults();
    }
  }

  Future<void> _loadDefaults() async {
    if (_createdAt == null) {
      FileStat? stat;
      try {
        stat = await File(_path!).stat();
      } catch (_) {
        stat = null;
      }
      final capturedStat = stat;
      if (mounted && capturedStat != null) {
        setState(() => _createdAt = capturedStat.changed);
      }
    }
    if (_receipt == null || _metadata == null) {
      setState(() => _loading = true);
      try {
        final repo = LibraryRepository.instance;
        final meta = await repo.loadMetadata(_path!);
        final metaMap = await repo.loadMetadataMap(_path!);
        if (mounted) {
          setState(() {
            _receipt = _receipt ?? meta;
            _metadata = _metadata ?? metaMap;
          });
        }
      } finally {
        if (mounted) setState(() => _loading = false);
      }
    }
  }

  Future<void> _rename() async {
    final path = _path;
    if (path == null) return;
    final currentName = File(path).uri.pathSegments.last;
    final controller = TextEditingController(text: currentName);
    final messenger = ScaffoldMessenger.of(context);
    final newName = await showDialog<String?>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename PDF'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Enter new file name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (newName == null) return;
    final sanitized = newName.isEmpty ? currentName : newName;
    final withExt =
        sanitized.toLowerCase().endsWith('.pdf') ? sanitized : '$sanitized.pdf';
    if (withExt == File(path).uri.pathSegments.last) return;
    try {
      final renamed = await LibraryRepository.instance.rename(path, withExt);
      if (renamed != null) {
        setState(() {
          _path = renamed.path;
          _receipt = null;
          _metadata = null;
        });
        await _loadDefaults();
      } else {
        messenger.showSnackBar(
          const SnackBar(content: Text('A file with that name already exists')),
        );
      }
    } catch (e) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Failed to rename file')),
      );
    }
  }

  Future<void> _editMetadata() async {
    final path = _path;
    if (path == null) return;
    final repo = LibraryRepository.instance;
    final metadata = _metadata ?? await repo.loadMetadataMap(path);
    final receipt = _receipt ?? await repo.loadMetadata(path);

    final result = await EditMetadataSheet.show(
      context,
      pdfPath: path,
      existingReceipt: receipt,
      existingMetadata: metadata,
    );
    if (result?.updated == true) {
      await _loadDefaults();
    }
  }

  Future<void> _share() async {
    final path = _path;
    if (path == null) return;
    if (_metadata == null && _receipt == null) {
      await _loadDefaults();
    }
    final settings = await SettingsService.load();
    await ShareService.shareFile(
      File(path),
      subject: 'My Scan',
      receipt: _receipt,
      metadata: _metadata,
      documentType: (_metadata?['documentType'] as String?) ??
          (_metadata != null &&
                  (_metadata!.containsKey('redactions') ||
                      _metadata!.containsKey('redactionMasks'))
              ? 'id'
              : _receipt != null
                  ? 'receipt'
                  : null),
      profile: settings.shareProfile,
    );
  }

  Future<void> _delete() async {
    final path = _path;
    if (path == null) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete PDF?'),
        content: const Text(
            'Remove this file from the device? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    await LibraryRepository.instance.delete(path);
    if (!mounted) return;
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final path = _path;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Preview PDF'),
        actions: [
          IconButton(
            tooltip: 'Edit metadata',
            icon: const Icon(Icons.edit_note_outlined),
            onPressed: _editMetadata,
          ),
          IconButton(
            tooltip: 'Rename',
            icon: const Icon(Icons.drive_file_rename_outline),
            onPressed: _rename,
          ),
          IconButton(
            tooltip: 'Share',
            icon: const Icon(Icons.ios_share),
            onPressed: _share,
          ),
          IconButton(
            tooltip: 'Delete',
            icon: const Icon(Icons.delete_forever),
            onPressed: _delete,
          ),
        ],
      ),
      body: path == null
          ? const Center(child: Text('No PDF to display'))
          : Column(
              children: [
                if (_createdAt != null || _receipt != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    child: _ReceiptInfoCard(
                      path: path,
                      createdAt: _createdAt,
                      receipt: _receipt,
                      loading: _loading,
                    ),
                  ),
                Expanded(
                  child: PdfPreview(
                    allowPrinting: false,
                    allowSharing: false,
                    canChangePageFormat: false,
                    canChangeOrientation: false,
                    actions: const <PdfPreviewAction>[],
                    build: (format) async => File(path).readAsBytes(),
                  ),
                ),
              ],
            ),
    );
  }
}

class _ReceiptInfoCard extends StatelessWidget {
  final String path;
  final DateTime? createdAt;
  final ReceiptIntelResult? receipt;
  final bool loading;

  const _ReceiptInfoCard({
    required this.path,
    required this.createdAt,
    required this.receipt,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    final info = <Widget>[];
    info.add(Text(
      File(path).uri.pathSegments.isNotEmpty
          ? File(path).uri.pathSegments.last
          : path,
      style: const TextStyle(fontWeight: FontWeight.w600),
    ));
    if (createdAt != null) {
      info.add(Text(
        'Created ${DateFormat.yMMMd().add_jm().format(createdAt!.toLocal())}',
        style: const TextStyle(color: Colors.black54),
      ));
    }
    if (receipt != null) {
      final r = receipt!;
      if (r.vendor != null && r.vendor!.isNotEmpty) {
        info.add(Text('Vendor: ${r.vendor}'));
      }
      if (r.purchaseDate != null) {
        info.add(Text(
            'Purchase date: ${DateFormat.yMMMd().format(r.purchaseDate!)}'));
      }
      if (r.total?.value != null) {
        info.add(Text(
            'Total: ${NumberFormat.simpleCurrency().format(r.total!.value)}'));
      }
      final methodRaw = r.paymentMethod;
      if (methodRaw != null) {
        final method = StringBuffer(methodRaw);
        if (r.last4 != null) {
          method.write(' ending ${r.last4}');
        }
        info.add(Text('Payment: $method'));
      }
      info.add(Text(
        'Confidence: ${(r.confidence * 100).round()}%',
        style: const TextStyle(color: Colors.black54),
      ));
    }
    if (info.length == 1 && loading) {
      info.add(const Padding(
        padding: EdgeInsets.only(top: 8),
        child: LinearProgressIndicator(minHeight: 2),
      ));
    } else if (loading) {
      info.add(const Padding(
        padding: EdgeInsets.only(top: 8),
        child: LinearProgressIndicator(minHeight: 2),
      ));
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: info,
        ),
      ),
    );
  }
}
