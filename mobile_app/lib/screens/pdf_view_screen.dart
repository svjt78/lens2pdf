import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';

import '../services/library_repository.dart';
import '../services/receipt_intel.dart';

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
      final stat = await File(_path!).stat().catchError((_) => null);
      if (mounted && stat != null) {
        setState(() => _createdAt = stat.changed);
      }
    }
    if (_receipt == null) {
      setState(() => _loading = true);
      try {
        final meta = await LibraryRepository.instance.loadMetadata(_path!);
        if (mounted) {
          setState(() => _receipt = meta);
        }
      } finally {
        if (mounted) setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final path = _path;
    return Scaffold(
      appBar: AppBar(title: const Text('Preview PDF')),
      body: path == null
          ? const Center(child: Text('No PDF to display'))
          : Column(
              children: [
                if (_createdAt != null || _receipt != null)
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
