import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'pdf_service.dart';

class CvService {
  static const MethodChannel _channel = MethodChannel('cv');

  /// Process a single image using native OpenCV if available.
  /// Falls back to no-op if the method is unimplemented.
  static Future<String> processImage({
    required String path,
    required ColorMode mode,
    int quality = 90,
  }) async {
    // In Simulator/Web or when plugin is absent, skip native call quickly.
    if (kIsWeb) return path;
    try {
      final result = await _channel.invokeMethod<String>('processImage', {
        'path': path,
        'mode': mode.name,
        'quality': quality,
      }).timeout(const Duration(seconds: 2));
      return result ?? path;
    } on MissingPluginException {
      return path; // no-op until native side is added
    } on TimeoutException {
      return path; // avoid hanging export if native side stalls
    } on PlatformException {
      return path; // be resilient in MVP
    }
  }

  static Future<List<String>> processBatch({
    required List<String> paths,
    required ColorMode mode,
    int quality = 90,
  }) async {
    final out = <String>[];
    for (final p in paths) {
      out.add(await processImage(path: p, mode: mode, quality: quality));
    }
    return out;
  }
}
