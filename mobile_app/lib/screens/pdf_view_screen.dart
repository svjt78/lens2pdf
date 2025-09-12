import 'dart:io';

import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

class PdfViewScreen extends StatelessWidget {
  static const route = '/pdf';
  const PdfViewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments;
    final path = args is String ? args : null;

    return Scaffold(
      appBar: AppBar(title: const Text('Preview PDF')),
      body: path == null
          ? const Center(child: Text('No PDF to display'))
          : PdfPreview(
              allowPrinting: false,
              allowSharing: false,
              canChangePageFormat: false,
              canChangeOrientation: false,
              actions: const <PdfPreviewAction>[],
              build: (format) async => File(path).readAsBytes(),
            ),
    );
  }
}
