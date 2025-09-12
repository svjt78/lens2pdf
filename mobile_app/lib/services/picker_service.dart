import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Helper to import images from gallery or Files app.
/// Returns a list of file paths copied to a temporary app location.
class PickResult {
  final List<String> images;
  final List<String> pdfs;
  final List<String> skipped;
  const PickResult({this.images = const [], this.pdfs = const [], this.skipped = const []});
}

class PickerService {
  static final ImagePicker _imagePicker = ImagePicker();

  /// Pick multiple images from the photo gallery.
  /// Ensures files are copied into the app's temp directory.
  static Future<List<String>> pickFromGallery() async {
    final List<XFile> media = await _imagePicker.pickMultiImage(
      imageQuality: 95, // ensure JPEG output, good quality
    );
    if (media.isEmpty) return [];
    final tmp = await getTemporaryDirectory();
    final out = <String>[];
    for (final x in media) {
      final ext = _normalizeExt(p.extension(x.path));
      final dest = p.join(tmp.path, 'import_${DateTime.now().millisecondsSinceEpoch}_${out.length}$ext');
      await File(x.path).copy(dest);
      out.add(dest);
    }
    return out;
  }

  /// Pick multiple images from the Files app using file_picker.
  /// Filters to common image types supported by the PDF encoder.
  /// Result of a mixed pick operation from Files.
  /// - [images]: copied into a temporary directory for pipeline use
  /// - [pdfs]: original paths to selected PDFs (caller can copy to Library)
  /// - [skipped]: file paths that are unsupported (e.g., HEIC/TIFF)
  static Future<PickResult> pickFromFilesAll() async {
    final res = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: const ['jpg', 'jpeg', 'png', 'heic', 'heif', 'tif', 'tiff', 'pdf'],
      withReadStream: false,
    );
    if (res == null || res.files.isEmpty) return const PickResult();
    final tmp = await getTemporaryDirectory();
    final images = <String>[];
    final pdfs = <String>[];
    final skipped = <String>[];
    for (final f in res.files) {
      final path = f.path;
      if (path == null) continue;
      final ext = _normalizeExt(p.extension(path));
      if (ext == '.pdf') {
        pdfs.add(path);
        continue;
      }
      if (ext != '.jpg' && ext != '.png') {
        skipped.add(path); // unsupported image type
        continue;
      }
      final dest = p.join(tmp.path, 'import_${DateTime.now().millisecondsSinceEpoch}_${images.length}$ext');
      await File(path).copy(dest);
      images.add(dest);
    }
    return PickResult(images: images, pdfs: pdfs, skipped: skipped);
  }

  static String _normalizeExt(String ext) {
    ext = ext.toLowerCase();
    if (ext.isEmpty) return '.jpg';
    // Map .jpeg to .jpg for consistency
    if (ext == '.jpeg') return '.jpg';
    return ext;
  }
}
