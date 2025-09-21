import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'receipt_intel.dart';
import 'share_profile.dart';

class SharePayload {
  final File pdf;
  final File? metadataFile;
  final String summary;
  final String? subject;

  SharePayload({
    required this.pdf,
    required this.summary,
    this.metadataFile,
    this.subject,
  });

  List<XFile> toXFiles() {
    final files = <XFile>[
      XFile(
        pdf.path,
        mimeType: 'application/pdf',
        name: pdf.uri.pathSegments.isNotEmpty
            ? pdf.uri.pathSegments.last
            : p.basename(pdf.path),
      ),
    ];
    final meta = metadataFile;
    if (meta != null) {
      files.add(
        XFile(
          meta.path,
          mimeType: 'application/json',
          name: meta.uri.pathSegments.isNotEmpty
              ? meta.uri.pathSegments.last
              : p.basename(meta.path),
        ),
      );
    }
    return files;
  }

  void dispose() {
    final meta = metadataFile;
    if (meta != null) {
      unawaited(Future<void>.delayed(const Duration(minutes: 5), () async {
        if (await meta.exists()) {
          try {
            await meta.delete();
          } catch (_) {
            // Best-effort cleanup; ignore failures.
          }
        }
      }));
    }
  }
}

class ShareService {
  static const MethodChannel _channel = MethodChannel('share_targets');

  @visibleForTesting
  static Future<SharePayload> debugBuildPayload(
    File file, {
    ReceiptIntelResult? receipt,
    Map<String, dynamic>? metadata,
    String? documentType,
    String? subject,
    ShareProfile profile = ShareProfile.standard,
  }) {
    return _buildPayload(
      file,
      receipt: receipt,
      metadata: metadata,
      documentType: documentType,
      subject: subject,
      profile: profile,
    );
  }

  static Future<SharePayload> _buildPayload(
    File file, {
    ReceiptIntelResult? receipt,
    Map<String, dynamic>? metadata,
    String? documentType,
    String? subject,
    ShareProfile profile = ShareProfile.standard,
  }) async {
    metadata ??= receipt?.toJson();
    final summary = _summaryFor(
      file: file,
      receipt: receipt,
      metadata: metadata,
      documentType: documentType,
    );

    final effectiveSubject = _subjectForProfile(subject, profile);

    File? metadataFile;
    final sanitized = profile == ShareProfile.compact
        ? null
        : metadata != null
            ? _stripNulls(metadata)
            : null;
    if (sanitized != null && sanitized.isNotEmpty) {
      final enriched = <String, dynamic>{
        'documentType': documentType ?? _documentTypeFor(receipt, sanitized),
        'fileName': p.basename(file.path),
        'generatedAt': DateTime.now().toIso8601String(),
        'data': sanitized,
      };
      metadataFile = await _writeTempMetadataFile(
        p.basenameWithoutExtension(file.path),
        enriched,
      );
    }

    return SharePayload(
      pdf: file,
      metadataFile: metadataFile,
      summary: summary,
      subject: effectiveSubject,
    );
  }

  static Future<File> _writeTempMetadataFile(
    String baseName,
    Map<String, dynamic> payload,
  ) async {
    final dir = await getTemporaryDirectory();
    final file = File(
      p.join(dir.path,
          '${baseName}_${DateTime.now().millisecondsSinceEpoch}.json'),
    );
    await file.writeAsString(jsonEncode(payload), flush: true);
    return file;
  }

  static String? _subjectForProfile(String? subject, ShareProfile profile) {
    if (profile != ShareProfile.compact) {
      return subject;
    }
    if (subject == null || subject.trim().isEmpty) {
      return subject;
    }
    if (subject.contains('(Compact)')) {
      return subject;
    }
    return '$subject (Compact)';
  }

  static String _summaryFor({
    required File file,
    ReceiptIntelResult? receipt,
    Map<String, dynamic>? metadata,
    String? documentType,
  }) {
    final buffer = StringBuffer();
    final type = documentType ?? _documentTypeFor(receipt, metadata);
    buffer.writeln('Document: ${type ?? 'Document'}');
    buffer.writeln('File: ${p.basename(file.path)}');

    if (receipt != null) {
      if (receipt.vendor != null && receipt.vendor!.isNotEmpty) {
        buffer.writeln('Vendor: ${receipt.vendor}');
      }
      if (receipt.purchaseDate != null) {
        buffer.writeln(
          'Purchase date: ${DateFormat.yMMMd().format(receipt.purchaseDate!)}',
        );
      }
      if (receipt.total?.value != null) {
        final currency =
            NumberFormat.simpleCurrency().format(receipt.total!.value);
        buffer.writeln('Total: $currency');
      }
      if (receipt.paymentMethod != null) {
        final method = receipt.paymentMethod!;
        final suffix = receipt.last4 != null ? ' ending ${receipt.last4}' : '';
        buffer.writeln('Payment: $method$suffix');
      }
    } else if (metadata != null) {
      final docType = metadata['documentType'] as String?;
      if (docType != null && docType.isNotEmpty) {
        buffer.writeln('Type: $docType');
      }
      final vendor = metadata['vendor'] as String?;
      if (vendor != null && vendor.isNotEmpty) {
        buffer.writeln('Vendor: $vendor');
      }
      final total = metadata['total'];
      if (total is num) {
        buffer.writeln(
          'Total: ${NumberFormat.simpleCurrency().format(total)}',
        );
      }
      final expiry = metadata['expiryDate'] as String?;
      if (expiry != null && expiry.isNotEmpty) {
        buffer.writeln('Expiry: $expiry');
      }
      final redactions = metadata['redactions'] ?? metadata['redactionApplied'];
      if (redactions != null) {
        buffer.writeln('Redactions: $redactions');
      }
    }

    if (metadata != null) {
      final confidence = metadata['confidence'];
      if (confidence is num) {
        buffer.writeln('Confidence: ${(confidence * 100).round()}%');
      }
    }

    return buffer.toString().trim();
  }

  static String? _documentTypeFor(
    ReceiptIntelResult? receipt,
    Map<String, dynamic>? metadata,
  ) {
    if (metadata != null) {
      final raw = metadata['documentType'];
      if (raw is String && raw.isNotEmpty) return raw;
      if (metadata.containsKey('redactions') ||
          metadata.containsKey('redactionMasks') ||
          metadata.containsKey('watermark') ||
          metadata.containsKey('idFields')) {
        return 'id';
      }
    }
    if (receipt != null) return 'receipt';
    return null;
  }

  static Map<String, dynamic>? _stripNulls(Map<String, dynamic>? input) {
    if (input == null) return null;
    final result = <String, dynamic>{};
    input.forEach((key, value) {
      final cleaned = _cleanValue(value);
      if (cleaned != null) {
        result[key] = cleaned;
      }
    });
    return result;
  }

  static dynamic _cleanValue(dynamic value) {
    if (value == null) return null;
    if (value is Map<String, dynamic>) {
      final nested = _stripNulls(value);
      if (nested == null || nested.isEmpty) return null;
      return nested;
    }
    if (value is List) {
      final list = <dynamic>[];
      for (final element in value) {
        final cleaned = _cleanValue(element);
        if (cleaned == null) continue;
        if (cleaned is Map && cleaned.isEmpty) continue;
        list.add(cleaned);
      }
      return list.isEmpty ? null : list;
    }
    return value;
  }

  static Future<void> shareFile(
    File file, {
    String? subject,
    ReceiptIntelResult? receipt,
    Map<String, dynamic>? metadata,
    String? documentType,
    ShareProfile profile = ShareProfile.standard,
  }) async {
    final payload = await _buildPayload(
      file,
      receipt: receipt,
      metadata: metadata,
      documentType: documentType,
      subject: subject,
      profile: profile,
    );
    try {
      // ignore: deprecated_member_use
      await Share.shareXFiles(
        payload.toXFiles(),
        subject: payload.subject,
        text: payload.summary,
      );
    } finally {
      payload.dispose();
    }
  }

  static Future<void> shareAirdrop(
    File file, {
    ReceiptIntelResult? receipt,
    Map<String, dynamic>? metadata,
    String? documentType,
    ShareProfile profile = ShareProfile.standard,
  }) async {
    final payload = await _buildPayload(
      file,
      receipt: receipt,
      metadata: metadata,
      documentType: documentType,
      profile: profile,
    );
    try {
      await _channel.invokeMethod('airdrop', {
        'path': file.path,
        'summaryText': payload.summary,
        'metadataPath': payload.metadataFile?.path,
        'metadataMime':
            payload.metadataFile != null ? 'application/json' : null,
      });
    } on PlatformException {
      // ignore: deprecated_member_use
      await Share.shareXFiles(
        payload.toXFiles(),
        text: payload.summary,
      );
    } on MissingPluginException {
      // ignore: deprecated_member_use
      await Share.shareXFiles(
        payload.toXFiles(),
        text: payload.summary,
      );
    } finally {
      payload.dispose();
    }
  }

  static Future<void> shareEmail(
    File file, {
    String? subject,
    String? body,
    ReceiptIntelResult? receipt,
    Map<String, dynamic>? metadata,
    String? documentType,
    ShareProfile profile = ShareProfile.standard,
  }) async {
    final payload = await _buildPayload(
      file,
      receipt: receipt,
      metadata: metadata,
      documentType: documentType,
      subject: subject ?? 'My Scan',
      profile: profile,
    );
    try {
      await _channel.invokeMethod('email', {
        'path': file.path,
        'subject': payload.subject ?? subject ?? 'My Scan',
        'body': body ?? payload.summary,
        'summaryText': payload.summary,
        'metadataPath': payload.metadataFile?.path,
        'metadataMime':
            payload.metadataFile != null ? 'application/json' : null,
      });
    } on PlatformException {
      // ignore: deprecated_member_use
      await Share.shareXFiles(
        payload.toXFiles(),
        subject: payload.subject,
        text: body ?? payload.summary,
      );
    } on MissingPluginException {
      // ignore: deprecated_member_use
      await Share.shareXFiles(
        payload.toXFiles(),
        subject: payload.subject,
        text: body ?? payload.summary,
      );
    } finally {
      payload.dispose();
    }
  }

  static Future<void> shareSms(
    File file, {
    String? body,
    ReceiptIntelResult? receipt,
    Map<String, dynamic>? metadata,
    String? documentType,
    ShareProfile profile = ShareProfile.standard,
  }) async {
    final payload = await _buildPayload(
      file,
      receipt: receipt,
      metadata: metadata,
      documentType: documentType,
      profile: profile,
    );
    final text = body ?? payload.summary;
    try {
      await _channel.invokeMethod('sms', {
        'path': file.path,
        'body': text,
        'summaryText': payload.summary,
        'metadataPath': payload.metadataFile?.path,
        'metadataMime':
            payload.metadataFile != null ? 'application/json' : null,
      });
    } on PlatformException {
      // ignore: deprecated_member_use
      await Share.shareXFiles(
        payload.toXFiles(),
        text: text,
      );
    } on MissingPluginException {
      // ignore: deprecated_member_use
      await Share.shareXFiles(
        payload.toXFiles(),
        text: text,
      );
    } finally {
      payload.dispose();
    }
  }

  static Future<void> shareWhatsApp(
    File file, {
    String? text,
    ReceiptIntelResult? receipt,
    Map<String, dynamic>? metadata,
    String? documentType,
    ShareProfile profile = ShareProfile.standard,
  }) async {
    final payload = await _buildPayload(
      file,
      receipt: receipt,
      metadata: metadata,
      documentType: documentType,
      profile: profile,
    );
    try {
      await _channel.invokeMethod('whatsapp', {
        'path': file.path,
        'text': text ?? payload.summary,
        'summaryText': payload.summary,
        'metadataPath': payload.metadataFile?.path,
        'metadataMime':
            payload.metadataFile != null ? 'application/json' : null,
      });
    } on PlatformException {
      // ignore: deprecated_member_use
      await Share.shareXFiles(
        payload.toXFiles(),
        text: text ?? payload.summary,
      );
    } on MissingPluginException {
      // ignore: deprecated_member_use
      await Share.shareXFiles(
        payload.toXFiles(),
        text: text ?? payload.summary,
      );
    } finally {
      payload.dispose();
    }
  }
}
