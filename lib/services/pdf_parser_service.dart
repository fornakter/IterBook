import 'dart:io';
import 'package:pdfrx/pdfrx.dart';

/// Result of PDF parsing operation
class PdfParseResult {
  final bool success;
  final String? text;
  final int pageCount;
  final String? errorMessage;
  final PdfErrorType? errorType;

  const PdfParseResult({
    required this.success,
    this.text,
    this.pageCount = 0,
    this.errorMessage,
    this.errorType,
  });

  factory PdfParseResult.success({
    required String text,
    required int pageCount,
  }) {
    return PdfParseResult(
      success: true,
      text: text,
      pageCount: pageCount,
    );
  }

  factory PdfParseResult.failure({
    required String message,
    required PdfErrorType type,
  }) {
    return PdfParseResult(
      success: false,
      errorMessage: message,
      errorType: type,
    );
  }
}

/// Types of PDF parsing errors
enum PdfErrorType {
  fileNotFound,
  fileNotReadable,
  invalidFormat,
  encrypted,
  corrupted,
  emptyDocument,
  unknown,
}

/// Result of word extraction
class WordExtractionResult {
  final bool success;
  final List<String> words;
  final int totalWordCount;
  final String? errorMessage;

  const WordExtractionResult({
    required this.success,
    required this.words,
    required this.totalWordCount,
    this.errorMessage,
  });

  factory WordExtractionResult.success(List<String> words) {
    return WordExtractionResult(
      success: true,
      words: words,
      totalWordCount: words.length,
    );
  }

  factory WordExtractionResult.failure(String message) {
    return WordExtractionResult(
      success: false,
      words: const [],
      totalWordCount: 0,
      errorMessage: message,
    );
  }
}

/// Service for parsing PDF files and extracting text
class PdfParserService {
  /// Extract text from entire PDF document
  Future<PdfParseResult> extractText(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        return PdfParseResult.failure(
          message: 'File not found: $filePath',
          type: PdfErrorType.fileNotFound,
        );
      }

      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) {
        return PdfParseResult.failure(
          message: 'File is empty',
          type: PdfErrorType.emptyDocument,
        );
      }

      final document = await PdfDocument.openFile(filePath);

      final int pageCount = document.pages.length;
      if (pageCount == 0) {
        document.dispose();
        return PdfParseResult.failure(
          message: 'PDF has no pages',
          type: PdfErrorType.emptyDocument,
        );
      }

      final StringBuffer textBuffer = StringBuffer();
      for (int i = 0; i < pageCount; i++) {
        final page = document.pages[i];
        final pageText = await page.loadText();
        final text = pageText.fullText;
        if (text.isNotEmpty) {
          if (textBuffer.isNotEmpty) {
            textBuffer.write('\n\n');
          }
          textBuffer.write(text);
        }
      }

      final String extractedText = textBuffer.toString();
      document.dispose();

      if (extractedText.trim().isEmpty) {
        return PdfParseResult.failure(
          message: 'No extractable text found (PDF may contain only images)',
          type: PdfErrorType.emptyDocument,
        );
      }

      return PdfParseResult.success(
        text: extractedText,
        pageCount: pageCount,
      );
    } on FileSystemException catch (e) {
      return PdfParseResult.failure(
        message: 'Cannot read file: ${e.message}',
        type: PdfErrorType.fileNotReadable,
      );
    } catch (e) {
      final errorMsg = e.toString().toLowerCase();
      if (errorMsg.contains('password') || errorMsg.contains('encrypted')) {
        return PdfParseResult.failure(
          message: 'PDF is password protected',
          type: PdfErrorType.encrypted,
        );
      }
      if (errorMsg.contains('invalid') || errorMsg.contains('corrupt')) {
        return PdfParseResult.failure(
          message: 'Invalid PDF format: $e',
          type: PdfErrorType.invalidFormat,
        );
      }
      return PdfParseResult.failure(
        message: 'Error parsing PDF: $e',
        type: PdfErrorType.unknown,
      );
    }
  }

  /// Extract text from a specific page (0-indexed)
  Future<PdfParseResult> extractTextFromPage(String filePath, int pageIndex) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        return PdfParseResult.failure(
          message: 'File not found: $filePath',
          type: PdfErrorType.fileNotFound,
        );
      }

      final document = await PdfDocument.openFile(filePath);
      final int pageCount = document.pages.length;

      if (pageIndex < 0 || pageIndex >= pageCount) {
        document.dispose();
        return PdfParseResult.failure(
          message: 'Page index $pageIndex out of range (0-${pageCount - 1})',
          type: PdfErrorType.invalidFormat,
        );
      }

      final page = document.pages[pageIndex];
      final pageText = await page.loadText();
      final text = pageText.fullText;

      document.dispose();

      return PdfParseResult.success(
        text: text,
        pageCount: pageCount,
      );
    } catch (e) {
      final errorMsg = e.toString().toLowerCase();
      if (errorMsg.contains('invalid') || errorMsg.contains('corrupt')) {
        return PdfParseResult.failure(
          message: 'Invalid PDF format: $e',
          type: PdfErrorType.invalidFormat,
        );
      }
      return PdfParseResult.failure(
        message: 'Error parsing PDF: $e',
        type: PdfErrorType.unknown,
      );
    }
  }

  /// Extract text from a range of pages (0-indexed, inclusive)
  Future<PdfParseResult> extractTextFromRange(
    String filePath,
    int startPage,
    int endPage,
  ) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        return PdfParseResult.failure(
          message: 'File not found: $filePath',
          type: PdfErrorType.fileNotFound,
        );
      }

      final document = await PdfDocument.openFile(filePath);
      final int pageCount = document.pages.length;

      if (startPage < 0 || startPage >= pageCount) {
        document.dispose();
        return PdfParseResult.failure(
          message: 'Start page $startPage out of range',
          type: PdfErrorType.invalidFormat,
        );
      }

      if (endPage < startPage || endPage >= pageCount) {
        document.dispose();
        return PdfParseResult.failure(
          message: 'End page $endPage invalid',
          type: PdfErrorType.invalidFormat,
        );
      }

      final StringBuffer textBuffer = StringBuffer();
      for (int i = startPage; i <= endPage; i++) {
        final page = document.pages[i];
        final pageText = await page.loadText();
        final text = pageText.fullText;
        if (text.isNotEmpty) {
          if (textBuffer.isNotEmpty) {
            textBuffer.write('\n\n');
          }
          textBuffer.write(text);
        }
      }

      document.dispose();

      return PdfParseResult.success(
        text: textBuffer.toString(),
        pageCount: pageCount,
      );
    } catch (e) {
      return PdfParseResult.failure(
        message: 'Error parsing PDF: $e',
        type: PdfErrorType.unknown,
      );
    }
  }

  /// Get page count without extracting text
  Future<int> getPageCount(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        return 0;
      }

      final document = await PdfDocument.openFile(filePath);
      final int pageCount = document.pages.length;
      document.dispose();

      return pageCount;
    } catch (e) {
      return 0;
    }
  }

  /// Extract words from text with various options
  WordExtractionResult extractWords(
    String text, {
    bool toLowerCase = false,
    bool removePunctuation = true,
    bool removeNumbers = false,
    int minWordLength = 1,
    int maxWordLength = 100,
  }) {
    if (text.isEmpty) {
      return WordExtractionResult.failure('No text provided');
    }

    try {
      String processedText = text;

      if (removePunctuation) {
        processedText = processedText.replaceAll(
          RegExp(r'[^\w\s\u00C0-\u024F]'),
          ' ',
        );
      }

      if (toLowerCase) {
        processedText = processedText.toLowerCase();
      }

      List<String> words = processedText
          .split(RegExp(r'\s+'))
          .where((word) => word.isNotEmpty)
          .toList();

      if (removeNumbers) {
        words = words.where((word) => !RegExp(r'^\d+$').hasMatch(word)).toList();
      }

      words = words.where((word) {
        return word.length >= minWordLength && word.length <= maxWordLength;
      }).toList();

      return WordExtractionResult.success(words);
    } catch (e) {
      return WordExtractionResult.failure('Error extracting words: $e');
    }
  }

  /// Extract unique words from text
  WordExtractionResult extractUniqueWords(
    String text, {
    bool toLowerCase = true,
    bool removePunctuation = true,
    bool removeNumbers = false,
    int minWordLength = 1,
  }) {
    final result = extractWords(
      text,
      toLowerCase: toLowerCase,
      removePunctuation: removePunctuation,
      removeNumbers: removeNumbers,
      minWordLength: minWordLength,
    );

    if (!result.success) {
      return result;
    }

    final uniqueWords = result.words.toSet().toList();
    return WordExtractionResult.success(uniqueWords);
  }

  /// Get word frequency map
  Map<String, int> getWordFrequency(
    String text, {
    bool toLowerCase = true,
    bool removePunctuation = true,
    bool removeNumbers = false,
    int minWordLength = 1,
  }) {
    final result = extractWords(
      text,
      toLowerCase: toLowerCase,
      removePunctuation: removePunctuation,
      removeNumbers: removeNumbers,
      minWordLength: minWordLength,
    );

    if (!result.success) {
      return {};
    }

    final frequency = <String, int>{};
    for (final word in result.words) {
      frequency[word] = (frequency[word] ?? 0) + 1;
    }

    return frequency;
  }

  /// Check if PDF is valid and readable
  Future<bool> isValidPdf(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        return false;
      }

      final bytes = await file.readAsBytes();
      if (bytes.length < 5) {
        return false;
      }

      final header = String.fromCharCodes(bytes.sublist(0, 5));
      if (!header.startsWith('%PDF-')) {
        return false;
      }

      final document = await PdfDocument.openFile(filePath);
      final isValid = document.pages.isNotEmpty;
      document.dispose();

      return isValid;
    } catch (e) {
      return false;
    }
  }

  /// Check if PDF is encrypted/password protected
  Future<bool> isEncrypted(String filePath) async {
    try {
      final document = await PdfDocument.openFile(filePath);
      document.dispose();
      return false;
    } catch (e) {
      final errorMsg = e.toString().toLowerCase();
      return errorMsg.contains('password') || errorMsg.contains('encrypted');
    }
  }

  /// Get PDF metadata
  Future<Map<String, String?>> getMetadata(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        return {};
      }

      final document = await PdfDocument.openFile(filePath);

      final metadata = <String, String?>{
        'pageCount': document.pages.length.toString(),
      };

      document.dispose();
      return metadata;
    } catch (e) {
      return {};
    }
  }
}
