import 'package:flutter/material.dart';

import '../services/pdf_service.dart';
import '../services/settings_service.dart';

class SettingsScreen extends StatefulWidget {
  static const route = '/settings';
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  Settings _settings = SettingsService.defaults;
  bool _loaded = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final s = await SettingsService.load();
    if (!mounted) return;
    setState(() {
      _settings = s;
      _loaded = true;
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await SettingsService.save(_settings);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Defaults saved')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _reset() {
    setState(() => _settings = SettingsService.defaults);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        actions: [
          TextButton(
            onPressed: !_loaded || _saving ? null : _save,
            child: _saving ? const Text('Saving...') : const Text('Save'),
          ),
        ],
      ),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Default Color Mode'),
                  const SizedBox(height: 8),
                  SegmentedButton<ColorMode>(
                    segments: const [
                      ButtonSegment(value: ColorMode.color, label: Text('Color')),
                      ButtonSegment(value: ColorMode.grayscale, label: Text('Gray')),
                      ButtonSegment(value: ColorMode.bw, label: Text('B&W')),
                    ],
                    selected: {_settings.mode},
                    onSelectionChanged: (s) => setState(() => _settings = _settings.copyWith(mode: s.first)),
                  ),
                  const SizedBox(height: 24),
                  Text('Default Quality: ${_settings.quality}'),
                  Slider(
                    value: _settings.quality.toDouble(),
                    min: 60,
                    max: 95,
                    divisions: 7,
                    label: '${_settings.quality}',
                    onChanged: (v) => setState(() => _settings = _settings.copyWith(quality: v.toInt())),
                  ),
                  const Spacer(),
                  Row(
                    children: [
                      OutlinedButton.icon(
                        onPressed: !_loaded || _saving ? null : _reset,
                        icon: const Icon(Icons.restart_alt),
                        label: const Text('Reset to defaults'),
                      ),
                      const Spacer(),
                      FilledButton.icon(
                        onPressed: !_loaded || _saving ? null : _save,
                        icon: const Icon(Icons.save),
                        label: const Text('Save'),
                      ),
                    ],
                  )
                ],
              ),
            ),
    );
  }
}

