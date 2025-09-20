import 'package:intl/intl.dart';

import 'ocr_service.dart';

class ReceiptAmount {
  final double value;
  final double confidence;
  const ReceiptAmount(this.value, this.confidence);
}

class ReceiptIntelResult {
  final String? vendor;
  final DateTime? purchaseDate;
  final ReceiptAmount? subtotal;
  final ReceiptAmount? tax;
  final ReceiptAmount? total;
  final String? paymentMethod;
  final String? last4;
  final double confidence;

  const ReceiptIntelResult({
    this.vendor,
    this.purchaseDate,
    this.subtotal,
    this.tax,
    this.total,
    this.paymentMethod,
    this.last4,
    this.confidence = 0.0,
  });

  Map<String, dynamic> toJson() => {
        'vendor': vendor,
        'purchaseDate': purchaseDate?.toIso8601String(),
        'subtotal': subtotal?.value,
        'subtotalConfidence': subtotal?.confidence,
        'tax': tax?.value,
        'taxConfidence': tax?.confidence,
        'total': total?.value,
        'totalConfidence': total?.confidence,
        'paymentMethod': paymentMethod,
        'last4': last4,
        'confidence': confidence,
      };
}

class ReceiptIntelService {
  static final _dateFormats = <DateFormat>[
    DateFormat('MM/dd/yyyy'),
    DateFormat('MM/dd/yy'),
    DateFormat('M/d/yyyy'),
    DateFormat('M/d/yy'),
    DateFormat('yyyy-MM-dd'),
  ];

  static final _currencyRegex = RegExp(r'(\d+[\.,]\d{2})');
  static final _dateRegex = RegExp(r'(\d{1,4}[\-/]\d{1,2}[\-/]\d{1,4})');
  static final _cardRegex = RegExp(r'(?:x{2,}|\*{2,}|#)(\d{4})', caseSensitive: false);

  static const _totalKeywords = [
    'grand total',
    'amount due',
    'total',
    'balance due',
  ];

  static const _subtotalKeywords = ['subtotal', 'sub total'];
  static const _taxKeywords = ['tax', 'sales tax', 'vat'];

  static const _paymentKeywords = <String, String>{
    'visa': 'Visa',
    'mastercard': 'Mastercard',
    'master card': 'Mastercard',
    'american express': 'American Express',
    'amex': 'American Express',
    'discover': 'Discover',
    'cash': 'Cash',
    'debit': 'Debit',
  };

  static Future<ReceiptIntelResult> analyze(List<OcrPage> pages) async {
    if (pages.isEmpty) return const ReceiptIntelResult(confidence: 0);

    final lines = <String>[];
    for (final page in pages) {
      for (final line in page.lines) {
        final cleaned = line.text.trim();
        if (cleaned.isNotEmpty) {
          lines.add(cleaned);
        }
      }
    }

    final vendor = _detectVendor(lines);
    final date = _detectDate(lines);
    final subtotal = _detectAmount(lines, _subtotalKeywords);
    final tax = _detectAmount(lines, _taxKeywords);
    final total = _detectAmount(lines, _totalKeywords, preferBottom: true);
    final payment = _detectPayment(lines);
    final last4 = _detectLast4(lines);

    final confidences = [
      if (vendor != null) 0.2,
      if (date != null) 0.2,
      if (subtotal != null) subtotal.confidence * 0.1,
      if (tax != null) tax.confidence * 0.1,
      if (total != null) total.confidence * 0.3,
      if (payment != null) 0.05,
      if (last4 != null) 0.05,
    ];

    final confidence = confidences.isEmpty
        ? 0.0
        : (confidences.reduce((a, b) => a + b).clamp(0.0, 1.0)).toDouble();

    return ReceiptIntelResult(
      vendor: vendor,
      purchaseDate: date,
      subtotal: subtotal,
      tax: tax,
      total: total,
      paymentMethod: payment,
      last4: last4,
      confidence: confidence,
    );
  }

  static String? _detectVendor(List<String> lines) {
    for (final raw in lines.take(5)) {
      final line = raw.trim();
      if (line.length < 3) continue;
      if (_currencyRegex.hasMatch(line)) continue;
      if (line.toLowerCase().contains('receipt')) continue;
      if (_totalKeywords.any((k) => line.toLowerCase().contains(k))) continue;
      return line;
    }
    return null;
  }

  static DateTime? _detectDate(List<String> lines) {
    for (final line in lines) {
      final match = _dateRegex.firstMatch(line);
      if (match == null) continue;
      final candidate = match.group(0);
      if (candidate == null) continue;
      for (final format in _dateFormats) {
        try {
          final parsed = format.parseStrict(candidate.replaceAll('.', '/'));
          if (parsed.year > 1990 && parsed.year < 2100) {
            return parsed;
          }
        } catch (_) {
          continue;
        }
      }
    }
    return null;
  }

  static ReceiptAmount? _detectAmount(List<String> lines, List<String> keywords,
      {bool preferBottom = false}) {
    final searchLines = preferBottom ? lines.reversed : lines;
    for (final raw in searchLines) {
      final line = raw.toLowerCase();
      if (!keywords.any(line.contains)) continue;
      final match = _currencyRegex.firstMatch(raw.replaceAll(',', '.'));
      if (match == null) continue;
      final value = double.tryParse(match.group(1)!);
      if (value == null) continue;
      final confidence = keywords.length > 1 ? 0.8 : 0.7;
      return ReceiptAmount(value, confidence);
    }

    // fallback: search numeric line
    for (final raw in searchLines) {
      final match = _currencyRegex.firstMatch(raw.replaceAll(',', '.'));
      if (match == null) continue;
      final value = double.tryParse(match.group(1)!);
      if (value == null) continue;
      return ReceiptAmount(value, 0.4);
    }
    return null;
  }

  static String? _detectPayment(List<String> lines) {
    for (final value in lines) {
      final lower = value.toLowerCase();
      for (final entry in _paymentKeywords.entries) {
        if (lower.contains(entry.key)) {
          return entry.value;
        }
      }
    }
    return null;
  }

  static String? _detectLast4(List<String> lines) {
    for (final value in lines) {
      final match = _cardRegex.firstMatch(value.toLowerCase());
      if (match != null) {
        return match.group(1);
      }
    }
    return null;
  }
}
