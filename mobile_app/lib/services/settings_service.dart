import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'pdf_service.dart';
import 'share_profile.dart';

class Settings {
  final int quality; // 60-95
  final ColorMode mode;
  final ShareProfile shareProfile;

  const Settings({
    required this.quality,
    required this.mode,
    required this.shareProfile,
  });

  Settings copyWith({
    int? quality,
    ColorMode? mode,
    ShareProfile? shareProfile,
  }) =>
      Settings(
        quality: quality ?? this.quality,
        mode: mode ?? this.mode,
        shareProfile: shareProfile ?? this.shareProfile,
      );

  Map<String, Object?> toJson() => {
        'quality': quality,
        'mode': mode.name,
        'shareProfile': shareProfile.name,
      };

  static Settings fromJson(Map<String, Object?> json) {
    final q = (json['quality'] as num?)?.toInt() ?? 90;
    final m = json['mode'] as String?;
    final mode = ColorMode.values.firstWhere(
      (e) => e.name == m,
      orElse: () => ColorMode.color,
    );
    final profileName = json['shareProfile'] as String?;
    final profile = ShareProfile.values.firstWhere(
      (p) => p.name == profileName,
      orElse: () => ShareProfile.standard,
    );
    return Settings(
      quality: q.clamp(60, 95),
      mode: mode,
      shareProfile: profile,
    );
  }
}

class SettingsService {
  static const Settings defaults = Settings(
    quality: 90,
    mode: ColorMode.color,
    shareProfile: ShareProfile.standard,
  );

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
