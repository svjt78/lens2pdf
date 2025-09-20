import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../main.dart';
import '../services/library_repository.dart';
import '../services/picker_service.dart';
import '../services/share_service.dart';
import 'capture_screen.dart';
import 'pdf_view_screen.dart';
import 'review_screen.dart';

class LibraryScreen extends StatefulWidget {
  static const route = '/';
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> with RouteAware {
  final LibraryRepository _libraryRepository = LibraryRepository.instance;

  @override
  void initState() {
    super.initState();
    _libraryRepository.refresh();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute) {
      routeObserver.subscribe(this, route);
    }
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  void didPopNext() {
    _libraryRepository.refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Scans'),
        actions: [
          IconButton(
            tooltip: 'Settings',
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.pushNamed(context, '/settings'),
          ),
        ],
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Wrap(
          alignment: WrapAlignment.end,
          spacing: 12,
          runSpacing: 12,
          children: [
            FloatingActionButton.extended(
              heroTag: 'fab_scan',
              onPressed: () =>
                  Navigator.pushNamed(context, CaptureScreen.route).then((_) {
                _libraryRepository.refresh();
              }),
              icon: const Icon(Icons.camera_alt),
              label: const Text('Scan'),
            ),
            FloatingActionButton.extended(
              heroTag: 'fab_import',
              onPressed: _importFromHome,
              icon: const Icon(Icons.add_photo_alternate_outlined),
              label: const Text('Import'),
            ),
          ],
        ),
      ),
      body: StreamBuilder<List<ScanEntry>>(
        stream: _libraryRepository.watch(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final items = snapshot.data!;
          if (items.isEmpty) {
            return const Center(
                child: Text('No scans yet. Tap Scan to start.'));
          }
          return ListView.builder(
            itemCount: items.length,
            itemBuilder: (context, index) {
              final entry = items[index];
              return ListTile(
                leading: const Icon(Icons.picture_as_pdf),
                title: Text(entry.name),
                subtitle: Text(_subtitleFor(entry)),
                onTap: () {
                  if (entry.isPdf) {
                    Navigator.pushNamed(
                      context,
                      PdfViewScreen.route,
                      arguments: PdfViewArgs(
                        path: entry.path,
                        createdAt: entry.modified,
                        receipt: entry.receipt,
                      ),
                    );
                  }
                },
                trailing: entry.isPdf
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: 'Rename',
                            icon: const Icon(Icons.drive_file_rename_outline),
                            onPressed: () => _renameEntry(context, entry),
                          ),
                          IconButton(
                            tooltip: 'Share',
                            icon: const Icon(Icons.ios_share),
                            onPressed: () => ShareService.shareFile(
                                File(entry.path),
                                subject: 'My Scan'),
                          ),
                          IconButton(
                            tooltip: 'Delete',
                            icon: const Icon(Icons.delete_forever),
                            onPressed: () => _deleteEntry(context, entry),
                          ),
                        ],
                      )
                    : null,
              );
            },
          );
        },
      ),
    );
  }

  String _subtitleFor(ScanEntry entry) {
    return DateFormat.yMMMd().add_jm().format(entry.modified.toLocal());
  }

  Future<void> _renameEntry(BuildContext context, ScanEntry entry) async {
    final controller = TextEditingController(text: entry.name);
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
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, controller.text.trim()),
              child: const Text('Save')),
        ],
      ),
    );
    if (newName == null) return;
    final sanitized = newName.isEmpty ? entry.name : newName;
    final withExt =
        sanitized.toLowerCase().endsWith('.pdf') ? sanitized : '$sanitized.pdf';
    if (withExt == entry.name) return;
    try {
      final renamed = await _libraryRepository.rename(entry.path, withExt);
      if (!mounted) return;
      if (renamed == null) {
        messenger.showSnackBar(
          const SnackBar(content: Text('A file with that name already exists')),
        );
      }
    } catch (_) {
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('Failed to rename file')),
      );
    }
  }

  Future<void> _deleteEntry(BuildContext context, ScanEntry entry) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete PDF?'),
        content:
            Text('Remove "${entry.name}" from device? This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await _libraryRepository.delete(entry.path);
    } catch (_) {
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('Failed to delete file')),
      );
    }
  }

  Future<void> _importFromHome() async {
    final messenger = ScaffoldMessenger.of(context);
    final source = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Photos'),
              onTap: () => Navigator.pop(context, 'gallery'),
            ),
            ListTile(
              leading: const Icon(Icons.folder_open),
              title: const Text('Files (images/PDFs)'),
              onTap: () => Navigator.pop(context, 'files'),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.bolt_outlined),
              title: const Text('Add sample page'),
              subtitle:
                  const Text('Useful on Simulator when camera is missing'),
              onTap: () => Navigator.pop(context, 'sample'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (source == null) return;

    if (source == 'sample') {
      final path = await _createSampleImage();
      if (!mounted) return;
      Navigator.pushNamed(context, ReviewScreen.route, arguments: [path]);
      return;
    }

    if (!mounted) return;
    messenger.hideCurrentSnackBar();
    List<String> images = [];
    try {
      if (source == 'gallery') {
        images = await PickerService.pickFromGallery();
        if (!mounted) return;
      } else {
        final res = await PickerService.pickFromFilesAll();
        if (!mounted) return;
        images = res.images;
        if (res.pdfs.isNotEmpty) {
          for (final pdfPath in res.pdfs) {
            await _libraryRepository.importPdf(pdfPath);
          }
          if (!mounted) return;
          messenger.showSnackBar(
            SnackBar(
                content: Text('Imported ${res.pdfs.length} PDF(s) to Library')),
          );
        }
        if (res.skipped.isNotEmpty) {
          if (!mounted) return;
          messenger.showSnackBar(
            SnackBar(
                content: Text(
                    'Skipped ${res.skipped.length} unsupported file(s): HEIC/TIFF')),
          );
        }
      }
    } catch (_) {
      if (!mounted) return;
      messenger.showSnackBar(const SnackBar(content: Text('Import failed')));
      return;
    }

    if (images.isEmpty) return;
    if (!mounted) return;
    Navigator.pushNamed(context, ReviewScreen.route, arguments: images);
  }

  Future<String> _createSampleImage() async {
    const width = 1240;
    const height = 1754;
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    final paintBg = ui.Paint()..color = const ui.Color(0xFFFFFFFF);
    final border = ui.Paint()
      ..color = const ui.Color(0xFFCCCCCC)
      ..style = ui.PaintingStyle.stroke
      ..strokeWidth = 6;
    canvas.drawRect(
        ui.Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()), paintBg);
    canvas.drawRect(
        ui.Rect.fromLTWH(20, 20, width - 40.0, height - 40.0), border);
    final picture = recorder.endRecording();
    final img = await picture.toImage(width, height);
    final data = await img.toByteData(format: ui.ImageByteFormat.png);
    final dir = await getTemporaryDirectory();
    final path =
        p.join(dir.path, 'sample_${DateTime.now().millisecondsSinceEpoch}.png');
    await File(path).writeAsBytes(data!.buffer.asUint8List(), flush: true);
    return path;
  }
}
