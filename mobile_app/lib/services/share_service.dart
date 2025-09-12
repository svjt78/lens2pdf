import 'dart:io';

import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

class ShareService {
  static const MethodChannel _channel = MethodChannel('share_targets');

  static Future<void> shareFile(File file, {String? subject, String? text}) async {
    final xfile = XFile(file.path, mimeType: 'application/pdf', name: file.uri.pathSegments.last);
    await Share.shareXFiles([xfile], subject: subject, text: text);
  }

  static Future<void> shareAirdrop(File file) async {
    try {
      await _channel.invokeMethod('airdrop', {
        'path': file.path,
      });
    } on PlatformException {
      await shareFile(file);
    } on MissingPluginException {
      await shareFile(file);
    }
  }

  static Future<void> shareEmail(File file, {String? subject, String? body}) async {
    try {
      await _channel.invokeMethod('email', {
        'path': file.path,
        'subject': subject ?? 'My Scan',
        'body': body ?? '',
      });
    } on PlatformException {
      await shareFile(file, subject: subject, text: body);
    } on MissingPluginException {
      await shareFile(file, subject: subject, text: body);
    }
  }

  static Future<void> shareSms(File file, {String? body}) async {
    try {
      await _channel.invokeMethod('sms', {
        'path': file.path,
        'body': body ?? '',
      });
    } on PlatformException {
      await shareFile(file, text: body);
    } on MissingPluginException {
      await shareFile(file, text: body);
    }
  }

  static Future<void> shareWhatsApp(File file, {String? text}) async {
    try {
      await _channel.invokeMethod('whatsapp', {
        'path': file.path,
        'text': text ?? '',
      });
    } on PlatformException {
      await shareFile(file, text: text);
    } on MissingPluginException {
      await shareFile(file, text: text);
    }
  }
}
