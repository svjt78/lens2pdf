import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../main.dart';
import '../services/library_repository.dart';
import '../services/library_filters.dart';
import '../services/picker_service.dart';
import '../services/settings_service.dart';
import 'edit_metadata_sheet.dart';
import '../services/share_service.dart';
import 'capture_screen.dart';
import 'pdf_view_screen.dart';
import 'review_screen.dart';
import 'home_shell_scope.dart';

class LibraryScreen extends StatefulWidget {
  static const route = '/library';
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> with RouteAware {
  final LibraryRepository _libraryRepository = LibraryRepository.instance;
  final TextEditingController _searchController = TextEditingController();
  String _query = '';
  MonthKey? _selectedMonth;
  final Set<String> _selectedTags = <String>{};

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
    _searchController.dispose();
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
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(64),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by vendor, amount, ID fields... ',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: _clearSearch,
                      ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onChanged: (value) {
                setState(() => _query = value);
              },
            ),
          ),
        ),
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
              onPressed: () {
                final scope = HomeShellScope.maybeOf(context);
                if (scope != null) {
                  scope.onSelectTab(1);
                } else {
                  Navigator.pushNamed(context, CaptureScreen.route).then((_) {
                    if (mounted) {
                      _libraryRepository.refresh();
                    }
                  });
                }
              },
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
          final filters = LibraryFilters(
            month: _selectedMonth,
            tags: _selectedTags,
            query: _query,
          );
          final result = LibraryFilterEngine.apply(items, filters);
          final filtered = result.items;

          return Column(
            children: [
              if (result.monthFacets.isNotEmpty ||
                  result.tagFacets.isNotEmpty ||
                  filters.hasActiveFilters ||
                  _query.isNotEmpty)
                _buildFiltersPanel(result, filters),
              Expanded(
                child: filtered.isEmpty
                    ? _buildFilteredEmptyState(filters)
                    : _buildGrid(filtered),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildFiltersPanel(
    LibraryFilterResult result,
    LibraryFilters filters,
  ) {
    final theme = Theme.of(context);
    final showMonthSection = result.monthFacets.isNotEmpty;
    final showTagSection = result.tagFacets.isNotEmpty;
    final showActions = filters.hasActiveFilters || filters.query.isNotEmpty;

    if (!showMonthSection && !showTagSection && !showActions) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (showMonthSection) ...[
                Text(
                  'Month',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: result.monthFacets.map((facet) {
                      final selected = _selectedMonth == facet.key;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: Text(
                            '${facet.label()} (${facet.count})',
                          ),
                          selected: selected,
                          onSelected: (_) => _handleSelectMonth(facet.key),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              if (showTagSection) ...[
                Text(
                  'Tags',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: result.tagFacets.take(12).map((facet) {
                    final normalized = facet.tag.toLowerCase();
                    final selected = _selectedTags.contains(normalized);
                    return FilterChip(
                      label: Text('${facet.tag} (${facet.count})'),
                      selected: selected,
                      onSelected: (_) => _handleToggleTag(facet.tag),
                    );
                  }).toList(),
                ),
                if (result.tagFacets.length > 12)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'Showing top 12 of ${result.tagFacets.length} tags',
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                const SizedBox(height: 12),
              ],
              if (showActions)
                Wrap(
                  spacing: 12,
                  children: [
                    if (filters.hasActiveFilters)
                      TextButton.icon(
                        onPressed: _clearFilters,
                        icon: const Icon(Icons.filter_alt_off),
                        label: const Text('Clear filters'),
                      ),
                    if (filters.query.isNotEmpty)
                      TextButton.icon(
                        onPressed: _clearSearch,
                        icon: const Icon(Icons.backspace_outlined),
                        label: const Text('Clear search'),
                      ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilteredEmptyState(LibraryFilters filters) {
    final hasFilters = filters.hasActiveFilters;
    final hasQuery = filters.query.isNotEmpty;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            hasFilters || hasQuery
                ? 'No scans match the current filters.'
                : 'No scans found.',
            textAlign: TextAlign.center,
          ),
          if (hasFilters)
            TextButton.icon(
              onPressed: _clearFilters,
              icon: const Icon(Icons.filter_alt_off),
              label: const Text('Clear filters'),
            ),
          if (hasQuery)
            TextButton.icon(
              onPressed: _clearSearch,
              icon: const Icon(Icons.backspace_outlined),
              label: const Text('Clear search'),
            ),
        ],
      ),
    );
  }

  void _handleSelectMonth(MonthKey key) {
    setState(() {
      if (_selectedMonth == key) {
        _selectedMonth = null;
      } else {
        _selectedMonth = key;
      }
    });
  }

  void _handleToggleTag(String tag) {
    final normalized = tag.trim().toLowerCase();
    setState(() {
      if (_selectedTags.contains(normalized)) {
        _selectedTags.remove(normalized);
      } else {
        _selectedTags.add(normalized);
      }
    });
  }

  void _clearFilters() {
    if (_selectedMonth == null && _selectedTags.isEmpty) return;
    setState(() {
      _selectedMonth = null;
      _selectedTags.clear();
    });
  }

  void _clearSearch() {
    if (_query.isEmpty) return;
    setState(() {
      _query = '';
      _searchController.clear();
    });
  }

  Widget _buildGrid(List<ScanEntry> entries) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxExtent = constraints.maxWidth < 400 ? 400.0 : 260.0;
        return GridView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: maxExtent,
            mainAxisExtent: 190,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
          ),
          itemCount: entries.length,
          itemBuilder: (context, index) {
            final entry = entries[index];
            final subtitle = _subtitleFor(entry);
            final docType = entry.documentType;
            return Card(
              clipBehavior: Clip.antiAlias,
              child: InkWell(
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
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.picture_as_pdf),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              entry.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      if (docType != null)
                        Text(
                          docType.toUpperCase(),
                          style: const TextStyle(
                            fontSize: 12,
                            letterSpacing: 0.6,
                            color: Colors.black54,
                          ),
                        ),
                      Text(
                        subtitle,
                        style: const TextStyle(fontSize: 12),
                      ),
                      if (entry.tags.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: entry.tags
                              .map(
                                (tag) => Chip(
                                  label: Text(tag),
                                  labelStyle: const TextStyle(fontSize: 11),
                                  visualDensity: VisualDensity.compact,
                                  materialTapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                              )
                              .toList(),
                        ),
                      ],
                      const Spacer(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          _ActionIconButton(
                            tooltip: 'Edit metadata',
                            icon: Icons.edit_note_outlined,
                            onPressed: () => _editMetadata(context, entry),
                          ),
                          const SizedBox(width: 4),
                          _ActionIconButton(
                            tooltip: 'Rename',
                            icon: Icons.drive_file_rename_outline,
                            onPressed: () => _renameEntry(context, entry),
                          ),
                          const SizedBox(width: 4),
                          _ActionIconButton(
                            tooltip: 'Share',
                            icon: Icons.ios_share,
                            onPressed: () => _shareEntry(entry),
                          ),
                          const SizedBox(width: 4),
                          _ActionIconButton(
                            tooltip: 'Delete',
                            icon: Icons.delete_forever,
                            onPressed: () => _deleteEntry(context, entry),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  String _subtitleFor(ScanEntry entry) {
    final parts = <String>[];
    final receipt = entry.receipt;
    final vendor = receipt?.vendor?.trim();
    if (vendor != null && vendor.isNotEmpty) {
      parts.add(vendor);
    }
    final date = receipt?.purchaseDate ?? entry.modified;
    parts.add(DateFormat.yMMMd().format(date));
    final total = receipt?.total?.value;
    if (total != null) {
      parts.add(NumberFormat.simpleCurrency().format(total));
    }
    return parts.join(' • ');
  }

  Future<void> _editMetadata(BuildContext context, ScanEntry entry) async {
    final receipt =
        entry.receipt ?? await _libraryRepository.loadMetadata(entry.path);
    final metadata =
        entry.metadata ?? await _libraryRepository.loadMetadataMap(entry.path);

    final result = await EditMetadataSheet.show(
      context,
      pdfPath: entry.path,
      existingReceipt: receipt,
      existingMetadata: metadata,
    );

    if (result?.updated == true) {
      await _libraryRepository.refresh();
    }
  }

  Future<void> _shareEntry(ScanEntry entry) async {
    final file = File(entry.path);
    final receipt =
        entry.receipt ?? await _libraryRepository.loadMetadata(entry.path);
    final metadata =
        entry.metadata ?? await _libraryRepository.loadMetadataMap(entry.path);
    final settings = await SettingsService.load();
    await ShareService.shareFile(
      file,
      subject: 'My Scan',
      receipt: receipt,
      metadata: metadata,
      documentType: entry.documentType,
      profile: settings.shareProfile,
    );
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

class _ActionIconButton extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  const _ActionIconButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      icon: Icon(icon, size: 20),
      onPressed: onPressed,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints.tightFor(width: 36, height: 36),
      visualDensity: VisualDensity.compact,
    );
  }
}
