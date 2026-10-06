import 'dart:convert';
import 'dart:io' show File;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'web_downloader_stub.dart'
    if (dart.library.html) 'web_downloader_web.dart' as web_downloader;

/// Helper class for downloading and uploading backup files.
///
/// Designed to work seamlessly across Web (Chrome) and Mobile / Desktop.
class FileHelper {
  /// Downloads or saves a JSON string as a .json file to the user's device.
  static Future<String?> downloadJsonFile({
    required String fileName,
    required String content,
  }) async {
    // 1. On Web: Use browser-native blob download (avoids FilePicker.saveFile UnimplementedError)
    if (kIsWeb) {
      final downloaded = await web_downloader.downloadWebFile(
        fileName: fileName,
        content: content,
      );
      if (downloaded) {
        return fileName;
      }
      throw Exception('Failed to initiate browser file download.');
    }

    // 2. On Desktop / Mobile: file_picker saveFile dialog
    final bytes = Uint8List.fromList(utf8.encode(content));
    final result = await FilePicker.platform.saveFile(
      dialogTitle: 'Save Passwords Backup',
      fileName: fileName,
      type: FileType.custom,
      allowedExtensions: ['json'],
      bytes: bytes,
    );

    // Explicitly write the content to disk on Desktop/Mobile to guarantee
    // the file is created with full contents (Windows file_picker often only returns the path)
    if (result != null && !kIsWeb) {
      String filePath = result;
      if (!filePath.toLowerCase().endsWith('.json')) {
        filePath = '$filePath.json';
      }
      final file = File(filePath);
      await file.writeAsBytes(bytes, flush: true);
      return filePath;
    }

    return result;
  }

  /// Opens the device file picker so the user can select and upload a .json file.
  /// Returns the text content of the JSON file, or null if cancelled.
  static Future<String?> pickAndReadJsonFile() async {
    final result = await FilePicker.platform.pickFiles(
      dialogTitle: 'Select Passwords Backup (.json)',
      type: FileType.custom,
      allowedExtensions: ['json'],
      withData: true, // Ensures file bytes are loaded into memory for web and desktop
    );

    if (result == null || result.files.isEmpty) {
      return null; // User cancelled
    }

    final picked = result.files.first;

    // 1. If file path is available on native desktop/mobile, prefer reading directly from file
    if (!kIsWeb && picked.path != null && picked.path!.isNotEmpty) {
      final file = File(picked.path!);
      if (await file.exists()) {
        final content = await file.readAsString();
        if (content.trim().isNotEmpty) {
          return content;
        }
      }
    }

    // 2. Fallback to in-memory bytes (Web or when path is unavailable)
    if (picked.bytes != null && picked.bytes!.isNotEmpty) {
      final content = utf8.decode(picked.bytes!);
      if (content.trim().isNotEmpty) {
        return content;
      }
    }

    throw Exception('The selected file is empty or could not be read.');
  }
}
