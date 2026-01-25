import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import '../models/book.dart';

/// Service for handling file picking operations
class FilePickerService {
  /// Pick a PDF file from device storage
  /// Returns a Book object if successful, null if cancelled or error
  Future<Book?> pickPdfFile() async {
    try {
      // Open file picker with PDF filter
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        allowMultiple: false,
      );

      if (result == null || result.files.isEmpty) {
        // User cancelled the picker
        return null;
      }

      final file = result.files.first;

      // Get file path
      final filePath = file.path;
      if (filePath == null) {
        debugPrint('Error: File path is null');
        return null;
      }

      // Verify file exists
      final fileExists = await File(filePath).exists();
      if (!fileExists) {
        debugPrint('Error: File does not exist at path: $filePath');
        return null;
      }

      // Extract file name without extension for title
      final fileName = path.basenameWithoutExtension(filePath);

      // Generate unique ID based on file path and timestamp
      final bookId = '${fileName}_${DateTime.now().millisecondsSinceEpoch}';

      // Create Book object
      final book = Book(
        id: bookId,
        title: fileName,
        filePath: filePath,
        dateAdded: DateTime.now(),
      );

      debugPrint('Successfully picked PDF: ${book.title}');
      return book;
    } catch (e) {
      debugPrint('Error picking PDF file: $e');
      return null;
    }
  }

  /// Validate if file is a PDF
  bool isPdfFile(String filePath) {
    final extension = path.extension(filePath).toLowerCase();
    return extension == '.pdf';
  }

  /// Get file size in bytes
  Future<int?> getFileSize(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        return await file.length();
      }
      return null;
    } catch (e) {
      debugPrint('Error getting file size: $e');
      return null;
    }
  }

  /// Format file size to human-readable string
  String formatFileSize(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    } else if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    } else if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    } else {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    }
  }

  /// Check if file at path is accessible
  Future<bool> isFileAccessible(String filePath) async {
    try {
      final file = File(filePath);
      return await file.exists();
    } catch (e) {
      debugPrint('Error checking file accessibility: $e');
      return false;
    }
  }
}
