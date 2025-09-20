import 'dart:io';
import 'dart:ui' as ui;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

import 'review_screen.dart';
import 'library_screen.dart';
import '../services/picker_service.dart';
import '../services/library_repository.dart';

class CaptureScreen extends StatefulWidget {
  static const route = '/capture';
  const CaptureScreen({super.key});

  @override
  State<CaptureScreen> createState() => _CaptureScreenState();
}

class _CaptureScreenState extends State<CaptureScreen>
    with WidgetsBindingObserver {
  CameraController? _controller;
  List<CameraDescription> _cameras = const [];
  final List<String> _captured = [];
  bool _busy = false;
  PermissionStatus? _cameraPermission;
  String? _cameraError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _init();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_controller == null) return;
    if (state == AppLifecycleState.inactive) {
      _controller?.dispose();
      _controller = null;
    } else if (state == AppLifecycleState.resumed &&
        !(_cameraPermission?.isPermanentlyDenied ?? false)) {
      _init();
    }
  }

  Future<void> _init() async {
    if (!mounted) return;
    if (_busy) return;
    setState(() => _busy = true);
    try {
      _cameraPermission = await _ensureCameraPermission();
      if (!(_cameraPermission?.isGranted ?? false)) {
        _controller = null;
        _cameras = const [];
        return;
      }
      _cameraError = null;
      await _initializeCameraController();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<PermissionStatus> _ensureCameraPermission() async {
    final status = await Permission.camera.status;
    if (status.isGranted) return status;
    if (status.isDenied || status.isLimited) {
      final result = await Permission.camera.request();
      return result;
    }
    return status;
  }

  Future<void> _initializeCameraController() async {
    WidgetsFlutterBinding.ensureInitialized();
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        if (mounted) setState(() {});
        return;
      }
      await _controller?.dispose();
      _controller = CameraController(_cameras.first, ResolutionPreset.max,
          enableAudio: false);
      await _controller!.initialize();
      if (mounted) setState(() {});
    } on CameraException catch (e) {
      _cameraError = e.description ?? e.code;
      _controller = null;
      if (mounted) setState(() {});
    } catch (e) {
      _cameraError = e.toString();
      if (mounted) setState(() {});
    }
  }

  Future<void> _capture() async {
    if (_controller == null || !_controller!.value.isInitialized) return;
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final shot = await _controller!.takePicture();
      final dir = await getTemporaryDirectory();
      final path =
          '${dir.path}/scan_${DateTime.now().millisecondsSinceEpoch}.jpg';
      await File(shot.path).copy(path);
      _captured.add(path);
      if (mounted) setState(() {});
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _goReview() {
    Navigator.pushNamed(context, ReviewScreen.route,
        arguments: _captured.toList());
  }

  Future<void> _importImages() async {
    if (_busy) return;
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
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (source == null) return;
    setState(() => _busy = true);
    try {
      List<String> imported = [];
      if (source == 'gallery') {
        imported = await PickerService.pickFromGallery();
      } else if (source == 'files') {
        final res = await PickerService.pickFromFilesAll();
        imported = res.images;
        // Handle PDFs: copy into Library (documents/scans/) so they appear on the home screen.
        if (res.pdfs.isNotEmpty) {
          for (final pdfPath in res.pdfs) {
            await LibraryRepository.instance.importPdf(pdfPath);
          }
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Imported ${res.pdfs.length} PDF(s) to Library'),
                action: SnackBarAction(
                  label: 'Go to Library',
                  onPressed: () {
                    Navigator.pushNamedAndRemoveUntil(
                        context, LibraryScreen.route, (route) => false);
                  },
                ),
              ),
            );
          }
        }
        // Inform about skipped unsupported files (HEIC/TIFF)
        if (res.skipped.isNotEmpty && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(
                    'Skipped ${res.skipped.length} unsupported file(s): HEIC/TIFF')),
          );
        }
      }
      if (imported.isNotEmpty) {
        _captured.addAll(imported);
        if (mounted) setState(() {});
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _addSample() async {
    // Generate a simple white PNG placeholder to simulate a captured page.
    const width = 1240; // ~A4 @150dpi portrait
    const height = 1754;
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    final paintBg = ui.Paint()..color = const ui.Color(0xFFFFFFFF);
    final border = ui.Paint()
      ..color = const ui.Color(0xFFDDDDDD)
      ..style = ui.PaintingStyle.stroke
      ..strokeWidth = 8;
    canvas.drawRect(
        ui.Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()), paintBg);
    // Subtle border
    canvas.drawRect(
        ui.Rect.fromLTWH(16, 16, width - 32.0, height - 32.0), border);
    final picture = recorder.endRecording();
    final img = await picture.toImage(width, height);
    final data = await img.toByteData(format: ui.ImageByteFormat.png);
    if (data == null) return;
    final dir = await getTemporaryDirectory();
    final path =
        '${dir.path}/sample_${DateTime.now().millisecondsSinceEpoch}.png';
    await File(path).writeAsBytes(data.buffer.asUint8List(), flush: true);
    _captured.add(path);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final initialized = _controller?.value.isInitialized ?? false;
    final noCamera = _cameras.isEmpty;
    return Scaffold(
      appBar: AppBar(title: const Text('Capture')),
      body: Column(
        children: [
          Expanded(
            child: (_cameraPermission?.isGranted == false)
                ? _PermissionFallback(
                    isPermanentlyDenied:
                        _cameraPermission?.isPermanentlyDenied ?? false,
                    onRequest: _init,
                    onOpenSettings: openAppSettings,
                  )
                : _cameraError != null
                    ? _ErrorFallback(message: _cameraError!)
                    : initialized
                        ? CameraPreview(_controller!)
                        : noCamera
                            ? const _NoCameraFallback()
                            : const Center(child: CircularProgressIndicator()),
          ),
          // Quick preview strip for feedback on captured/imported pages
          if (_captured.isNotEmpty)
            SizedBox(
              height: 110,
              child: ListView.separated(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                scrollDirection: Axis.horizontal,
                itemCount: _captured.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, i) => ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.file(
                    File(_captured[i]),
                    width: 80,
                    height: 100,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(width: 4),
                  Text('Pages: ${_captured.length}'),
                  const Spacer(),
                  Expanded(
                    flex: 0,
                    child: Wrap(
                      alignment: WrapAlignment.end,
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        IconButton(
                          onPressed: (_busy ||
                                  noCamera ||
                                  (_cameraPermission?.isGranted != true) ||
                                  _cameraError != null)
                              ? null
                              : _capture,
                          icon: const Icon(Icons.camera),
                          tooltip: (_cameraPermission?.isGranted != true)
                              ? 'Camera permission required'
                              : noCamera
                                  ? 'Camera not available in Simulator'
                                  : _cameraError != null
                                      ? 'Camera unavailable'
                                      : 'Capture',
                        ),
                        if (noCamera)
                          OutlinedButton.icon(
                            onPressed: _busy ? null : _addSample,
                            icon:
                                const Icon(Icons.add_photo_alternate_outlined),
                            label: const Text('Add sample'),
                          ),
                        OutlinedButton.icon(
                          onPressed: _busy ? null : _importImages,
                          icon: const Icon(Icons.add_photo_alternate_outlined),
                          label: const Text('Import'),
                        ),
                        ElevatedButton.icon(
                          onPressed: _captured.isEmpty ? null : _goReview,
                          icon: const Icon(Icons.check),
                          label: const Text('Review'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }
}

class _NoCameraFallback extends StatelessWidget {
  const _NoCameraFallback();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.camera_alt_outlined, size: 48, color: Colors.grey),
            SizedBox(height: 12),
            Text(
              'Camera not available on this device.\nOn the iOS Simulator, use “Add sample” to try the flow.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _PermissionFallback extends StatelessWidget {
  final bool isPermanentlyDenied;
  final VoidCallback? onRequest;
  final Future<bool> Function()? onOpenSettings;
  const _PermissionFallback({
    required this.isPermanentlyDenied,
    this.onRequest,
    this.onOpenSettings,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lock_outlined, size: 48, color: Colors.grey),
            const SizedBox(height: 12),
            const Text(
              'Camera permission is required to capture new scans.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            if (!isPermanentlyDenied)
              FilledButton.icon(
                onPressed: onRequest,
                icon: const Icon(Icons.lock_open_outlined),
                label: const Text('Grant Access'),
              ),
            if (isPermanentlyDenied) ...[
              FilledButton.icon(
                onPressed: onOpenSettings == null
                    ? null
                    : () => onOpenSettings?.call(),
                icon: const Icon(Icons.settings),
                label: const Text('Open Settings'),
              ),
              const SizedBox(height: 12),
              const Text(
                'Enable the camera permission in Settings to continue.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.black54),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ErrorFallback extends StatelessWidget {
  final String message;
  const _ErrorFallback({required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }
}
