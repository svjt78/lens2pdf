import 'dart:io';

import 'package:flutter/material.dart';

import 'export_screen.dart';

class ReviewScreen extends StatefulWidget {
  static const route = '/review';
  const ReviewScreen({super.key});

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  final List<String> _images = [];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is List<String> && _images.isEmpty) {
      _images.addAll(args);
      setState(() {});
    }
  }

  void _toExport() {
    Navigator.pushNamed(context, ExportScreen.route, arguments: _images.toList());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Review & Reorder')),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: FilledButton.icon(
            onPressed: _images.isEmpty ? null : _toExport,
            icon: const Icon(Icons.tune),
            label: const Text('Export Settings'),
          ),
        ),
      ),
      body: _images.isEmpty
          ? const Center(child: Text('No pages captured'))
          : ReorderableListView.builder(
              itemCount: _images.length,
              onReorder: (oldIndex, newIndex) {
                if (newIndex > oldIndex) newIndex--;
                setState(() => _images.insert(newIndex, _images.removeAt(oldIndex)));
              },
              itemBuilder: (context, index) {
                final path = _images[index];
                return Card(
                  key: ValueKey(path),
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: ListTile(
                    leading: Image.file(File(path), width: 64, height: 64, fit: BoxFit.cover),
                    title: Text('Page ${index + 1}'),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete),
                      onPressed: () => setState(() => _images.removeAt(index)),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
