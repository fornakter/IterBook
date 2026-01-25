import 'package:flutter/foundation.dart';
import 'pdf_parser_service.dart';
import 'rsvp_service.dart';
import 'book_service.dart';
import 'reading_progress_service.dart';
import '../models/book.dart';

/// Result of starting a reading session
class ReadingSessionResult {
  final bool success;
  final String? errorMessage;
  final int? totalWords;
  final int? pageCount;
  final bool resumed; // True if resuming from saved position

  const ReadingSessionResult({
    required this.success,
    this.errorMessage,
    this.totalWords,
    this.pageCount,
    this.resumed = false,
  });

  factory ReadingSessionResult.success({
    required int totalWords,
    required int pageCount,
    bool resumed = false,
  }) {
    return ReadingSessionResult(
      success: true,
      totalWords: totalWords,
      pageCount: pageCount,
      resumed: resumed,
    );
  }

  factory ReadingSessionResult.failure(String message) {
    return ReadingSessionResult(
      success: false,
      errorMessage: message,
    );
  }
}

/// Service for managing a complete reading session
/// Integrates PdfParserService, RsvpService, and ReadingProgressService
class ReadingSessionService extends ChangeNotifier {
  final PdfParserService _pdfParser = PdfParserService();
  final RsvpService _rsvpService = RsvpService();
  final BookService? _bookService;
  late final ReadingProgressService? _progressService;

  // Session data
  Book? _currentBook;
  int _pageCount = 0;
  bool _isLoading = false;
  String? _errorMessage;

  // Configuration
  final int autoSaveInterval;

  ReadingSessionService({
    BookService? bookService,
    this.autoSaveInterval = 10,
  }) : _bookService = bookService {
    // Create progress service if BookService is provided
    if (_bookService != null) {
      _progressService = ReadingProgressService(
        bookService: _bookService,
        rsvpService: _rsvpService,
        autoSaveInterval: autoSaveInterval,
      );
    } else {
      _progressService = null;
    }
  }

  // Getters
  RsvpService get rsvp => _rsvpService;
  ReadingProgressService? get progress => _progressService;
  Book? get currentBook => _currentBook;
  int get pageCount => _pageCount;
  bool get isLoading => _isLoading;
  bool get hasError => _errorMessage != null;
  String? get errorMessage => _errorMessage;
  bool get hasSession => _currentBook != null && _rsvpService.hasContent;
  bool get canSaveProgress => _progressService != null;

  /// Start a new reading session from a Book
  /// If book has saved progress, resumes from that position
  Future<ReadingSessionResult> startSession(Book book, {bool forceRestart = false}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // Parse PDF
      final result = await _pdfParser.extractText(book.filePath);

      if (!result.success) {
        _isLoading = false;
        _errorMessage = result.errorMessage;
        notifyListeners();
        return ReadingSessionResult.failure(
          result.errorMessage ?? 'Failed to parse PDF',
        );
      }

      // Extract words
      final wordsResult = _pdfParser.extractWords(
        result.text!,
        removePunctuation: false, // Keep punctuation for natural reading
        minWordLength: 1,
      );

      if (!wordsResult.success || wordsResult.words.isEmpty) {
        _isLoading = false;
        _errorMessage = 'No words found in PDF';
        notifyListeners();
        return ReadingSessionResult.failure('No words found in PDF');
      }

      // Load words into RSVP service
      _rsvpService.loadWords(wordsResult.words);
      _currentBook = book;
      _pageCount = result.pageCount;
      _isLoading = false;
      _errorMessage = null;

      // Check for saved progress and resume if available
      bool resumed = false;
      if (!forceRestart && _progressService != null) {
        await _progressService.startTracking(book);

        // Resume from saved position
        if (book.currentWordIndex > 0 && book.currentWordIndex < wordsResult.totalWordCount) {
          _rsvpService.jumpToIndex(book.currentWordIndex);
          resumed = true;
        }

        // Restore saved WPM
        if (book.lastWpm > 0) {
          _rsvpService.setWpm(book.lastWpm);
        }

        // Update book with total words if not set
        if (book.totalWords != wordsResult.totalWordCount) {
          await _bookService?.initializeRsvpSession(
            book.id,
            totalWords: wordsResult.totalWordCount,
          );
        }
      }

      notifyListeners();

      return ReadingSessionResult.success(
        totalWords: wordsResult.totalWordCount,
        pageCount: result.pageCount,
        resumed: resumed,
      );
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Error starting session: $e';
      notifyListeners();
      return ReadingSessionResult.failure('Error starting session: $e');
    }
  }

  /// Start session from specific page range
  Future<ReadingSessionResult> startSessionFromPages(
    Book book,
    int startPage,
    int endPage,
  ) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await _pdfParser.extractTextFromRange(
        book.filePath,
        startPage,
        endPage,
      );

      if (!result.success) {
        _isLoading = false;
        _errorMessage = result.errorMessage;
        notifyListeners();
        return ReadingSessionResult.failure(
          result.errorMessage ?? 'Failed to parse PDF',
        );
      }

      final wordsResult = _pdfParser.extractWords(
        result.text!,
        removePunctuation: false,
        minWordLength: 1,
      );

      if (!wordsResult.success || wordsResult.words.isEmpty) {
        _isLoading = false;
        _errorMessage = 'No words found in selected pages';
        notifyListeners();
        return ReadingSessionResult.failure('No words found in selected pages');
      }

      _rsvpService.loadWords(wordsResult.words);
      _currentBook = book;
      _pageCount = result.pageCount;
      _isLoading = false;
      _errorMessage = null;

      notifyListeners();

      return ReadingSessionResult.success(
        totalWords: wordsResult.totalWordCount,
        pageCount: result.pageCount,
      );
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Error starting session: $e';
      notifyListeners();
      return ReadingSessionResult.failure('Error starting session: $e');
    }
  }

  /// End current session and save progress
  Future<void> endSession() async {
    // Save progress before ending
    if (_progressService != null) {
      await _progressService.stopTracking();
    }

    _rsvpService.stop();
    _rsvpService.clear();
    _currentBook = null;
    _pageCount = 0;
    _errorMessage = null;
    notifyListeners();
  }

  /// Manually save current progress
  Future<void> saveProgress() async {
    await _progressService?.saveProgress();
  }

  /// Reset progress for current book
  Future<void> resetProgress() async {
    if (_currentBook != null && _progressService != null) {
      await _progressService.resetProgress(_currentBook!.id);
    }
  }

  /// Get session statistics
  Map<String, dynamic> getSessionStats() {
    return {
      'book': _currentBook?.title,
      'pageCount': _pageCount,
      'hasError': hasError,
      'errorMessage': _errorMessage,
      ...(_rsvpService.getStatistics()),
    };
  }

  @override
  void dispose() {
    _progressService?.dispose();
    _rsvpService.dispose();
    super.dispose();
  }
}
