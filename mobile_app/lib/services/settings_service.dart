import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'pdf_service.dart';

class Settings {
  final int quality; // 60-95
  final ColorMode mode;

  const Settings({required this.quality, required this.mode});

  Settings copyWith({int? quality, ColorMode? mode}) =>
      Settings(quality: quality ?? this.quality, mode: mode ?? this.mode);

  Map<String, Object?> toJson() => {
        'quality': quality,
        'mode': mode.name,
      };

  static Settings fromJson(Map<String, Object?> json) {
    final q = (json['quality'] as num?)?.toInt() ?? 90;
    final m = json['mode'] as String?;
    final mode = ColorMode.values.firstWhere(
      (e) => e.name == m,
      orElse: () => ColorMode.color,
    );
    return Settings(quality: q.clamp(60, 95), mode: mode);
  }
}

class SettingsService {
  static const Settings defaults = Settings(quality: 90, mode: ColorMode.color);

  static Future<File> _file() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/settings.json');
  }

  static Future<Settings> load() async {
    try {
      final f = await _file();
      if (!await f.exists()) return defaults;
      final txt = await f.readAsString();
      final map = json.decode(txt) as Map<String, Object?>;
      return Settings.fromJson(map);
    } catch (_) {
      return defaults;
    }
  }

  static Future<void> save(Settings s) async {
      final f = await _file();
      await f.writeAsString(json.encode(s.toJson()), flush: true);
  }
}

