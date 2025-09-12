import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import 'capture_screen.dart';
import 'review_screen.dart';
import 'pdf_view_screen.dart';
import '../services/share_service.dart';
import '../services/picker_service.dart';
import 'package:path/path.dart' as p;
import '../main.dart';
import 'dart:ui' as ui;

class LibraryScreen extends StatefulWidget {
  static const route = '/';
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> with RouteAware {
  late Future<List<FileSystemEntity>> _future;

  @override
  void initState() {
    super.initState();
    _future = _loadScans();
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

  // Called when a pushed route above this screen is popped and this becomes visible again.
  @override
  void didPopNext() {
    if (mounted) {
      setState(() { _future = _loadScans(); });
    }
  }

  Future<List<FileSystemEntity>> _loadScans() async {
    final dir = await getApplicationDocumentsDirectory();
    final scans = Directory('${dir.path}/scans');
    if (!await scans.exists()) return [];
    final entries = await scans.list().toList();
    entries.sort((a, b) => b.statSync().modified.compareTo(a.statSync().modified));
    return entries;
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
              onPressed: () => Navigator.pushNamed(context, CaptureScreen.route).then((_) {
                if (mounted) {
                  setState(() { _future = _loadScans(); });
                }
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
      body: FutureBuilder<List<FileSystemEntity>>(
        future: _future,
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final items = snap.data!;
          if (items.isEmpty) {
            return const Center(child: Text('No scans yet. Tap Scan to start.'));
          }
          return ListView.builder(
            itemCount: items.length,
            itemBuilder: (context, i) {
              final f = items[i];
              final name = f.uri.pathSegments.isNotEmpty ? f.uri.pathSegments.last : f.path;
              return ListTile(
                leading: const Icon(Icons.picture_as_pdf),
                title: Text(name),
                subtitle: Text(f.statSync().modified.toLocal().toString()),
                onTap: () {
                  if (f is File && name.toLowerCase().endsWith('.pdf')) {
                    Navigator.pushNamed(context, PdfViewScreen.route, arguments: f.path);
                  }
                },
                trailing: (f is File && name.toLowerCase().endsWith('.pdf'))
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: 'Rename',
                            icon: const Icon(Icons.drive_file_rename_outline),
                            onPressed: () => _renameFile(context, File(f.path)),
                          ),
                          IconButton(
                            tooltip: 'Share',
                            icon: const Icon(Icons.ios_share),
                            onPressed: () => ShareService.shareFile(File(f.path), subject: 'My Scan'),
                          ),
                          IconButton(
                            tooltip: 'Delete',
                            icon: const Icon(Icons.delete_forever),
                            onPressed: () async {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text('Delete PDF?'),
                                  content: Text('Remove "$name" from device? This cannot be undone.'),
                                  actions: [
                                    TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                                    FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
                                  ],
                                ),
                              );
                              if (confirm == true) {
                                try {
                                  await File(f.path).delete();
                                  if (mounted) { setState(() { _future = _loadScans(); }); }
                                } catch (_) {
                                  if (!mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to delete file')));
                                }
                              }
                            },
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

  Future<void> _renameFile(BuildContext context, File file) async {
    final dir = file.parent;
    final currentName = file.uri.pathSegments.isNotEmpty ? file.uri.pathSegments.last : file.path;
    final controller = TextEditingController(text: currentName);
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
          TextButton(onPressed: () => Navigator.pop(context, null), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: const Text('Save')),
        ],
      ),
    );
    if (newName == null) return;
    final sanitized = newName.isEmpty ? currentName : newName;
    final withExt = sanitized.toLowerCase().endsWith('.pdf') ? sanitized : '$sanitized.pdf';
    if (withExt == currentName) return;
    final newPath = '${dir.path}/$withExt';
    try {
      final target = File(newPath);
      if (await target.exists()) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('A file with that name already exists')));
        return;
      }
      await file.rename(newPath);
      if (mounted) { setState(() { _future = _loadScans(); }); }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to rename file')));
    }
  }

  Future<void> _importFromHome() async {
    // Let user pick either from Photos or Files (images/PDFs)
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
              subtitle: const Text('Useful on Simulator when camera is missing'),
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
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    List<String> images = [];
    try {
      if (source == 'gallery') {
        images = await PickerService.pickFromGallery();
      } else {
        final res = await PickerService.pickFromFilesAll();
        images = res.images;
        if (res.pdfs.isNotEmpty) {
          // Copy picked PDFs into Library so they appear in the list immediately.
          final docs = await getApplicationDocumentsDirectory();
          final scans = Directory(p.join(docs.path, 'scans'));
          if (!await scans.exists()) await scans.create(recursive: true);
          for (final pdfPath in res.pdfs) {
            final name = p.basename(pdfPath);
            var target = File(p.join(scans.path, name));
            if (await target.exists()) {
              final ts = DateTime.now().millisecondsSinceEpoch;
              final base = p.basenameWithoutExtension(name);
              final ext = p.extension(name);
              target = File(p.join(scans.path, '${base}_$ts$ext'));
            }
            await File(pdfPath).copy(target.path);
          }
          if (!mounted) return;
          setState(() { _future = _loadScans(); });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Imported ${res.pdfs.length} PDF(s) to Library')),
          );
        }
        if (res.skipped.isNotEmpty && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Skipped ${res.skipped.length} unsupported file(s): HEIC/TIFF')),
          );
        }
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Import failed')));
      return;
    }

    if (images.isEmpty) return;
    if (!mounted) return;
    // Go straight to Review so user can see pages and export.
    Navigator.pushNamed(context, ReviewScreen.route, arguments: images);
  }

  Future<String> _createSampleImage() async {
    // Create a simple white PNG page with a light border
    const width = 1240;
    const height = 1754;
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    final paintBg = ui.Paint()..color = const ui.Color(0xFFFFFFFF);
    final border = ui.Paint()
      ..color = const ui.Color(0xFFCCCCCC)
      ..style = ui.PaintingStyle.stroke
      ..strokeWidth = 6;
    canvas.drawRect(ui.Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()), paintBg);
    canvas.drawRect(ui.Rect.fromLTWH(20, 20, width - 40.0, height - 40.0), border);
    final picture = recorder.endRecording();
    final img = await picture.toImage(width, height);
    final data = await img.toByteData(format: ui.ImageByteFormat.png);
    final dir = await getTemporaryDirectory();
    final path = p.join(dir.path, 'sample_${DateTime.now().millisecondsSinceEpoch}.png');
    await File(path).writeAsBytes(data!.buffer.asUint8List(), flush: true);
    return path;
  }
}
