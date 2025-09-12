import 'dart:io';

import 'package:flutter/material.dart';

import '../services/pdf_service.dart';
import '../services/share_service.dart';
import '../services/cv_service.dart';
import '../services/settings_service.dart';
import 'pdf_view_screen.dart';

class ExportScreen extends StatefulWidget {
  static const route = '/export';
  const ExportScreen({super.key});

  @override
  State<ExportScreen> createState() => _ExportScreenState();
}

class _ExportScreenState extends State<ExportScreen> {
  int _quality = 90;
  ColorMode _mode = ColorMode.color;
  bool _busy = false;
  List<String> _images = const [];
  String? _lastPath;
  bool _defaultsLoaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is List<String>) _images = args;
    // Load defaults once per screen instance.
    if (!_defaultsLoaded) {
      _defaultsLoaded = true;
      SettingsService.load().then((s) {
        if (!mounted) return;
        setState(() {
          _quality = s.quality;
          _mode = s.mode;
        });
      });
    }
  }

  Future<void> _export() async {
    setState(() => _busy = true);
    try {
      // Pre-process images (grayscale/B&W/quality) via native CV when available.
      // Falls back to original paths if not implemented.
      final processed = await CvService.processBatch(
        paths: _images,
        mode: _mode,
        quality: _quality,
      );

      final out = await PdfService.buildPdf(
        imagePaths: processed,
        quality: _quality,
        mode: _mode,
      );
      setState(() => _lastPath = out.path);

      if (!mounted) return;
      // Notify user with quick actions.
      final path = out.path;
      // Offer share targets immediately
      _showShareSheet(context, File(path));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _share() async {
    final path = _lastPath;
    if (path == null) return;
    _showShareSheet(context, File(path));
  }

  void _showShareSheet(BuildContext context, File file) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 8, left: 16, right: 16, bottom: 4),
              child: Text(
                'Choose the app on the next screen. The PDF is already attached.',
                style: TextStyle(color: Colors.black54),
                textAlign: TextAlign.center,
              ),
            ),
            ListTile(
              leading: const Icon(Icons.share_outlined),
              title: const Text('Share...'),
              subtitle: const Text('Generic share sheet (simulator-friendly)'),
              onTap: () {
                Navigator.pop(context);
                ShareService.shareFile(file);
              },
            ),
            ListTile(
              leading: const Icon(Icons.ios_share),
              title: const Text('Airdrop'),
              onTap: () {
                Navigator.pop(context);
                ShareService.shareAirdrop(file);
              },
            ),
            ListTile(
              leading: const Icon(Icons.email_outlined),
              title: const Text('Email'),
              onTap: () {
                Navigator.pop(context);
                ShareService.shareEmail(file, subject: 'My Scan');
              },
            ),
            ListTile(
              leading: const Icon(Icons.chat_bubble_outline),
              title: const Text('WhatsApp'),
              onTap: () {
                Navigator.pop(context);
                ShareService.shareWhatsApp(file);
              },
            ),
            ListTile(
              leading: const Icon(Icons.sms_outlined),
              title: const Text('SMS / iMessage'),
              onTap: () {
                Navigator.pop(context);
                ShareService.shareSms(file);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Export Settings'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) async {
              if (value == 'save') {
                await SettingsService.save(Settings(quality: _quality, mode: _mode));
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Saved as default')));
              } else if (value == 'load') {
                final s = await SettingsService.load();
                if (!mounted) return;
                setState(() {
                  _quality = s.quality;
                  _mode = s.mode;
                });
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Loaded defaults')));
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'save', child: Text('Save as default')),
              PopupMenuItem(value: 'load', child: Text('Load defaults')),
            ],
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Color Mode'),
            SegmentedButton<ColorMode>(
              segments: const [
                ButtonSegment(value: ColorMode.color, label: Text('Color')),
                ButtonSegment(value: ColorMode.grayscale, label: Text('Gray')),
                ButtonSegment(value: ColorMode.bw, label: Text('B&W')),
              ],
              selected: {_mode},
              onSelectionChanged: (s) => setState(() => _mode = s.first),
            ),
            const SizedBox(height: 16),
            Text('Quality: $_quality'),
            Slider(
              value: _quality.toDouble(),
              min: 60,
              max: 95,
              divisions: 7,
              label: '$_quality',
              onChanged: (v) => setState(() => _quality = v.toInt()),
            ),
            const Spacer(),
            if (_lastPath != null) Text('Last export: ${_lastPath!}', maxLines: 2, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _busy ? null : _export,
                    icon: const Icon(Icons.picture_as_pdf),
                    label: _busy ? const Text('Exporting...') : const Text('Export PDF'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _lastPath == null || _busy ? null : _share,
                    icon: const Icon(Icons.ios_share),
                    label: const Text('Share'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _lastPath == null || _busy
                        ? null
                        : () => Navigator.pushNamed(context, PdfViewScreen.route, arguments: _lastPath),
                    icon: const Icon(Icons.visibility),
                    label: const Text('View'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
