import 'package:intl/intl.dart';

import 'library_repository.dart';

class MonthKey implements Comparable<MonthKey> {
  final int year;
  final int month;

  const MonthKey(this.year, this.month);

  factory MonthKey.fromDate(DateTime date) => MonthKey(date.year, date.month);

  DateTime get asDate => DateTime(year, month);

  bool includes(DateTime date) => date.year == year && date.month == month;

  String label({DateFormat? format}) {
    final fmt = format ?? DateFormat('MMM yyyy');
    return fmt.format(asDate);
  }

  @override
  int compareTo(MonthKey other) {
    if (year != other.year) return year.compareTo(other.year);
    return month.compareTo(other.month);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MonthKey && other.year == year && other.month == month;
  }

  @override
  int get hashCode => Object.hash(year, month);
}

class MonthFacet {
  final MonthKey key;
  final int count;

  const MonthFacet({required this.key, required this.count});

  String label() => key.label();
}

class TagFacet {
  final String tag;
  final int count;

  const TagFacet({required this.tag, required this.count});
}

class LibraryFilters {
  final MonthKey? month;
  final Set<String> tags;
  final String query;

  LibraryFilters({
    this.month,
    Set<String>? tags,
    String? query,
  })  : tags = {
          if (tags != null) ...tags.map((tag) => tag.trim().toLowerCase()),
        },
        query = (query ?? '').trim();

  bool get hasActiveFilters => month != null || tags.isNotEmpty;

  bool matches(ScanEntry entry) {
    if (month != null) {
      final date = entry.receipt?.purchaseDate ?? entry.modified;
      if (!month!.includes(date)) return false;
    }

    if (tags.isNotEmpty) {
      final entryTags = entry.tags.map((e) => e.toLowerCase()).toSet();
      for (final tag in tags) {
        if (!entryTags.contains(tag)) return false;
      }
    }

    if (query.isNotEmpty && !entry.matchesQuery(query)) {
      return false;
    }

    return true;
  }
}

class LibraryFilterResult {
  final List<ScanEntry> items;
  final List<MonthFacet> monthFacets;
  final List<TagFacet> tagFacets;

  const LibraryFilterResult({
    required this.items,
    required this.monthFacets,
    required this.tagFacets,
  });
}

class LibraryFilterEngine {
  static LibraryFilterResult apply(
    List<ScanEntry> entries,
    LibraryFilters filters,
  ) {
    final monthFacets = _buildMonthFacets(entries);
    final tagFacets = _buildTagFacets(entries);

    final filtered = entries.where(filters.matches).toList();

    return LibraryFilterResult(
      items: filtered,
      monthFacets: monthFacets,
      tagFacets: tagFacets,
    );
  }

  static List<MonthFacet> _buildMonthFacets(List<ScanEntry> entries) {
    final counts = <MonthKey, int>{};
    for (final entry in entries) {
      final date = entry.receipt?.purchaseDate ?? entry.modified;
      final key = MonthKey.fromDate(date);
      counts[key] = (counts[key] ?? 0) + 1;
    }
    final facets = counts.entries
        .map((e) => MonthFacet(key: e.key, count: e.value))
        .toList();
    facets.sort((a, b) => b.key.compareTo(a.key));
    return facets;
  }

  static List<TagFacet> _buildTagFacets(List<ScanEntry> entries) {
    final counts = <String, int>{};
    final displayLabels = <String, String>{};
    for (final entry in entries) {
      for (final tag in entry.tags) {
        final lower = tag.toLowerCase();
        counts[lower] = (counts[lower] ?? 0) + 1;
        displayLabels.putIfAbsent(lower, () => tag);
      }
    }
    final facets = counts.entries
        .map(
          (e) => TagFacet(tag: displayLabels[e.key] ?? e.key, count: e.value),
        )
        .toList();
    facets.sort((a, b) {
      if (b.count != a.count) return b.count.compareTo(a.count);
      return a.tag.toLowerCase().compareTo(b.tag.toLowerCase());
    });
    return facets;
  }
}
