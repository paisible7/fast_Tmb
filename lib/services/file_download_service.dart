import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

class FileDownloadService {
  static const MethodChannel _channel = MethodChannel('com.example.fl/downloads');

  Future<String?> saveFileToDownloads(List<int> bytes, String fileName, {String? mimeType}) async {
    if (Platform.isAndroid) {
      // On Android < Q, WRITE_EXTERNAL_STORAGE may be required
      var status = await Permission.storage.status;
      if (!status.isGranted) {
        status = await Permission.storage.request();
      }

      if (!status.isGranted) return null;

      final inferredMime = mimeType ?? _inferMimeType(fileName);
      try {
        final uriString = await _channel.invokeMethod<String>('saveToDownloads', {
          'bytes': Uint8List.fromList(bytes),
          'fileName': fileName,
          'mimeType': inferredMime,
        });
        return uriString; // content:// or file://
      } on PlatformException {
        return null;
      }
    }
    return null;
  }

  Future<String?> pickAndSaveWithDialog(List<int> bytes, String fileName, {String? mimeType}) async {
    if (Platform.isAndroid) {
      // SAF handles permissions; still request legacy if needed for completeness (<Q)
      var status = await Permission.storage.status;
      if (!status.isGranted) {
        await Permission.storage.request();
      }

      final inferredMime = mimeType ?? _inferMimeType(fileName);
      try {
        final uriString = await _channel.invokeMethod<String>('pickAndSaveDocument', {
          'bytes': Uint8List.fromList(bytes),
          'fileName': fileName,
          'mimeType': inferredMime,
        });
        return uriString;
      } on PlatformException {
        return null;
      }
    }
    return null;
  }

  String _inferMimeType(String fileName) {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.pdf')) return 'application/pdf';
    if (lower.endsWith('.csv')) return 'text/csv';
    return 'application/octet-stream';
  }
}
